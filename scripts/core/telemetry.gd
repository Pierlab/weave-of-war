extends Node
class_name Telemetry

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")

static var _instance: Telemetry

var _buffer: Array = []
var _event_bus: EventBus

func _ready() -> void:
    _instance = self
    _event_bus = EVENT_BUS.get_instance()
    _connect_signals()

static func get_instance() -> Telemetry:
    return _instance

func log_event(name: StringName, payload: Dictionary = {}) -> void:
    var entry := {
        "name": name,
        "payload": payload.duplicate(true),
        "timestamp": Time.get_ticks_msec(),
    }
    _buffer.append(entry)

func get_buffer() -> Array:
    return _buffer.duplicate(true)

func clear() -> void:
    _buffer.clear()

func _connect_signals() -> void:
    if _event_bus == null:
        return

    _event_bus.turn_started.connect(_capture_event.bind("turn_started"))
    _event_bus.turn_ended.connect(_capture_event.bind("turn_ended"))
    _event_bus.elan_spent.connect(_capture_event.bind("elan_spent"))
    _event_bus.logistics_update.connect(_capture_event.bind("logistics_update"))
    _event_bus.logistics_break.connect(_capture_event.bind("logistics_break"))
    _event_bus.combat_resolved.connect(_capture_event.bind("combat_resolved"))
    _event_bus.espionage_ping.connect(_capture_event.bind("espionage_ping"))
    _event_bus.weather_changed.connect(_capture_event.bind("weather_changed"))
    _event_bus.assistant_order_packet.connect(_capture_event.bind("assistant_order_packet"))
    _event_bus.data_loader_ready.connect(_capture_event.bind("data_loader_ready"))
    _event_bus.data_loader_error.connect(_capture_event.bind("data_loader_error"))
    _event_bus.competence_reallocated.connect(_capture_event.bind("competence_reallocated"))
    _event_bus.formation_changed.connect(_capture_event.bind("formation_changed"))

func _capture_event(payload, event_name: StringName) -> void:
    if payload is Dictionary:
        log_event(event_name, payload)
    else:
        log_event(event_name, {"value": payload})
