extends GdUnitLiteTestCase

func test_main_scene_loads() -> void:
    var scene_path := "res://scenes/main.tscn"
    var packed_scene: PackedScene = ResourceLoader.load(scene_path)
    asserts.is_not_null(packed_scene, "Main scene should load without errors")
    if packed_scene != null:
        var instance := packed_scene.instantiate()
        asserts.is_not_null(instance, "Main scene should instantiate")
        if instance != null:
            asserts.is_instance(instance, "Node", "Main scene instance should be a Node")
            instance.queue_free()
