class_name FormationSystem
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const COMBAT_SYSTEM := preload("res://scripts/systems/combat_system.gd")
const ELAN_SYSTEM := preload("res://scripts/systems/elan_system.gd")
const TURN_MANAGER := preload("res://scripts/core/turn_manager.gd")

var event_bus: EventBus
var data_loader: DataLoader
var combat_system: CombatSystem
var elan_system: ElanSystem
var turn_manager: TurnManager

var _formation_rules: Dictionary = {}
var _unit_catalog: Dictionary = {}
var _unit_inertia: Dictionary = {}
var _unit_status: Dictionary = {}
var _available_elan: float = 0.0
var _current_turn: int = 0

func setup(event_bus_ref: EventBus, data_loader_ref: DataLoader, combat_system_ref: CombatSystem, elan_system_ref: ElanSystem, turn_manager_ref: TurnManager) -> void:
    event_bus = event_bus_ref
    data_loader = data_loader_ref
    combat_system = combat_system_ref
    elan_system = elan_system_ref
    turn_manager = turn_manager_ref

    if turn_manager:
        _current_turn = turn_manager.current_turn

    _formation_rules.clear()
    _unit_catalog.clear()
    _unit_inertia.clear()
    _unit_status.clear()

    if event_bus:
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.formation_change_requested.is_connected(_on_formation_change_requested):
            event_bus.formation_change_requested.connect(_on_formation_change_requested)
        if not event_bus.formation_changed.is_connected(_on_formation_changed):
            event_bus.formation_changed.connect(_on_formation_changed)
        if not event_bus.elan_updated.is_connected(_on_elan_updated):
            event_bus.elan_updated.connect(_on_elan_updated)
        if not event_bus.turn_started.is_connected(_on_turn_started):
            event_bus.turn_started.connect(_on_turn_started)

    if elan_system:
        _on_elan_updated(elan_system.get_state_payload())

    _refresh_catalog()
    _sync_with_combat()
    _emit_status_update("ready")

func _refresh_catalog() -> void:
    if data_loader == null or not data_loader.is_ready():
        return

    _formation_rules.clear()
    for entry_variant in data_loader.list_formations():
        if not (entry_variant is Dictionary):
            continue
        var entry: Dictionary = entry_variant
        var formation_id := str(entry.get("id", ""))
        if formation_id.is_empty():
            continue
        _formation_rules[formation_id] = {
            "id": formation_id,
            "name": str(entry.get("name", formation_id)),
            "posture": str(entry.get("posture", "")),
            "elan_cost": max(float(entry.get("elan_cost", 0.0)), 0.0),
            "inertia_lock_turns": max(int(entry.get("inertia_lock_turns", 0)), 0),
            "description": str(entry.get("description", "")),
        }

    _unit_catalog.clear()
    for unit_variant in data_loader.list_units():
        if not (unit_variant is Dictionary):
            continue
        var unit: Dictionary = unit_variant
        var unit_id := str(unit.get("id", ""))
        if unit_id.is_empty():
            continue
        var formations: Array = []
        for formation_variant in data_loader.list_formations_for_unit(unit_id):
            if not (formation_variant is Dictionary):
                continue
            var formation: Dictionary = formation_variant
            var formation_id := str(formation.get("id", ""))
            if formation_id.is_empty() or formations.has(formation_id):
                continue
            formations.append(formation_id)
        _unit_catalog[unit_id] = {
            "name": str(unit.get("name", unit_id.capitalize())),
            "formations": formations,
        }

func _sync_with_combat() -> void:
    if combat_system == null:
        return
    for unit_id_variant in _unit_catalog.keys():
        var unit_id := str(unit_id_variant)
        var current := combat_system.get_unit_formation(unit_id)
        _update_unit_status(unit_id, current, "sync")

func _on_data_loader_ready(_payload: Dictionary) -> void:
    _refresh_catalog()
    _sync_with_combat()
    _emit_status_update("data_loader_ready")

