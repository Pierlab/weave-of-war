extends Node
class_name TurnManager

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")

var current_turn: int = 0
var event_bus: EventBus

func _ready() -> void:
    event_bus = EVENT_BUS.get_instance()
    if event_bus == null:
        await get_tree().process_frame
        event_bus = EVENT_BUS.get_instance()

func start_game() -> void:
    current_turn = 0
    advance_turn()

func advance_turn() -> void:
    current_turn += 1
    _emit_turn_started()
    # Placeholder for systems integration.
    _emit_turn_ended()

func _emit_turn_started() -> void:
    print("Turn %d started" % current_turn)
    if event_bus:
        event_bus.emit_turn_started(current_turn)

func _emit_turn_ended() -> void:
    print("Turn %d ended" % current_turn)
    if event_bus:
        event_bus.emit_turn_ended(current_turn)
