class_name TurnManager
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const COMPETENCE_CATEGORIES := ["tactics", "strategy", "logistics"]

const DEFAULT_SLIDER_BASE := {
    "tactics": 2.0,
    "strategy": 2.0,
    "logistics": 2.0,
}

const DEFAULT_SLIDER_VALUES := {
    "base_allocation": 2.0,
    "min_allocation": 0.0,
    "max_allocation": 6.0,
    "max_delta_per_turn": 2.0,
    "inertia_lock_turns": 1,
    "logistics_penalty_multiplier": 1.0,
}

@export var base_competence_per_turn: float = 6.0

var current_turn: int = 0
var event_bus: EventBus

var _competence_allocations: Dictionary = {}
var _competence_budget: float = 0.0
var _available_competence: float = 0.0
var _processed_break_ids: Dictionary = {}
var _competence_revision: int = 0
var _last_competence_event: Dictionary = {}
var _competence_config: Dictionary = {}
var _inertia_state: Dictionary = {}
var _modifier_state: Dictionary = {
    "logistics_penalty": 0.0,
}
var _last_competence_snapshot: Dictionary = {}

func _ready() -> void:
    var bus := EVENT_BUS.get_instance()
    if bus == null:
        await get_tree().process_frame
        bus = EVENT_BUS.get_instance()
    setup(bus)

func setup(event_bus_ref: EventBus) -> void:
    event_bus = event_bus_ref
    if event_bus and not event_bus.logistics_update.is_connected(_on_logistics_update):
        event_bus.logistics_update.connect(_on_logistics_update)
    if event_bus and not event_bus.competence_allocation_requested.is_connected(_on_competence_allocation_requested):
        event_bus.competence_allocation_requested.connect(_on_competence_allocation_requested)

    _initialise_competence_state("initial")

func start_game() -> void:
    current_turn = 0
    advance_turn()

func advance_turn() -> void:
    current_turn += 1
    _initialise_competence_state("turn_start")
    _emit_turn_started()
    # Placeholder for systems integration.
    _emit_turn_ended()

func set_competence_allocations(allocations: Dictionary) -> Dictionary:
    _ensure_slider_config_loaded()
    var validation: Dictionary = _validate_allocations(allocations, true)
    if not validation.get("success", false):
        return validation

    var cleaned: Dictionary = validation.get("allocations", {})
    var delta_report: Dictionary = validation.get("delta_report", {})
    _competence_allocations = cleaned
    _available_competence = max(_competence_budget - _sum_allocations(), 0.0)
    _apply_inertia_updates(delta_report)
    _last_competence_event = {
        "reason": "manual",
        "delta": delta_report.duplicate(true),
    }
    _emit_competence("manual")
    return {
        "success": true,
        "allocations": _competence_allocations.duplicate(true),
        "available": _available_competence,
        "inertia": _serialise_inertia_state(),
        "modifiers": _serialise_modifier_state(),
    }

func request_competence_cost(costs: Dictionary, context: Dictionary = {}) -> Dictionary:
    var sanitised: Dictionary = _sanitize_competence_cost(costs)
    if not sanitised.get("success", false):
        return sanitised

    var filtered: Dictionary = sanitised.get("costs", {})
    if filtered.is_empty():
        return {
            "success": true,
            "costs": {},
            "remaining": _competence_allocations.duplicate(true),
        }

    var deficits: Dictionary = _competence_deficits(filtered)
    if not deficits.is_empty():
        return {
            "success": false,
            "reason": "insufficient_competence",
            "required": filtered.duplicate(true),
            "available": _competence_allocations.duplicate(true),
            "deficits": deficits,
        }

    _apply_competence_spend(filtered, context)
    return {
        "success": true,
        "costs": filtered.duplicate(true),
        "remaining": _competence_allocations.duplicate(true),
    }

