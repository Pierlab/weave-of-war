extends RefCounted
class_name WoWUtils

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
