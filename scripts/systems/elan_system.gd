class_name ElanSystem
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

@export var max_elan: float = 6.0
@export var decay_amount: float = 1.0

var event_bus: EventBusAutoload
var data_loader: DataLoaderAutoload

var _orders_by_id: Dictionary = {}
var _allowed_order_ids: Array[String] = []
var _current_elan: float = 0.0
var _turn_income: float = 0.0
var _current_upkeep: float = 0.0
var _current_doctrine_id: String = ""
var _base_max_elan: float = 0.0
var _current_cap_bonus: float = 0.0
var _rounds_at_cap: int = 0

func _ready() -> void:
    setup(EVENT_BUS.get_instance(), DATA_LOADER.get_instance())

func setup(event_bus_ref: EventBusAutoload, data_loader_ref: DataLoaderAutoload) -> void:
    event_bus = event_bus_ref
    data_loader = data_loader_ref

    if is_zero_approx(_base_max_elan):
        _base_max_elan = max(max_elan, 0.0)

    if data_loader and data_loader.is_ready():
        configure(data_loader.list_orders(), data_loader.list_units())

    if event_bus:
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.turn_started.is_connected(_on_turn_started):
            event_bus.turn_started.connect(_on_turn_started)
        if not event_bus.turn_ended.is_connected(_on_turn_ended):
            event_bus.turn_ended.connect(_on_turn_ended)
        if not event_bus.doctrine_selected.is_connected(_on_doctrine_selected):
            event_bus.doctrine_selected.connect(_on_doctrine_selected)
        if not event_bus.order_execution_requested.is_connected(_on_order_execution_requested):
            event_bus.order_execution_requested.connect(_on_order_execution_requested)

    _emit_state("ready")

func configure(order_entries: Array, unit_entries: Array) -> void:
    _orders_by_id.clear()
    for entry in order_entries:
        if entry is Dictionary and entry.has("id"):
            _orders_by_id[entry.get("id")] = entry

    _turn_income = _calculate_turn_income(unit_entries)
    _emit_state("configure")

func add_elan(amount: float, reason: String = "manual", metadata: Dictionary = {}) -> void:
    if amount == 0.0:
        return
    var previous_value: float = _current_elan
    var new_value: float = clamp(previous_value + amount, 0.0, max_elan)
    if !is_equal_approx(new_value, previous_value):
        _current_elan = new_value
        var gained: float = max(new_value - previous_value, 0.0)
        if gained > 0.0 and event_bus:
            event_bus.emit_elan_gained({
                "amount": gained,
                "previous": previous_value,
                "current": _current_elan,
                "reason": reason,
                "metadata": metadata.duplicate(true),
            })
        _emit_state("gain")
    _update_cap_tracking()

func spend_elan(amount: float) -> bool:
    if amount <= 0.0:
        return true
    if amount > _current_elan:
        return false
    _current_elan = clamp(_current_elan - amount, 0.0, max_elan)
    _emit_state("spend")
    _update_cap_tracking(true)
    return true

func set_allowed_orders(order_ids: Array) -> void:
    _allowed_order_ids.clear()
    for order_id in order_ids:
        _allowed_order_ids.append(str(order_id))
    _emit_state("orders")

func set_doctrine_upkeep(value: float) -> void:
    _current_upkeep = max(value, 0.0)
    _emit_state("upkeep")

func get_state_payload(reason := "status") -> Dictionary:
    return {
        "current": _current_elan,
        "max": max_elan,
        "income": _turn_income,
        "upkeep": _current_upkeep,
        "allowed_order_ids": _allowed_order_ids.duplicate(),
        "reason": reason,
        "doctrine_id": _current_doctrine_id,
        "rounds_at_cap": _rounds_at_cap,
        "decay_amount": decay_amount,
        "cap_bonus": _current_cap_bonus,
    }

func can_issue_order(order_id: String) -> Dictionary:
    var result: Dictionary = {
        "success": false,
        "reason": "unknown_order",
    }
    if order_id.is_empty() or not _orders_by_id.has(order_id):
        return result
    if not _allowed_order_ids.has(order_id):
        result.reason = "doctrine_locked"
        return result
    var order: Dictionary = _orders_by_id.get(order_id, {})
    var cost: float = float(order.get("base_elan_cost", 0))
    if cost > _current_elan:
        result.reason = "insufficient_elan"
        result["required"] = cost
        result["available"] = _current_elan
        return result
    result.success = true
    result.reason = ""
    result["order"] = order
    result["cost"] = cost
    result["inertia_impact"] = int(order.get("inertia_impact", 0))
    return result

func issue_order(order_id: String) -> Dictionary:
    var result: Dictionary = can_issue_order(order_id)
    if not result.get("success", false):
        return result
    var cost: float = float(result.get("cost", 0.0))
    spend_elan(cost)
    result["remaining"] = _current_elan
    return result

