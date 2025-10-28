extends Node
class_name EventBus

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal next_turn_requested()
signal logistics_toggled(show: bool)
signal spawn_unit_requested()

static var _instance: EventBus
var _logistics_visible := false

func _ready() -> void:
    _instance = self
    add_to_group("event_bus")

static func get_instance() -> EventBus:
    return _instance

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
