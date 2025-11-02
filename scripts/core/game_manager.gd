extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const DOCTRINE_SYSTEM := preload("res://scripts/systems/doctrine_system.gd")
const ELAN_SYSTEM := preload("res://scripts/systems/elan_system.gd")
const LOGISTICS_SYSTEM := preload("res://scripts/systems/logistics_system.gd")
const WEATHER_SYSTEM := preload("res://scripts/systems/weather_system.gd")
const COMBAT_SYSTEM := preload("res://scripts/systems/combat_system.gd")
const ESPIONAGE_SYSTEM := preload("res://scripts/systems/espionage_system.gd")
const FORMATION_SYSTEM := preload("res://scripts/systems/formation_system.gd")

var event_bus: EventBus
var turn_manager: TurnManager
var data_loader: DataLoader
var doctrine_system: DoctrineSystem
var elan_system: ElanSystem
var logistics_system: LogisticsSystem
var weather_system: WeatherSystem
var combat_system: CombatSystem
var espionage_system: EspionageSystem
var formation_system: Node

var _core_systems_initialised: bool = false

func _ready() -> void:
    event_bus = EVENT_BUS.get_instance()
    if event_bus == null:
        await get_tree().process_frame
        event_bus = EVENT_BUS.get_instance()

    data_loader = DATA_LOADER.get_instance()

    doctrine_system = DOCTRINE_SYSTEM.new()
    add_child(doctrine_system)

    elan_system = ELAN_SYSTEM.new()
    add_child(elan_system)

    logistics_system = LOGISTICS_SYSTEM.new()
    add_child(logistics_system)

    weather_system = WEATHER_SYSTEM.new()
    add_child(weather_system)

    combat_system = COMBAT_SYSTEM.new()
    add_child(combat_system)

    espionage_system = ESPIONAGE_SYSTEM.new()
    add_child(espionage_system)

    formation_system = FORMATION_SYSTEM.new()
    add_child(formation_system)

    turn_manager = TurnManager.new()
    add_child(turn_manager)
    if elan_system:
        elan_system.set_turn_manager(turn_manager)

    if event_bus:
        event_bus.next_turn_requested.connect(_on_next_turn_requested)
        event_bus.logistics_toggled.connect(_on_logistics_toggled)
        event_bus.spawn_unit_requested.connect(_on_spawn_unit_requested)
        event_bus.data_loader_ready.connect(_on_data_loader_ready)
        event_bus.data_loader_error.connect(_on_data_loader_error)

    if data_loader and data_loader.is_ready():
        _on_data_loader_ready(_build_data_loader_payload())
    else:
        print("[GameManager] Waiting for DataLoader readiness before initialising Doctrine/Élan systems.")

func _on_next_turn_requested() -> void:
    turn_manager.advance_turn()

func _on_logistics_toggled(should_show: bool) -> void:
    var state: String = "visible" if should_show else "hidden"
    print("Logistics overlay is now %s" % state)

func _on_spawn_unit_requested() -> void:
    print("Spawn unit requested (placeholder)")

func _on_data_loader_ready(payload: Dictionary) -> void:
    if _core_systems_initialised:
        return

    if data_loader == null or not data_loader.is_ready():
        push_warning("DataLoader reported ready but instance is missing or not ready; deferring core system setup.")
        return

    doctrine_system.setup(event_bus, data_loader)
    elan_system.setup(event_bus, data_loader)
    if combat_system:
        combat_system.setup(event_bus, data_loader)
    if weather_system:
        weather_system.setup(event_bus, data_loader)
    if logistics_system:
        logistics_system.setup(event_bus, data_loader)
    if espionage_system:
        espionage_system.setup(event_bus, data_loader)
        var terrain_lookup: Dictionary = _build_terrain_lookup(payload)
        if not terrain_lookup.is_empty():
            espionage_system.configure_map(terrain_lookup)
    if formation_system and formation_system.has_method("setup"):
        formation_system.call(
            "setup",
            event_bus,
            data_loader,
            combat_system,
            elan_system,
            turn_manager,
        )

    _core_systems_initialised = true

    var counts: Dictionary = payload.get("counts", {})
    assert(not counts.is_empty(), "GameManager expected data_loader_ready counts payload.")
    print("[GameManager] DataLoader ready → doctrines=%d, orders=%d, units=%d, terrain_tiles=%d" % [
        counts.get("doctrines", 0),
        counts.get("orders", 0),
        counts.get("units", 0),
        counts.get("terrain", 0),
    ])

    turn_manager.start_game()

