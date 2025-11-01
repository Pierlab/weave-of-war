extends GdUnitLiteTestCase

const COMBAT_SYSTEM := preload("res://scripts/systems/combat_system.gd")
const ESPIONAGE_SYSTEM := preload("res://scripts/systems/espionage_system.gd")

class StubCombatEventBus:
    var payloads: Array = []
    var formations: Array = []

    func emit_combat_resolved(payload: Dictionary) -> void:
        payloads.append(payload)

    func emit_formation_changed(payload: Dictionary) -> void:
        formations.append(payload)

class StubIntelEventBus:
    var payloads: Array = []
    var intel_reveals: Array = []
    var fog_updates: Array = []

    func emit_espionage_ping(payload: Dictionary) -> void:
        payloads.append(payload.duplicate(true))

    func emit_intel_intent_revealed(payload: Dictionary) -> void:
        intel_reveals.append(payload.duplicate(true))

    func emit_fog_of_war_updated(payload: Dictionary) -> void:
        fog_updates.append(payload.duplicate(true))

func _find_tile(snapshot: Dictionary, tile_id: String) -> Dictionary:
    var entries: Array = snapshot.get("visibility", [])
    for entry in entries:
        if str(entry.get("tile_id", "")) == tile_id:
            return entry
    return {}

func test_combat_system_resolves_three_pillars() -> void:
    var system: CombatSystem = COMBAT_SYSTEM.new()
    system.set_rng_seed(1)
    var formations := [
        {
            "id": "shield_wall",
            "pillar_modifiers": {"position": 0.4, "impulse": -0.2, "information": -0.1},
            "posture": "defensive",
            "competence_weight": {"logistics": 0.2},
        },
        {
            "id": "advance_column",
            "pillar_modifiers": {"position": -0.1, "impulse": 0.3, "information": 0.0},
            "posture": "aggressive",
            "competence_weight": {"tactics": 0.1},
        },
        {
            "id": "wedge",
            "pillar_modifiers": {"position": 0.1, "impulse": 0.4, "information": -0.05},
            "posture": "aggressive",
            "competence_weight": {"tactics": 0.25},
        },
        {
            "id": "screen",
            "pillar_modifiers": {"position": -0.05, "impulse": 0.1, "information": 0.2},
            "posture": "balanced",
            "competence_weight": {"strategy": 0.1},
        }
    ]

    system.configure(
        [
            {
                "id": "infantry",
                "combat_profile": {"position": 1.1, "impulse": 0.9, "information": 0.6},
                "recon_profile": {"detection": 0.3, "counter_intel": 0.2},
                "competence_synergy": {"tactics": 2, "strategy": 1, "logistics": 1},
                "default_formations": ["shield_wall", "advance_column"],
            },
            {
                "id": "cavalry",
                "combat_profile": {"position": 0.9, "impulse": 1.4, "information": 0.7},
                "recon_profile": {"detection": 0.45, "counter_intel": 0.25},
                "competence_synergy": {"tactics": 3, "strategy": 1, "logistics": 2},
                "default_formations": ["wedge", "screen"],
            }
        ],
        [
            {
                "id": "advance",
                "pillar_weights": {"position": 0.35, "impulse": 0.6, "information": 0.25},
                "intel_profile": {"signal_strength": 0.65, "counter_intel": 0.1},
            },
            {
                "id": "fortify",
                "pillar_weights": {"position": 0.75, "impulse": 0.3, "information": 0.35},
                "intel_profile": {"signal_strength": 0.45, "counter_intel": 0.35},
            }
        ],
        [
            {
                "id": "force",
                "effects": {
                    "intel_visibility_modifier": 0.0,
                    "combat_bonus": {"position": 0.05, "impulse": 0.35, "information": -0.05},
                }
            }
        ],
        [
            {
                "id": "sunny",
                "combat_modifiers": {"position": 1.0, "impulse": 1.0, "information": 1.0},
            }
        ],
        formations
    )
    system.set_active_doctrine("force")
    system.set_current_weather("sunny")
    var stub_bus := StubCombatEventBus.new()
    system.event_bus = stub_bus

    var engagement := {
        "engagement_id": "vs_test",
        "order_id": "advance",
        "attacker_unit_ids": ["infantry", "cavalry"],
        "defender_unit_ids": ["infantry"],
        "terrain": "forest",
        "target_hex": "2,2",
        "intel_confidence": 0.6,
        "espionage_bonus": 0.2,
        "defender_posture": "hold",
        "attacker_bonus": {"information": 0.1},
    }

    var result := system.resolve_engagement(engagement)
    asserts.is_true(not result.is_empty(), "Combat resolution should return a payload")
    asserts.is_equal("attacker", result.get("victor", ""), "Attacker should win at least two pillars")

    var pillars: Dictionary = result.get("pillars", {})
    asserts.is_true(pillars.has("position"), "Position pillar should be evaluated")
    asserts.is_true(pillars.has("impulse"), "Impulse pillar should be evaluated")
    asserts.is_true(pillars.has("information"), "Information pillar should be evaluated")

    var intel := result.get("intel", {})
    asserts.is_equal(0.8, intel.get("confidence", 0.0), "Intel confidence should reflect base plus espionage bonus")
    asserts.is_true(stub_bus.payloads.size() == 1, "Combat system should emit a telemetry payload via the event bus")

    var summary: Dictionary = result.get("pillar_summary", {})
    asserts.is_true(summary.has("attacker_total"), "Pillar summary should expose attacker total strength")
    asserts.is_true(summary.has("decisive_pillars"), "Pillar summary should include decisive pillar metadata")

    var units := result.get("units", {})
    asserts.is_true(units.has("attacker"), "Units payload should list attacking units")
    asserts.is_true(units.has("defender"), "Units payload should list defending units")
    asserts.is_true(units.get("attacker", []).size() == 2, "Attacker units payload should map each contributor")
    asserts.is_true(units.get("defender", []).size() == 1, "Defender units payload should map each contributor")
    var first_attacker: Dictionary = units.get("attacker", [])[0]
    asserts.is_true(first_attacker.has("status"), "Each unit state should expose a status label")

    system._on_logistics_update({
        "turn": 3,
        "logistics_id": "vs_logistics",
        "supply_zones": [
            {"tile_id": "2,2", "logistics_flow": 0.6, "movement_cost": 1.4, "supply_level": "strained"}
        ],
        "supply_deficits": [
            {"tile_id": "2,2", "severity": "critical"}
        ],
    })
    system.set_rng_seed(1)
    var strained := system.resolve_engagement(engagement)
    var strained_position := strained.get("pillars", {}).get("position", {}).get("attacker", 0.0)
    var baseline_position := pillars.get("position", {}).get("attacker", 0.0)
    asserts.is_true(strained_position < baseline_position, "Critical logistics should reduce attacker position strength")

    var baseline_impulse := pillars.get("impulse", {}).get("attacker", 0.0)
    system.set_rng_seed(1)
    var changed := system.set_unit_formation("infantry", "advance_column")
    asserts.is_true(changed, "Infantry formation should switch to advance column")
    changed = system.set_unit_formation("cavalry", "wedge")
    asserts.is_true(changed, "Cavalry formation should accept wedge posture")
    system._on_competence_reallocated({
        "allocations": {"tactics": 3.0, "strategy": 2.0, "logistics": 1.0},
    })
    var empowered := system.resolve_engagement(engagement)
    var boosted_impulse := empowered.get("pillars", {}).get("impulse", {}).get("attacker", 0.0)
    asserts.is_true(boosted_impulse > baseline_impulse, "Competence and formation bonuses should lift impulse strength")
    asserts.is_true(stub_bus.formations.size() >= 2, "Formation changes should emit telemetry payloads")

