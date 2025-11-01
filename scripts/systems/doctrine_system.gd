class_name DoctrineSystem
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

var event_bus: EventBusAutoload
var data_loader: DataLoaderAutoload

var _doctrines_by_id: Dictionary = {}
var _orders_by_id: Dictionary = {}
var _active_doctrine_id := ""
var _inertia_turns_remaining := 0
var _allowed_order_ids: Array[String] = []
var _command_profiles_by_id: Dictionary = {}
var _active_command_profile: Dictionary = {}

func _ready() -> void:
    setup(EVENT_BUS.get_instance(), DATA_LOADER.get_instance())

func setup(event_bus_ref: EventBusAutoload, data_loader_ref: DataLoaderAutoload) -> void:
    event_bus = event_bus_ref
    data_loader = data_loader_ref

    if data_loader and data_loader.is_ready():
        configure(data_loader.list_doctrines(), data_loader.list_orders())

    if event_bus:
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.turn_started.is_connected(_on_turn_started):
            event_bus.turn_started.connect(_on_turn_started)
        if not event_bus.doctrine_change_requested.is_connected(_on_doctrine_change_requested):
            event_bus.doctrine_change_requested.connect(_on_doctrine_change_requested)
        if not event_bus.order_issued.is_connected(_on_order_issued):
            event_bus.order_issued.connect(_on_order_issued)

    if _active_doctrine_id.is_empty() and not _doctrines_by_id.is_empty():
        var keys := _doctrines_by_id.keys()
        if keys.size() > 0:
            select_doctrine(str(keys[0]))

func configure(doctrine_entries: Array, order_entries: Array) -> void:
    _doctrines_by_id.clear()
    _orders_by_id.clear()
    _command_profiles_by_id.clear()
    for entry in doctrine_entries:
        if entry is Dictionary and entry.has("id"):
            _doctrines_by_id[entry.get("id")] = entry
            var profile_variant: Variant = entry.get("command_profile", {})
            if profile_variant is Dictionary:
                _command_profiles_by_id[entry.get("id")] = profile_variant
    for entry in order_entries:
        if entry is Dictionary and entry.has("id"):
            _orders_by_id[entry.get("id")] = entry

    if _active_doctrine_id.is_empty() and not _doctrines_by_id.is_empty():
        var keys := _doctrines_by_id.keys()
        if keys.size() > 0:
            select_doctrine(str(keys[0]))
    else:
        _refresh_allowed_orders()
        _broadcast_status("configure")

func select_doctrine(doctrine_id: String) -> bool:
    if doctrine_id.is_empty() or not _doctrines_by_id.has(doctrine_id):
        return false
    if doctrine_id != _active_doctrine_id and _inertia_turns_remaining > 0:
        return false

    _active_doctrine_id = doctrine_id
    var doctrine: Dictionary = _doctrines_by_id.get(doctrine_id, {})
    _active_command_profile = _command_profiles_by_id.get(doctrine_id, {})
    _inertia_turns_remaining = max(doctrine.get("inertia_lock_turns", 0), 0)
    _refresh_allowed_orders()
    _broadcast_status("selected")
    return true

func can_select_doctrine(doctrine_id: String) -> bool:
    if doctrine_id.is_empty() or not _doctrines_by_id.has(doctrine_id):
        return false
    if doctrine_id == _active_doctrine_id:
        return true
    return _inertia_turns_remaining <= 0

func get_active_doctrine_id() -> String:
    return _active_doctrine_id

func get_inertia_turns_remaining() -> int:
    return _inertia_turns_remaining

func get_allowed_order_ids() -> Array[String]:
    return _allowed_order_ids.duplicate()

