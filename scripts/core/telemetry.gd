class_name Telemetry
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")

static var _instance: Telemetry

var _buffer: Array = []
var _event_bus: EventBus
var _history_by_event: Dictionary = {}

func _ready() -> void:
    _instance = self
    _event_bus = EVENT_BUS.get_instance()
    _connect_signals()
    var connected := _event_bus != null
    print("[Autoload] TelemetryAutoload ready (event_bus_connected: %s)" % ("true" if connected else "false"))

static func get_instance() -> Telemetry:
    return _instance

func log_event(name: StringName, payload: Dictionary = {}) -> void:
    var event_key := String(name)
    var entry := {
        "name": name,
        "payload": payload.duplicate(true),
        "timestamp": Time.get_ticks_msec(),
    }
    _buffer.append(entry)

    var history: Array = _history_by_event.get(event_key, [])
    history.append(entry)
    _history_by_event[event_key] = history

func get_buffer() -> Array:
    return _buffer.duplicate(true)

func get_history(event_name: StringName) -> Array:
    var key := String(event_name)
    var events: Variant = _history_by_event.get(key, [])
    if events is Array:
        return (events as Array).duplicate(true)
    return []

func clear() -> void:
    _buffer.clear()
    _history_by_event.clear()

func _connect_signals() -> void:
    if _event_bus == null:
        return

    _event_bus.doctrine_selected.connect(_on_doctrine_selected)
    _event_bus.order_issued.connect(_on_order_issued)
    _event_bus.order_rejected.connect(_on_order_rejected)
    _event_bus.elan_spent.connect(_on_elan_spent)
    _event_bus.elan_gained.connect(_on_elan_gained)
    _event_bus.turn_started.connect(_capture_event.bind("turn_started"))
    _event_bus.turn_ended.connect(_capture_event.bind("turn_ended"))
    _event_bus.logistics_update.connect(_capture_event.bind("logistics_update"))
    _event_bus.logistics_break.connect(_capture_event.bind("logistics_break"))
    _event_bus.combat_resolved.connect(_on_combat_resolved)
    _event_bus.espionage_ping.connect(_on_espionage_ping)
    _event_bus.intel_intent_revealed.connect(_on_intel_intent_revealed)
    _event_bus.weather_changed.connect(_on_weather_changed)
    _event_bus.assistant_order_packet.connect(_capture_event.bind("assistant_order_packet"))
    _event_bus.data_loader_ready.connect(_capture_event.bind("data_loader_ready"))
    _event_bus.data_loader_error.connect(_capture_event.bind("data_loader_error"))
    _event_bus.competence_reallocated.connect(_on_competence_reallocated)
    _event_bus.competence_spent.connect(_capture_event.bind("competence_spent"))
    _event_bus.formation_changed.connect(_capture_event.bind("formation_changed"))

func _capture_event(payload, event_name: StringName) -> void:
    if payload is Dictionary:
        log_event(event_name, payload)
    else:
        log_event(event_name, {"value": payload})

func _on_combat_resolved(payload: Dictionary) -> void:
    var safe_payload := {
        "engagement_id": str(payload.get("engagement_id", "")),
        "order_id": str(payload.get("order_id", "")),
        "victor": str(payload.get("victor", "stalemate")),
        "terrain": str(payload.get("terrain", "")),
        "weather_id": str(payload.get("weather_id", "")),
        "doctrine_id": str(payload.get("doctrine_id", "")),
        "reason": str(payload.get("reason", "resolution")),
        "intel": _coerce_dictionary(payload.get("intel", {})),
        "logistics": _coerce_dictionary(payload.get("logistics", {})),
    }

    safe_payload["pillars"] = _serialise_pillars(payload.get("pillars", {}))
    safe_payload["pillar_summary"] = _serialise_pillar_summary(payload.get("pillar_summary", {}))
    safe_payload["units"] = _serialise_units(payload.get("units", {}))

    log_event("combat_resolved", safe_payload)