func test_espionage_ping_reflects_visibility_and_noise() -> void:
    var system: EspionageSystem = ESPIONAGE_SYSTEM.new()
    system.set_rng_seed(2)
    system.configure([
        {"id": "sunny", "intel_noise": 0.0},
        {"id": "mist", "intel_noise": 0.35},
    ])
    system.configure_map({"0,0": {}, "1,0": {}})
    var stub_bus := StubIntelEventBus.new()
    system.event_bus = stub_bus

    system.ingest_logistics_payload({
        "turn": 1,
        "supply_zones": [
            {"tile_id": "0,0", "supply_level": "core"},
            {"tile_id": "1,0", "supply_level": "fringe"}
        ],
    })

    system._on_assistant_order_packet({
        "intents": {
            "advance": {"intention": "offense", "confidence": 0.7, "target": "0,0"}
        },
        "orders": [
            {"order_id": "advance", "target": "0,0"}
        ]
    })

    var sunny_ping := system.perform_ping("0,0", 0.5, {"source": "test"})
    asserts.is_true(sunny_ping.get("success", false), "High visibility ping should usually succeed")
    asserts.is_equal("offense", sunny_ping.get("intention", ""), "Successful ping should reveal stored intention")
    asserts.is_true(stub_bus.payloads.size() == 1, "Ping should emit telemetry")
    asserts.is_true(stub_bus.intel_reveals.size() == 1, "Successful ping should emit an intel_intent_revealed event")
    asserts.is_equal("offense", sunny_ping.get("intent_category", ""), "Intention category should mirror revealed intention")
    asserts.is_true(sunny_ping.has("roll"), "Ping should record the RNG roll")
    asserts.is_true(sunny_ping.has("visibility_before"), "Ping should expose visibility deltas")
    asserts.is_true(float(sunny_ping.get("visibility_after", 0.0)) >= float(sunny_ping.get("visibility_before", 0.0)), "Recon success should not reduce visibility")
    asserts.is_equal("test", sunny_ping.get("order_id", ""), "Source metadata should propagate to the payload")
    asserts.is_equal(0.7, float(sunny_ping.get("intention_confidence", 0.0)), "Stored intention confidence should be surfaced")

    system._on_weather_changed({"weather_id": "mist"})
    system.ingest_logistics_payload({
        "turn": 2,
        "supply_zones": [
            {"tile_id": "0,0", "supply_level": "fringe"}
        ],
    })

    var mist_ping := system.perform_ping("0,0", 0.2)
    asserts.is_true(mist_ping.get("confidence", 1.0) < sunny_ping.get("confidence", 0.0), "Mist should reduce confidence")
    asserts.is_equal(1, stub_bus.intel_reveals.size(), "Follow-up pings without new intentions should not duplicate reveal events")
    var snapshot := system.get_fog_snapshot()
    asserts.is_true(snapshot.size() > 0, "Fog snapshot should expose tracked tiles")
    asserts.is_true(mist_ping.has("visibility_before"), "Fog pings should expose before visibility")
    asserts.is_true(float(mist_ping.get("visibility_after", 0.0)) >= float(mist_ping.get("visibility_before", 0.0)), "Visibility should not drop below tracked baseline")
    asserts.is_true(mist_ping.has("roll"), "Fog pings should capture RNG roll even without metadata")