func _on_elan_updated(payload: Dictionary) -> void:
    _available_elan = float(payload.get("current", _available_elan))
    _emit_status_update("elan")

func _on_turn_started(turn_number: int) -> void:
    _current_turn = turn_number
    var updated := false
    var keys := _unit_inertia.keys()
    for unit_id_variant in keys:
        var unit_id := str(unit_id_variant)
        var state: Dictionary = _unit_inertia.get(unit_id, {})
        var turns_remaining := int(state.get("turns_remaining", 0))
        if turns_remaining <= 0:
            continue
        turns_remaining = max(turns_remaining - 1, 0)
        if turns_remaining <= 0:
            _unit_inertia.erase(unit_id)
        else:
            state["turns_remaining"] = turns_remaining
            _unit_inertia[unit_id] = state
        updated = true
        var current_status: Dictionary = _unit_status.get(unit_id, {})
        _update_unit_status(unit_id, str(current_status.get("formation_id", "")), "turn_tick")
    _emit_status_update("turn_tick")

func _on_formation_change_requested(payload: Dictionary) -> void:
    var unit_id := str(payload.get("unit_id", ""))
    var formation_id := str(payload.get("formation_id", ""))
    if unit_id.is_empty() or not _unit_catalog.has(unit_id):
        _emit_change_failed(unit_id, formation_id, "unknown_unit")
        return
    if formation_id.is_empty() or not _formation_rules.has(formation_id):
        _emit_change_failed(unit_id, formation_id, "unknown_formation")
        return
    if not _is_formation_allowed(unit_id, formation_id):
        _emit_change_failed(unit_id, formation_id, "formation_not_allowed")
        return

    var inertia_state: Dictionary = _unit_inertia.get(unit_id, {})
    var turns_remaining := int(inertia_state.get("turns_remaining", 0))
    if turns_remaining > 0:
        _emit_change_failed(unit_id, formation_id, "inertia_locked", {
            "turns_remaining": turns_remaining,
        })
        return

    var current_status: Dictionary = _unit_status.get(unit_id, {})
    var current_id := str(current_status.get("formation_id", ""))
    if formation_id == current_id:
        _emit_status_update("noop")
        return

    var rules: Dictionary = _formation_rules.get(formation_id, {})
    var cost: float = max(float(rules.get("elan_cost", 0.0)), 0.0)
    if cost > 0.0 and _available_elan + 0.0001 < cost:
        _emit_change_failed(unit_id, formation_id, "insufficient_elan", {
            "required": cost,
            "available": _available_elan,
        })
        return

    if cost > 0.0 and elan_system and not elan_system.spend_elan(cost):
        _emit_change_failed(unit_id, formation_id, "insufficient_elan", {
            "required": cost,
            "available": _available_elan,
        })
        return

    if cost > 0.0 and event_bus:
        var remaining := max(_available_elan - cost, 0.0)
        event_bus.emit_elan_spent({
            "amount": cost,
            "remaining": remaining,
            "reason": "formation_change",
            "unit_id": unit_id,
            "formation_id": formation_id,
        })

    var changed := false
    if combat_system:
        changed = combat_system.set_unit_formation(unit_id, formation_id)
    if not changed:
        if cost > 0.0 and elan_system:
            elan_system.add_elan(cost, "formation_refund", {
                "unit_id": unit_id,
                "formation_id": formation_id,
            })
        _emit_change_failed(unit_id, formation_id, "not_allowed")
        return