func _on_espionage_ping(payload: Dictionary) -> void:
    var safe_payload := {
        "target": str(payload.get("target", "")),
        "success": bool(payload.get("success", false)),
        "confidence": float(payload.get("confidence", 0.0)),
        "noise": float(payload.get("noise", 0.0)),
        "intention": str(payload.get("intention", "unknown")),
        "intent_category": str(payload.get("intent_category", payload.get("intention", "unknown"))),
        "intention_confidence": float(payload.get("intention_confidence", 0.0)),
        "turn": int(payload.get("turn", 0)),
        "source": str(payload.get("source", "")),
        "order_id": str(payload.get("order_id", "")),
        "roll": float(payload.get("roll", 0.0)),
        "probe_strength": float(payload.get("probe_strength", 0.0)),
        "detection_bonus": float(payload.get("detection_bonus", 0.0)),
        "visibility_before": float(payload.get("visibility_before", 0.0)),
        "visibility_after": float(payload.get("visibility_after", 0.0)),
        "counter_intel_before": float(payload.get("counter_intel_before", 0.0)),
        "counter_intel_after": float(payload.get("counter_intel_after", 0.0)),
        "visibility_map": _serialise_visibility_map(payload.get("visibility_map", [])),
    }

    if payload.has("competence_remaining") and payload.get("competence_remaining") is Dictionary:
        safe_payload["competence_remaining"] = (payload.get("competence_remaining") as Dictionary).duplicate(true)

    log_event("espionage_ping", safe_payload)

func _on_intel_intent_revealed(payload: Dictionary) -> void:
    var safe_payload := {
        "target": str(payload.get("target", "")),
        "intention": str(payload.get("intention", "unknown")),
        "intent_category": str(payload.get("intent_category", payload.get("intention", "unknown"))),
        "intention_confidence": float(payload.get("intention_confidence", 0.0)),
        "confidence": float(payload.get("confidence", 0.0)),
        "success": true,
        "turn": int(payload.get("turn", 0)),
        "source": str(payload.get("source", "")),
        "order_id": str(payload.get("order_id", "")),
        "roll": float(payload.get("roll", 0.0)),
        "noise": float(payload.get("noise", 0.0)),
        "probe_strength": float(payload.get("probe_strength", 0.0)),
        "detection_bonus": float(payload.get("detection_bonus", 0.0)),
        "visibility_before": float(payload.get("visibility_before", 0.0)),
        "visibility_after": float(payload.get("visibility_after", 0.0)),
    }

    log_event("intel_intent_revealed", safe_payload)

func _on_doctrine_selected(payload: Dictionary) -> void:
    var allowed_variant: Variant = payload.get("allowed_orders", [])
    var allowed_payload: Array = []
    if allowed_variant is Array:
        for entry in allowed_variant:
            if entry is Dictionary:
                allowed_payload.append({
                    "id": str(entry.get("id", "")),
                    "name": str(entry.get("name", entry.get("id", ""))),
                    "base_elan_cost": float(entry.get("base_elan_cost", 0.0)),
                    "inertia_impact": float(entry.get("inertia_impact", 0.0)),
                })
    log_event("doctrine_selected", {
        "id": str(payload.get("id", "")),
        "name": str(payload.get("name", "")),
        "inertia_remaining": int(payload.get("inertia_remaining", 0)),
        "inertia_lock_turns": int(payload.get("inertia_lock_turns", 0)),
        "elan_upkeep": float(payload.get("elan_upkeep", 0.0)),
        "elan_cap_bonus": float(payload.get("elan_cap_bonus", 0.0)),
        "inertia_multiplier": float(payload.get("inertia_multiplier", 1.0)),
        "swap_token_budget": int(payload.get("swap_token_budget", 0)),
        "allowed_orders": allowed_payload,
        "reason": str(payload.get("reason", "status")),
    })

func _on_order_issued(payload: Dictionary) -> void:
    log_event("order_issued", {
        "order_id": str(payload.get("order_id", "")),
        "order_name": str(payload.get("order_name", "")),
        "cost": float(payload.get("cost", 0.0)),
        "remaining": float(payload.get("remaining", 0.0)),
        "inertia_impact": int(payload.get("inertia_impact", 0)),
        "base_inertia_turns": int(payload.get("base_inertia_turns", 0)),
        "metadata": _coerce_dictionary(payload.get("metadata", {})),
    })

