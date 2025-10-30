extends GdUnitLiteTestCase

const LOGISTICS_SYSTEM := preload("res://scripts/systems/logistics_system.gd")

func _baseline_logistics_entry() -> Dictionary:
    return {
        "id": "baseline",
        "supply_radius": 2,
        "route_types": ["ring", "road"],
        "convoy_spawn_threshold": 2,
        "intercept_chance": 0.0,
        "links": {},
    }

func _forward_entry() -> Dictionary:
    return {
        "id": "forward",
        "supply_radius": 3,
        "route_types": ["ring", "road", "convoy"],
        "convoy_spawn_threshold": 1,
        "intercept_chance": 1.0,
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

    var zones: Array = payload.get("supply_zones", [])
    var core_tiles := zones.filter(func(zone): return zone.get("supply_level") == "core")
    var isolated_tiles := zones.filter(func(zone): return zone.get("supply_level") == "isolated")

    asserts.is_true(core_tiles.size() > 0, "Tiles near the center should be in the core supply ring")
    asserts.is_true(isolated_tiles.size() > 0, "Tiles far from depots should be isolated")

func test_weather_updates_movement_and_flow() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    var logistics_entries := [_baseline_logistics_entry()]
    system.configure(logistics_entries, _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    system.set_weather_state("rain")
    var rain_payload := system.get_last_payload()
    var rain_zone := rain_payload.get("supply_zones", [])[0]
    asserts.is_equal(0.8, rain_payload.get("flow_multiplier"), "Rain should reduce global logistics flow")
    asserts.is_true(rain_zone.get("movement_cost") <= 1.6, "Movement cost should reflect weather penalties")

    system.set_weather_state("sunny")
    var sunny_payload := system.get_last_payload()
    asserts.is_true(sunny_payload.get("flow_multiplier") > rain_payload.get("flow_multiplier"), "Sunny flow should recover")

func test_convoys_can_be_intercepted() -> void:
    var system: LogisticsSystem = LOGISTICS_SYSTEM.new()
    system.set_rng_seed(42)
    system.configure([_forward_entry()], _weather_entries())
    system.configure_map(_simple_map(), _supply_centers(), _routes())

    # Spawn convoys immediately and guarantee interception via intercept chance 1.0
    system.advance_turn()
    var payload := system.get_last_payload()
    var routes := payload.get("routes", [])
    var intercepted := routes.filter(func(route): return route.get("convoy", {}).get("last_event") == "intercepted")
    asserts.is_true(intercepted.size() > 0, "High interception chance should flag intercepted convoys")
    var breaks := payload.get("breaks", [])
    var intercept_breaks := breaks.filter(func(entry): return entry.get("type", "") == "convoy_intercept")
    asserts.is_true(intercept_breaks.size() > 0, "Intercepted convoys should emit break telemetry")
    asserts.is_true(float(payload.get("competence_penalty", 0.0)) > 0.0, "Break telemetry should quantify competence penalties")