func test_recon_order_triggers_automatic_ping() -> void:
    var system: EspionageSystem = ESPIONAGE_SYSTEM.new()
    system.set_rng_seed(3)
    system.configure_map({"0,0": {}, "1,0": {}})
    var stub_bus := StubIntelEventBus.new()
    system.event_bus = stub_bus
    system.ingest_logistics_payload({
        "turn": 2,
        "supply_zones": [
            {"tile_id": "0,0", "supply_level": "core"},
            {"tile_id": "1,0", "supply_level": "isolated"},
        ],
    })

    system._on_order_issued({
        "order_id": "recon_probe",
        "metadata": {
            "competence_cost": {"tactics": 1.0},
            "intel_profile": {"signal_strength": 0.6},
        },
    })

    asserts.is_equal(1, stub_bus.payloads.size(), "Recon order should emit an espionage ping automatically.")
    var ping := stub_bus.payloads.back()
    asserts.is_equal("1,0", ping.get("target", ""), "Ping should target the lowest visibility tile.")
    asserts.is_equal("recon_probe", ping.get("source", ""), "Ping context should reflect the recon order id.")
    asserts.is_true(ping.has("probe_strength"), "Recon ping payload should record probe strength.")
    asserts.is_true(float(ping.get("detection_bonus", 0.0)) >= 0.04, "Competence spend should translate into a detection bonus.")

