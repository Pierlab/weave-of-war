class_name FormationOverlay
extends Node2D

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const UTILS := preload("res://scripts/core/utils.gd")

const CLASS_ROW_RATIOS := {
    "line": 0.38,
    "mobile": 0.32,
    "ranged": 0.52,
    "support": 0.62,
    "": 0.48,
    "_": 0.48,
}

const POSTURE_COLORS := {
    "defensive": Color(0.32, 0.58, 0.86, 1.0),
    "aggressive": Color(0.88, 0.32, 0.32, 1.0),
    "balanced": Color(0.95, 0.72, 0.35, 1.0),
    "fluid": Color(0.50, 0.78, 0.58, 1.0),
    "recon": Color(0.58, 0.55, 0.92, 1.0),
    "ranged": Color(0.88, 0.57, 0.82, 1.0),
    "support": Color(0.74, 0.74, 0.74, 1.0),
}

const DEFAULT_POSTURE_COLOR := Color(0.72, 0.72, 0.72, 1.0)
const TOKEN_RADIUS := 14.0
const HIGHLIGHT_DURATION := 1.15
const LABEL_FONT_SIZE := 16
const LOCK_FONT_SIZE := 12
const POSITION_VERTICAL_OFFSET := -18.0

var event_bus: EventBus
var data_loader: DataLoader
var _columns: int = 10
var _rows: int = 10
var _unit_entries: Dictionary = {}
var _unit_positions: Dictionary = {}
var _unit_tokens: Dictionary = {}
var _highlights: Dictionary = {}
var _font: Font
var _font_size: int = LABEL_FONT_SIZE
var _lock_font_size: int = LOCK_FONT_SIZE

func _ready() -> void:
    z_index = 30
    visible = true
    set_process(false)
    _font = get_theme_default_font()
    if _font == null:
        _font = ThemeDB.fallback_font
    _acquire_sources()

func _exit_tree() -> void:
    _disconnect_events()

func set_dimensions(columns: int, rows: int) -> void:
    _columns = max(columns, 1)
    _rows = max(rows, 1)
    _rebuild_unit_positions()
    queue_redraw()

func set_data_sources(event_bus_ref: EventBus, data_loader_ref: DataLoader) -> void:
    if event_bus_ref != null:
        event_bus = event_bus_ref
    if data_loader_ref != null:
        data_loader = data_loader_ref
        _cache_unit_entries()
        _rebuild_unit_positions()
    _connect_events()

func _process(delta: float) -> void:
    if _highlights.is_empty():
        set_process(false)
        return
    var dirty := false
    for unit_id in _highlights.keys():
        var remaining := float(_highlights.get(unit_id, 0.0)) - delta
        if remaining <= 0.0:
            _highlights.erase(unit_id)
            dirty = true
        else:
            _highlights[unit_id] = remaining
            dirty = true
    if dirty:
        queue_redraw()
    if _highlights.is_empty():
        set_process(false)