func _apply_doctrine_upkeep() -> void:
    if _current_upkeep <= 0.0:
        return
    if _current_elan <= 0.0:
        return
    var new_value: float = max(_current_elan - _current_upkeep, 0.0)
    if !is_equal_approx(new_value, _current_elan):
        _current_elan = new_value
        _emit_state("upkeep_tick")
    _update_cap_tracking()

func _emit_state(reason: String) -> void:
    if event_bus == null:
        return
    event_bus.emit_elan_updated(get_state_payload(reason))

func _calculate_turn_income(unit_entries: Array) -> float:
    var total: float = 0.0
    for entry in unit_entries:
        if entry is Dictionary:
            var generation_value: Variant = entry.get("elan_generation")
            if generation_value is Dictionary:
                var generation_data: Dictionary = generation_value as Dictionary
                total += float(generation_data.get("base", 0))
    return total

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(
        collections.get("orders", []),
        collections.get("units", [])
    )

func _on_turn_started(_turn_number: int) -> void:
    _apply_decay_if_needed()
    _apply_doctrine_upkeep()
    if _turn_income > 0.0:
        add_elan(_turn_income, "turn_income", {"turn": _turn_number})

func _on_turn_ended(_turn_number: int) -> void:
    if _is_at_cap():
        _rounds_at_cap = clamp(_rounds_at_cap + 1, 0, 2)
    else:
        _rounds_at_cap = 0
    _update_cap_tracking()

func _on_doctrine_selected(payload: Dictionary) -> void:
    _current_doctrine_id = payload.get("id", "")
    set_doctrine_upkeep(float(payload.get("elan_upkeep", 0)))
    _apply_doctrine_cap_bonus(float(payload.get("elan_cap_bonus", 0.0)))
    var allowed_orders_variant: Variant = payload.get("allowed_orders", [])
    var allowed_orders_payload: Array = allowed_orders_variant if allowed_orders_variant is Array else []
    var allowed_ids: Array[String] = []
    for entry in allowed_orders_payload:
        if entry is Dictionary:
            allowed_ids.append(str(entry.get("id", "")))
    set_allowed_orders(allowed_ids)
    _emit_state("doctrine")

func _on_order_execution_requested(order_id: String) -> void:
    if order_id.is_empty():
        return
    var result: Dictionary = issue_order(order_id)
    if not result.get("success", false):
        if event_bus:
            event_bus.emit_order_execution_failed({
                "reason": result.get("reason", "unknown"),
                "order_id": order_id,
                "required": result.get("required", 0.0),
                "available": result.get("available", _current_elan),
            })
            event_bus.emit_order_rejected({
                "reason": result.get("reason", "unknown"),
                "order_id": order_id,
                "required": result.get("required", 0.0),
                "available": result.get("available", _current_elan),
                "doctrine_id": _current_doctrine_id,
                "allowed": _allowed_order_ids.has(order_id),
            })
        return

    var order: Dictionary = result.get("order", {})
    var payload: Dictionary = {
        "order_id": order_id,
        "order_name": order.get("name", order_id),
        "cost": result.get("cost", 0.0),
        "remaining": result.get("remaining", _current_elan),
        "inertia_impact": result.get("inertia_impact", 0),
        "base_inertia_turns": order.get("inertia_impact", result.get("inertia_impact", 0)),
    }

    if event_bus:
        event_bus.emit_elan_spent({
            "order_id": order_id,
            "amount": payload.get("cost", 0.0),
            "remaining": payload.get("remaining", _current_elan),
            "reason": "order_cost",
        })
        event_bus.emit_order_issued(payload)

func _apply_doctrine_cap_bonus(bonus: float) -> void:
    _current_cap_bonus = bonus
    var target_cap := max(_base_max_elan + bonus, 0.0)
    if is_equal_approx(target_cap, max_elan):
        return
    max_elan = target_cap
    _current_elan = clamp(_current_elan, 0.0, max_elan)
    _update_cap_tracking()
    _emit_state("cap_update")

func _update_cap_tracking(spent := false) -> void:
    if spent and not _is_at_cap():
        _rounds_at_cap = 0
        return
    if not _is_at_cap():
        _rounds_at_cap = 0

func _apply_decay_if_needed() -> void:
    if _rounds_at_cap <= 0:
        return
    if not _is_at_cap():
        _rounds_at_cap = 0
        return
    if decay_amount <= 0.0 or event_bus == null:
        return
    var new_value: float = max(_current_elan - decay_amount, 0.0)
    if is_equal_approx(new_value, _current_elan):
        return
    _current_elan = new_value
    event_bus.emit_elan_spent({
        "order_id": "",
        "amount": decay_amount,
        "remaining": _current_elan,
        "reason": "decay",
    })
    _emit_state("decay")
    if _is_at_cap():
        _rounds_at_cap = 1
    else:
        _rounds_at_cap = 0

func _is_at_cap() -> bool:
    return _current_elan >= max_elan - 0.001
