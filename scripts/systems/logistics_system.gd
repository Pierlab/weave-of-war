class_name LogisticsSystem
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const TERRAIN_DATA := preload("res://scenes/map/terrain_data.gd")

@export var map_columns := 6
@export var map_rows := 5

var event_bus: EventBusAutoload
var data_loader: DataLoaderAutoload

var _terrain_lookup: Dictionary = {}
var _terrain_definitions: Dictionary = {}
var _supply_centers: Array = []
var _routes: Array = []
var _convoys_by_route: Dictionary = {}
var _logistics_by_id: Dictionary = {}
var _weather_by_id: Dictionary = {}
var _weather_sequence: Array = []
var _current_logistics_id := ""
var _current_weather_id := ""
var _turn_counter := 0
var _visible := false
var _weather_rotation_turns := 0
var _last_payload: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _pending_breaks: Array = []
var _previous_supply_levels: Dictionary = {}
var _weather_controlled_externally := false

func _ready() -> void:
    setup(EVENT_BUS.get_instance(), DATA_LOADER.get_instance())

func setup(event_bus_ref: EventBusAutoload, data_loader_ref: DataLoaderAutoload) -> void:
    event_bus = event_bus_ref
    data_loader = data_loader_ref
    _terrain_definitions = TERRAIN_DATA.get_default()
    _rng.randomize()

    _generate_default_map()
    _configure_default_network()

    if data_loader and data_loader.is_ready():
        configure(data_loader.list_logistics_states(), data_loader.list_weather_states())

    if event_bus:
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.turn_started.is_connected(_on_turn_started):
            event_bus.turn_started.connect(_on_turn_started)
        if not event_bus.logistics_toggled.is_connected(_on_logistics_toggled):
            event_bus.logistics_toggled.connect(_on_logistics_toggled)
        if not event_bus.weather_changed.is_connected(_on_weather_changed):
            event_bus.weather_changed.connect(_on_weather_changed)

    _recalculate_state("ready")

func configure(logistics_entries: Array, weather_entries: Array) -> void:
    _logistics_by_id.clear()
    _weather_by_id.clear()
    _weather_sequence.clear()
    _weather_controlled_externally = false

    for entry in logistics_entries:
        if entry is Dictionary and entry.has("id"):
            _logistics_by_id[entry.get("id")] = entry
    for entry in weather_entries:
        if entry is Dictionary and entry.has("id"):
            var weather_id := str(entry.get("id"))
            _weather_by_id[weather_id] = entry
            if not _weather_sequence.has(weather_id):
                _weather_sequence.append(weather_id)

    if _current_logistics_id.is_empty() and not _logistics_by_id.is_empty():
        _current_logistics_id = str(_logistics_by_id.keys()[0])
    elif not _logistics_by_id.has(_current_logistics_id) and not _logistics_by_id.is_empty():
        _current_logistics_id = str(_logistics_by_id.keys()[0])

    _apply_logistics_map(_logistics_by_id.get(_current_logistics_id, {}))
    _ingest_terrain_from_data_loader()
    if _current_weather_id.is_empty() and _weather_sequence.size() > 0:
        _current_weather_id = str(_weather_sequence[0])
    elif not _weather_by_id.has(_current_weather_id) and _weather_sequence.size() > 0:
        _current_weather_id = str(_weather_sequence[0])

    _update_weather_rotation_turns()
    _ensure_convoy_states()
    _recalculate_state("configure")

func set_rng_seed(seed: int) -> void:
    _rng.seed = seed

func set_logistics_state(logistics_id: String) -> void:
    if logistics_id.is_empty() or not _logistics_by_id.has(logistics_id):
        return
    _current_logistics_id = logistics_id
    _apply_logistics_map(_logistics_by_id.get(_current_logistics_id, {}))
    _update_weather_rotation_turns()
    _ensure_convoy_states()
    _recalculate_state("state_change")

func set_weather_state(weather_id: String, reason := "manual") -> void:
    if weather_id.is_empty() or not _weather_by_id.has(weather_id):
        return
    _current_weather_id = weather_id
    _recalculate_state("weather_change")
    if event_bus:
        event_bus.emit_weather_changed({
            "weather_id": weather_id,
            "name": _weather_by_id.get(weather_id, {}).get("name", weather_id),
            "effects": _weather_by_id.get(weather_id, {}).get("effects", ""),
            "turn": _turn_counter,
            "reason": reason,
            "source": "logistics_system",
        })

