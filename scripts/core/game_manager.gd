extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const DOCTRINE_SYSTEM := preload("res://scripts/systems/doctrine_system.gd")
const ELAN_SYSTEM := preload("res://scripts/systems/elan_system.gd")

var event_bus: EventBusAutoload
var turn_manager: TurnManager
var data_loader: DataLoaderAutoload
var doctrine_system: DoctrineSystem
var elan_system: ElanSystem

var _core_systems_initialised := false

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

    turn_manager = TurnManager.new()
    add_child(turn_manager)

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

    _core_systems_initialised = true

    var counts: Dictionary = payload.get("counts", {})
    assert(not counts.is_empty(), "GameManager expected data_loader_ready counts payload.")
    print("[GameManager] DataLoader ready → doctrines=%d, orders=%d, units=%d" % [
        counts.get("doctrines", 0),
        counts.get("orders", 0),
        counts.get("units", 0),
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
        }
    }