func _on_order_rejected(payload: Dictionary) -> void:
    log_event("order_rejected", {
        "order_id": str(payload.get("order_id", "")),
        "reason": str(payload.get("reason", "unknown")),
        "required": float(payload.get("required", 0.0)),
        "available": float(payload.get("available", 0.0)),
        "doctrine_id": str(payload.get("doctrine_id", "")),
        "allowed": bool(payload.get("allowed", false)),
    })

func _on_elan_spent(payload: Dictionary) -> void:
    log_event("elan_spent", {
        "order_id": str(payload.get("order_id", "")),
        "amount": float(payload.get("amount", 0.0)),
        "remaining": float(payload.get("remaining", 0.0)),
        "reason": str(payload.get("reason", "spend")),
    })

func _on_elan_gained(payload: Dictionary) -> void:
    var metadata_variant: Variant = payload.get("metadata", {})
    var metadata_dict: Dictionary = metadata_variant if metadata_variant is Dictionary else {}
    log_event("elan_gained", {
        "amount": float(payload.get("amount", 0.0)),
        "previous": float(payload.get("previous", 0.0)),
        "current": float(payload.get("current", 0.0)),
        "reason": str(payload.get("reason", "manual")),
        "metadata": metadata_dict.duplicate(true),
    })

func _on_weather_changed(payload: Dictionary) -> void:
    var combat_variant: Variant = payload.get("combat_modifiers", {})
    var combat_modifiers: Dictionary = combat_variant if combat_variant is Dictionary else {}
    var duration_variant: Variant = payload.get("duration_range", [])
    var duration_range: Array = []
    if duration_variant is Array:
        for entry in duration_variant:
            duration_range.append(int(entry))
    log_event("weather_changed", {
        "weather_id": str(payload.get("weather_id", "")),
        "name": str(payload.get("name", "")),
        "effects": str(payload.get("effects", "")),
        "movement_modifier": float(payload.get("movement_modifier", 1.0)),
        "logistics_flow_modifier": float(payload.get("logistics_flow_modifier", 1.0)),
        "intel_noise": float(payload.get("intel_noise", 0.0)),
        "elan_regeneration_bonus": float(payload.get("elan_regeneration_bonus", 0.0)),
        "combat_modifiers": combat_modifiers.duplicate(true),
        "duration_remaining": int(payload.get("duration_remaining", 0)),
        "duration_range": duration_range,
        "turn": int(payload.get("turn", 0)),
        "reason": str(payload.get("reason", "status")),
        "source": str(payload.get("source", "weather_system")),
    })

func _on_competence_reallocated(payload: Dictionary) -> void:
    var base_snapshot := _serialise_competence_snapshot(payload)
    var before_snapshot := _serialise_competence_snapshot(payload.get("before", {}))
    var after_snapshot := _serialise_competence_snapshot(payload.get("after", {}))
    base_snapshot["reason"] = str(payload.get("reason", base_snapshot.get("reason", "status")))
    base_snapshot["before"] = before_snapshot
    base_snapshot["after"] = after_snapshot if not after_snapshot.is_empty() else base_snapshot.duplicate(true)
    base_snapshot["last_event"] = _coerce_dictionary(payload.get("last_event", {}))
    log_event("competence_reallocated", base_snapshot)

func _serialise_competence_snapshot(value: Variant) -> Dictionary:
    if not (value is Dictionary):
        return {}
    var snapshot: Dictionary = value
    var result: Dictionary = {
        "turn": int(snapshot.get("turn", 0)),
        "turn_id": str(snapshot.get("turn_id", "")),
        "revision": int(snapshot.get("revision", 0)),
        "allocations": _serialise_competence_allocations(snapshot.get("allocations", {})),
        "available": float(snapshot.get("available", 0.0)),
        "budget": float(snapshot.get("budget", 0.0)),
        "inertia": _serialise_competence_inertia(snapshot.get("inertia", {})),
        "modifiers": _serialise_competence_modifiers(snapshot.get("modifiers", {})),
    }
    if snapshot.has("reason"):
        result["reason"] = str(snapshot.get("reason", "status"))
    if snapshot.has("last_event"):
        result["last_event"] = _coerce_dictionary(snapshot.get("last_event", {}))
    return result

