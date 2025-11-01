class_name EventBusAutoload
extends Node

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal next_turn_requested()
signal logistics_toggled(show: bool)
signal spawn_unit_requested()
signal data_loader_ready(payload: Dictionary)
signal data_loader_error(context: Dictionary)
signal doctrine_selected(payload: Dictionary)
signal order_issued(payload: Dictionary)
signal assistant_order_packet(payload: Dictionary)
signal elan_spent(payload: Dictionary)
signal elan_updated(payload: Dictionary)
signal logistics_update(payload: Dictionary)
signal logistics_break(payload: Dictionary)
signal combat_resolved(payload: Dictionary)
signal espionage_ping(payload: Dictionary)
signal weather_changed(payload: Dictionary)
signal competence_reallocated(payload: Dictionary)
signal formation_changed(payload: Dictionary)
signal doctrine_change_requested(doctrine_id: String)
signal order_execution_requested(order_id: String)
signal order_execution_failed(payload: Dictionary)

static var _instance: EventBusAutoload
var _logistics_visible: bool = false

func _ready() -> void:
    _instance = self
    add_to_group("event_bus")
    var signal_count := 0
    for info in get_signal_list():
        if info is Dictionary and info.get("class_name", "") == "EventBusAutoload":
            signal_count += 1
    print("[Autoload] EventBusAutoload ready (signals registered: %d)" % signal_count)

static func get_instance() -> EventBusAutoload:
    return _instance

func emit_data_loader_ready(payload: Dictionary) -> void:
    data_loader_ready.emit(payload)

func emit_data_loader_error(context: Dictionary) -> void:
    data_loader_error.emit(context)

func emit_doctrine_selected(payload: Dictionary) -> void:
    doctrine_selected.emit(payload)

func emit_order_issued(payload: Dictionary) -> void:
    order_issued.emit(payload)

func emit_assistant_order_packet(payload: Dictionary) -> void:
    assistant_order_packet.emit(payload)

func emit_elan_spent(payload: Dictionary) -> void:
    elan_spent.emit(payload)

func emit_elan_updated(payload: Dictionary) -> void:
    elan_updated.emit(payload)

func emit_logistics_update(payload: Dictionary) -> void:
    logistics_update.emit(payload)

func emit_logistics_break(payload: Dictionary) -> void:
    logistics_break.emit(payload)

func emit_combat_resolved(payload: Dictionary) -> void:
    combat_resolved.emit(payload)

func emit_espionage_ping(payload: Dictionary) -> void:
    espionage_ping.emit(payload)

func emit_weather_changed(payload: Dictionary) -> void:
    weather_changed.emit(payload)

func emit_competence_reallocated(payload: Dictionary) -> void:
    competence_reallocated.emit(payload)

func emit_formation_changed(payload: Dictionary) -> void:
    formation_changed.emit(payload)

func request_next_turn() -> void:
    next_turn_requested.emit()

func emit_turn_started(turn_number: int) -> void:
    turn_started.emit(turn_number)

func emit_turn_ended(turn_number: int) -> void:
    turn_ended.emit(turn_number)

func toggle_logistics() -> void:
    _logistics_visible = !_logistics_visible
    logistics_toggled.emit(_logistics_visible)

func request_spawn_unit() -> void:
    spawn_unit_requested.emit()

func request_doctrine_change(doctrine_id: String) -> void:
    doctrine_change_requested.emit(doctrine_id)

func request_order_execution(order_id: String) -> void:
    order_execution_requested.emit(order_id)

func emit_order_execution_failed(payload: Dictionary) -> void:
    order_execution_failed.emit(payload)
