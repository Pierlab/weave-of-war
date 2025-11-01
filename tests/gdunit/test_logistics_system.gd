extends GdUnitLiteTestCase

const LOGISTICS_SYSTEM := preload("res://scripts/systems/logistics_system.gd")

class MockEventBus:
    var updates: Array = []
    var breaks: Array = []
    var weather_events: Array = []

    func emit_logistics_update(payload: Dictionary) -> void:
        updates.append(payload)

    func emit_logistics_break(payload: Dictionary) -> void:
        breaks.append(payload)

    func emit_weather_changed(payload: Dictionary) -> void:
        weather_events.append(payload)

func _baseline_logistics_entry() -> Dictionary:
    return {
        "id": "baseline",
        "supply_radius": 2,
        "route_types": ["ring", "road"],
        "convoy_spawn_threshold": 2,
        "intercept_chance": 0.0,
        "deficit_flow_threshold": 0.8,
        "links": {},
    }

func _forward_entry() -> Dictionary:
    return {
        "id": "forward",
        "supply_radius": 3,
        "route_types": ["ring", "road", "convoy"],
        "convoy_spawn_threshold": 1,
        "intercept_chance": 1.0,
        "deficit_flow_threshold": 0.9,
        "links": {},
    }

func _weather_entries() -> Array:
    return [
        {
            "id": "sunny",
            "movement_modifier": 1.0,
            "logistics_flow_modifier": 1.0,
        },
        {
            "id": "rain",
            "movement_modifier": 0.8,
            "logistics_flow_modifier": 0.7,
        },
        {
            "id": "mist",
            "movement_modifier": 0.9,
            "logistics_flow_modifier": 0.8,
        },
    ]

func _stormy_weather_entries() -> Array:
    return [
        {
            "id": "clear",
            "movement_modifier": 1.0,
            "logistics_flow_modifier": 1.0,
        },
        {
            "id": "storm",
            "movement_modifier": 0.5,
            "logistics_flow_modifier": 0.2,
        },
        {
            "id": "mist",
            "movement_modifier": 0.9,
            "logistics_flow_modifier": 0.7,
        },
    ]

func _simple_map() -> Dictionary:
    return {
        "0,0": {"q": 0, "r": 0, "terrain": "plains", "base_movement_cost": 1.0},
        "1,0": {"q": 1, "r": 0, "terrain": "forest", "base_movement_cost": 2.0},
        "2,0": {"q": 2, "r": 0, "terrain": "hill", "base_movement_cost": 3.0},
        "0,1": {"q": 0, "r": 1, "terrain": "plains", "base_movement_cost": 1.0},
        "1,1": {"q": 1, "r": 1, "terrain": "forest", "base_movement_cost": 2.0},
        "2,1": {"q": 2, "r": 1, "terrain": "hill", "base_movement_cost": 3.0},
    }

func _supply_centers() -> Array:
    return [
        {"id": "main", "q": 0, "r": 0, "type": "city"},
        {"id": "front", "q": 2, "r": 1, "type": "depot"},
    ]

func _routes() -> Array:
    return [
        {"id": "ring", "type": "ring", "path": ["0,0", "1,0", "1,1", "0,1"]},
        {"id": "road", "type": "road", "path": ["0,0", "1,0", "2,0", "2,1"]},
    ]