func configure_map(terrain_tiles: Dictionary, supply_centers: Array, routes: Array) -> void:
    _terrain_lookup = terrain_tiles.duplicate(true)
    _supply_centers = supply_centers.duplicate(true)
    _routes = routes.duplicate(true)
    _ensure_convoy_states()
    _recalculate_state("map_configured")

func get_last_payload() -> Dictionary:
    return _last_payload.duplicate(true)

func advance_turn() -> void:
    _turn_counter += 1
    _maybe_rotate_weather()
    _advance_convoys()
    _recalculate_state("turn")

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(collections.get("logistics", []), collections.get("weather", []))

func _on_turn_started(_turn_number: int) -> void:
    advance_turn()

func _on_logistics_toggled(is_visible: bool) -> void:
    _visible = is_visible
    _recalculate_state("visibility")

func _on_weather_changed(payload: Dictionary) -> void:
    if payload.get("source", "") == "logistics_system":
        return
    var weather_id := str(payload.get("weather_id", ""))
    if weather_id.is_empty():
        return
    _weather_controlled_externally = true
    if weather_id == _current_weather_id and str(payload.get("reason", "")) == "tick":
        return
    _current_weather_id = weather_id
    var reason := str(payload.get("reason", "weather_event"))
    _recalculate_state(reason)

func _generate_default_map() -> void:
    _terrain_lookup.clear()
    var terrain_keys := _terrain_definitions.keys()
    terrain_keys.sort()
    var terrain_count := terrain_keys.size()
    for q in range(map_columns):
        for r in range(map_rows):
            var terrain_id := str(terrain_keys[(q + r) % terrain_count]) if terrain_count > 0 else "plains"
            var terrain := _terrain_definitions.get(terrain_id, {"movement_cost": 1})
            var movement := float(terrain.get("movement_cost", 1))
            var tile_id := _tile_id(q, r)
            _terrain_lookup[tile_id] = {
                "q": q,
                "r": r,
                "terrain": terrain_id,
                "base_movement_cost": movement,
                "name": str(terrain.get("name", terrain_id.capitalize())),
                "description": str(terrain.get("description", "")),
                "id": tile_id,
            }
    _ensure_tile_metadata()

func _configure_default_network() -> void:
    _supply_centers = [
        {"id": "capital", "q": 1, "r": 2, "type": "city"},
        {"id": "forward_depot", "q": 4, "r": 1, "type": "depot"},
        {"id": "harbor", "q": 5, "r": 3, "type": "harbor"},
    ]

    _routes = [
        {
            "id": "capital_ring",
            "type": "ring",
            "path": [
                _tile_id(1, 2),
                _tile_id(1, 1),
                _tile_id(2, 1),
                _tile_id(2, 2),
                _tile_id(1, 3),
                _tile_id(0, 2)
            ]
        },
        {
            "id": "forward_road",
            "type": "road",
            "path": [
                _tile_id(1, 2),
                _tile_id(2, 2),
                _tile_id(3, 2),
                _tile_id(4, 1)
            ]
        },
        {
            "id": "harbor_convoy",
            "type": "convoy",
            "path": [
                _tile_id(4, 1),
                _tile_id(5, 2),
                _tile_id(5, 3)
            ]
        }
    ]
    _reset_convoy_states_for_routes()
    _ensure_convoy_states()

func _ingest_terrain_from_data_loader() -> void:
    if data_loader == null:
        _ensure_tile_metadata()
        return
    var definitions := data_loader.list_terrain_definitions()
    if definitions.size() > 0:
        _merge_terrain_definitions(definitions)
    var tiles := data_loader.list_terrain_tiles()
    if tiles.size() > 0:
        _apply_terrain_tiles(tiles)
    _ensure_tile_metadata()

