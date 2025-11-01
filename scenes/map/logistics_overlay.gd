class_name LogisticsOverlay
extends Node2D

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const UTILS := preload("res://scripts/core/utils.gd")

@export var pulse_speed := 2.4
@export var convoy_lerp_duration := 0.75
@export var hex_outline_width := 2.0

var event_bus: EventBusAutoload
var _hex_points := PackedVector2Array()
var _supply_tiles: Dictionary = {}
var _route_tracks: Dictionary = {}
var _pulse_clock := 0.0
var _visible_state := false

func _ready() -> void:
    z_index = 25
    _hex_points = _build_hex_points()
    _acquire_event_bus()
    set_process(true)
    visible = false

func _exit_tree() -> void:
    if event_bus:
        if event_bus.logistics_update.is_connected(_on_logistics_update):
            event_bus.logistics_update.disconnect(_on_logistics_update)
        if event_bus.logistics_toggled.is_connected(_on_logistics_toggled):
            event_bus.logistics_toggled.disconnect(_on_logistics_toggled)

func _process(delta: float) -> void:
    _pulse_clock = fmod(_pulse_clock + delta * pulse_speed, TAU)
    for route_id in _route_tracks.keys():
        var track: Dictionary = _route_tracks.get(route_id, {})
        var duration := max(float(track.get("duration", 0.0)), 0.0001)
        var timer := min(float(track.get("timer", 0.0)) + delta, duration)
        var start_value := float(track.get("start", 0.0))
        var target_value := float(track.get("target", 0.0))
        var progress_ratio := timer / duration
        track["timer"] = timer
        track["current"] = lerp(start_value, target_value, progress_ratio)
        _route_tracks[route_id] = track
    if visible:
        queue_redraw()

func _draw() -> void:
    if not visible:
        return
    _draw_supply_tiles()
    _draw_routes_and_convoys()

func _draw_supply_tiles() -> void:
    for tile_id in _supply_tiles.keys():
        var tile: Dictionary = _supply_tiles.get(tile_id, {})
        var center: Vector2 = tile.get("position", Vector2.ZERO)
        var supply_level := String(tile.get("supply_level", "core"))
        var flow_strength := clamp(float(tile.get("logistics_flow", 0.0)) / 2.0, 0.0, 1.0)
        var offset := float(tile.get("pulse_offset", 0.0))
        var wave := 0.6 + 0.4 * sin(_pulse_clock + offset)
        var base_color := _color_for_supply(supply_level, flow_strength, wave)
        var polygon := _translate_hex(center)
        draw_polygon(polygon, [base_color])
        var outline := base_color
        outline.a = clamp(outline.a + 0.25, 0.0, 1.0)
        draw_polyline(_close_polygon(polygon), outline, hex_outline_width)

func _draw_routes_and_convoys() -> void:
    for route_id in _route_tracks.keys():
        var track: Dictionary = _route_tracks.get(route_id, {})
        var route_type := String(track.get("type", "road"))
        var points: PackedVector2Array = track.get("points", PackedVector2Array())
        if points.size() < 2:
            continue
        var route_color := _color_for_route(route_type)
        var path_color := route_color
        path_color.a = 0.45
        var draw_points := PackedVector2Array()
        for point in points:
            draw_points.append(point)
        if route_type == "ring" and points.size() > 2:
            var closed := PackedVector2Array()
            for point in points:
                closed.append(point)
            closed.append(points[0])
            draw_points = closed
        draw_polyline(draw_points, path_color, 3.0)

        var convoy_state: Dictionary = track.get("state", {})
        var position := _position_along_route(track)
        var marker_color := route_color
        marker_color.a = 0.9
        var radius := 6.0
        if convoy_state.get("active", false):
            radius = 7.5
            marker_color = marker_color.lightened(0.2)
        elif convoy_state.get("intercepted", false):
            marker_color = Color(0.95, 0.35, 0.25, 0.95)
        elif convoy_state.get("last_event", "") == "delivered":
            marker_color = route_color.lightened(0.35)
        draw_circle(position, radius, marker_color)
        if convoy_state.get("intercepted", false):
            _draw_cross(position, marker_color.darkened(0.25), radius + 2.0)

func _draw_cross(center: Vector2, color: Color, size: float) -> void:
    var half := size * 0.6
    var a := center + Vector2(-half, -half)
    var b := center + Vector2(half, half)
    var c := center + Vector2(-half, half)
    var d := center + Vector2(half, -half)
    draw_line(a, b, color, 2.0)
    draw_line(c, d, color, 2.0)