func _draw() -> void:
    for unit_id in _unit_tokens.keys():
        var token: Dictionary = _unit_tokens.get(unit_id, {})
        var position: Vector2 = token.get("position", Vector2.ZERO)
        var posture := str(token.get("posture", ""))
        var base_color := posture_color(posture)
        var locked := bool(token.get("locked", false))
        var turns_remaining := int(token.get("turns_remaining", 0))
        var highlight_strength := _highlight_strength(unit_id)
        if highlight_strength > 0.0:
            var highlight_color := base_color.lightened(0.25)
            highlight_color.a = clamp(highlight_color.a * 0.4 * highlight_strength, 0.0, 0.6)
            draw_circle(position, TOKEN_RADIUS + 6.0, highlight_color)
        draw_circle(position, TOKEN_RADIUS, base_color)
        if locked:
            var ring_color := Color(1.0, 1.0, 1.0, 0.9)
            draw_arc(position, TOKEN_RADIUS + 3.0, 0.0, TAU, 32, ring_color, 2.0)
            if turns_remaining > 0 and _font:
                var lock_text := str(turns_remaining)
                var lock_size := _font.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, _lock_font_size)
                var lock_pos := position + Vector2(-lock_size.x / 2.0, TOKEN_RADIUS + lock_size.y + 2.0)
                draw_string_outline(_font, lock_pos, lock_text, 1, Color(0.0, 0.0, 0.0, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1.0, _lock_font_size)
                draw_string(_font, lock_pos, lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _lock_font_size, Color(0.95, 0.95, 0.95, 0.95))
        var label := str(token.get("label", ""))
        if label != "" and _font:
            var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, _font_size)
            var ascent := _font.get_ascent(_font_size)
            var label_pos := position + Vector2(-text_size.x / 2.0, text_size.y / 2.0)
            label_pos.y += (ascent - text_size.y)
            draw_string_outline(_font, label_pos, label, 2, Color(0.0, 0.0, 0.0, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size)
            draw_string(_font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, Color(1.0, 1.0, 1.0, 0.95))

func _acquire_sources() -> void:
    if event_bus == null:
        event_bus = EVENT_BUS.get_instance()
    if data_loader == null:
        data_loader = DATA_LOADER.get_instance()
    if data_loader and data_loader.is_ready():
        _cache_unit_entries()
        _rebuild_unit_positions()
    _connect_events()

func _connect_events() -> void:
    if event_bus:
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.formation_status_updated.is_connected(_on_formation_status_updated):
            event_bus.formation_status_updated.connect(_on_formation_status_updated)
        if not event_bus.formation_changed.is_connected(_on_formation_changed):
            event_bus.formation_changed.connect(_on_formation_changed)

func _disconnect_events() -> void:
    if event_bus:
        if event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.disconnect(_on_data_loader_ready)
        if event_bus.formation_status_updated.is_connected(_on_formation_status_updated):
            event_bus.formation_status_updated.disconnect(_on_formation_status_updated)
        if event_bus.formation_changed.is_connected(_on_formation_changed):
            event_bus.formation_changed.disconnect(_on_formation_changed)

func _on_data_loader_ready(_payload: Dictionary) -> void:
    data_loader = DATA_LOADER.get_instance()
    _cache_unit_entries()
    _rebuild_unit_positions()
    queue_redraw()

func _on_formation_status_updated(payload: Dictionary) -> void:
    var units_variant: Variant = payload.get("units", {})
    if not (units_variant is Dictionary):
        return
    var units: Dictionary = units_variant
    if data_loader == null or not data_loader.is_ready():
        _cache_entries_from_status(units)
    _ensure_positions_for_units(units.keys())
    for unit_id_variant in units.keys():
        var unit_id := str(unit_id_variant)
        var status_variant: Variant = units.get(unit_id_variant, {})
        if not (status_variant is Dictionary):
            continue
        var status: Dictionary = status_variant
        var token := _unit_tokens.get(unit_id, {})
        token["unit_name"] = str(status.get("unit_name", unit_id.capitalize()))
        token["formation_id"] = str(status.get("formation_id", token.get("formation_id", "")))
        token["formation_name"] = str(status.get("formation_name", token.get("formation_name", "")))
        token["posture"] = str(status.get("posture", token.get("posture", "")))
        token["locked"] = bool(status.get("locked", false))
        token["turns_remaining"] = int(status.get("turns_remaining", 0))
        token["elan_cost"] = float(status.get("elan_cost", 0.0))
        token["description"] = str(status.get("description", ""))
        token["position"] = _unit_positions.get(unit_id, {}).get("position", Vector2.ZERO)
        token["label"] = _build_label(token)
        _unit_tokens[unit_id] = token
    var incoming_ids := []
    for unit_id_variant in units.keys():
        incoming_ids.append(str(unit_id_variant))
    var stored_ids := _unit_tokens.keys()
    for stored_id_variant in stored_ids:
        var stored_id := str(stored_id_variant)
        if not incoming_ids.has(stored_id):
            _unit_tokens.erase(stored_id)
            _unit_positions.erase(stored_id)
            if _highlights.has(stored_id):
                _highlights.erase(stored_id)
    queue_redraw()

func _on_formation_changed(payload: Dictionary) -> void:
    var unit_id := str(payload.get("unit_id", ""))
    if unit_id.is_empty():
        return
    _highlights[unit_id] = HIGHLIGHT_DURATION
    set_process(true)
    queue_redraw()

func _cache_unit_entries() -> void:
    _unit_entries.clear()
    if data_loader == null or not data_loader.is_ready():
        return
    for entry_variant in data_loader.list_units():
        if not (entry_variant is Dictionary):
            continue
        var entry: Dictionary = entry_variant
        var unit_id := str(entry.get("id", ""))
        if unit_id.is_empty():
            continue
        _unit_entries[unit_id] = entry.duplicate(true)

func _cache_entries_from_status(units: Dictionary) -> void:
    for unit_id_variant in units.keys():
        var unit_id := str(unit_id_variant)
        if unit_id.is_empty() or _unit_entries.has(unit_id):
            continue
        var status_variant: Variant = units.get(unit_id_variant, {})
        if status_variant is Dictionary:
            var status: Dictionary = status_variant
            _unit_entries[unit_id] = {
                "id": unit_id,
                "name": str(status.get("unit_name", unit_id.capitalize())),
                "unit_class": str(status.get("unit_class", "")),
            }

func _ensure_positions_for_units(unit_ids: Array) -> void:
    var rebuild := false
    for unit_id_variant in unit_ids:
        var unit_id := str(unit_id_variant)
        if unit_id.is_empty():
            continue
        if not _unit_positions.has(unit_id):
            rebuild = true
            break
    if rebuild:
        _rebuild_unit_positions()

func _rebuild_unit_positions() -> void:
    if _unit_entries.is_empty():
        return
    var groups: Dictionary = {}
    for unit_id in _unit_entries.keys():
        var entry: Dictionary = _unit_entries.get(unit_id, {})
        var class_id := str(entry.get("unit_class", ""))
        var key := class_id if not class_id.is_empty() else "_"
        if not groups.has(key):
            groups[key] = []
        var group: Array = groups.get(key, [])
        group.append(entry)
        groups[key] = group
    _unit_positions.clear()
    for class_id in groups.keys():
        var group: Array = groups.get(class_id, [])
        if group.is_empty():
            continue
        group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            return str(a.get("id", "")) < str(b.get("id", ""))
        )
        var row_ratio := _row_ratio_for_class(class_id)
        var row_index := _row_from_ratio(row_ratio)
        var total := group.size()
        for index in range(total):
            var entry: Dictionary = group[index]
            var unit_id := str(entry.get("id", ""))
            if unit_id.is_empty():
                continue
            var column_index := _column_for_slot(index, total)
            var coords := Vector2i(column_index, row_index)
            var position := UTILS.axial_to_pixel(coords.x, coords.y)
            position.y += POSITION_VERTICAL_OFFSET
            _unit_positions[unit_id] = {
                "coords": coords,
                "position": position,
            }
    for unit_id in _unit_tokens.keys():
        var token: Dictionary = _unit_tokens.get(unit_id, {})
        token["position"] = _unit_positions.get(unit_id, {}).get("position", token.get("position", Vector2.ZERO))
        token["label"] = _build_label(token)
        _unit_tokens[unit_id] = token

