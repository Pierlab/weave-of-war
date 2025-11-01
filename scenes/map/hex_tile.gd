class_name HexTile
extends Node2D

const TERRAIN_COLORS := {
    "plains": Color(0.305882, 0.52549, 0.403922, 1.0),
    "forest": Color(0.227, 0.396, 0.294, 1.0),
    "hill": Color(0.458, 0.4, 0.278, 1.0),
}

const FOG_MIN_ALPHA := 0.0
const FOG_MAX_ALPHA := 0.85

@export var axial_coords := Vector2.ZERO
var terrain_id := "plains"
var terrain_name := "Plains"
var terrain_description := ""
var movement_cost := 1.0
var fog_visibility := 0.2

@onready var polygon: Polygon2D = $Polygon2D
@onready var label: Label = $Label
@onready var fog_overlay: Polygon2D = $FogOverlay

func _ready() -> void:
    _update_label()
    _apply_terrain_style()
    _update_tooltip()
    _update_fog_overlay()

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

func apply_visibility(value: float) -> void:
    fog_visibility = clamp(value, 0.0, 1.0)
    _update_fog_overlay()
    _update_label()
    _update_tooltip()

func _update_label() -> void:
    if label == null:
        return
    var coords_text := "%d,%d" % [int(axial_coords.x), int(axial_coords.y)]
    if fog_visibility < 0.35:
        label.text = "%s\n??" % coords_text
    elif terrain_name.is_empty():
        label.text = coords_text
    else:
        label.text = "%s\n%s" % [coords_text, terrain_name]
    label.visible = fog_visibility >= 0.15
    label.modulate = Color(1.0, 1.0, 1.0, clamp(fog_visibility + 0.2, 0.0, 1.0))

func _update_tooltip() -> void:
    if label == null:
        return
    var heading := terrain_name if terrain_name != "" else terrain_id.capitalize()
    if fog_visibility < 0.35:
        label.tooltip_text = "%s\nBrouillard de guerre" % heading
        return
    var lines := ["%s — coût déplacement %.1f" % [heading, movement_cost]]
    if terrain_description != "":
        lines.append(terrain_description)
    label.tooltip_text = "\n".join(lines)

func _apply_terrain_style() -> void:
    if polygon == null:
        return
    var base_color: Color = TERRAIN_COLORS.get(terrain_id, TERRAIN_COLORS.get("plains"))
    polygon.color = base_color

func _update_fog_overlay() -> void:
    if fog_overlay == null:
        return
    var intensity := clamp(1.0 - fog_visibility, 0.0, 1.0)
    if intensity <= 0.01:
        fog_overlay.visible = false
        return
    fog_overlay.visible = true
    var color := Color.BLACK
    color.a = lerp(FOG_MIN_ALPHA, FOG_MAX_ALPHA, intensity)
    fog_overlay.color = color