func test_fog_updates_emit_snapshots_for_visibility_changes() -> void:
    var system: EspionageSystem = ESPIONAGE_SYSTEM.new()
    system.configure([
        {"id": "clear", "intel_noise": 0.0},
    ])
    var stub_bus := StubIntelEventBus.new()
    system.event_bus = stub_bus
    system.configure_map({"0,0": {}, "0,1": {}})

    asserts.is_equal(1, stub_bus.fog_updates.size(), "Configuring the map should emit an initial fog snapshot")
    var initial_snapshot: Dictionary = stub_bus.fog_updates[0]
    var initial_core := _find_tile(initial_snapshot, "0,0")
    asserts.is_true(not initial_core.is_empty(), "Initial snapshot should expose each tracked tile")
    asserts.is_equal(0.1, float(initial_core.get("visibility", 0.0)), "Tiles should start at the default visibility level")

    system.ingest_logistics_payload({
        "turn": 1,
        "supply_zones": [
            {"tile_id": "0,0", "supply_level": "core"},
            {"tile_id": "0,1", "supply_level": "isolated"},
        ],
    })

    asserts.is_equal(2, stub_bus.fog_updates.size(), "Logistics updates should broadcast a refreshed fog snapshot")
    var boosted_snapshot: Dictionary = stub_bus.fog_updates.back()
    var boosted_core := _find_tile(boosted_snapshot, "0,0")
    asserts.is_equal(0.85, float(boosted_core.get("visibility", 0.0)), "Core supply tiles should jump to 0.85 visibility")
    asserts.is_equal(0.1, float(boosted_core.get("counter_intel", 0.0)), "Logistics boosts should trim counter-intel pressure")

    system._on_turn_started(2)

    asserts.is_equal(3, stub_bus.fog_updates.size(), "Turn ticks should decay fog and emit a new snapshot")
    var decayed_snapshot: Dictionary = stub_bus.fog_updates.back()
    var decayed_core := _find_tile(decayed_snapshot, "0,0")
    asserts.is_true(float(decayed_core.get("visibility", 0.0)) < float(boosted_core.get("visibility", 0.0)), "Visibility should decay after each turn")
    asserts.is_equal(0.15, float(decayed_core.get("counter_intel", 0.0)), "Counter-intel should regrow by 0.05 each turn")

func test_ping_success_rate_tracks_effective_confidence() -> void:
    var system: EspionageSystem = ESPIONAGE_SYSTEM.new()
    system.set_rng_seed(7)
    system.configure([
        {"id": "clear", "intel_noise": 0.0},
    ])
    system.configure_map({"0,0": {}})
    var stub_bus := StubIntelEventBus.new()
    system.event_bus = stub_bus

    var runs := 200
    var successes := 0
    for i in range(runs):
        system._fog_by_tile["0,0"] = {"visibility": 0.2, "counter_intel": 0.0}
        var payload := system.perform_ping("0,0", 0.4)
        if payload.get("success", false):
            successes += 1

    var success_rate := float(successes) / float(runs)
    var expected := 0.6
    asserts.is_true(absf(success_rate - expected) <= 0.1, "Ping success rate should approximate the effective confidence (0.60 ± 0.10)")

func test_intel_decay_limits_visibility_floor() -> void:
    var system: EspionageSystem = ESPIONAGE_SYSTEM.new()
    system.configure([{"id": "clear", "intel_noise": 0.0}])
    system.configure_map({"0,0": {}})
    var stub_bus := StubIntelEventBus.new()
    system.event_bus = stub_bus

    system._fog_by_tile["0,0"] = {"visibility": 0.12, "counter_intel": 0.9}
    system._on_turn_started(5)

    var snapshot: Dictionary = stub_bus.fog_updates.back()
    var tile := _find_tile(snapshot, "0,0")
    asserts.is_equal(0.1, float(tile.get("visibility", 0.0)), "Visibility should not decay below the global floor")
    asserts.is_equal(0.95, float(tile.get("counter_intel", 0.0)), "Counter-intel growth should clamp at 1.0")