func _on_data_loader_error(context: Dictionary) -> void:
    var errors: Array = context.get("errors", [])
    push_warning("DataLoader reported %d error(s): %s" % [errors.size(), errors])

func _build_data_loader_payload() -> Dictionary:
    var counts: Dictionary = {}
    if data_loader:
        var summary: Dictionary = data_loader.get_summary()
        counts = summary.get("counts", {})
    return {
        "counts": counts,
        "collections": {
            "doctrines": data_loader.list_doctrines() if data_loader else [],
            "orders": data_loader.list_orders() if data_loader else [],
            "units": data_loader.list_units() if data_loader else [],
            "weather": data_loader.list_weather_states() if data_loader else [],
            "logistics": data_loader.list_logistics_states() if data_loader else [],
            "formations": data_loader.list_formations() if data_loader else [],
            "terrain": data_loader.list_terrain_entries() if data_loader else [],
        }
    }

func _build_terrain_lookup(payload: Dictionary) -> Dictionary:
    var terrain_entries: Array = _extract_terrain_entries(payload)
    if terrain_entries.is_empty():
        return {}

    var definitions: Dictionary = _index_terrain_definitions(terrain_entries)
    var lookup: Dictionary = {}
    for entry in terrain_entries:
        var descriptor: Dictionary = _build_tile_descriptor(entry, definitions)
        if descriptor.is_empty():
            continue
        var tile_id: String = str(descriptor.get("tile_id", ""))
        if tile_id.is_empty():
            continue
        lookup[tile_id] = descriptor
    return lookup

func _extract_terrain_entries(payload: Dictionary) -> Array:
    var collections: Dictionary = payload.get("collections", {})
    var terrain_entries_variant: Variant = collections.get("terrain", [])
    if terrain_entries_variant is Array:
        return terrain_entries_variant
    if data_loader:
        return data_loader.list_terrain_entries()
    return []

func _index_terrain_definitions(entries: Array) -> Dictionary:
    var definitions: Dictionary = {}
    for entry in entries:
        if not (entry is Dictionary):
            continue
        if str(entry.get("type", "")) != "definition":
            continue
        var definition_id: String = str(entry.get("id", ""))
        if definition_id.is_empty():
            continue
        definitions[definition_id] = {
            "name": str(entry.get("name", definition_id.capitalize())),
            "description": str(entry.get("description", "")),
            "movement_cost": float(entry.get("movement_cost", 1.0)),
        }
    return definitions

func _build_tile_descriptor(entry: Dictionary, definitions: Dictionary) -> Dictionary:
    if not (entry is Dictionary):
        return {}
    if str(entry.get("type", "")) != "tile":
        return {}

    var q: int = int(entry.get("q", 0))
    var r: int = int(entry.get("r", 0))
    var tile_id: String = str(entry.get("id", "%d,%d" % [q, r]))
    if tile_id.is_empty():
        tile_id = "%d,%d" % [q, r]

    var terrain_id: String = str(entry.get("terrain", "plains"))
    var definition: Dictionary = definitions.get(terrain_id, {})
    var name: String = str(entry.get("name", definition.get("name", terrain_id.capitalize())))
    var description: String = str(entry.get("description", definition.get("description", "")))
    var movement: float = float(entry.get("movement_cost", definition.get("movement_cost", 1.0)))

    return {
        "tile_id": tile_id,
        "q": q,
        "r": r,
        "terrain": terrain_id,
        "name": name,
        "description": description,
        "movement_cost": movement,
    }