func get_competence_payload(reason := "status") -> Dictionary:
    return {
        "turn": current_turn,
        "turn_id": _build_turn_identifier(),
        "allocations": _competence_allocations.duplicate(true),
        "available": _available_competence,
        "budget": _competence_budget,
        "reason": reason,
        "revision": _competence_revision,
        "last_event": _last_competence_event.duplicate(true),
        "inertia": _serialise_inertia_state(),
        "modifiers": _serialise_modifier_state(),
        "config": _competence_config.duplicate(true),
    }

func _emit_turn_started() -> void:
    print("Turn %d started" % current_turn)
    if event_bus:
        event_bus.emit_turn_started(current_turn)

func _emit_turn_ended() -> void:
    print("Turn %d ended" % current_turn)
    if event_bus:
        event_bus.emit_turn_ended(current_turn)

func _initialise_competence_state(reason: String) -> void:
    _ensure_slider_config_loaded()
    if _inertia_state.is_empty():
        _reset_inertia_state()
    if reason == "turn_start":
        _decrement_inertia_locks()
    _reset_spent_this_turn()
    if reason == "initial" or reason == "turn_start":
        _modifier_state["logistics_penalty"] = 0.0

    _competence_budget = max(base_competence_per_turn, 0.0)
    var target_allocations: Dictionary = {}
    if _competence_allocations.is_empty():
        target_allocations = _default_allocations_for_budget(_competence_budget)
    else:
        var sum: float = _sum_allocations()
        if sum <= 0.0:
            for category in COMPETENCE_CATEGORIES:
                target_allocations[category] = _clamp_and_snap(category, 0.0)
        else:
            var scale: float = _competence_budget / sum if sum > 0.0 else 0.0
            for category in COMPETENCE_CATEGORIES:
                var value: float = float(_competence_allocations.get(category, 0.0)) * scale
                target_allocations[category] = _clamp_and_snap(category, value)

    var validated: Dictionary = _validate_allocations(target_allocations, false)
    _competence_allocations = validated.get("allocations", {})
    _available_competence = max(_competence_budget - _sum_allocations(), 0.0)
    _processed_break_ids.clear()
    _last_competence_event = {"reason": reason}
    _emit_competence(reason)

func _validate_allocations(raw_allocations: Dictionary, enforce_inertia := false) -> Dictionary:
    var cleaned: Dictionary = {}
    var total: float = 0.0
    var delta_report: Dictionary = {}
    for category in COMPETENCE_CATEGORIES:
        var requested: float = float(raw_allocations.get(category, 0.0))
        var clamped := _clamp_and_snap(category, requested)
        cleaned[category] = clamped
        total += clamped

        if enforce_inertia and not _competence_allocations.is_empty():
            var current: float = float(_competence_allocations.get(category, clamped))
            var delta := abs(clamped - current)
            if delta <= 0.001:
                continue

            var state: Dictionary = _inertia_state.get(category, {})
            var turns_remaining: int = int(state.get("turns_remaining", 0))
            if turns_remaining > 0:
                return {
                    "success": false,
                    "reason": "inertia_locked",
                    "category": category,
                    "turns_remaining": turns_remaining,
                }

            var spent_this_turn: float = float(state.get("spent_this_turn", 0.0))
            var max_delta: float = float(_get_slider_config(category).get("max_delta_per_turn", _competence_budget)) - spent_this_turn
            if max_delta < 0.0:
                max_delta = 0.0
            if delta > max_delta + 0.001:
                return {
                    "success": false,
                    "reason": "delta_exceeds_cap",
                    "category": category,
                    "delta": delta,
                    "max_delta": max_delta,
                }

            delta_report[category] = delta

    if total > _competence_budget + 0.001:
        return {
            "success": false,
            "reason": "over_budget",
            "budget": _competence_budget,
            "requested": total,
        }

    return {
        "success": true,
        "allocations": cleaned,
        "total": total,
        "delta_report": delta_report,
    }

func _sum_allocations() -> float:
    var total: float = 0.0
    for category in COMPETENCE_CATEGORIES:
        total += float(_competence_allocations.get(category, 0.0))
    return total

