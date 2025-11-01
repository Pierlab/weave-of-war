class_name WeatherSystem
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

var event_bus: EventBusAutoload
var data_loader: DataLoaderAutoload

var _weather_lookup: Dictionary = {}
var _weather_sequence: Array = []
var _current_weather_id := ""
var _turn_counter := 0
var _turns_remaining := 0
var _configured := false
var _seed_locked := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    setup(EVENT_BUS.get_instance(), DATA_LOADER.get_instance())

func setup(event_bus_ref: EventBusAutoload, data_loader_ref: DataLoaderAutoload) -> void:
    event_bus = event_bus_ref
    data_loader = data_loader_ref
    if not _seed_locked:
        _rng.randomize()
    if event_bus:
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.turn_started.is_connected(_on_turn_started):
            event_bus.turn_started.connect(_on_turn_started)
    if data_loader and data_loader.is_ready():
        configure(data_loader.list_weather_states())

func set_rng_seed(seed: int) -> void:
    _seed_locked = true
    _rng.seed = seed

func configure(weather_entries: Array) -> void:
    _weather_lookup.clear()
    _weather_sequence.clear()
    for entry in weather_entries:
        if not (entry is Dictionary):
            continue
        var weather_id := str(entry.get("id", ""))
        if weather_id.is_empty():
            continue
        _weather_lookup[weather_id] = entry.duplicate(true)
        if not _weather_sequence.has(weather_id):
            _weather_sequence.append(weather_id)
    _configured = _weather_sequence.size() > 0
    if not _configured:
        _current_weather_id = ""
        _turns_remaining = 0
        return
    if _current_weather_id.is_empty() or not _weather_lookup.has(_current_weather_id):
        _current_weather_id = _weather_sequence[0]
    _turns_remaining = _roll_duration(_current_weather_id)
    _emit_weather_changed("initial")

func advance_turn(turn_number: int) -> void:
    _on_turn_started(turn_number)

func force_weather(weather_id: String, reason := "forced") -> void:
    if weather_id.is_empty() or not _weather_lookup.has(weather_id):
        return
    _current_weather_id = weather_id
    _turns_remaining = _roll_duration(weather_id)
    _emit_weather_changed(reason)

func get_current_weather() -> Dictionary:
    var entry: Dictionary = _weather_lookup.get(_current_weather_id, {})
    var payload := entry.duplicate(true)
    payload["id"] = _current_weather_id
    payload["turn"] = _turn_counter
    payload["remaining_turns"] = _turns_remaining
    return payload

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(collections.get("weather", []))

func _on_turn_started(turn_number: int) -> void:
    _turn_counter = turn_number
    if not _configured or _weather_sequence.is_empty():
        return
    if _turns_remaining > 0:
        _turns_remaining -= 1
    if _turns_remaining <= 0:
        _advance_weather()
        return
    _emit_weather_changed("tick")

func _advance_weather() -> void:
    if _weather_sequence.is_empty():
        return
    var index: int = _weather_sequence.find(_current_weather_id)
    if index == -1:
        index = 0
    index = (index + 1) % _weather_sequence.size()
    _current_weather_id = str(_weather_sequence[index])
    _turns_remaining = _roll_duration(_current_weather_id)
    _emit_weather_changed("rotation")

func _roll_duration(weather_id: String) -> int:
    var range: Vector2i = _duration_range(weather_id)
    var minimum: int = max(range.x, 1)
    var maximum: int = max(range.y, minimum)
    return _rng.randi_range(minimum, maximum)

func _duration_range(weather_id: String) -> Vector2i:
    var entry: Dictionary = _weather_lookup.get(weather_id, {})
    var variant: Variant = entry.get("duration_turns", [])
    if variant is Array:
        var duration: Array = variant
        if duration.size() >= 2:
            return Vector2i(int(duration[0]), int(duration[1]))
        if duration.size() == 1:
            var value: int = int(duration[0])
            return Vector2i(value, value)
    return Vector2i(1, 1)

func _emit_weather_changed(reason: String) -> void:
    if event_bus == null:
        return
    var entry: Dictionary = _weather_lookup.get(_current_weather_id, {})
    var payload := {
        "weather_id": _current_weather_id,
        "name": str(entry.get("name", _current_weather_id.capitalize())),
        "effects": str(entry.get("effects", "")),
        "movement_modifier": float(entry.get("movement_modifier", 1.0)),
        "logistics_flow_modifier": float(entry.get("logistics_flow_modifier", 1.0)),
        "intel_noise": float(entry.get("intel_noise", 0.0)),
        "elan_regeneration_bonus": float(entry.get("elan_regeneration_bonus", 0.0)),
        "combat_modifiers": _duplicate_dictionary(entry.get("combat_modifiers", {})),
        "duration_remaining": _turns_remaining,
        "duration_range": _duration_array(entry.get("duration_turns", [])),
        "turn": _turn_counter,
        "reason": reason,
        "source": "weather_system",
    }
    event_bus.emit_weather_changed(payload)

func _duration_array(value: Variant) -> Array:
    if value is Array:
        var result: Array = []
        for entry in value:
            result.append(int(entry))
        return result
    return []

func _duplicate_dictionary(value: Variant) -> Dictionary:
    if value is Dictionary:
        return (value as Dictionary).duplicate(true)
    return {}