func get_state_payload(reason := "status") -> Dictionary:
    var doctrine: Dictionary = _doctrines_by_id.get(_active_doctrine_id, {})
    var profile: Dictionary = _active_command_profile if _active_command_profile is Dictionary else {}
    return {
        "id": _active_doctrine_id,
        "name": doctrine.get("name", ""),
        "inertia_remaining": _inertia_turns_remaining,
        "inertia_lock_turns": doctrine.get("inertia_lock_turns", 0),
        "elan_upkeep": doctrine.get("elan_upkeep", 0),
        "inertia_multiplier": float(profile.get("inertia_multiplier", 1.0)),
        "elan_cap_bonus": float(profile.get("elan_cap_bonus", 0.0)),
        "swap_token_budget": int(profile.get("swap_token_budget", 0)),
        "allowed_orders": _build_allowed_order_payload(),
        "reason": reason,
    }

func register_order_inertia(order_id: String, impact_turns: float) -> void:
    var computed_turns := _calculate_order_inertia(order_id, impact_turns)
    if computed_turns <= 0:
        return
    _inertia_turns_remaining = max(_inertia_turns_remaining, computed_turns)
    _broadcast_status("order_inertia")

func advance_turn() -> void:
    if _inertia_turns_remaining > 0:
        _inertia_turns_remaining = max(_inertia_turns_remaining - 1, 0)
        _broadcast_status("turn")

func _refresh_allowed_orders() -> void:
    _allowed_order_ids.clear()
    if _active_doctrine_id.is_empty():
        return
    for order_id in _orders_by_id.keys():
        var order: Dictionary = _orders_by_id.get(order_id)
        var allowed_doctrines: Array = order.get("allowed_doctrines", [])
        if allowed_doctrines.has(_active_doctrine_id):
            _allowed_order_ids.append(str(order_id))

func _build_allowed_order_payload() -> Array:
    var payload: Array = []
    for order_id in _allowed_order_ids:
        var order: Dictionary = _orders_by_id.get(order_id, {})
        payload.append({
            "id": order_id,
            "name": order.get("name", order_id),
            "base_elan_cost": order.get("base_elan_cost", 0),
            "inertia_impact": order.get("inertia_impact", 0),
            "inertia_profile": order.get("inertia_profile", {}),
        })
    return payload

func _calculate_order_inertia(order_id: String, base_turns: float) -> int:
    var order: Dictionary = _orders_by_id.get(order_id, {})
    var profile: Dictionary = _active_command_profile if _active_command_profile is Dictionary else {}

    var base_value := max(float(base_turns), 0.0)
    if base_value <= 0.0:
        return 0

    var multiplier: float = float(profile.get("inertia_multiplier", 1.0))
    var doctrine_multiplier := 1.0
    var inertia_profile_variant: Variant = order.get("inertia_profile", {})
    if inertia_profile_variant is Dictionary:
        var doctrine_multipliers_variant: Variant = inertia_profile_variant.get("doctrine_multipliers", {})
        if doctrine_multipliers_variant is Dictionary:
            doctrine_multiplier = float(doctrine_multipliers_variant.get(_active_doctrine_id, doctrine_multiplier))

    var computed := ceil(base_value * multiplier * doctrine_multiplier)
    if computed <= 0:
        return 0
    return max(computed, 1)

func _broadcast_status(reason: String) -> void:
    if event_bus == null:
        return
    event_bus.emit_doctrine_selected(get_state_payload(reason))

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(
        collections.get("doctrines", []),
        collections.get("orders", [])
    )

func _on_turn_started(_turn_number: int) -> void:
    advance_turn()

func _on_doctrine_change_requested(doctrine_id: String) -> void:
    var changed := select_doctrine(doctrine_id)
    if not changed and event_bus:
        event_bus.emit_order_execution_failed({
            "reason": "doctrine_locked",
            "doctrine_id": doctrine_id,
            "inertia_remaining": _inertia_turns_remaining,
        })

func _on_order_issued(payload: Dictionary) -> void:
    var order_id := str(payload.get("order_id", ""))
    var impact := float(payload.get("base_inertia_turns", payload.get("inertia_impact", 0)))
    if order_id.is_empty():
        return
    if impact <= 0.0:
        return
    register_order_inertia(order_id, impact)