func _emit_competence(reason: String) -> void:
    var before_snapshot := _last_competence_snapshot.duplicate(true)
    _competence_revision += 1
    var payload := get_competence_payload(reason)
    payload["turn_id"] = _build_turn_identifier()
    var after_snapshot := _build_competence_snapshot(payload)
    if before_snapshot.is_empty():
        before_snapshot = after_snapshot.duplicate(true)
        before_snapshot["revision"] = max(int(after_snapshot.get("revision", 1)) - 1, 0)
    payload["before"] = before_snapshot.duplicate(true)
    payload["after"] = after_snapshot.duplicate(true)
    if event_bus:
        event_bus.emit_competence_reallocated(payload)
    _last_competence_snapshot = after_snapshot.duplicate(true)

func _sanitize_competence_cost(raw: Dictionary) -> Dictionary:
    var cleaned: Dictionary = {}
    var invalid: Array[String] = []
    for key in raw.keys():
        var category := str(key)
        if not COMPETENCE_CATEGORIES.has(category):
            invalid.append(category)
            continue
        var value: float = max(float(raw.get(key, 0.0)), 0.0)
        if value <= 0.0:
            continue
        cleaned[category] = snapped(value, 0.01)
    if not invalid.is_empty():
        return {
            "success": false,
            "reason": "invalid_competence_category",
            "invalid": invalid,
        }
    return {
        "success": true,
        "costs": cleaned,
    }

func _competence_deficits(costs: Dictionary) -> Dictionary:
    var deficits: Dictionary = {}
    for category in costs.keys():
        var required: float = float(costs.get(category, 0.0))
        var available: float = float(_competence_allocations.get(category, 0.0))
        if required > available + 0.001:
            deficits[category] = {
                "required": required,
                "available": available,
            }
    return deficits

func _apply_competence_spend(costs: Dictionary, context: Dictionary) -> void:
    var total: float = 0.0
    for category in costs.keys():
        var value: float = max(float(costs.get(category, 0.0)), 0.0)
        if value <= 0.0:
            continue
        total += value
        _competence_allocations[category] = snapped(max(float(_competence_allocations.get(category, 0.0)) - value, 0.0), 0.01)
    if total > 0.0:
        _competence_budget = max(_competence_budget - total, 0.0)
    _available_competence = max(_competence_budget - _sum_allocations(), 0.0)
    _last_competence_event = {
        "reason": context.get("reason", "order_cost"),
        "costs": costs.duplicate(true),
        "source": context.duplicate(true),
    }
    _emit_competence(context.get("reason", "order_cost"))
    if event_bus:
        event_bus.emit_competence_spent({
            "costs": costs.duplicate(true),
            "remaining": _competence_allocations.duplicate(true),
            "reason": context.get("reason", "order_cost"),
            "source": context.duplicate(true),
        })

func _apply_competence_penalty(amount: float, source: Dictionary) -> void:
    if amount <= 0.0:
        return
    _competence_budget = max(_competence_budget - amount, 0.0)
    _modifier_state["logistics_penalty"] = float(_modifier_state.get("logistics_penalty", 0.0)) + amount
    var total: float = _sum_allocations()
    if total > _competence_budget and total > 0.0:
        var scale: float = _competence_budget / total if total > 0.0 else 0.0
        for category in COMPETENCE_CATEGORIES:
            var value: float = float(_competence_allocations.get(category, 0.0)) * scale
            _competence_allocations[category] = snapped(value, 0.01)
    _available_competence = max(_competence_budget - _sum_allocations(), 0.0)
    _last_competence_event = {
        "reason": source.get("reason", "logistics_break"),
        "amount": amount,
        "source": source.duplicate(true),
    }
    _emit_competence(source.get("reason", "logistics_break"))
    if event_bus:
        event_bus.emit_competence_spent({
            "amount": amount,
            "remaining": _competence_allocations.duplicate(true),
            "reason": source.get("reason", "logistics_break"),
            "source": source.duplicate(true),
        })

