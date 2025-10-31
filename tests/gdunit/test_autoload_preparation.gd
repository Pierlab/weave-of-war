extends GdUnitLiteTestCase

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const TELEMETRY := preload("res://scripts/core/telemetry.gd")
const ASSISTANT_AI := preload("res://scripts/core/assistant_ai.gd")

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
    TelemetryAutoload._instance = null
    AssistantAIAutoload._instance = null

func test_autoloads_emit_data_loader_ready_captured_by_telemetry() -> void:
    var tree := Engine.get_main_loop()
    asserts.is_true(tree is SceneTree, "Tests require a SceneTree main loop")
    if not (tree is SceneTree):
        return

    var root := tree.get_root()
    var event_bus: EventBusAutoload = EVENT_BUS.new()
    var data_loader: DataLoaderAutoload = DATA_LOADER.new()
    var telemetry: TelemetryAutoload = TELEMETRY.new()
    var assistant_ai: AssistantAIAutoload = ASSISTANT_AI.new()

    root.add_child(event_bus)
    root.add_child(data_loader)
    root.add_child(telemetry)
    root.add_child(assistant_ai)

    _nodes_to_cleanup.append_array([assistant_ai, telemetry, data_loader, event_bus])

    await tree.process_frame
    await tree.process_frame

    var buffer := telemetry.get_buffer()
    var ready_events: Array = []
    for entry in buffer:
        if entry.get("name") == StringName("data_loader_ready"):
            ready_events.append(entry)
    asserts.is_true(ready_events.size() == 1, "Telemetry should log exactly one data_loader_ready event during autoload init")

    var payload := ready_events[0].get("payload", {}) if ready_events.size() > 0 else {}
    asserts.is_true(payload.has("counts"), "Telemetry payload should include data collection counts")
    asserts.is_true(payload.has("collections"), "Telemetry payload should include raw data collections for downstream systems")

    # Ensure AssistantAI received the ready payload to guarantee downstream systems can rely on it.
    var assistant_received := assistant_ai._data_loader != null and assistant_ai._data_loader.is_ready()
    asserts.is_true(assistant_received, "AssistantAI should have access to the ready DataLoader instance after initialisation")
