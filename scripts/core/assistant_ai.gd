class_name AssistantAI
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

static var _instance: AssistantAI

var _event_bus: EventBus
var _data_loader: DataLoader
var _recent_packets: Array[Dictionary] = []
var _competence_allocations: Dictionary = {
    "tactics": 0.0,
    "strategy": 0.0,
    "logistics": 0.0,
}
var _competence_config: Dictionary = {}

const MAX_PACKET_HISTORY := 10

func _ready() -> void:
    _instance = self
    _event_bus = EVENT_BUS.get_instance()
    _data_loader = DATA_LOADER.get_instance()
    _connect_signals()
    print("[Autoload] AssistantAIAutoload ready (awaiting data_loader_ready)")

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

    var order_id := str(payload.get("order_id", payload.get("id", "")))
    var order_data: Dictionary = {}
    if _data_loader:
        var order_variant: Variant = _data_loader.get_order(order_id)
        if order_variant is Dictionary:
            order_data = (order_variant as Dictionary)
    var intention := str(order_data.get("intention", "unknown"))
    var signal_strength := float(order_data.get("intel_profile", {}).get("signal_strength", 0.4))
    var pillar_weights_variant: Variant = order_data.get("pillar_weights", {})
    var pillar_weights: Dictionary = {}
    if pillar_weights_variant is Dictionary:
        pillar_weights = (pillar_weights_variant as Dictionary)
    var competence_alignment := _competence_alignment(pillar_weights)
    var adjusted_confidence := clamp(signal_strength * competence_alignment, 0.1, 0.95)
    var enriched_order: Dictionary = payload.duplicate(true)
    enriched_order["order_id"] = order_id
    enriched_order["intention"] = intention
    enriched_order["pillar_weights"] = pillar_weights
    enriched_order["competence_alignment"] = competence_alignment
    enriched_order["adjusted_confidence"] = adjusted_confidence
    var competence_variant: Variant = order_data.get("competence_cost", {})
    if competence_variant is Dictionary:
        enriched_order["competence_cost"] = (competence_variant as Dictionary).duplicate(true)
    if not enriched_order.has("target") and not enriched_order.has("target_hex"):
        enriched_order["target"] = "frontline"

    var intents: Dictionary = {}
    intents[order_id] = {
        "intention": intention,
        "confidence": adjusted_confidence,
        "base_confidence": signal_strength,
        "competence_alignment": competence_alignment,
        "target": enriched_order.get("target", enriched_order.get("target_hex", "")),
    }

    var engagement: Dictionary = {
        "engagement_id": "%s-%d" % [order_id if order_id != "" else "order", Time.get_ticks_msec()],
        "order_id": order_id,
        "attacker_unit_ids": enriched_order.get("unit_ids", []),
        "defender_unit_ids": enriched_order.get("defender_unit_ids", []),
        "terrain": enriched_order.get("terrain", "plains"),
        "intel_confidence": adjusted_confidence,
        "reason": "assistant_prediction",
    }

    var packet: Dictionary = {
        "orders": [enriched_order],
        "intents": intents,
        "expected_engagements": [engagement],
        "competence_snapshot": _build_competence_snapshot(),
    }

    if _event_bus:
        _event_bus.emit_assistant_order_packet(packet)
    _record_packet(packet)

func _on_doctrine_selected(_payload: Dictionary) -> void:
    # Placeholder for doctrine awareness; will influence packet generation in Checklist C.
    pass

func _on_competence_reallocated(payload: Dictionary) -> void:
    var allocations: Dictionary = payload.get("allocations", {})
    for category in _competence_allocations.keys():
        _competence_allocations[category] = float(allocations.get(category, _competence_allocations.get(category, 0.0)))
    var config_variant: Variant = payload.get("config", {})
    if config_variant is Dictionary:
        _competence_config = (config_variant as Dictionary).duplicate(true)

func _on_data_ready(_payload: Dictionary) -> void:
    if _data_loader == null:
        _data_loader = DATA_LOADER.get_instance()
    var cache_ready := _data_loader != null and _data_loader.is_ready()
    print("[Autoload] AssistantAIAutoload observed data_loader_ready (cache_ready: %s)" % ("true" if cache_ready else "false"))

func get_recent_packets() -> Array[Dictionary]:
    return _recent_packets.duplicate(true)

func _record_packet(packet: Dictionary) -> void:
    _recent_packets.append(packet.duplicate(true))
    while _recent_packets.size() > MAX_PACKET_HISTORY:
        _recent_packets.remove_at(0)

func _build_competence_snapshot() -> Dictionary:
    return {
        "allocations": _competence_allocations.duplicate(true),
        "ratios": _current_competence_ratios(),
    }

func _current_competence_ratios() -> Dictionary:
    var ratios: Dictionary = {}
    for category in _competence_allocations.keys():
        ratios[category] = _competence_ratio(category)
    return ratios

func _competence_ratio(category: String) -> float:
    var allocation: float = max(float(_competence_allocations.get(category, 0.0)), 0.0)
    var config: Dictionary = {}
    if _competence_config.has(category) and _competence_config.get(category) is Dictionary:
        config = (_competence_config.get(category) as Dictionary)
    var base_allocation: float = float(config.get("base_allocation", 0.0))
    if base_allocation <= 0.01:
        base_allocation = allocation if allocation > 0.0 else 1.0
    return clamp(allocation / base_allocation, 0.2, 3.0)

func _competence_alignment(pillar_weights: Dictionary) -> float:
    var mapping: Dictionary = {
        "position": _competence_ratio("logistics"),
        "impulse": _competence_ratio("tactics"),
        "information": _competence_ratio("strategy"),
    }
    var total_weight: float = 0.0
    var weighted_sum: float = 0.0
    for pillar in mapping.keys():
        var weight: float = float(pillar_weights.get(pillar, 0.0))
        if abs(weight) <= 0.001:
            continue
        total_weight += abs(weight)
        weighted_sum += weight * float(mapping.get(pillar, 1.0))
    if total_weight <= 0.0:
        return 1.0
    var alignment: float = weighted_sum / total_weight
    return clamp(alignment, 0.5, 1.5)
