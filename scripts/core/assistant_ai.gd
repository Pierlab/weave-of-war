class_name AssistantAIAutoload
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

static var _instance: AssistantAIAutoload

var _event_bus: EventBusAutoload
var _data_loader: DataLoaderAutoload

func _ready() -> void:
    _instance = self
    _event_bus = EVENT_BUS.get_instance()
    _data_loader = DATA_LOADER.get_instance()
    _connect_signals()

static func get_instance() -> AssistantAIAutoload:
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

    var order_id := str(payload.get("order_id", payload.get("id", "")))
    var order_data := _data_loader.get_order(order_id) if _data_loader else {}
    var intention := str(order_data.get("intention", "unknown"))
    var signal_strength := float(order_data.get("intel_profile", {}).get("signal_strength", 0.4))
    var enriched_order := payload.duplicate(true)
    enriched_order["intention"] = intention
    enriched_order["pillar_weights"] = order_data.get("pillar_weights", {})
    if not enriched_order.has("target") and not enriched_order.has("target_hex"):
        enriched_order["target"] = "frontline"

    var intents := {}
    intents[order_id] = {
        "intention": intention,
        "confidence": signal_strength,
        "target": enriched_order.get("target", enriched_order.get("target_hex", "")),
    }

    var engagement := {
        "engagement_id": "%s-%d" % [order_id if order_id != "" else "order", Time.get_ticks_msec()],
        "order_id": order_id,
        "attacker_unit_ids": enriched_order.get("unit_ids", []),
        "defender_unit_ids": enriched_order.get("defender_unit_ids", []),
        "terrain": enriched_order.get("terrain", "plains"),
        "intel_confidence": signal_strength,
        "reason": "assistant_prediction",
    }

    var packet := {
        "orders": [enriched_order],
        "intents": intents,
        "expected_engagements": [engagement],
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
