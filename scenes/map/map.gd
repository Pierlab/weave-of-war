extends Node2D

const Utils := preload("res://scripts/core/utils.gd")
const HexTileScene := preload("res://scenes/map/hex_tile.tscn")

@export var columns := 10
@export var rows := 10
@export var hex_scene: PackedScene = HexTileScene

func _ready() -> void:
    _generate_map()

func _generate_map() -> void:
    for child in get_children():
        if child is HexTile:
            child.queue_free()
    for q in range(columns):
        for r in range(rows):
            var hex := hex_scene.instantiate()
            if hex.has_method("set_axial"):
                hex.set_axial(q, r)
            add_child(hex)
            hex.position = Utils.axial_to_pixel(q, r)