func _merge_terrain_definitions(definitions: Array) -> void:
    for entry in definitions:
        if not (entry is Dictionary):
            continue
        var id := str(entry.get("id", ""))
        if id.is_empty():
            continue
        var current := _terrain_definitions.get(id, {})
        var definition := {
            "name": str(entry.get("name", current.get("name", id.capitalize()))),
            "movement_cost": float(entry.get("movement_cost", current.get("movement_cost", 1.0))),
            "description": str(entry.get("description", current.get("description", ""))),
        }
        _terrain_definitions[id] = definition

func _apply_terrain_tiles(tiles: Array) -> void:
    for entry in tiles:
        if not (entry is Dictionary):
            continue
        var q := int(entry.get("q", 0))
        var r := int(entry.get("r", 0))
        var tile_id := _tile_id(q, r)
        var terrain_id := str(entry.get("terrain", "plains"))
        var definition := _terrain_definitions.get(terrain_id, {})
        var tile := _terrain_lookup.get(tile_id, {
            "q": q,
            "r": r,
        })
        tile["q"] = q
        tile["r"] = r
        tile["id"] = tile_id
        tile["terrain"] = terrain_id
        tile["name"] = str(entry.get("name", definition.get("name", terrain_id.capitalize())))
        tile["description"] = str(entry.get("description", definition.get("description", "")))
        var base_cost := definition.get("movement_cost", tile.get("base_movement_cost", 1.0))
        if entry.has("movement_cost"):
            base_cost = entry.get("movement_cost")
        tile["base_movement_cost"] = float(base_cost)
        _terrain_lookup[tile_id] = tile

func _ensure_tile_metadata() -> void:
    for tile_id in _terrain_lookup.keys():
        var tile := _terrain_lookup.get(tile_id, {})
        var q := int(tile.get("q", 0))
        var r := int(tile.get("r", 0))
        tile["q"] = q
        tile["r"] = r
        tile["id"] = tile_id
        var terrain_id := str(tile.get("terrain", "plains"))
        if terrain_id.is_empty():
            terrain_id = "plains"
            tile["terrain"] = terrain_id
        var definition := _terrain_definitions.get(terrain_id, {})
        if not tile.has("name") or String(tile.get("name", "")).is_empty():
            tile["name"] = str(definition.get("name", terrain_id.capitalize()))
        if not tile.has("description"):
            tile["description"] = str(definition.get("description", ""))
        var movement_variant := tile.get("base_movement_cost", definition.get("movement_cost", 1.0))
        tile["base_movement_cost"] = float(movement_variant)
        _terrain_lookup[tile_id] = tile

func _apply_logistics_map(logistics_config: Dictionary) -> void:
    if not logistics_config.has("map"):
        return
    var map_data := logistics_config.get("map")
    if not (map_data is Dictionary):
        return

    var updated := false
    if map_data.has("columns") or map_data.has("rows"):
        map_columns = int(map_data.get("columns", map_columns))
        map_rows = int(map_data.get("rows", map_rows))
        _generate_default_map()
        updated = true
    elif _terrain_lookup.is_empty():
        _generate_default_map()

    if map_data.has("supply_centers") and map_data.get("supply_centers") is Array:
        var centers: Array = []
        for center_data in map_data.get("supply_centers"):
            if not (center_data is Dictionary):
                continue
            var center_id := str(center_data.get("id", ""))
            if center_id.is_empty():
                continue
            centers.append({
                "id": center_id,
                "q": int(center_data.get("q", 0)),
                "r": int(center_data.get("r", 0)),
                "type": str(center_data.get("type", "depot")),
            })
        if centers.size() > 0:
            _supply_centers = centers
            updated = true

    if map_data.has("routes") and map_data.get("routes") is Array:
        var routes: Array = []
        for route_data in map_data.get("routes"):
            if not (route_data is Dictionary):
                continue
            var route_id := str(route_data.get("id", ""))
            if route_id.is_empty():
                continue
            var path_ids: Array = []
            if route_data.has("path") and route_data.get("path") is Array:
                for node in route_data.get("path"):
                    var tile_id := _tile_id_from_variant(node)
                    if tile_id.is_empty():
                        continue
                    path_ids.append(tile_id)
            if path_ids.is_empty():
                continue
            var route_payload := {
                "id": route_id,
                "type": str(route_data.get("type", "road")),
                "path": path_ids,
            }
            if route_data.has("origin"):
                route_payload["origin"] = str(route_data.get("origin"))
            if route_data.has("destination"):
                route_payload["destination"] = str(route_data.get("destination"))
            routes.append(route_payload)
        if routes.size() > 0:
            _routes = routes
            updated = true

    if updated:
        _reset_convoy_states_for_routes()
        _ensure_convoy_states()
        _previous_supply_levels.clear()
    _ensure_tile_metadata()

