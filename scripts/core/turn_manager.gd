class_name TurnManager
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const COMPETENCE_CATEGORIES := ["tactics", "strategy", "logistics"]

@export var base_competence_per_turn: float = 6.0

var current_turn: int = 0
var event_bus: EventBusAutoload

var _competence_allocations: Dictionary = {}
var _competence_budget: float = 0.0
var _available_competence: float = 0.0
var _processed_break_ids: Dictionary = {}
var _competence_revision: int = 0

func _ready() -> void:
    var bus := EVENT_BUS.get_instance()
    if bus == null:
        await get_tree().process_frame
        bus = EVENT_BUS.get_instance()
    setup(bus)

func setup(event_bus_ref: EventBusAutoload) -> void:
    event_bus = event_bus_ref
    if event_bus and not event_bus.logistics_update.is_connected(_on_logistics_update):
        event_bus.logistics_update.connect(_on_logistics_update)

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
    var validation := _validate_allocations(allocations)
    if not validation.get("success", false):
        return validation

    _competence_allocations = validation.get("allocations", {})
    _available_competence = max(_competence_budget - _sum_allocations(), 0.0)
    _emit_competence("manual")
    return {
        "success": true,
        "allocations": _competence_allocations.duplicate(true),
        "available": _available_competence,
    }

func get_competence_payload(reason := "status") -> Dictionary:
    return {
        "turn": current_turn,
        "allocations": _competence_allocations.duplicate(true),
        "available": _available_competence,
        "budget": _competence_budget,
        "reason": reason,
        "revision": _competence_revision,
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
    _competence_budget = max(base_competence_per_turn, 0.0)
    var target_allocations: Dictionary = {}
    if _competence_allocations.is_empty():
        var default_split: float = max(_competence_budget / float(COMPETENCE_CATEGORIES.size()), 0.0)
        for category in COMPETENCE_CATEGORIES:
            target_allocations[category] = snapped(default_split, 0.01)
    else:
        var sum: float = _sum_allocations()
        if sum <= 0.0:
            for category in COMPETENCE_CATEGORIES:
                target_allocations[category] = 0.0
        else:
            var scale: float = _competence_budget / sum if sum > 0.0 else 0.0
            for category in COMPETENCE_CATEGORIES:
                var value: float = float(_competence_allocations.get(category, 0.0)) * scale
                target_allocations[category] = snapped(value, 0.01)

    var validated: Dictionary = _validate_allocations(target_allocations)
    _competence_allocations = validated.get("allocations", {})
    _available_competence = max(_competence_budget - _sum_allocations(), 0.0)
    _processed_break_ids.clear()
    _emit_competence(reason)

func _validate_allocations(raw_allocations: Dictionary) -> Dictionary:
    var cleaned: Dictionary = {}
    var total: float = 0.0
    for category in COMPETENCE_CATEGORIES:
        var value: float = float(raw_allocations.get(category, 0.0))
        value = max(value, 0.0)
        cleaned[category] = snapped(value, 0.01)
        total += cleaned[category]

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
    }

func _sum_allocations() -> float:
    var total: float = 0.0
    for category in COMPETENCE_CATEGORIES:
        total += float(_competence_allocations.get(category, 0.0))
    return total

func _emit_competence(reason: String) -> void:
    _competence_revision += 1
    if event_bus:
        event_bus.emit_competence_reallocated(get_competence_payload(reason))

func _apply_competence_penalty(amount: float, source: Dictionary) -> void:
    if amount <= 0.0:
        return
    _competence_budget = max(_competence_budget - amount, 0.0)
    var total: float = _sum_allocations()
    if total > _competence_budget and total > 0.0:
        var scale: float = _competence_budget / total if total > 0.0 else 0.0
        for category in COMPETENCE_CATEGORIES:
            var value: float = float(_competence_allocations.get(category, 0.0)) * scale
            _competence_allocations[category] = snapped(value, 0.01)
    _available_competence = max(_competence_budget - _sum_allocations(), 0.0)
    _emit_competence(source.get("reason", "logistics_break"))

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