func _on_formation_changed(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var unit_id := str(payload.get("unit_id", ""))
    if unit_id.is_empty():
        return
    var formation_id := str(payload.get("formation_id", ""))
    var reason := str(payload.get("reason", ""))
    if reason == "manual":
        var rules: Dictionary = _formation_rules.get(formation_id, {})
        var lock_turns := max(int(rules.get("inertia_lock_turns", 0)), 0)
        if lock_turns > 0:
            _unit_inertia[unit_id] = {"turns_remaining": lock_turns}
        else:
            _unit_inertia.erase(unit_id)
    elif reason == "combat":
        pass
    else:
        _unit_inertia.erase(unit_id)

    _update_unit_status(unit_id, formation_id, reason, payload)
    _emit_status_update("change")

func _update_unit_status(unit_id: String, formation_id: String, reason: String, context: Dictionary = {}) -> void:
    var unit_info: Dictionary = _unit_catalog.get(unit_id, {})
    var formation_info: Dictionary = _formation_rules.get(formation_id, {})
    var inertia_state: Dictionary = _unit_inertia.get(unit_id, {})
    var turns_remaining := max(int(inertia_state.get("turns_remaining", 0)), 0)
    var available_formations := _get_available_formations(unit_id)
    var status := {
        "unit_id": unit_id,
        "unit_name": str(unit_info.get("name", unit_id)),
        "formation_id": formation_id,
        "formation_name": str(formation_info.get("name", formation_id)),
        "posture": str(formation_info.get("posture", "")),
        "elan_cost": float(formation_info.get("elan_cost", 0.0)),
        "inertia_lock_turns": int(formation_info.get("inertia_lock_turns", 0)),
        "description": str(formation_info.get("description", "")),
        "turns_remaining": turns_remaining,
        "locked": turns_remaining > 0,
        "reason": reason,
        "available_formations": available_formations,
    }
    if not context.is_empty():
        var filtered: Dictionary = {}
        for key in context.keys():
            if key in ["unit_id", "formation_id", "reason"]:
                continue
            var value := context.get(key)
            if value is Dictionary:
                filtered[key] = (value as Dictionary).duplicate(true)
            elif value is Array:
                filtered[key] = (value as Array).duplicate(true)
            else:
                filtered[key] = value
        if not filtered.is_empty():
            status["context"] = filtered
    _unit_status[unit_id] = status

func _get_available_formations(unit_id: String) -> Array:
    var info: Dictionary = _unit_catalog.get(unit_id, {})
    var result: Array = []
    var formations_variant: Variant = info.get("formations", [])
    if formations_variant is Array:
        for formation_id_variant in formations_variant:
            var formation_id := str(formation_id_variant)
            var rules: Dictionary = _formation_rules.get(formation_id, {})
            if rules.is_empty():
                continue
            result.append({
                "id": formation_id,
                "name": str(rules.get("name", formation_id)),
                "elan_cost": float(rules.get("elan_cost", 0.0)),
                "inertia_lock_turns": int(rules.get("inertia_lock_turns", 0)),
                "posture": str(rules.get("posture", "")),
                "description": str(rules.get("description", "")),
            })
    return result

func _is_formation_allowed(unit_id: String, formation_id: String) -> bool:
    var info: Dictionary = _unit_catalog.get(unit_id, {})
    var formations_variant: Variant = info.get("formations", [])
    if formations_variant is Array:
        return (formations_variant as Array).has(formation_id)
    return false

func _emit_status_update(reason: String) -> void:
    if event_bus == null:
        return
    var payload_units: Dictionary = {}
    for unit_id in _unit_status.keys():
        var status: Dictionary = _unit_status.get(unit_id, {})
        payload_units[unit_id] = status.duplicate(true)
    event_bus.emit_formation_status({
        "reason": reason,
        "turn": _current_turn,
        "available_elan": _available_elan,
        "units": payload_units,
    })

func _emit_change_failed(unit_id: String, formation_id: String, reason: String, extras: Dictionary = {}) -> void:
    if event_bus == null:
        return
    var payload := {
        "unit_id": unit_id,
        "formation_id": formation_id,
        "reason": reason,
    }
    if _formation_rules.has(formation_id):
        var rules: Dictionary = _formation_rules.get(formation_id, {})
        payload["elan_cost"] = float(rules.get("elan_cost", 0.0))
        payload["inertia_lock_turns"] = int(rules.get("inertia_lock_turns", 0))
    if not extras.is_empty():
        for key in extras.keys():
            payload[key] = extras.get(key)
    event_bus.emit_formation_change_failed(payload)