func _on_logistics_update(payload: Dictionary) -> void:
    var breaks_variant: Variant = payload.get("breaks", [])
    var breaks: Array = breaks_variant if breaks_variant is Array else []
    if breaks.is_empty():
        return

    var penalised := false
    for entry in breaks:
        if not (entry is Dictionary):
            continue
        var turn := int(entry.get("turn", current_turn))
        if turn != current_turn:
            continue
        var identifier := _break_identifier(entry)
        if _processed_break_ids.has(identifier):
            continue
        _processed_break_ids[identifier] = true
        var penalty: float = float(entry.get("competence_penalty", 0.0))
        if penalty <= 0.0:
            continue
        penalised = true
        _apply_competence_penalty(penalty, {
            "reason": "logistics_break",
            "break": entry,
        })

    if penalised:
        _available_competence = max(_competence_budget - _sum_allocations(), 0.0)

func _break_identifier(entry: Dictionary) -> String:
    var type := str(entry.get("type", "break"))
    var scope := ""
    if entry.has("route_id"):
        scope = str(entry.get("route_id"))
    elif entry.has("tile_id"):
        scope = str(entry.get("tile_id"))
    var turn := int(entry.get("turn", current_turn))
    return "%s:%s:%d" % [type, scope, turn]

func configure_sliders(entries: Array) -> void:
    _competence_config.clear()
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var dictionary_entry: Dictionary = entry
        var identifier := str(dictionary_entry.get("id", ""))
        if identifier == "":
            continue
        _competence_config[identifier] = dictionary_entry.duplicate(true)
    _fill_missing_slider_config()
    _reset_inertia_state()

func _ensure_slider_config_loaded() -> void:
    if not _competence_config.is_empty():
        return
    var loader: DataLoader = DATA_LOADER.get_instance()
    if loader:
        configure_sliders(loader.list_competence_sliders())
    else:
        configure_sliders([])

func _fill_missing_slider_config() -> void:
    for category in COMPETENCE_CATEGORIES:
        var existing: Dictionary = {}
        if _competence_config.has(category):
            existing = (_competence_config.get(category) as Dictionary).duplicate(true)
        for key in DEFAULT_SLIDER_VALUES.keys():
            if not existing.has(key):
                if key == "base_allocation":
                    existing[key] = DEFAULT_SLIDER_BASE.get(category, DEFAULT_SLIDER_VALUES[key])
                else:
                    existing[key] = DEFAULT_SLIDER_VALUES[key]
        if not existing.has("telemetry_tags"):
            existing["telemetry_tags"] = []
        _competence_config[category] = existing

func _reset_inertia_state() -> void:
    _inertia_state.clear()
    for category in COMPETENCE_CATEGORIES:
        _inertia_state[category] = {
            "turns_remaining": 0,
            "spent_this_turn": 0.0,
        }

func _build_turn_identifier() -> String:
    return "turn_%03d_rev_%03d" % [current_turn, _competence_revision]

func _build_competence_snapshot(payload: Dictionary) -> Dictionary:
    return {
        "turn": int(payload.get("turn", current_turn)),
        "turn_id": str(payload.get("turn_id", "")),
        "revision": int(payload.get("revision", _competence_revision)),
        "allocations": _duplicate_dictionary(payload.get("allocations", {})),
        "available": float(payload.get("available", 0.0)),
        "budget": float(payload.get("budget", 0.0)),
        "inertia": _duplicate_dictionary(payload.get("inertia", {})),
        "modifiers": _duplicate_dictionary(payload.get("modifiers", {})),
        "last_event": _duplicate_dictionary(payload.get("last_event", {})),
        "reason": str(payload.get("reason", "status")),
    }

func _duplicate_dictionary(value: Variant) -> Dictionary:
    if value is Dictionary:
        return (value as Dictionary).duplicate(true)
    return {}

