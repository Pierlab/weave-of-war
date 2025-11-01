class_name WoWUtils
extends RefCounted

## Utility helpers for the Weave of War prototype.

const HEX_WIDTH := 64.0
const HEX_HEIGHT := 56.0

static func axial_to_pixel(q: int, r: int) -> Vector2:
    var x := HEX_WIDTH * (q + r / 2.0)
    var y := HEX_HEIGHT * (r * 0.8660254038)
    return Vector2(x, y)

static func pixel_to_axial(position: Vector2) -> Vector2:
    var q := (position.x * 2.0 / 3.0) / (HEX_WIDTH / 2.0)
    var r := ((-position.x / 3.0) + (0.5773502692 * position.y)) / (HEX_HEIGHT / 2.0)
    return Vector2(q, r)

static func build_terrain_tooltip(definitions: Array, tiles: Array) -> String:
    var definition_lookup: Dictionary = {}
    for entry in definitions:
        if not (entry is Dictionary):
            continue
        var terrain_id := String(entry.get("id", ""))
        if terrain_id.is_empty():
            continue
        definition_lookup[terrain_id] = {
            "name": String(entry.get("name", terrain_id.capitalize())),
            "movement_cost": float(entry.get("movement_cost", 1.0)),
            "description": String(entry.get("description", "")),
        }

    var counts: Dictionary = {}
    for tile_entry in tiles:
        if not (tile_entry is Dictionary):
            continue
        var tile_terrain := String(tile_entry.get("terrain", ""))
        if tile_terrain.is_empty():
            continue
        counts[tile_terrain] = int(counts.get(tile_terrain, 0)) + 1

    var ordered_ids := ["plains", "forest", "hill"]
    var lines: Array[String] = []

    for terrain_id in ordered_ids:
        if definition_lookup.has(terrain_id) or counts.has(terrain_id):
            lines += _terrain_summary_lines(terrain_id, definition_lookup, counts)

    for terrain_id in definition_lookup.keys():
        if ordered_ids.has(terrain_id):
            continue
        lines += _terrain_summary_lines(terrain_id, definition_lookup, counts)

    if lines.is_empty():
        return "Terrains : données non chargées."
    lines.insert(0, "Terrains connus :")
    return "\n".join(lines)

static func _terrain_summary_lines(terrain_id: String, definition_lookup: Dictionary, counts: Dictionary) -> Array[String]:
    var lines: Array[String] = []
    var info: Dictionary = definition_lookup.get(terrain_id, {})
    var name := String(info.get("name", terrain_id.capitalize()))
    var movement := float(info.get("movement_cost", 1.0))
    var description := String(info.get("description", ""))
    var count := int(counts.get(terrain_id, 0))
    var plural_suffix := "s" if count != 1 else ""
    var summary := "%s — coût %.1f (%d tuile%s)" % [name, movement, count, plural_suffix]
    lines.append(summary)
    if not description.is_empty():
        lines.append("  %s" % description)
    return lines
