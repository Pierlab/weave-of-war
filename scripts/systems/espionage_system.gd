class_name EspionageSystem
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

const SUPPLY_VISIBILITY := {
    "core": 0.85,
    "fringe": 0.55,
    "isolated": 0.3,
}
const DEFAULT_TILE_VISIBILITY := 0.1
const COUNTER_INTEL_DECAY := 0.15
const COUNTER_INTEL_GROWTH := 0.05
const BASE_PROBE_STRENGTH := 0.4

var event_bus: EventBusAutoload
var data_loader: DataLoaderAutoload

var _fog_by_tile: Dictionary = {}
var _weather_by_id: Dictionary = {}
var _current_weather_id := ""
var _last_ping: Dictionary = {}
var _intentions_by_target: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _turn_counter := 0

func _ready() -> void:
    setup(EVENT_BUS.get_instance(), DATA_LOADER.get_instance())

func setup(event_bus_ref: EventBusAutoload, data_loader_ref: DataLoaderAutoload) -> void:
    event_bus = event_bus_ref
    data_loader = data_loader_ref
    _rng.randomize()

    if data_loader and data_loader.is_ready():
        configure(data_loader.list_weather_states())

    if event_bus:
        if not event_bus.logistics_update.is_connected(_on_logistics_update):
            event_bus.logistics_update.connect(_on_logistics_update)
        if not event_bus.weather_changed.is_connected(_on_weather_changed):
            event_bus.weather_changed.connect(_on_weather_changed)
        if not event_bus.assistant_order_packet.is_connected(_on_assistant_packet):
            event_bus.assistant_order_packet.connect(_on_assistant_packet)
        if not event_bus.turn_started.is_connected(_on_turn_started):
            event_bus.turn_started.connect(_on_turn_started)
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)

func configure(weather_entries: Array) -> void:
    _weather_by_id = {}
    for entry in weather_entries:
        if entry is Dictionary and entry.has("id"):
            _weather_by_id[str(entry.get("id"))] = entry
    if _current_weather_id.is_empty() and not _weather_by_id.is_empty():
        _current_weather_id = str(_weather_by_id.keys()[0])
    elif not _weather_by_id.has(_current_weather_id) and not _weather_by_id.is_empty():
        _current_weather_id = str(_weather_by_id.keys()[0])

func configure_map(terrain_tiles: Dictionary) -> void:
    _fog_by_tile.clear()
    for tile_id in terrain_tiles.keys():
        _fog_by_tile[str(tile_id)] = _new_tile_state()

func set_rng_seed(seed: int) -> void:
    _rng.seed = seed

func ingest_logistics_payload(payload: Dictionary) -> void:
    var supply_zones: Array = payload.get("supply_zones", [])
    for zone in supply_zones:
        if not (zone is Dictionary):
            continue
        var tile_id := str(zone.get("tile_id", ""))
        if tile_id == "":
            continue
        var level := str(zone.get("supply_level", "isolated"))
        var tile_state := _fog_by_tile.get(tile_id, _new_tile_state())
        var visibility := SUPPLY_VISIBILITY.get(level, DEFAULT_TILE_VISIBILITY)
        tile_state["visibility"] = max(float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY)), visibility)
        tile_state["counter_intel"] = max(float(tile_state.get("counter_intel", 0.0)) - COUNTER_INTEL_DECAY, 0.0)
        _fog_by_tile[tile_id] = tile_state
    _turn_counter = int(payload.get("turn", _turn_counter))