func test_supply_levels_follow_distance() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    system.configure([_baseline_logistics_entry()], _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    var payload := system.get_last_payload()
    asserts.is_true(payload.has("supply_zones"), "Logistics payload should contain supply zones")
    asserts.is_true(payload.has("reachable_tiles"), "Logistics payload should surface reachable tiles")
    asserts.is_true(payload.has("supply_deficits"), "Logistics payload should surface supply deficits")

    var zones: Array = payload.get("supply_zones", [])
    var core_tiles := zones.filter(func(zone): return zone.get("supply_level") == "core")
    var isolated_tiles := zones.filter(func(zone): return zone.get("supply_level") == "isolated")

    asserts.is_true(core_tiles.size() > 0, "Tiles near the center should be in the core supply ring")
    asserts.is_true(isolated_tiles.size() > 0, "Tiles far from depots should be isolated")

    var reachable: Array = payload.get("reachable_tiles", [])
    var deficits: Array = payload.get("supply_deficits", [])
    asserts.is_true(reachable.size() > 0, "Reachable list should include at least one tile")
    var critical_deficits := deficits.filter(func(entry): return entry.get("severity") == "critical")
    asserts.is_true(critical_deficits.size() > 0, "Supply deficits should classify isolated tiles as critical")

func test_weather_updates_movement_and_flow() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    var logistics_entries := [_baseline_logistics_entry()]
    system.configure(logistics_entries, _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    system.set_weather_state("rain")
    var rain_payload := system.get_last_payload()
    var rain_zone := rain_payload.get("supply_zones", [])[0]
    asserts.is_equal(0.7, rain_payload.get("flow_multiplier"), "Rain should reduce global logistics flow")
    asserts.is_true(rain_zone.get("movement_cost") <= 1.6, "Movement cost should reflect weather penalties")

    var rain_adjustments := rain_payload.get("weather_adjustments", {})
    asserts.is_true(rain_adjustments is Dictionary and not rain_adjustments.is_empty(), "Weather adjustments should be surfaced")
    asserts.is_equal(0.7, rain_adjustments.get("final_flow_multiplier"), "Weather adjustments should capture the final flow multiplier")
    asserts.is_equal(0.3, rain_adjustments.get("flow_penalty"), "Flow penalty should reflect throughput loss compared to clear weather")
    asserts.is_true(String(rain_adjustments.get("notes", "")).length() > 0, "Weather adjustments should provide QA notes")

    system.set_weather_state("sunny")
    var sunny_payload := system.get_last_payload()
    asserts.is_true(sunny_payload.get("flow_multiplier") > rain_payload.get("flow_multiplier"), "Sunny flow should recover")

func test_competence_allocation_modifies_logistics_flow() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    system.configure([_baseline_logistics_entry()], _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    var baseline_payload := system.get_last_payload()
    var baseline_flow := float(baseline_payload.get("flow_multiplier", 1.0))

    system._on_competence_reallocated({
        "allocations": {
            "logistics": 4.0,
            "tactics": 1.5,
            "strategy": 1.5,
        },
        "config": {
            "logistics": {"base_allocation": 2.0, "logistics_penalty_multiplier": 1.2},
            "tactics": {"base_allocation": 2.0},
            "strategy": {"base_allocation": 2.0},
        },
    })

    var boosted_payload := system.get_last_payload()
    asserts.is_true(float(boosted_payload.get("flow_multiplier", 0.0)) > baseline_flow,
        "Increasing logistics competence should raise the flow multiplier")
    asserts.is_true(float(boosted_payload.get("competence_multiplier", 1.0)) > 1.0,
        "Payload should expose competence multiplier above 1 when logistics focus increases")

    system._on_competence_reallocated({
        "allocations": {
            "logistics": 0.6,
            "tactics": 1.5,
            "strategy": 1.5,
        },
        "config": {
            "logistics": {"base_allocation": 2.0, "logistics_penalty_multiplier": 1.2},
            "tactics": {"base_allocation": 2.0},
            "strategy": {"base_allocation": 2.0},
        },
    })

    var reduced_payload := system.get_last_payload()
    asserts.is_true(float(reduced_payload.get("flow_multiplier", 1.0)) < float(boosted_payload.get("flow_multiplier", 1.0)),
        "Reducing logistics competence should shrink the resulting flow multiplier")
    asserts.is_true(float(reduced_payload.get("competence_multiplier", 1.0)) < float(boosted_payload.get("competence_multiplier", 1.0)),
        "Competence multiplier should decrease when allocations drop below baseline")

func test_convoys_can_be_intercepted() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    system.set_rng_seed(42)
    var mock_bus := MockEventBus.new()
    system.event_bus = mock_bus
    system.configure([_forward_entry()], _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    # Spawn convoys immediately and guarantee interception via intercept chance 1.0
    system.advance_turn()
    var payload := system.get_last_payload()
    var routes := payload.get("routes", [])
    var intercepted := routes.filter(func(route): return route.get("convoy", {}).get("last_event") == "intercepted")
    asserts.is_true(intercepted.size() > 0, "High interception chance should flag intercepted convoys")
    var convoy_statuses: Array = payload.get("convoy_statuses", [])
    asserts.is_true(convoy_statuses.size() >= routes.size(), "Convoy status summary should mirror listed routes")
    var intercepted_statuses := convoy_statuses.filter(func(status): return status.get("last_event") == "intercepted")
    asserts.is_true(intercepted_statuses.size() > 0, "Convoy statuses should surface interception state")
    for route in routes:
        var risk := route.get("intercept_risk", {})
        asserts.is_true(risk is Dictionary and risk.has("effective"), "Route payload should expose intercept risk breakdown")
        asserts.is_true(float(risk.get("effective", 0.0)) >= float(risk.get("base", 0.0)), "Effective intercept chance should include weather penalties")
    var breaks := payload.get("breaks", [])
    var intercept_breaks := breaks.filter(func(entry): return entry.get("type", "") == "convoy_intercept")
    asserts.is_true(intercept_breaks.size() > 0, "Intercepted convoys should emit break telemetry")
    asserts.is_true(float(payload.get("competence_penalty", 0.0)) > 0.0, "Break telemetry should quantify competence penalties")
    asserts.is_true(mock_bus.breaks.size() > 0, "Dedicated logistics_break events should be emitted for analytics")

func test_payload_tracks_reachability_thresholds() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    var entry := _baseline_logistics_entry()
    entry["deficit_flow_threshold"] = 0.95
    system.configure([entry], _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    var payload := system.get_last_payload()
    var reachable: Array = payload.get("reachable_tiles", [])
    var deficits: Array = payload.get("supply_deficits", [])

    var reachable_isolated := reachable.filter(func(tile): return tile.get("supply_level", "isolated") == "isolated")
    asserts.is_equal(0, reachable_isolated.size(), "Reachable tiles should exclude isolated zones")
    var warning_deficits := deficits.filter(func(tile): return tile.get("severity") == "warning")
    asserts.is_true(warning_deficits.size() > 0, "Threshold should mark fringe tiles with low flow as warnings")

func test_reachable_tiles_shrink_under_storm_penalties() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    var entry := _baseline_logistics_entry()
    entry["links"] = {
        "weather_modifiers": {
            "storm": -0.8,
        }
    }
    entry["supply_radius"] = 2
    system.set_rng_seed(1)
    var bus := MockEventBus.new()
    system.event_bus = bus
    system.configure([entry], _stormy_weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    asserts.is_true(bus.updates.size() > 0, "Configuring logistics should emit an initial payload")
    var clear_payload: Dictionary = bus.updates.back()
    var clear_reachable: Array = clear_payload.get("reachable_tiles", [])
    asserts.is_true(clear_reachable.size() > 0, "Clear weather should expose reachable tiles")

    bus.updates.clear()
    system.set_weather_state("storm", "manual_test")
    asserts.is_true(bus.updates.size() > 0, "Weather change should emit a logistics payload")
    var storm_payload: Dictionary = bus.updates.back()
    var storm_reachable: Array = storm_payload.get("reachable_tiles", [])
    asserts.is_true(storm_reachable.size() < clear_reachable.size(), "Storm penalties should reduce the number of reachable tiles")
    for entry_payload in storm_reachable:
        asserts.is_true(float(entry_payload.get("logistics_flow", 1.0)) <= 0.5, "Storm flow should cap reachable logistics flow at or below 0.5")

func test_convoy_intercept_break_emits_once_per_event() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    var entry := _forward_entry()
    entry["weather_rotation_turns"] = 2
    entry["intercept_chance"] = 1.0
    entry["convoy_spawn_threshold"] = 1
    var bus := MockEventBus.new()
    system.event_bus = bus
    system.set_rng_seed(7)
    system.configure([entry], _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    bus.breaks.clear()
    system.advance_turn()
    asserts.is_equal(1, bus.breaks.size(), "First intercept should produce a single break event")

    system.advance_turn()
    asserts.is_equal(1, bus.breaks.size(), "Follow-up turns should not duplicate the same intercept break")

    system.advance_turn()
    asserts.is_equal(2, bus.breaks.size(), "A new convoy interception should emit a fresh break event")

func test_weather_rotation_uses_configured_cadence() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    var entry := _baseline_logistics_entry()
    entry["weather_rotation_turns"] = 2
    entry["links"] = {
        "weather_modifiers": {
            "rain": -0.2,
            "mist": -0.1,
        }
    }
    var bus := MockEventBus.new()
    system.event_bus = bus
    system.configure([entry], _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    bus.weather_events.clear()
    bus.updates.clear()

    system.advance_turn()
    asserts.is_equal(0, bus.weather_events.size(), "Weather should not rotate before the cadence threshold")
    asserts.is_true(bus.updates.size() == 1, "Each turn should emit a logistics update payload")
    var first_turn_payload: Dictionary = bus.updates.back()
    asserts.is_equal("sunny", first_turn_payload.get("weather_id"))

    bus.updates.clear()
    system.advance_turn()
    asserts.is_equal(1, bus.weather_events.size(), "Weather rotation should fire when cadence threshold is met")
    var rotation_event: Dictionary = bus.weather_events.back()
    asserts.is_equal("rotation", rotation_event.get("reason"))
    asserts.is_equal(2, rotation_event.get("turn"))

    asserts.is_true(bus.updates.size() > 0, "Rotation should trigger a fresh logistics payload")
    var rotation_payload: Dictionary = bus.updates.back()
    asserts.is_equal(rotation_event.get("weather_id"), rotation_payload.get("weather_id"), "Logistics payload should adopt the rotated weather state")
    asserts.is_true(rotation_payload.get("flow_multiplier") < first_turn_payload.get("flow_multiplier"), "Weather penalties should affect flow after rotation")

    bus.updates.clear()
    system.advance_turn()
    asserts.is_equal(1, bus.weather_events.size(), "Cadence should prevent back-to-back weather rotations")
