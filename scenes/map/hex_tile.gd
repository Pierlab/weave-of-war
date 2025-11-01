class_name HexTile
extends Node2D

const TERRAIN_COLORS := {
    "plains": Color(0.305882, 0.52549, 0.403922, 1.0),
    "forest": Color(0.227, 0.396, 0.294, 1.0),
    "hill": Color(0.458, 0.4, 0.278, 1.0),
}

@export var axial_coords := Vector2.ZERO
var terrain_id := "plains"
var terrain_name := "Plains"
var terrain_description := ""
var movement_cost := 1.0

@onready var polygon: Polygon2D = $Polygon2D
@onready var label: Label = $Label

func _ready() -> void:
    _update_label()
    _apply_terrain_style()
    _update_tooltip()

func set_axial(q: int, r: int) -> void:
    axial_coords = Vector2(q, r)
    _update_label()
    _update_tooltip()

func set_terrain(data: Dictionary) -> void:
    terrain_id = str(data.get("id", data.get("terrain", terrain_id)))
    if terrain_id.is_empty():
        terrain_id = "plains"
    terrain_name = str(data.get("name", terrain_name))
    if terrain_name.is_empty():
        terrain_name = terrain_id.capitalize()
    terrain_description = str(data.get("description", terrain_description))
    movement_cost = float(data.get("movement_cost", movement_cost))
    _update_label()
    _apply_terrain_style()
    _update_tooltip()

func _update_label() -> void:
    if label == null:
        return
    var coords_text := "%d,%d" % [int(axial_coords.x), int(axial_coords.y)]
    if terrain_name.is_empty():
        label.text = coords_text
    else:
        label.text = "%s\n%s" % [coords_text, terrain_name]

func _update_tooltip() -> void:
    if label == null:
        return
    var heading := terrain_name if terrain_name != "" else terrain_id.capitalize()
    var lines := ["%s — coût déplacement %.1f" % [heading, movement_cost]]
    if terrain_description != "":
        lines.append(terrain_description)
    label.tooltip_text = "\n".join(lines)

func _apply_terrain_style() -> void:
    if polygon == null:
        return
    var base_color: Color = TERRAIN_COLORS.get(terrain_id, TERRAIN_COLORS.get("plains"))
    polygon.color = base_color