func perform_ping(target: String, probe_strength := BASE_PROBE_STRENGTH, metadata: Dictionary = {}) -> Dictionary:
    if target.is_empty():
        return {}
    var tile_state := _fog_by_tile.get(target, _new_tile_state())
    _fog_by_tile[target] = tile_state

    var weather_noise := _current_weather_noise()
    var detection_bonus := float(metadata.get("detection_bonus", 0.0))
    var intention_context: Dictionary = _intentions_by_target.get(target, {})
    if intention_context.is_empty():
        intention_context = _intentions_by_target.get(metadata.get("order_id", ""), {})

    var base_visibility := float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY))
    var counter_intel := float(tile_state.get("counter_intel", 0.0))
    var effective_confidence := clamp(base_visibility + probe_strength + detection_bonus - (weather_noise + counter_intel), 0.0, 1.0)
    var roll := _rng.randf()
    var success := roll <= effective_confidence

    var revealed_intention := "unknown"
    if success and not intention_context.is_empty():
        revealed_intention = str(intention_context.get("intention", "unknown"))

    tile_state["visibility"] = clamp(max(base_visibility, effective_confidence + (0.15 if success else 0.0)), DEFAULT_TILE_VISIBILITY, 1.0)
    tile_state["counter_intel"] = clamp(counter_intel + (COUNTER_INTEL_GROWTH if not success else COUNTER_INTEL_GROWTH * 0.25), 0.0, 1.0)
    _fog_by_tile[target] = tile_state

    var payload := {
        "target": target,
        "success": success,
        "confidence": snapped(effective_confidence, 0.01),
        "noise": snapped(weather_noise + counter_intel, 0.01),
        "intention": revealed_intention,
        "turn": _turn_counter,
        "source": metadata.get("source", "probe"),
        "visibility_map": _build_visibility_snapshot(),
    }

    _last_ping = payload.duplicate(true)
    if event_bus:
        event_bus.emit_espionage_ping(_last_ping)
    return _last_ping

func get_fog_snapshot() -> Array:
    return _build_visibility_snapshot()

func get_last_ping() -> Dictionary:
    return _last_ping.duplicate(true)

func _new_tile_state() -> Dictionary:
    return {
        "visibility": DEFAULT_TILE_VISIBILITY,
        "counter_intel": 0.25,
    }

func _current_weather_noise() -> float:
    var weather: Dictionary = _weather_by_id.get(_current_weather_id, {})
    return float(weather.get("intel_noise", 0.0))

func _build_visibility_snapshot() -> Array:
    var snapshot: Array = []
    for tile_id in _fog_by_tile.keys():
        var tile_state: Dictionary = _fog_by_tile.get(tile_id, _new_tile_state())
        snapshot.append({
            "tile_id": tile_id,
            "visibility": snapped(float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY)), 0.01),
            "counter_intel": snapped(float(tile_state.get("counter_intel", 0.0)), 0.01),
        })
    snapshot.sort_custom(func(a, b): return String(a.get("tile_id", "")) < String(b.get("tile_id", "")))
    return snapshot

func _on_logistics_update(payload: Dictionary) -> void:
    ingest_logistics_payload(payload)

func _on_weather_changed(payload: Dictionary) -> void:
    var weather_id := str(payload.get("weather_id", ""))
    if weather_id != "":
        _current_weather_id = weather_id

func _on_assistant_order_packet(packet: Dictionary) -> void:
    var intents := packet.get("intents", {})
    if intents is Dictionary:
        for key in intents.keys():
            var context := intents.get(key)
            if not (context is Dictionary):
                continue
            var intention := str(context.get("intention", ""))
            if intention == "":
                continue
            var target := str(context.get("target", context.get("target_hex", "")))
            _intentions_by_target[str(key)] = {
                "intention": intention,
                "confidence": float(context.get("confidence", 0.0)),
            }
            if target != "":
                _intentions_by_target[target] = {
                    "intention": intention,
                    "confidence": float(context.get("confidence", 0.0)),
                }

    var orders := packet.get("orders", [])
    for order_payload in orders:
        if not (order_payload is Dictionary):
            continue
        var order_id := str(order_payload.get("order_id", order_payload.get("id", "")))
        var target_hex := str(order_payload.get("target", order_payload.get("target_hex", "")))
        if target_hex != "" and _intentions_by_target.has(order_id):
            _intentions_by_target[target_hex] = _intentions_by_target.get(order_id)

func _on_turn_started(turn_number: int) -> void:
    _turn_counter = turn_number
    for tile_id in _fog_by_tile.keys():
        var tile_state := _fog_by_tile.get(tile_id, _new_tile_state())
        tile_state["visibility"] = clamp(float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY)) - 0.05, DEFAULT_TILE_VISIBILITY, 1.0)
        tile_state["counter_intel"] = clamp(float(tile_state.get("counter_intel", 0.0)) + COUNTER_INTEL_GROWTH, 0.0, 1.0)
        _fog_by_tile[tile_id] = tile_state

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(collections.get("weather", []))