func _ensure_convoy_states() -> void:
    for route in _routes:
        if not (route is Dictionary):
            continue
        var route_id := route.get("id", "")
        if route_id.is_empty():
            continue
        if not _convoys_by_route.has(route_id):
            _convoys_by_route[route_id] = _new_convoy_state()

func _maybe_flag_isolation_break(tile_id: String, supply_level: String, logistics_config: Dictionary) -> void:
    var previous := str(_previous_supply_levels.get(tile_id, ""))
    _previous_supply_levels[tile_id] = supply_level
    if supply_level != "isolated":
        return
    if previous == "isolated":
        return
    _pending_breaks.append({
        "type": "supply_isolated",
        "tile_id": tile_id,
        "turn": _turn_counter,
        "competence_penalty": 1.0,
        "elan_penalty": int(logistics_config.get("elan_penalty_on_break", 0)),
    })

func _aggregate_break_penalty() -> float:
    var total := 0.0
    for entry in _pending_breaks:
        if entry is Dictionary:
            total += float(entry.get("competence_penalty", 0.0))
    return total

func _new_convoy_state() -> Dictionary:
    return {
        "active": false,
        "progress": 0.0,
        "intercepted": false,
        "completed": 0,
        "spawn_timer": 0,
        "last_speed": 0.0,
        "last_event": "idle",
        "intercept_reported": true,
    }

func _recalculate_state(reason: String) -> void:
    if _current_logistics_id.is_empty() or _terrain_lookup.is_empty():
        return

    var logistics_config: Dictionary = _logistics_by_id.get(_current_logistics_id, {})
    var weather_config: Dictionary = _weather_by_id.get(_current_weather_id, {})

    var flow_multiplier := _compute_flow_multiplier(logistics_config, weather_config)
    var supply_radius := int(logistics_config.get("supply_radius", 0))
    _pending_breaks.clear()
    var supply_zones := _build_supply_payload(supply_radius, flow_multiplier, weather_config, logistics_config)
    var routes_payload := _build_route_payload(flow_multiplier, logistics_config)
    var reachable_tiles := _derive_reachable_tiles(supply_zones)
    var supply_deficits := _collect_supply_deficits(supply_zones, logistics_config)
    var convoy_statuses := _summarise_convoys(routes_payload)
    var total_competence_penalty := _aggregate_break_penalty()

    _last_payload = {
        "reason": reason,
        "turn": _turn_counter,
        "visible": _visible,
        "logistics_id": _current_logistics_id,
        "weather_id": _current_weather_id,
        "flow_multiplier": flow_multiplier,
        "supply_zones": supply_zones,
        "routes": routes_payload,
        "reachable_tiles": reachable_tiles,
        "supply_deficits": supply_deficits,
        "convoy_statuses": convoy_statuses,
        "breaks": _pending_breaks.duplicate(true),
        "competence_penalty": total_competence_penalty,
    }

    if event_bus:
        event_bus.emit_logistics_update(_last_payload)
        _emit_break_events()

func _emit_break_events() -> void:
    if event_bus == null:
        return

    for break_event in _pending_breaks:
        if not (break_event is Dictionary):
            continue
        var payload := break_event.duplicate(true)
        if not payload.has("turn"):
            payload["turn"] = _turn_counter
        payload["logistics_id"] = _current_logistics_id
        payload["weather_id"] = _current_weather_id
        event_bus.emit_logistics_break(payload)

