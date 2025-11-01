extends GdUnitLiteTestCase

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const GAME_MANAGER := preload("res://scripts/core/game_manager.gd")

var _nodes_to_cleanup: Array = []

func after_each() -> void:
    var tree := Engine.get_main_loop()
    if tree is SceneTree:
        for node in _nodes_to_cleanup:
            if is_instance_valid(node):
                node.queue_free()
        _nodes_to_cleanup.clear()
        await tree.process_frame
    EventBusAutoload._instance = null
    DataLoaderAutoload._instance = null

func test_game_manager_bootstraps_logistics_system() -> void:
    var tree := Engine.get_main_loop()
    asserts.is_true(tree is SceneTree, "Tests require a SceneTree main loop")
    if not (tree is SceneTree):
        return

    var root := tree.get_root()

    var event_bus: EventBusAutoload = EVENT_BUS.new()
    var data_loader: DataLoaderAutoload = DATA_LOADER.new()

    root.add_child(event_bus)
    root.add_child(data_loader)
    _nodes_to_cleanup.append_array([data_loader, event_bus])

    await tree.process_frame
    await tree.process_frame

    var manager: Node = GAME_MANAGER.new()
    root.add_child(manager)
    _nodes_to_cleanup.append(manager)

    await tree.process_frame
    await tree.process_frame

    var logistics_system := manager.logistics_system as LogisticsSystem
    asserts.is_instance_valid(logistics_system, "GameManager should instantiate LogisticsSystem")
    asserts.is_equal(event_bus, logistics_system.event_bus, "LogisticsSystem should bind to the shared EventBus instance")

    var updates: Array = []
    event_bus.logistics_update.connect(func(payload: Dictionary) -> void:
        updates.append(payload)
    )

    var initial_payload := logistics_system.get_last_payload()
    var initial_turn := int(initial_payload.get("turn", 0))

    event_bus.toggle_logistics()
    await tree.process_frame

    asserts.is_true(updates.size() > 0, "Toggling the logistics overlay should emit an update payload")
    var toggle_payload: Dictionary = updates[updates.size() - 1]
    asserts.is_true(toggle_payload.get("visible", false), "Logistics overlay toggle should mark the system visible")

    updates.clear()

    event_bus.emit_turn_started(42)
    await tree.process_frame

    asserts.is_true(updates.size() > 0, "Turn start should trigger a logistics update")
    var turn_payload: Dictionary = logistics_system.get_last_payload()
    asserts.is_equal(initial_turn + 1, int(turn_payload.get("turn", 0)), "LogisticsSystem should advance its turn counter when the EventBus emits turn_started")
