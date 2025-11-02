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

var event_bus: EventBus
var data_loader: DataLoader

var _fog_by_tile: Dictionary = {}
var _weather_by_id: Dictionary = {}
var _current_weather_id := ""
var _last_ping: Dictionary = {}
var _intentions_by_target: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _turn_counter := 0

func _ready() -> void:
    setup(EVENT_BUS.get_instance(), DATA_LOADER.get_instance())

func setup(event_bus_ref: EventBus, data_loader_ref: DataLoader) -> void:
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
        if not event_bus.assistant_order_packet.is_connected(_on_assistant_order_packet):
            event_bus.assistant_order_packet.connect(_on_assistant_order_packet)
        if not event_bus.turn_started.is_connected(_on_turn_started):
            event_bus.turn_started.connect(_on_turn_started)
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.order_issued.is_connected(_on_order_issued):
            event_bus.order_issued.connect(_on_order_issued)

func configure(weather_entries: Array) -> void:
    _weather_by_id = {}
    for entry_variant in weather_entries:
        if not (entry_variant is Dictionary):
            continue
        var entry: Dictionary = entry_variant
        if not entry.has("id"):
            continue
        _weather_by_id[str(entry.get("id"))] = entry
    var weather_ids: Array = _weather_by_id.keys()
    if _current_weather_id.is_empty() and not weather_ids.is_empty():
        _current_weather_id = str(weather_ids[0])
    elif not _weather_by_id.has(_current_weather_id) and not weather_ids.is_empty():
        _current_weather_id = str(weather_ids[0])

func configure_map(terrain_tiles: Dictionary) -> void:
    _fog_by_tile.clear()
    for tile_id in terrain_tiles.keys():
        _fog_by_tile[str(tile_id)] = _new_tile_state()
    _emit_fog_update()

func set_rng_seed(seed: int) -> void:
    _rng.seed = seed

func ingest_logistics_payload(payload: Dictionary) -> void:
    var supply_zones_variant: Variant = payload.get("supply_zones", [])
    var supply_zones: Array = []
    if supply_zones_variant is Array:
        supply_zones = supply_zones_variant
    for zone_variant in supply_zones:
        if not (zone_variant is Dictionary):
            continue
        var zone: Dictionary = zone_variant
        var tile_id := str(zone.get("tile_id", ""))
        if tile_id == "":
            continue
        var level := str(zone.get("supply_level", "isolated"))
        var tile_state: Dictionary = _fog_by_tile.get(tile_id, _new_tile_state())
        var visibility: float = SUPPLY_VISIBILITY.get(level, DEFAULT_TILE_VISIBILITY)
        tile_state["visibility"] = max(float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY)), visibility)
        tile_state["counter_intel"] = max(float(tile_state.get("counter_intel", 0.0)) - COUNTER_INTEL_DECAY, 0.0)
        _fog_by_tile[tile_id] = tile_state
    _turn_counter = int(payload.get("turn", _turn_counter))
    _emit_fog_update()