func _build_supply_payload(supply_radius: int, flow_multiplier: float, weather_config: Dictionary, logistics_config: Dictionary) -> Array:
    var zones: Array = []
    var movement_modifier := float(weather_config.get("movement_modifier", 1.0))
    for tile_id in _terrain_lookup.keys():
        var tile: Dictionary = _terrain_lookup.get(tile_id, {})
        var axial := Vector2i(int(tile.get("q", 0)), int(tile.get("r", 0)))
        var distance := _distance_to_nearest_center(axial)
        var base_movement := float(tile.get("base_movement_cost", 1.0))
        var terrain_id := str(tile.get("terrain", "plains"))
        var terrain_name := str(tile.get("name", terrain_id.capitalize()))
        var terrain_description := str(tile.get("description", ""))
        var supply_level := _supply_level(distance, supply_radius)
        var logistics_flow := _compute_tile_flow(flow_multiplier, terrain_id, distance, supply_radius)
        zones.append({
            "tile_id": tile_id,
            "terrain": terrain_id,
            "terrain_name": terrain_name,
            "terrain_description": terrain_description,
            "distance": distance,
            "supply_level": supply_level,
            "movement_cost": snapped(base_movement * movement_modifier, 0.01),
            "logistics_flow": snapped(logistics_flow, 0.01),
        })
        _maybe_flag_isolation_break(tile_id, supply_level, logistics_config)
    return zones

func _build_route_payload(flow_multiplier: float, logistics_config: Dictionary) -> Array:
    var payload: Array = []
    for route in _routes:
        if not (route is Dictionary):
            continue
        var route_id := route.get("id", "")
        if route_id.is_empty():
            continue
        var state: Dictionary = _convoys_by_route.get(route_id, _new_convoy_state())
        var route_length := max(route.get("path", []).size() - 1, 1)
        var eta := 0.0
        if state.get("active", false) and state.get("last_speed", 0.0) > 0.0:
            eta = max((route_length - state.get("progress", 0.0)) / state.get("last_speed", 0.01), 0.0)
        payload.append({
            "id": route_id,
            "type": route.get("type", "road"),
            "path": route.get("path", []),
            "convoy": {
                "active": state.get("active", false),
                "progress": snapped(state.get("progress", 0.0), 0.01),
                "intercepted": state.get("intercepted", false),
                "completed": state.get("completed", 0),
                "last_event": state.get("last_event", "idle"),
                "eta_turns": snapped(eta, 0.01),
            }
        })
        if state.get("last_event", "") == "intercepted" and not state.get("intercept_reported", false):
            state["intercept_reported"] = true
            _pending_breaks.append({
                "type": "convoy_intercept",
                "route_id": route_id,
                "turn": _turn_counter,
                "elan_penalty": int(logistics_config.get("elan_penalty_on_break", 0)),
                "competence_penalty": max(1.0, float(logistics_config.get("elan_penalty_on_break", 0)) * 0.5),
            })
    return payload

func _derive_reachable_tiles(zones: Array) -> Array:
    var reachable: Array = []
    for zone in zones:
        if not (zone is Dictionary):
            continue
        var tile_id := str(zone.get("tile_id", ""))
        if tile_id.is_empty():
            continue
        var supply_level := str(zone.get("supply_level", "isolated"))
        var flow := float(zone.get("logistics_flow", 0.0))
        if flow <= 0.0 or supply_level == "isolated":
            continue
        reachable.append({
            "tile_id": tile_id,
            "supply_level": supply_level,
            "logistics_flow": snapped(flow, 0.01),
            "terrain": zone.get("terrain", "plains"),
            "terrain_name": zone.get("terrain_name", ""),
            "movement_cost": zone.get("movement_cost", 0.0),
        })
    reachable.sort_custom(func(a, b): return String(a.get("tile_id", "")) < String(b.get("tile_id", "")))
    return reachable

