class_name Telemetry
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")

static var _instance: Telemetry

var _buffer: Array = []
var _event_bus: EventBus

func _ready() -> void:
    _instance = self
    _event_bus = EVENT_BUS.get_instance()
    _connect_signals()
    var connected := _event_bus != null
    print("[Autoload] TelemetryAutoload ready (event_bus_connected: %s)" % ("true" if connected else "false"))

static func get_instance() -> Telemetry:
    return _instance

func log_event(name: StringName, payload: Dictionary = {}) -> void:
    var entry := {
        "name": name,
        "payload": payload.duplicate(true),
        "timestamp": Time.get_ticks_msec(),
    }
    _buffer.append(entry)

func get_buffer() -> Array:
    return _buffer.duplicate(true)

func clear() -> void:
    _buffer.clear()

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
    _event_bus.combat_resolved.connect(_capture_event.bind("combat_resolved"))
    _event_bus.espionage_ping.connect(_capture_event.bind("espionage_ping"))
    _event_bus.weather_changed.connect(_on_weather_changed)
    _event_bus.assistant_order_packet.connect(_capture_event.bind("assistant_order_packet"))
    _event_bus.data_loader_ready.connect(_capture_event.bind("data_loader_ready"))
    _event_bus.data_loader_error.connect(_capture_event.bind("data_loader_error"))
    _event_bus.competence_reallocated.connect(_capture_event.bind("competence_reallocated"))
    _event_bus.formation_changed.connect(_capture_event.bind("formation_changed"))

func _capture_event(payload, event_name: StringName) -> void:
    if payload is Dictionary:
        log_event(event_name, payload)
    else:
        log_event(event_name, {"value": payload})

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

func _coerce_dictionary(value: Variant) -> Dictionary:
    if value is Dictionary:
        return (value as Dictionary).duplicate(true)
    return {}
