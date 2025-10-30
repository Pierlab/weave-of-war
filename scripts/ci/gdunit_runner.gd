extends SceneTree

const TEST_ROOT := "res://tests/gdunit"
const SUPPORT_FILES := [
    "res://tests/gdunit/test_case.gd",
    "res://tests/gdunit/assertions.gd",
]

func _initialize() -> void:
    for support in SUPPORT_FILES:
        ResourceLoader.load(support)
    var test_files := _collect_test_files(TEST_ROOT)
    var failures: Array[Dictionary] = []
    var executed_tests := 0
    for test_path in test_files:
        if SUPPORT_FILES.has(test_path):
            continue
        var script := ResourceLoader.load(test_path)
        if script == null:
            failures.append({"name": test_path, "messages": ["Failed to load test script."]})
            continue
        var instance = script.new()
        if not instance.has_method("run_test"):
            if instance is Node:
                instance.free()
            failures.append({"name": test_path, "messages": ["Test script does not extend GdUnitLiteTestCase."]})
            continue
        var method_list := instance.get_method_list()
        for method_data in method_list:
            var method_name: String = method_data.name
            if method_name.begins_with("test_"):
                executed_tests += 1
                var result = instance.run_test(method_name)
                if result is GDScriptFunctionState:
                    result = await result
                if typeof(result) != TYPE_DICTIONARY:
                    failures.append({
                        "name": "%s::%s" % [test_path, method_name],
                        "messages": ["Test did not return a result dictionary."],
                    })
                    continue
                if not result.get("passed", false):
                    var messages: Array = result.get("messages", [])
                    failures.append({
                        "name": "%s::%s" % [test_path, method_name],
                        "messages": messages,
                    })
        if instance is Node:
            instance.free()
    if failures.is_empty():
        print("gdunit_runner: OK (%d tests)" % executed_tests)
        quit(0)
    else:
        for failure in failures:
            var failure_message := failure.get("name", "<unknown test>")
            var details: Array = failure.get("messages", [])
            if not details.is_empty():
                failure_message += "\n  - " + "\n  - ".join(details)
            push_error(failure_message)
        quit(1)


func _collect_test_files(base_path: String) -> Array[String]:
    var collected: Array[String] = []
    var dir := DirAccess.open(base_path)
    if dir == null:
        return collected
    dir.list_dir_begin()
    while true:
        var entry := dir.get_next()
        if entry == "":
            break
        if dir.current_is_dir():
            if entry.begins_with('.'):
                continue
            collected.append_array(_collect_test_files(base_path + "/" + entry))
        else:
            if entry.ends_with(".gd"):
                collected.append(base_path + "/" + entry)
    dir.list_dir_end()
    return collected