func _acquire_event_bus() -> void:
    event_bus = EVENT_BUS.get_instance()
    if event_bus == null:
        call_deferred("_acquire_event_bus")
        return
    if not event_bus.logistics_update.is_connected(_on_logistics_update):
        event_bus.logistics_update.connect(_on_logistics_update)
    if not event_bus.logistics_toggled.is_connected(_on_logistics_toggled):
        event_bus.logistics_toggled.connect(_on_logistics_toggled)

func _on_logistics_update(payload: Dictionary) -> void:
    _visible_state = bool(payload.get("visible", _visible_state))
    visible = _visible_state
    _refresh_supply_tiles(payload.get("supply_zones", []))
    _refresh_routes(payload.get("routes", []))
    queue_redraw()

func _on_logistics_toggled(should_show: bool) -> void:
    _visible_state = should_show
    visible = should_show
    queue_redraw()

func _refresh_supply_tiles(zones: Array) -> void:
    var active_tiles: Dictionary = {}
    for zone in zones:
        if not (zone is Dictionary):
            continue
        var tile_id := String(zone.get("tile_id", ""))
        if tile_id.is_empty():
            continue
        var coords := _coords_from_id(tile_id)
        var position := UTILS.axial_to_pixel(coords.x, coords.y)
        var pulse_offset := float((coords.x + coords.y) * 0.37) % TAU
        active_tiles[tile_id] = {
            "position": position,
            "supply_level": zone.get("supply_level", "core"),
            "logistics_flow": zone.get("logistics_flow", 0.0),
            "pulse_offset": pulse_offset,
        }
    _supply_tiles = active_tiles

func _refresh_routes(routes: Array) -> void:
    var remaining: Dictionary = {}
    for route in routes:
        if not (route is Dictionary):
            continue
        var route_id := String(route.get("id", ""))
        if route_id.is_empty():
            continue
        var path: Array = route.get("path", [])
        var points := PackedVector2Array()
        for node in path:
            var tile_id := String(node)
            var coords := _coords_from_id(tile_id)
            points.append(UTILS.axial_to_pixel(coords.x, coords.y))
        if points.size() < 2:
            continue
        var convoy: Dictionary = route.get("convoy", {})
        var previous: Dictionary = _route_tracks.get(route_id, {})
        var current_value := float(previous.get("current", convoy.get("progress", 0.0)))
        var target_value := float(convoy.get("progress", 0.0))
        var duration := convoy_lerp_duration if convoy.get("active", false) else 0.35
        var track := {
            "points": points,
            "type": route.get("type", "road"),
            "state": convoy,
            "start": current_value,
            "target": target_value,
            "current": current_value,
            "timer": 0.0,
            "duration": duration,
        }
        remaining[route_id] = track
    _route_tracks = remaining

func _position_along_route(track: Dictionary) -> Vector2:
    var points: PackedVector2Array = track.get("points", PackedVector2Array())
    if points.size() == 0:
        return Vector2.ZERO
    if points.size() == 1:
        return points[0]
    var max_index := points.size() - 1
    var route_length := max(float(max_index), 1.0)
    var progress := clamp(float(track.get("current", 0.0)), 0.0, route_length)
    var segment := int(clamp(floor(progress), 0, max_index - 1))
    var local := clamp(progress - float(segment), 0.0, 1.0)
    var start_point := points[segment]
    var end_point := points[segment + 1]
    return start_point.lerp(end_point, local)

func _coords_from_id(tile_id: String) -> Vector2:
    var parts := tile_id.split(",")
    if parts.size() >= 2:
        return Vector2(parts[0].to_int(), parts[1].to_int())
    return Vector2.ZERO

func _build_hex_points() -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(0, -32),
        Vector2(27, -16),
        Vector2(27, 16),
        Vector2(0, 32),
        Vector2(-27, 16),
        Vector2(-27, -16),
    ])

func _translate_hex(center: Vector2) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point in _hex_points:
        result.append(center + point)
    return result

func _close_polygon(points: PackedVector2Array) -> PackedVector2Array:
    var closed := PackedVector2Array()
    for point in points:
        closed.append(point)
    if points.size() > 0:
        closed.append(points[0])
    return closed

func _color_for_supply(level: String, flow: float, wave: float) -> Color:
    match level:
        "core":
            return Color(0.2, 0.82, 0.45, 0.35 + 0.35 * flow * wave)
        "fringe":
            return Color(0.95, 0.63, 0.24, 0.28 + 0.4 * wave)
        "isolated":
            return Color(0.92, 0.3, 0.3, 0.22 + 0.45 * wave)
        _:
            return Color(0.7, 0.7, 0.85, 0.2 + 0.25 * wave)

func _color_for_route(route_type: String) -> Color:
    match route_type:
        "ring":
            return Color(0.36, 0.76, 0.98, 0.9)
        "convoy":
            return Color(0.95, 0.88, 0.35, 0.95)
        _:
            return Color(0.45, 0.9, 0.62, 0.85)