func _serialise_competence_allocations(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if value is Dictionary:
        for key in (value as Dictionary).keys():
            result[str(key)] = float((value as Dictionary).get(key, 0.0))
    return result

func _serialise_competence_inertia(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if value is Dictionary:
        for key in (value as Dictionary).keys():
            var entry_variant: Variant = (value as Dictionary).get(key, {})
            if entry_variant is Dictionary:
                var entry: Dictionary = entry_variant
                result[str(key)] = {
                    "turns_remaining": int(entry.get("turns_remaining", 0)),
                    "spent_this_turn": float(entry.get("spent_this_turn", 0.0)),
                    "max_delta_per_turn": float(entry.get("max_delta_per_turn", 0.0)),
                }
    return result

func _serialise_competence_modifiers(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if value is Dictionary:
        for key in (value as Dictionary).keys():
            result[str(key)] = float((value as Dictionary).get(key, 0.0))
    return result

func _serialise_visibility_map(value: Variant) -> Array:
    if not (value is Array):
        return []
    var result: Array = []
    for entry in (value as Array):
        if not (entry is Dictionary):
            continue
        var tile := entry as Dictionary
        result.append({
            "tile_id": str(tile.get("tile_id", "")),
            "visibility": float(tile.get("visibility", 0.0)),
            "counter_intel": float(tile.get("counter_intel", 0.0)),
        })
    return result

func _coerce_dictionary(value: Variant) -> Dictionary:
    if value is Dictionary:
        return (value as Dictionary).duplicate(true)
    return {}

func _serialise_pillars(value: Variant) -> Dictionary:
    var pillars: Dictionary = {}
    if value is Dictionary:
        for pillar in (value as Dictionary).keys():
            var entry_variant: Variant = (value as Dictionary).get(pillar, {})
            if entry_variant is Dictionary:
                var entry: Dictionary = entry_variant
                pillars[pillar] = {
                    "attacker": float(entry.get("attacker", 0.0)),
                    "defender": float(entry.get("defender", 0.0)),
                    "margin": float(entry.get("margin", 0.0)),
                    "winner": str(entry.get("winner", "stalemate")),
                }
    return pillars

func _serialise_pillar_summary(value: Variant) -> Dictionary:
    if value is Dictionary:
        var summary: Dictionary = value
        var decisive: Array = []
        var decisive_variant: Variant = summary.get("decisive_pillars", [])
        if decisive_variant is Array:
            for entry in decisive_variant:
                if entry is Dictionary:
                    decisive.append({
                        "pillar": str(entry.get("pillar", "")),
                        "winner": str(entry.get("winner", "")),
                        "margin": float(entry.get("margin", 0.0)),
                    })
        return {
            "attacker_total": float(summary.get("attacker_total", 0.0)),
            "defender_total": float(summary.get("defender_total", 0.0)),
            "margin_score": float(summary.get("margin_score", 0.0)),
            "decisive_pillars": decisive,
        }
    return {
        "attacker_total": 0.0,
        "defender_total": 0.0,
        "margin_score": 0.0,
        "decisive_pillars": [],
    }

func _serialise_units(value: Variant) -> Dictionary:
    var units := {
        "attacker": [],
        "defender": [],
    }
    if not (value is Dictionary):
        return units

    for side in ["attacker", "defender"]:
        var side_variant: Variant = (value as Dictionary).get(side, [])
        var side_entries: Array = []
        if side_variant is Array:
            for entry in side_variant:
                if entry is Dictionary:
                    var state: Dictionary = entry
                    side_entries.append({
                        "unit_id": str(state.get("unit_id", "")),
                        "name": str(state.get("name", "")),
                        "side": side,
                        "formation_id": str(state.get("formation_id", "")),
                        "formation_name": str(state.get("formation_name", "")),
                        "status": str(state.get("status", "")),
                        "casualties": float(state.get("casualties", 0.0)),
                        "strength_remaining": float(state.get("strength_remaining", 1.0)),
                        "notes": str(state.get("notes", "")),
                        "pillar_profile": _serialise_pillar_profile(state.get("pillar_profile", {})),
                    })
        units[side] = side_entries

    return units

func _serialise_pillar_profile(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if value is Dictionary:
        for key in (value as Dictionary).keys():
            result[str(key)] = float((value as Dictionary).get(key, 0.0))
    return result
