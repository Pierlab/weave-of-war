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
const MAX_REASONING_HISTORY := 12

var _reasoning_traces: Dictionary = {
    "orders": [],
    "espionage": [],
    "logistics": [],
}
var _last_logistics_payload: Dictionary = {}

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
    _event_bus.espionage_ping.connect(_on_espionage_ping)
    _event_bus.logistics_update.connect(_on_logistics_update)
    _event_bus.logistics_break.connect(_on_logistics_break)

func _on_order_issued(payload: Dictionary) -> void:
    if _data_loader == null:
        _data_loader = DATA_LOADER.get_instance()

    var order_id: String = str(payload.get("order_id", payload.get("id", "")))
    var order_data: Dictionary = {}
    if _data_loader:
        var order_variant: Variant = _data_loader.get_order(order_id)
        if order_variant is Dictionary:
            order_data = (order_variant as Dictionary)
    var intention: String = str(order_data.get("intention", "unknown"))
    var signal_strength: float = float(order_data.get("intel_profile", {}).get("signal_strength", 0.4))
    var pillar_weights_variant: Variant = order_data.get("pillar_weights", {})
    var pillar_weights: Dictionary = {}
    if pillar_weights_variant is Dictionary:
        pillar_weights = (pillar_weights_variant as Dictionary)
    var competence_alignment: float = _competence_alignment(pillar_weights)
    var adjusted_confidence: float = clamp(signal_strength * competence_alignment, 0.1, 0.95)
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
    _record_order_reasoning(enriched_order, order_data, adjusted_confidence, signal_strength)

func _on_doctrine_selected(_payload: Dictionary) -> void:
    # Placeholder for doctrine awareness; will influence packet generation in Checklist C.
    pass

func _on_competence_reallocated(payload: Dictionary) -> void:
    var allocations_variant: Variant = payload.get("allocations", {})
    var allocations: Dictionary = {}
    if allocations_variant is Dictionary:
        allocations = (allocations_variant as Dictionary)
    for category in _competence_allocations.keys():
        _competence_allocations[category] = float(allocations.get(category, _competence_allocations.get(category, 0.0)))
    var config_variant: Variant = payload.get("config", {})
    if config_variant is Dictionary:
        _competence_config = (config_variant as Dictionary).duplicate(true)

func _on_data_ready(_payload: Dictionary) -> void:
    if _data_loader == null:
        _data_loader = DATA_LOADER.get_instance()
    var cache_ready: bool = _data_loader != null and _data_loader.is_ready()
    print("[Autoload] AssistantAIAutoload observed data_loader_ready (cache_ready: %s)" % ("true" if cache_ready else "false"))