func perform_ping(target: String, probe_strength := BASE_PROBE_STRENGTH, metadata: Dictionary = {}) -> Dictionary:
    if target.is_empty():
        return {}
    var tile_state: Dictionary = _fog_by_tile.get(target, _new_tile_state())
    _fog_by_tile[target] = tile_state

    var weather_noise: float = _current_weather_noise()
    var detection_bonus: float = float(metadata.get("detection_bonus", 0.0))
    var intention_context: Dictionary = {}
    var intention_context_variant: Variant = _intentions_by_target.get(target, {})
    if intention_context_variant is Dictionary:
        intention_context = intention_context_variant
    if intention_context.is_empty():
        var fallback_variant: Variant = _intentions_by_target.get(metadata.get("order_id", ""), {})
        if fallback_variant is Dictionary:
            intention_context = fallback_variant

    var base_visibility: float = float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY))
    var counter_intel: float = float(tile_state.get("counter_intel", 0.0))
    var effective_confidence: float = clamp(base_visibility + probe_strength + detection_bonus - (weather_noise + counter_intel), 0.0, 1.0)
    var roll: float = _rng.randf()
    var success: bool = roll <= effective_confidence

    var revealed_intention := "unknown"
    if success and not intention_context.is_empty():
        revealed_intention = str(intention_context.get("intention", "unknown"))

    tile_state["visibility"] = clamp(max(base_visibility, effective_confidence + (0.15 if success else 0.0)), DEFAULT_TILE_VISIBILITY, 1.0)
    tile_state["counter_intel"] = clamp(counter_intel + (COUNTER_INTEL_GROWTH if not success else COUNTER_INTEL_GROWTH * 0.25), 0.0, 1.0)
    _fog_by_tile[target] = tile_state

    var visibility_after: float = float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY))
    var counter_intel_after: float = float(tile_state.get("counter_intel", 0.0))
    var intention_confidence: float = 0.0
    if not intention_context.is_empty():
        intention_confidence = float(intention_context.get("confidence", intention_confidence))

    var payload: Dictionary = {
        "target": target,
        "success": success,
        "confidence": snapped(effective_confidence, 0.01),
        "noise": snapped(weather_noise + counter_intel, 0.01),
        "intention": revealed_intention,
        "intent_category": revealed_intention,
        "intention_confidence": snapped(intention_confidence, 0.01),
        "turn": _turn_counter,
        "source": metadata.get("source", "probe"),
        "order_id": metadata.get("order_id", metadata.get("source", "")),
        "roll": snapped(roll, 0.01),
        "probe_strength": snapped(probe_strength, 0.01),
        "detection_bonus": snapped(detection_bonus, 0.01),
        "visibility_before": snapped(base_visibility, 0.01),
        "visibility_after": snapped(visibility_after, 0.01),
        "counter_intel_before": snapped(counter_intel, 0.01),
        "counter_intel_after": snapped(counter_intel_after, 0.01),
        "visibility_map": _build_visibility_snapshot(),
    }

    if metadata.has("competence_remaining") and metadata.get("competence_remaining") is Dictionary:
        payload["competence_remaining"] = (metadata.get("competence_remaining") as Dictionary).duplicate(true)

    _last_ping = payload.duplicate(true)
    if event_bus:
        event_bus.emit_espionage_ping(_last_ping)
        if revealed_intention != "unknown":
            event_bus.emit_intel_intent_revealed({
                "target": target,
                "intention": revealed_intention,
                "intent_category": revealed_intention,
                "intention_confidence": snapped(intention_confidence, 0.01),
                "confidence": snapped(effective_confidence, 0.01),
                "turn": _turn_counter,
                "source": metadata.get("source", "probe"),
                "order_id": metadata.get("order_id", metadata.get("source", "")),
                "roll": snapped(roll, 0.01),
                "noise": snapped(weather_noise + counter_intel, 0.01),
                "probe_strength": snapped(probe_strength, 0.01),
                "detection_bonus": snapped(detection_bonus, 0.01),
                "visibility_before": snapped(base_visibility, 0.01),
                "visibility_after": snapped(visibility_after, 0.01),
            })
        _emit_fog_update()
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
    snapshot.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("tile_id", "")) < str(b.get("tile_id", ""))
    )
    return snapshot

func _on_logistics_update(payload: Dictionary) -> void:
    ingest_logistics_payload(payload)

func _on_weather_changed(payload: Dictionary) -> void:
    var weather_id := str(payload.get("weather_id", ""))
    if weather_id != "":
        _current_weather_id = weather_id

