extends Node
class_name AssistantAI

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

static var _instance: AssistantAI

var _event_bus: EventBus
var _data_loader: DataLoader

func _ready() -> void:
    _instance = self
    _event_bus = EVENT_BUS.get_instance()
    _data_loader = DATA_LOADER.get_instance()
    _connect_signals()

static func get_instance() -> AssistantAI:
    return _instance

func _connect_signals() -> void:
    if _event_bus == null:
        return

    _event_bus.order_issued.connect(_on_order_issued)
    _event_bus.doctrine_selected.connect(_on_doctrine_selected)
    _event_bus.competence_reallocated.connect(_on_competence_reallocated)
    _event_bus.data_loader_ready.connect(_on_data_ready)

func _on_order_issued(payload: Dictionary) -> void:
    if _data_loader == null:
        _data_loader = DATA_LOADER.get_instance()

    var packet := {
        "orders": [payload],
        "intents": {},
        "expected_outcomes": {},
    }

    if _event_bus:
        _event_bus.emit_assistant_order_packet(packet)

func _on_doctrine_selected(_payload: Dictionary) -> void:
    # Placeholder for doctrine awareness; will influence packet generation in Checklist C.
    pass

func _on_competence_reallocated(_payload: Dictionary) -> void:
    # Placeholder for competence budgeting hooks to adjust assistant intent suggestions.
    pass

func _on_data_ready(_payload: Dictionary) -> void:
    # Data is now confirmed; upcoming Checklist C work can assume loader caches are populated.
    pass
