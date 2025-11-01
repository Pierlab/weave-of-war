class_name TerrainData
extends Resource

## Basic terrain metadata for the procedural map prototype.

const TERRAIN_TYPES := {
    "plains": {
        "name": "Plains",
        "movement_cost": 1.0,
        "description": "Open ground that keeps convoys quick and logistics stable."
    },
    "forest": {
        "name": "Forest",
        "movement_cost": 2.0,
        "description": "Dense woodland that slows supply chains but offers concealment."
    },
    "hill": {
        "name": "Hill",
        "movement_cost": 3.0,
        "description": "Elevated ridges that tax convoys while improving lines of sight."
    }
}

static func get_default() -> Dictionary:
    return TERRAIN_TYPES