func _on_assistant_order_packet(packet: Dictionary) -> void:
    var intents_variant: Variant = packet.get("intents", {})
    if intents_variant is Dictionary:
        var intents: Dictionary = intents_variant
        for key in intents.keys():
            var context_variant: Variant = intents.get(key)
            if not (context_variant is Dictionary):
                continue
            var context: Dictionary = context_variant
            var intention := str(context.get("intention", ""))
            if intention.is_empty():
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

    var orders_variant: Variant = packet.get("orders", [])
    if orders_variant is Array:
        var orders: Array = orders_variant
        for order_payload_variant in orders:
            if not (order_payload_variant is Dictionary):
                continue
            var order_payload: Dictionary = order_payload_variant
            var order_id := str(order_payload.get("order_id", order_payload.get("id", "")))
            var target_hex := str(order_payload.get("target", order_payload.get("target_hex", "")))
            if target_hex != "" and _intentions_by_target.has(order_id):
                _intentions_by_target[target_hex] = _intentions_by_target.get(order_id)

func _on_order_issued(payload: Dictionary) -> void:
    var order_id := str(payload.get("order_id", ""))
    if order_id == "":
        return
    if order_id != "recon_probe" and order_id != "deep_cover":
        return
    var metadata_variant: Variant = payload.get("metadata", {})
    var metadata: Dictionary = metadata_variant if metadata_variant is Dictionary else {}
    var target := _select_recon_target(order_id, metadata)
    if target.is_empty():
        return
    var intel_profile_variant: Variant = metadata.get("intel_profile", {})
    var intel_profile: Dictionary = intel_profile_variant if intel_profile_variant is Dictionary else {}
    var probe_strength := float(intel_profile.get("signal_strength", BASE_PROBE_STRENGTH))
    var detection_bonus := _competence_detection_bonus(metadata.get("competence_cost", {}))
    var context := {
        "source": order_id,
        "order_id": order_id,
        "target_hex": target,
        "detection_bonus": detection_bonus,
    }
    var remaining_variant: Variant = metadata.get("competence_remaining", {})
    if remaining_variant is Dictionary:
        context["competence_remaining"] = (remaining_variant as Dictionary).duplicate(true)
    perform_ping(target, probe_strength, context)

func _on_turn_started(turn_number: int) -> void:
    _turn_counter = turn_number
    for tile_id in _fog_by_tile.keys():
        var tile_state: Dictionary = _fog_by_tile.get(tile_id, _new_tile_state())
        tile_state["visibility"] = clamp(float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY)) - 0.05, DEFAULT_TILE_VISIBILITY, 1.0)
        tile_state["counter_intel"] = clamp(float(tile_state.get("counter_intel", 0.0)) + COUNTER_INTEL_GROWTH, 0.0, 1.0)
        _fog_by_tile[tile_id] = tile_state
    _emit_fog_update()

func _emit_fog_update() -> void:
    if event_bus == null:
        return
    event_bus.emit_fog_of_war_updated({
        "turn": _turn_counter,
        "visibility": _build_visibility_snapshot(),
    })

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(collections.get("weather", []))

func _select_recon_target(order_id: String, metadata: Dictionary) -> String:
    var explicit_target := str(metadata.get("target_hex", metadata.get("target", "")))
    if not explicit_target.is_empty():
        return explicit_target
    if _fog_by_tile.is_empty():
        return ""
    var selected := ""
    var best_score := INF
    for tile_id in _fog_by_tile.keys():
        var tile_state: Dictionary = _fog_by_tile.get(tile_id, _new_tile_state())
        var visibility := float(tile_state.get("visibility", DEFAULT_TILE_VISIBILITY))
        var counter_intel := float(tile_state.get("counter_intel", 0.0))
        var score := visibility - counter_intel * 0.5
        if order_id == "deep_cover":
            score = (1.0 - visibility) + counter_intel
        if selected == "" or score < best_score:
            best_score = score
            selected = tile_id
    return selected

func _competence_detection_bonus(cost_variant: Variant) -> float:
    if not (cost_variant is Dictionary):
        return 0.0
    var total: float = 0.0
    for value in (cost_variant as Dictionary).values():
        total += max(float(value), 0.0)
    return clamp(total * 0.05, 0.0, 0.3)