func _collect_supply_deficits(zones: Array, logistics_config: Dictionary) -> Array:
    var deficits: Array = []
    var threshold := float(logistics_config.get("deficit_flow_threshold", 0.75))
    for zone in zones:
        if not (zone is Dictionary):
            continue
        var tile_id := str(zone.get("tile_id", ""))
        if tile_id.is_empty():
            continue
        var supply_level := str(zone.get("supply_level", "isolated"))
        var flow := float(zone.get("logistics_flow", 0.0))
        var severity := ""
        if supply_level == "isolated":
            severity = "critical"
        elif flow < threshold:
            severity = "warning"
        else:
            continue
        deficits.append({
            "tile_id": tile_id,
            "supply_level": supply_level,
            "logistics_flow": snapped(flow, 0.01),
            "severity": severity,
            "terrain": zone.get("terrain", "plains"),
            "terrain_name": zone.get("terrain_name", ""),
            "movement_cost": zone.get("movement_cost", 0.0),
        })
    deficits.sort_custom(func(a, b): return String(a.get("tile_id", "")) < String(b.get("tile_id", "")))
    return deficits

func _summarise_convoys(routes_payload: Array) -> Array:
    var statuses: Array = []
    for route in routes_payload:
        if not (route is Dictionary):
            continue
        var route_id := str(route.get("id", ""))
        if route_id.is_empty():
            continue
        var convoy_variant := route.get("convoy", {})
        var convoy: Dictionary = convoy_variant if convoy_variant is Dictionary else {}
        statuses.append({
            "route_id": route_id,
            "type": route.get("type", "road"),
            "active": bool(convoy.get("active", false)),
            "last_event": str(convoy.get("last_event", "idle")),
            "progress": snapped(float(convoy.get("progress", 0.0)), 0.01),
            "eta_turns": snapped(float(convoy.get("eta_turns", 0.0)), 0.01),
            "intercepted": bool(convoy.get("intercepted", false)),
            "completed": int(convoy.get("completed", 0)),
        })
    statuses.sort_custom(func(a, b): return String(a.get("route_id", "")) < String(b.get("route_id", "")))
    return statuses

func _advance_convoys() -> void:
    var logistics_config: Dictionary = _logistics_by_id.get(_current_logistics_id, {})
    var weather_config: Dictionary = _weather_by_id.get(_current_weather_id, {})
    var flow_multiplier := _compute_flow_multiplier(logistics_config, weather_config)
    var spawn_threshold := int(logistics_config.get("convoy_spawn_threshold", 4))

    for route in _routes:
        if not (route is Dictionary):
            continue
        var route_id := route.get("id", "")
        if route_id.is_empty():
            continue
        var state: Dictionary = _convoys_by_route.get(route_id, _new_convoy_state())
        var route_length := max(route.get("path", []).size() - 1, 1)
        if not state.get("active", false):
            state["spawn_timer"] = int(state.get("spawn_timer", 0)) + 1
            if state.get("spawn_timer") >= spawn_threshold:
                state["spawn_timer"] = 0
                state["active"] = true
                state["intercepted"] = false
                state["progress"] = 0.0
                state["last_event"] = "spawned"
                state["intercept_reported"] = true
        if state.get("active", false):
            var speed := _route_speed(route.get("type", "road"), flow_multiplier)
            state["last_speed"] = speed
            state["progress"] = min(state.get("progress", 0.0) + speed, route_length)
            if not state.get("intercepted", false) and _should_intercept(route, logistics_config, flow_multiplier):
                state["intercepted"] = true
                state["active"] = false
                state["last_event"] = "intercepted"
                state["intercept_reported"] = false
            elif state.get("progress", 0.0) >= route_length:
                state["completed"] = int(state.get("completed", 0)) + 1
                state["active"] = false
                state["last_event"] = "delivered"
                state["intercept_reported"] = true
        _convoys_by_route[route_id] = state

func _maybe_rotate_weather() -> void:
    if _weather_controlled_externally:
        return
    if _weather_rotation_turns <= 0:
        return
    if _weather_sequence.size() <= 1:
        return
    if _turn_counter % _weather_rotation_turns != 0:
        return
    var index := _weather_sequence.find(_current_weather_id)
    if index == -1:
        index = 0
    index = (index + 1) % _weather_sequence.size()
    _current_weather_id = str(_weather_sequence[index])
    if event_bus:
        event_bus.emit_weather_changed({
            "weather_id": _current_weather_id,
            "name": _weather_by_id.get(_current_weather_id, {}).get("name", _current_weather_id),
            "effects": _weather_by_id.get(_current_weather_id, {}).get("effects", ""),
            "turn": _turn_counter,
            "reason": "rotation",
            "source": "logistics_system",
        })

