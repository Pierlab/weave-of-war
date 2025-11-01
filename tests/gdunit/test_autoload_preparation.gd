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
    EventBus._instance = null
    DataLoader._instance = null
    Telemetry._instance = null
    AssistantAI._instance = null

func test_project_autoload_configuration() -> void:
    var config := ConfigFile.new()
    var error := config.load("res://project.godot")
    asserts.is_equal(error, OK, "project.godot should load so autoload entries can be inspected")
    if error != OK:
        return

    var expected := {
        "EventBusAutoload": "*res://scripts/core/event_bus.gd",
        "DataLoaderAutoload": "*res://scripts/core/data_loader.gd",
        "TelemetryAutoload": "*res://scripts/core/telemetry.gd",
        "AssistantAIAutoload": "*res://scripts/core/assistant_ai.gd",
    }

    for name in expected.keys():
        var value := str(config.get_value("autoload", name, ""))
        asserts.is_equal(value, expected[name], "Autoload %s should point to %s" % [name, expected[name]])

    var autoload_keys := config.get_section_keys("autoload")
    for key in autoload_keys:
        asserts.is_true(str(key).ends_with("Autoload"), "Autoload %s should follow the *Autoload naming pattern" % key)
func test_autoloads_emit_data_loader_ready_captured_by_telemetry() -> void:
    var tree := Engine.get_main_loop()
    asserts.is_true(tree is SceneTree, "Tests require a SceneTree main loop")
    if not (tree is SceneTree):
        return

    var root := tree.get_root()
    var event_bus: EventBus = EVENT_BUS.new()
    var data_loader: DataLoader = DATA_LOADER.new()
    var telemetry: Telemetry = TELEMETRY.new()
    var assistant_ai: AssistantAI = ASSISTANT_AI.new()

    root.add_child(event_bus)
    root.add_child(data_loader)
    root.add_child(telemetry)
    root.add_child(assistant_ai)

    _nodes_to_cleanup.append_array([assistant_ai, telemetry, data_loader, event_bus])

    await tree.process_frame
    await tree.process_frame

    asserts.is_true(data_loader.is_ready(), "DataLoader should report ready after autoload initialisation")

    var buffer := telemetry.get_buffer()
    var error_events: Array = []
    for entry in buffer:
        if entry.get("name") == StringName("data_loader_error"):
            error_events.append(entry)
    asserts.is_true(error_events.is_empty(), "Telemetry should not record data_loader_error during startup")

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

func test_telemetry_preserves_event_history() -> void:
    Telemetry._instance = null
    var telemetry: Telemetry = TELEMETRY.new()
    telemetry._ready()
    telemetry.clear()

    telemetry.log_event("espionage_ping", {"target": "0,0", "success": true})
    telemetry.log_event("espionage_ping", {"target": "1,0", "success": false})
    telemetry.log_event("combat_resolved", {"order_id": "advance"})

    var history := telemetry.get_history("espionage_ping")
    asserts.is_equal(2, history.size(), "Telemetry history should retain all espionage ping events")
    if history.size() == 2:
        var last_payload: Dictionary = history.back().get("payload", {})
        asserts.is_equal("1,0", last_payload.get("target", ""), "History should preserve payload order")