func _on_espionage_ping(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var reasoning: Dictionary = _build_espionage_reasoning(payload)
    if not reasoning.is_empty():
        _record_reasoning("espionage", reasoning)

func _on_logistics_update(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    _last_logistics_payload = payload.duplicate(true)

func _on_logistics_break(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var reasoning: Dictionary = _build_logistics_reasoning(payload)
    if not reasoning.is_empty():
        _record_reasoning("logistics", reasoning)

func get_recent_packets() -> Array[Dictionary]:
    return _recent_packets.duplicate(true)

func get_reasoning_history() -> Dictionary:
    var copy: Dictionary = {}
    for domain in _reasoning_traces.keys():
        var history_variant: Variant = _reasoning_traces.get(domain, [])
        if history_variant is Array:
            copy[domain] = (history_variant as Array).duplicate(true)
        else:
            copy[domain] = []
    return copy

func get_reasoning_for(domain: String) -> Array:
    if not _reasoning_traces.has(domain):
        return []
    var history_variant: Variant = _reasoning_traces.get(domain, [])
    if history_variant is Array:
        return (history_variant as Array).duplicate(true)
    return []

func _record_packet(packet: Dictionary) -> void:
    _recent_packets.append(packet.duplicate(true))
    while _recent_packets.size() > MAX_PACKET_HISTORY:
        _recent_packets.remove_at(0)

func _record_reasoning(domain: String, entry: Dictionary) -> void:
    if not _reasoning_traces.has(domain):
        _reasoning_traces[domain] = []
    var history_variant: Variant = _reasoning_traces.get(domain, [])
    var history: Array = []
    if history_variant is Array:
        history = (history_variant as Array)
    history.append(entry.duplicate(true))
    while history.size() > MAX_REASONING_HISTORY:
        history.remove_at(0)
    _reasoning_traces[domain] = history

func _record_order_reasoning(order: Dictionary, order_data: Dictionary, adjusted_confidence: float, base_confidence: float) -> void:
    var order_id: String = str(order.get("order_id", order.get("id", "")))
    var target: String = str(order.get("target", order.get("target_hex", "frontline")))
    var intention: String = str(order.get("intention", "unknown"))
    var competence_alignment: float = float(order.get("competence_alignment", 1.0))
    var elan_cost: float = float(order.get("base_elan_cost", order.get("cost", order_data.get("base_elan_cost", 0.0))))
    var pillar_weights_variant: Variant = order.get("pillar_weights", {})
    var pillar_weights: Dictionary = {}
    if pillar_weights_variant is Dictionary:
        pillar_weights = (pillar_weights_variant as Dictionary).duplicate(true)
    var competence_cost: Dictionary = {}
    if order.has("competence_cost") and order.get("competence_cost") is Dictionary:
        competence_cost = (order.get("competence_cost") as Dictionary).duplicate(true)
    var reasoning: Dictionary = {
        "timestamp": Time.get_ticks_msec(),
        "order_id": order_id,
        "target": target,
        "intention": intention,
        "confidence": snapped(adjusted_confidence, 0.01),
        "base_signal": snapped(base_confidence, 0.01),
        "competence_alignment": snapped(competence_alignment, 0.01),
        "elan_cost": elan_cost,
        "recommendation": _recommend_order_follow_up(adjusted_confidence, competence_cost),
    }
    if not pillar_weights.is_empty():
        reasoning["pillar_focus"] = pillar_weights
    if not competence_cost.is_empty():
        reasoning["competence_cost"] = competence_cost
    _record_reasoning("orders", reasoning)

func _build_espionage_reasoning(payload: Dictionary) -> Dictionary:
    var target: String = str(payload.get("target", payload.get("order_id", "")))
    if target.is_empty():
        target = "unknown"
    var confidence: float = snapped(float(payload.get("confidence", 0.0)), 0.01)
    var detection_risk: float = snapped(float(payload.get("noise", 0.0)), 0.01)
    var counter_intel: float = snapped(float(payload.get("counter_intel_after", payload.get("counter_intel", 0.0))), 0.01)
    var recommendation: String = _recommend_espionage_follow_up(payload, confidence, counter_intel)
    var reasoning: Dictionary = {
        "timestamp": Time.get_ticks_msec(),
        "target": target,
        "success": bool(payload.get("success", false)),
        "confidence": confidence,
        "intent": str(payload.get("intent_category", payload.get("intention", "unknown"))),
        "probe_strength": snapped(float(payload.get("probe_strength", 0.0)), 0.01),
        "detection_risk": detection_risk,
        "counter_intel": counter_intel,
        "recommendation": recommendation,
    }
    if payload.has("competence_remaining") and payload.get("competence_remaining") is Dictionary:
        reasoning["competence_remaining"] = (payload.get("competence_remaining") as Dictionary).duplicate(true)
    return reasoning

func _build_logistics_reasoning(payload: Dictionary) -> Dictionary:
    var alert_type: String = str(payload.get("type", ""))
    var location: String = ""
    if payload.has("tile_id"):
        location = str(payload.get("tile_id", ""))
    elif payload.has("route_id"):
        location = str(payload.get("route_id", ""))
    var entry: Dictionary = {
        "timestamp": Time.get_ticks_msec(),
        "type": alert_type,
        "location": location,
        "turn": int(payload.get("turn", 0)),
        "competence_penalty": float(payload.get("competence_penalty", 0.0)),
        "elan_penalty": float(payload.get("elan_penalty", 0.0)),
        "weather_id": str(payload.get("weather_id", _last_logistics_payload.get("weather_id", ""))),
        "recommendation": _recommend_logistics_follow_up(alert_type, payload),
    }
    var context: Dictionary = _logistics_context_for_location(alert_type, location)
    if not context.is_empty():
        entry["context"] = context
    return entry

func _recommend_order_follow_up(confidence: float, competence_cost: Dictionary) -> String:
    if confidence < 0.4:
        return "Hold execution until recon improves confidence or reallocating competence."
    if confidence < 0.65:
        if not competence_cost.is_empty():
            return "Proceed with reserves and ensure competence budget covers follow-up costs."
        return "Proceed cautiously and pair with logistics escort coverage."
    if confidence > 0.85:
        return "Greenlight — confidence margin supports immediate execution."
    return "Execute and monitor telemetry for counterplay cues."

func _recommend_espionage_follow_up(payload: Dictionary, confidence: float, counter_intel: float) -> String:
    if not bool(payload.get("success", false)):
        if confidence < 0.35:
            return "Switch to Deep Cover with extra competence before retrying."
        if float(payload.get("detection_bonus", 0.0)) <= 0.0:
            return "Stack detection bonuses (logistics support or recon doctrine) before another probe."
        return "Retry next turn with increased probe strength."
    if counter_intel >= 0.6:
        return "Stand down temporarily; counter-intel is spiking around the target."
    if confidence < 0.55:
        return "Schedule a confirmatory probe to raise confidence above 60%."
    return "Leverage intel for planning and monitor counter-intel drift."

func _recommend_logistics_follow_up(alert_type: String, payload: Dictionary) -> String:
    match alert_type:
        "convoy_intercept":
            return "Dispatch escort and reroute the convoy away from high intercept risk tiles."
        "supply_isolated":
            return "Prioritise retaking the isolated tile or allocate Logistics competence to extend supply radius."
        _:
            if float(payload.get("competence_penalty", 0.0)) > 1.5:
                return "Allocate extra Logistics competence to stabilise penalties."
            return "Audit supply routes and confirm weather adjustments before next turn."

func _logistics_context_for_location(alert_type: String, location: String) -> Dictionary:
    if location.is_empty():
        return {}
    if alert_type == "supply_isolated":
        return _lookup_tile_context(location)
    if alert_type == "convoy_intercept":
        return _lookup_route_context(location)
    return {}

func _lookup_tile_context(tile_id: String) -> Dictionary:
    var context: Dictionary = {}
    var deficits_variant: Variant = _last_logistics_payload.get("supply_deficits", [])
    if deficits_variant is Array:
        for deficit_entry in (deficits_variant as Array):
            if deficit_entry is Dictionary and str(deficit_entry.get("tile_id", "")) == tile_id:
                context = (deficit_entry as Dictionary).duplicate(true)
                break
    if context.is_empty():
        var zones_variant: Variant = _last_logistics_payload.get("supply_zones", [])
        if zones_variant is Array:
            for zone_entry in (zones_variant as Array):
                if zone_entry is Dictionary and str(zone_entry.get("tile_id", "")) == tile_id:
                    var zone_dict: Dictionary = zone_entry
                    context = {
                        "supply_level": zone_dict.get("supply_level", "isolated"),
                        "logistics_flow": zone_dict.get("logistics_flow", 0.0),
                        "terrain": zone_dict.get("terrain", ""),
                        "terrain_name": zone_dict.get("terrain_name", ""),
                    }
                    break
    return context

func _lookup_route_context(route_id: String) -> Dictionary:
    var context: Dictionary = {}
    var convoys_variant: Variant = _last_logistics_payload.get("convoy_statuses", [])
    if convoys_variant is Array:
        for convoy_entry in (convoys_variant as Array):
            if convoy_entry is Dictionary and str(convoy_entry.get("id", "")) == route_id:
                context = (convoy_entry as Dictionary).duplicate(true)
                break
    return context

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
