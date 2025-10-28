extends Resource
class_name TerrainData

## Basic terrain metadata for the procedural map prototype.

const TERRAIN_TYPES := {
    "plains": {
        "name": "Plains",
        "movement_cost": 1
    },
    "forest": {
        "name": "Forest",
        "movement_cost": 2
    },
    "hill": {
        "name": "Hill",
        "movement_cost": 3
    }
}

static func get_default() -> Dictionary:
    return TERRAIN_TYPES
