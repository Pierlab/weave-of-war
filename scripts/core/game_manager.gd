extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

var event_bus: EventBus
var turn_manager: TurnManager
var data_loader: DataLoader

func _ready() -> void:
    event_bus = EVENT_BUS.get_instance()
    if event_bus == null:
        await get_tree().process_frame
        event_bus = EVENT_BUS.get_instance()

    data_loader = DATA_LOADER.get_instance()

    turn_manager = TurnManager.new()
    add_child(turn_manager)

    if event_bus:
        event_bus.next_turn_requested.connect(_on_next_turn_requested)
        event_bus.logistics_toggled.connect(_on_logistics_toggled)
        event_bus.spawn_unit_requested.connect(_on_spawn_unit_requested)
        event_bus.data_loader_ready.connect(_on_data_loader_ready)
        event_bus.data_loader_error.connect(_on_data_loader_error)

    turn_manager.start_game()

func _on_next_turn_requested() -> void:
    turn_manager.advance_turn()

func _on_logistics_toggled(should_show: bool) -> void:
    var state := "visible" if should_show else "hidden"
    print("Logistics overlay is now %s" % state)

func _on_spawn_unit_requested() -> void:
    print("Spawn unit requested (placeholder)")

func _on_data_loader_ready(payload: Dictionary) -> void:
    var counts := payload.get("counts", {})
    print("DataLoader ready → doctrines=%d, orders=%d, units=%d" % [
        counts.get("doctrines", 0),
        counts.get("orders", 0),
        counts.get("units", 0),
    ])

func _on_data_loader_error(context: Dictionary) -> void:
    var errors := context.get("errors", [])
    push_warning("DataLoader reported %d error(s): %s" % [errors.size(), errors])
