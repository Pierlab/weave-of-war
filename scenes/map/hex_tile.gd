class_name HexTile
extends Node2D

@export var axial_coords := Vector2.ZERO
@onready var label: Label = $Label

func _ready() -> void:
    _update_label()

func set_axial(q: int, r: int) -> void:
    axial_coords = Vector2(q, r)
    _update_label()

func _update_label() -> void:
    if label:
        label.text = "%d,%d" % [int(axial_coords.x), int(axial_coords.y)]
