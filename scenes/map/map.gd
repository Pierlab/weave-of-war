extends Node2D

const UTILS := preload("res://scripts/core/utils.gd")
const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const TERRAIN_DATA := preload("res://scenes/map/terrain_data.gd")
const FORMATION_OVERLAY := preload("res://scenes/map/formation_overlay.gd")
const HexTileScene := preload("res://scenes/map/hex_tile.tscn")
const HexTileScript := preload("res://scenes/map/hex_tile.gd")

@export var columns: int = 10
@export var rows: int = 10
@export var hex_scene: PackedScene = HexTileScene

var event_bus: EventBus
var data_loader: DataLoader
var _terrain_definitions: Dictionary = TERRAIN_DATA.get_default()
var _tiles: Dictionary = {}
var _default_visibility: float = 0.2
var _formation_overlay: FormationOverlay

func _ready() -> void:
    _generate_map()
    _apply_default_terrain()
    _acquire_sources()
    _configure_overlays()

func _acquire_sources() -> void:
    event_bus = EVENT_BUS.get_instance()
    data_loader = DATA_LOADER.get_instance()
    if event_bus == null or data_loader == null:
        await get_tree().process_frame
        if event_bus == null:
            event_bus = EVENT_BUS.get_instance()
        if data_loader == null:
            data_loader = DATA_LOADER.get_instance()
    if event_bus and not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
        event_bus.data_loader_ready.connect(_on_data_loader_ready)
    if event_bus and not event_bus.fog_of_war_updated.is_connected(_on_fog_of_war_updated):
        event_bus.fog_of_war_updated.connect(_on_fog_of_war_updated)
    if data_loader and data_loader.is_ready():
        _apply_terrain_from_data_loader()
    _configure_overlays()

func _on_data_loader_ready(_payload: Dictionary) -> void:
    data_loader = DATA_LOADER.get_instance()
    _apply_terrain_from_data_loader()
    _configure_overlays()

func _generate_map() -> void:
    for child in get_children():
        if child is HexTileScript:
            child.queue_free()
    _tiles.clear()
    for q in range(columns):
        for r in range(rows):
            var hex: Node2D = hex_scene.instantiate() as Node2D
            if hex.has_method("set_axial"):
                hex.set_axial(q, r)
            add_child(hex)
            hex.position = UTILS.axial_to_pixel(q, r)
            var tile_id: String = _tile_id(q, r)
            _tiles[tile_id] = hex
            if hex.has_method("apply_visibility"):
                hex.apply_visibility(_default_visibility)

func _apply_terrain_from_data_loader() -> void:
    if data_loader == null:
        _apply_default_terrain()
        return
    var definitions: Array = data_loader.list_terrain_definitions()
    if definitions.size() > 0:
        _merge_definitions(definitions)
    var tiles: Array = data_loader.list_terrain_tiles()
    if tiles.size() > 0:
        _apply_terrain_tiles(tiles)
    else:
        _apply_default_terrain()

func _merge_definitions(entries: Array) -> void:
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var id := str(entry.get("id", ""))
        if id.is_empty():
            continue
        var current_variant: Variant = _terrain_definitions.get(id, {})
        var current: Dictionary = {}
        if current_variant is Dictionary:
            current = current_variant
        _terrain_definitions[id] = {
            "name": str(entry.get("name", current.get("name", id.capitalize()))),
            "movement_cost": float(entry.get("movement_cost", current.get("movement_cost", 1.0))),
            "description": str(entry.get("description", current.get("description", ""))),
        }

func _apply_terrain_tiles(entries: Array) -> void:
    var applied: bool = false
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var q := int(entry.get("q", 0))
        var r := int(entry.get("r", 0))
        var tile_id: String = _tile_id(q, r)
        var terrain_id := str(entry.get("terrain", "plains"))
        var definition_variant: Variant = _terrain_definitions.get(terrain_id, {})
        var definition: Dictionary = {}
        if definition_variant is Dictionary:
            definition = definition_variant
        var name := str(entry.get("name", definition.get("name", terrain_id.capitalize())))
        var description := str(entry.get("description", definition.get("description", "")))
        var movement := float(entry.get("movement_cost", definition.get("movement_cost", 1.0)))
        _set_tile_terrain(tile_id, terrain_id, name, description, movement)
        applied = true
    if not applied:
        _apply_default_terrain()

func _apply_default_terrain() -> void:
    var keys: Array = _terrain_definitions.keys()
    keys.sort()
    var count: int = keys.size()
    if count == 0:
        return
    for tile_id in _tiles.keys():
        var coords: PackedStringArray = tile_id.split(",")
        if coords.size() < 2:
            continue
        var q: int = int(coords[0])
        var r: int = int(coords[1])
        var terrain_id := str(keys[(q + r) % count])
        var definition_variant: Variant = _terrain_definitions.get(terrain_id, {})
        var definition: Dictionary = {}
        if definition_variant is Dictionary:
            definition = definition_variant
        var name := str(definition.get("name", terrain_id.capitalize()))
        var description := str(definition.get("description", ""))
        var movement := float(definition.get("movement_cost", 1.0))
        _set_tile_terrain(tile_id, terrain_id, name, description, movement)

func _set_tile_terrain(tile_id: String, terrain_id: String, name: String, description: String, movement_cost: float) -> void:
    if not _tiles.has(tile_id):
        return
    var tile: Node = _tiles.get(tile_id) as Node
    if tile and tile.has_method("set_terrain"):
        tile.set_terrain({
            "id": terrain_id,
            "name": name,
            "description": description,
            "movement_cost": movement_cost,
        })

func _set_tile_visibility(tile_id: String, visibility: float) -> void:
    if not _tiles.has(tile_id):
        return
    var tile: Node = _tiles.get(tile_id) as Node
    if tile and tile.has_method("apply_visibility"):
        tile.apply_visibility(visibility)

func _on_fog_of_war_updated(payload: Dictionary) -> void:
    var entries_variant: Variant = payload.get("visibility", payload.get("visibility_map", []))
    var entries: Array = []
    if entries_variant is Array:
        entries = entries_variant
    var applied: Dictionary = {}
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var tile_id := str(entry.get("tile_id", ""))
        if tile_id == "":
            continue
        var visibility := clamp(float(entry.get("visibility", _default_visibility)), 0.0, 1.0)
        _set_tile_visibility(tile_id, visibility)
        applied[tile_id] = true
    for tile_id in _tiles.keys():
        if not applied.has(tile_id):
            _set_tile_visibility(tile_id, _default_visibility)

func _configure_overlays() -> void:
    if _formation_overlay == null:
        for child in get_children():
            if child is FORMATION_OVERLAY:
                _formation_overlay = child
                break
    if _formation_overlay:
        _formation_overlay.set_dimensions(columns, rows)
        _formation_overlay.set_data_sources(event_bus, data_loader)

func _tile_id(q: int, r: int) -> String:
    return "%d,%d" % [q, r]
