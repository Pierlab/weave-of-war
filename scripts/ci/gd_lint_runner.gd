extends Node

const ROOT_DIR := "res://"

func _ready() -> void:
    var scripts := _collect_scripts(ROOT_DIR)
    var failures: Array[String] = []
    for script_path in scripts:
        var resource := ResourceLoader.load(script_path)
        if resource == null:
            failures.append("Failed to load %s" % script_path)
    if failures.is_empty():
        print("gd_lint_runner: OK (%d scripts)" % scripts.size())
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error(failure)
        get_tree().quit(1)


func _collect_scripts(base_path: String) -> Array[String]:
    var collected: Array[String] = []
    var dir := DirAccess.open(base_path)
    if dir == null:
        push_error("gd_lint_runner: unable to open %s" % base_path)
        return collected
    dir.list_dir_begin()
    while true:
        var entry := dir.get_next()
        if entry == "":
            break
        if dir.current_is_dir():
            if entry.begins_with('.'):
                continue
            collected.append_array(_collect_scripts(base_path + entry + "/"))
        else:
            if entry.ends_with(".gd"):
                collected.append(base_path + entry)
    dir.list_dir_end()
    return collected
