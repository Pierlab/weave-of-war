extends Node

const EventBus := preload("res://scripts/core/event_bus.gd")

var event_bus: EventBus
var turn_manager: TurnManager

func _ready() -> void:
    event_bus = EventBus.get_instance()
    if event_bus == null and has_node("../EventBus"):
        event_bus = get_node("../EventBus")
    turn_manager = TurnManager.new()
    add_child(turn_manager)
    if event_bus:
        event_bus.next_turn_requested.connect(_on_next_turn_requested)
        event_bus.logistics_toggled.connect(_on_logistics_toggled)
        event_bus.spawn_unit_requested.connect(_on_spawn_unit_requested)
    turn_manager.start_game()

func _on_next_turn_requested() -> void:
    turn_manager.advance_turn()

func _on_logistics_toggled(show: bool) -> void:
    var state := "visible" if show else "hidden"
    print("Logistics overlay is now %s" % state)

func _on_spawn_unit_requested() -> void:
    print("Spawn unit requested (placeholder)")
