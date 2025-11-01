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

    func emit_espionage_ping(payload: Dictionary) -> void:
        payloads.append(payload)

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

    system._on_weather_changed({"weather_id": "mist"})
    system.ingest_logistics_payload({
        "turn": 2,
        "supply_zones": [
            {"tile_id": "0,0", "supply_level": "fringe"}
        ],
    })

    var mist_ping := system.perform_ping("0,0", 0.2)
    asserts.is_true(mist_ping.get("confidence", 1.0) < sunny_ping.get("confidence", 0.0), "Mist should reduce confidence")
    var snapshot := system.get_fog_snapshot()
    asserts.is_true(snapshot.size() > 0, "Fog snapshot should expose tracked tiles")