func _row_ratio_for_class(class_id: String) -> float:
    return float(CLASS_ROW_RATIOS.get(class_id, CLASS_ROW_RATIOS.get("_", 0.48)))

func _row_from_ratio(ratio: float) -> int:
    var max_row := max(_rows - 1, 0)
    return clamp(int(round(ratio * max_row)), 0, max_row)

func _column_for_slot(index: int, total: int) -> int:
    var column_count := max(_columns - 1, 0)
    if total <= 1 or column_count == 0:
        return int(round(column_count / 2.0))
    var ratio := float(index + 1) / float(total + 1)
    return clamp(int(round(ratio * column_count)), 0, column_count)

func _highlight_strength(unit_id: String) -> float:
    if not _highlights.has(unit_id):
        return 0.0
    return clamp(float(_highlights.get(unit_id, 0.0)) / HIGHLIGHT_DURATION, 0.0, 1.0)

func _build_label(token: Dictionary) -> String:
    var formation_name := str(token.get("formation_name", ""))
    if formation_name != "":
        return abbreviate_label(formation_name)
    var formation_id := str(token.get("formation_id", ""))
    if formation_id != "":
        return abbreviate_label(formation_id.replace("_", " "))
    return abbreviate_label(str(token.get("unit_name", "")))

static func abbreviate_label(source: String) -> String:
    var cleaned := source.strip_edges()
    if cleaned == "":
        return ""
    var parts := cleaned.split(" ", false)
    var letters: PackedStringArray = []
    for part in parts:
        if part == "":
            continue
        letters.append(part.substr(0, 1).to_upper())
        if letters.size() >= 2:
            break
    if letters.is_empty():
        letters.append(cleaned.substr(0, 1).to_upper())
    return "".join(letters)

static func posture_color(posture: String) -> Color:
    if posture == "":
        return DEFAULT_POSTURE_COLOR
    return POSTURE_COLORS.get(posture, DEFAULT_POSTURE_COLOR)
