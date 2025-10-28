extends SceneTree

const SCENES := [
    "res://scenes/main.tscn",
]

func _initialize() -> void:
    var failures: Array[String] = []
    for scene_path in SCENES:
        var packed_scene: PackedScene = ResourceLoader.load(scene_path)
        if packed_scene == null:
            failures.append("Failed to load scene %s" % scene_path)
            continue
        var instance := packed_scene.instantiate()
        if instance == null:
            failures.append("Failed to instantiate scene %s" % scene_path)
        else:
            instance.queue_free()
    if failures.is_empty():
        print("gd_build_check: OK (%d scenes)" % SCENES.size())
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