func _route_speed(route_type: String, flow_multiplier: float) -> float:
    var base_speed := 1.0
    match route_type:
        "ring":
            base_speed = 0.5
        "convoy":
            base_speed = 0.8
        _:
            base_speed = 1.0
    return max(base_speed * flow_multiplier, 0.0)

func _compute_flow_multiplier(logistics_config: Dictionary, weather_config: Dictionary) -> float:
    var base := float(weather_config.get("logistics_flow_modifier", 1.0))
    var links: Dictionary = logistics_config.get("links", {})
    if links.has("weather_modifiers"):
        var weather_modifiers: Dictionary = links.get("weather_modifiers")
        if weather_modifiers.has(_current_weather_id):
            base += float(weather_modifiers.get(_current_weather_id))
    return clamp(base, 0.2, 2.0)

func _compute_tile_flow(flow_multiplier: float, terrain_id: String, distance: int, supply_radius: int) -> float:
    var penalty := 0.0
    match terrain_id:
        "forest":
            penalty = 0.15
        "hill":
            penalty = 0.25
        _:
            penalty = 0.0
    var fringe_penalty := 0.0
    if distance > supply_radius:
        fringe_penalty = 0.1 * float(distance - supply_radius)
    return clamp(flow_multiplier - penalty - fringe_penalty, 0.0, 2.0)

func _should_intercept(route: Dictionary, logistics_config: Dictionary, flow_multiplier: float) -> bool:
    var base := clamp(float(logistics_config.get("intercept_chance", 0.0)), 0.0, 1.0)
    var terrain_bonus := _route_terrain_bonus(route)
    var flow_penalty := max(0.0, 1.0 - flow_multiplier)
    var effective := clamp(base + terrain_bonus + flow_penalty, 0.0, 1.0)
    if effective >= 1.0:
        return true
    return _rng.randf() < effective

func _route_terrain_bonus(route: Dictionary) -> float:
    var path: Array = route.get("path", [])
    var bonus := 0.0
    for tile_id in path:
        if not _terrain_lookup.has(tile_id):
            continue
        var terrain_id := str(_terrain_lookup.get(tile_id, {}).get("terrain", "plains"))
        match terrain_id:
            "forest":
                bonus += 0.05
            "hill":
                bonus += 0.08
            _:
                pass
    return min(bonus, 0.5)

func _distance_to_nearest_center(axial: Vector2i) -> int:
    var min_distance := 9999
    for center in _supply_centers:
        if not (center is Dictionary):
            continue
        var q := int(center.get("q", 0))
        var r := int(center.get("r", 0))
        var distance := _hex_distance(axial, Vector2i(q, r))
        if distance < min_distance:
            min_distance = distance
    return min_distance if min_distance != 9999 else 0

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
    var dq := a.x - b.x
    var dr := a.y - b.y
    var ds := (-a.x - a.y) - (-b.x - b.y)
    return int(max(abs(dq), max(abs(dr), abs(ds))))

func _supply_level(distance: int, radius: int) -> String:
    if distance <= radius:
        return "core"
    if distance <= radius + 1:
        return "fringe"
    return "isolated"

func _tile_id(q: int, r: int) -> String:
    return "%d,%d" % [q, r]

func _update_weather_rotation_turns() -> void:
    _weather_rotation_turns = 0
    var config: Dictionary = _logistics_by_id.get(_current_logistics_id, {})
    if config.has("weather_rotation_turns"):
        _weather_rotation_turns = int(config.get("weather_rotation_turns"))

func _reset_convoy_states_for_routes() -> void:
    var next_states: Dictionary = {}
    for route in _routes:
        if not (route is Dictionary):
            continue
        var route_id := route.get("id", "")
        if route_id.is_empty():
            continue
        next_states[route_id] = _convoys_by_route.get(route_id, _new_convoy_state())
    _convoys_by_route = next_states

func _tile_id_from_variant(node: Variant) -> String:
    if node is Dictionary:
        return _tile_id(int(node.get("q", 0)), int(node.get("r", 0)))
    if node is Array and node.size() >= 2:
        return _tile_id(int(node[0]), int(node[1]))
    return ""