func _decrement_inertia_locks() -> void:
    for category in COMPETENCE_CATEGORIES:
        var state: Dictionary = _inertia_state.get(category, {}).duplicate(true)
        var remaining := int(state.get("turns_remaining", 0))
        if remaining > 0:
            state["turns_remaining"] = max(remaining - 1, 0)
        _inertia_state[category] = state

func _reset_spent_this_turn() -> void:
    for category in COMPETENCE_CATEGORIES:
        var state: Dictionary = _inertia_state.get(category, {}).duplicate(true)
        state["spent_this_turn"] = 0.0
        _inertia_state[category] = state

func _default_allocations_for_budget(budget: float) -> Dictionary:
    var base_map: Dictionary = {}
    var total: float = 0.0
    for category in COMPETENCE_CATEGORIES:
        var config: Dictionary = _get_slider_config(category)
        var base_value := max(float(config.get("base_allocation", DEFAULT_SLIDER_BASE.get(category, budget))), 0.0)
        base_map[category] = base_value
        total += base_value

    var allocations: Dictionary = {}
    if total <= 0.0:
        var equal_split: float = budget / float(COMPETENCE_CATEGORIES.size()) if COMPETENCE_CATEGORIES.size() > 0 else 0.0
        for category in COMPETENCE_CATEGORIES:
            allocations[category] = _clamp_and_snap(category, equal_split)
        return allocations

    var scale: float = budget / total
    for category in COMPETENCE_CATEGORIES:
        var scaled := float(base_map.get(category, 0.0)) * scale
        allocations[category] = _clamp_and_snap(category, scaled)
    return allocations

func _apply_inertia_updates(delta_report: Dictionary) -> void:
    if delta_report.is_empty():
        return
    for category in delta_report.keys():
        var delta := float(delta_report.get(category, 0.0))
        if delta <= 0.001:
            continue
        var state: Dictionary = _inertia_state.get(category, {}).duplicate(true)
        state["spent_this_turn"] = float(state.get("spent_this_turn", 0.0)) + delta
        var lock_turns := int(max(_get_slider_config(category).get("inertia_lock_turns", 0), 0))
        state["turns_remaining"] = lock_turns
        _inertia_state[category] = state

func _serialise_inertia_state() -> Dictionary:
    var report: Dictionary = {}
    for category in COMPETENCE_CATEGORIES:
        var state: Dictionary = _inertia_state.get(category, {})
        var config: Dictionary = _get_slider_config(category)
        report[category] = {
            "turns_remaining": int(state.get("turns_remaining", 0)),
            "spent_this_turn": float(state.get("spent_this_turn", 0.0)),
            "max_delta_per_turn": float(config.get("max_delta_per_turn", _competence_budget)),
        }
    return report

func _serialise_modifier_state() -> Dictionary:
    return {
        "logistics_penalty": float(_modifier_state.get("logistics_penalty", 0.0)),
    }

func _clamp_and_snap(category: String, value: float) -> float:
    return snapped(_clamp_to_slider_bounds(category, value), 0.01)

func _clamp_to_slider_bounds(category: String, value: float) -> float:
    var config: Dictionary = _get_slider_config(category)
    var min_value := float(config.get("min_allocation", 0.0))
    var max_value := float(config.get("max_allocation", min_value))
    if max_value < min_value:
        max_value = min_value
    return clamp(value, min_value, max_value)

func _get_slider_config(category: String) -> Dictionary:
    if _competence_config.has(category):
        return _competence_config.get(category, {})
    var fallback: Dictionary = DEFAULT_SLIDER_VALUES.duplicate(true)
    fallback["base_allocation"] = DEFAULT_SLIDER_BASE.get(category, fallback.get("base_allocation", 0.0))
    fallback["telemetry_tags"] = []
    return fallback

func _on_competence_allocation_requested(allocations: Dictionary) -> void:
    if allocations.is_empty():
        return
    var result := set_competence_allocations(allocations)
    if not result.get("success", false) and event_bus:
        var payload := result.duplicate(true)
        payload["requested"] = allocations.duplicate(true)
        event_bus.emit_competence_allocation_failed(payload)
