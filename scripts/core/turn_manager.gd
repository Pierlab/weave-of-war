extends Node
class_name TurnManager

var current_turn: int = 0
var event_bus: EventBus

func _ready() -> void:
    event_bus = EventBus.get_instance()
    if event_bus == null:
        var buses := get_tree().get_nodes_in_group("event_bus")
        if buses.size() > 0:
            event_bus = buses[0]

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
