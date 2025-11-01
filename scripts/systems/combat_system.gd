class_name CombatSystem
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

const PILLARS := ["position", "impulse", "information"]
const TERRAIN_PROFILES := {
    "plains": {"position": 1.0, "impulse": 1.0, "information": 0.95},
    "forest": {"position": 1.15, "impulse": 0.9, "information": 0.8},
    "hill": {"position": 1.25, "impulse": 0.95, "information": 0.9},
}
const DEFENDER_POSTURES := {
    "hold": {"position": 0.35, "impulse": 0.05, "information": 0.1},
    "ambush": {"position": 0.2, "impulse": 0.25, "information": 0.35},
    "screen": {"position": 0.15, "impulse": 0.15, "information": 0.25},
}
const COMPETENCE_CATEGORIES := ["tactics", "strategy", "logistics"]
const COMPETENCE_SCALAR := 0.05

var event_bus: EventBus
var data_loader: DataLoader

var _orders_by_id: Dictionary = {}
var _units_by_id: Dictionary = {}
var _doctrines_by_id: Dictionary = {}
var _weather_by_id: Dictionary = {}
var _formations_by_id: Dictionary = {}
var _formation_unit_classes: Dictionary = {}
var _current_doctrine_id: String = ""
var _current_weather_id: String = ""
var _last_resolution: Dictionary = {}
var _recent_intel: Dictionary = {}
var _default_intel_confidence: float = 0.5
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _unit_formations: Dictionary = {}
var _competence_allocations: Dictionary = {
    "tactics": 0.0,
    "strategy": 0.0,
    "logistics": 0.0,
}
var _competence_config: Dictionary = {}
var _competence_ratios: Dictionary = {
    "tactics": 1.0,
    "strategy": 1.0,
    "logistics": 1.0,
}
var _logistics_lookup: Dictionary = {}
var _logistics_deficits: Dictionary = {}
var _last_logistics_payload: Dictionary = {}
var _pending_order_id: String = ""
var _last_order_payload: Dictionary = {}

func _ready() -> void:
    setup(EVENT_BUS.get_instance(), DATA_LOADER.get_instance())

func setup(event_bus_ref: EventBus, data_loader_ref: DataLoader) -> void:
    event_bus = event_bus_ref
    data_loader = data_loader_ref
    _rng.randomize()

    if data_loader and data_loader.is_ready():
        configure(
            data_loader.list_units(),
            data_loader.list_orders(),
            data_loader.list_doctrines(),
            data_loader.list_weather_states(),
            data_loader.list_formations()
        )

    if event_bus:
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.doctrine_selected.is_connected(_on_doctrine_selected):
            event_bus.doctrine_selected.connect(_on_doctrine_selected)
        if not event_bus.weather_changed.is_connected(_on_weather_changed):
            event_bus.weather_changed.connect(_on_weather_changed)
        if not event_bus.espionage_ping.is_connected(_on_espionage_ping):
            event_bus.espionage_ping.connect(_on_espionage_ping)
        if not event_bus.assistant_order_packet.is_connected(_on_assistant_order_packet):
            event_bus.assistant_order_packet.connect(_on_assistant_order_packet)
        if not event_bus.competence_reallocated.is_connected(_on_competence_reallocated):
            event_bus.competence_reallocated.connect(_on_competence_reallocated)
        if not event_bus.logistics_update.is_connected(_on_logistics_update):
            event_bus.logistics_update.connect(_on_logistics_update)
        if not event_bus.order_execution_requested.is_connected(_on_order_execution_requested):
            event_bus.order_execution_requested.connect(_on_order_execution_requested)
        if not event_bus.order_issued.is_connected(_on_order_issued):
            event_bus.order_issued.connect(_on_order_issued)

func configure(unit_entries: Array, order_entries: Array, doctrine_entries: Array, weather_entries: Array, formation_entries: Array) -> void:
    _units_by_id = _index_entries(unit_entries)
    _orders_by_id = _index_entries(order_entries)
    _doctrines_by_id = _index_entries(doctrine_entries)
    _weather_by_id = _index_entries(weather_entries)
    _formations_by_id = _index_entries(formation_entries)
    _refresh_formation_unit_classes()

    if _current_doctrine_id.is_empty() and not _doctrines_by_id.is_empty():
        _current_doctrine_id = str(_doctrines_by_id.keys()[0])
    elif not _doctrines_by_id.has(_current_doctrine_id) and not _doctrines_by_id.is_empty():
        _current_doctrine_id = str(_doctrines_by_id.keys()[0])

    if _current_weather_id.is_empty() and not _weather_by_id.is_empty():
        _current_weather_id = str(_weather_by_id.keys()[0])
    elif not _weather_by_id.has(_current_weather_id) and not _weather_by_id.is_empty():
        _current_weather_id = str(_weather_by_id.keys()[0])

    _recalculate_doctrine_confidence()
    _ensure_default_formations()

func set_rng_seed(seed: int) -> void:
    _rng.seed = seed

func set_active_doctrine(doctrine_id: String) -> void:
    if doctrine_id.is_empty() or not _doctrines_by_id.has(doctrine_id):
        return
    _current_doctrine_id = doctrine_id
    _recalculate_doctrine_confidence()

func set_current_weather(weather_id: String) -> void:
    if weather_id.is_empty() or not _weather_by_id.has(weather_id):
        return
    _current_weather_id = weather_id

func set_unit_formation(unit_id: String, formation_id: String) -> bool:
    if unit_id.is_empty() or not _units_by_id.has(unit_id):
        return false
    if formation_id.is_empty() or not _formations_by_id.has(formation_id):
        return false
    var unit_entry: Dictionary = _units_by_id.get(unit_id, {})
    var allowed: Array = unit_entry.get("default_formations", [])
    var is_allowed: bool = allowed.has(formation_id)
    if not is_allowed:
        var unit_class: String = str(unit_entry.get("unit_class", ""))
        if not unit_class.is_empty():
            var classes: Array = _formation_unit_classes.get(formation_id, [])
            is_allowed = classes.has(unit_class)
    if allowed.size() > 0 and not is_allowed:
        return false
    var previous: String = str(_unit_formations.get(unit_id, ""))
    _unit_formations[unit_id] = formation_id
    if previous != formation_id:
        _emit_formation_update(unit_id, "manual")
    return true

func get_unit_formation(unit_id: String) -> String:
    return str(_unit_formations.get(unit_id, ""))

func _ensure_default_formations() -> void:
    for unit_id in _units_by_id.keys():
        var stored: String = str(_unit_formations.get(unit_id, ""))
        if stored.is_empty() or not _formations_by_id.has(stored):
            var resolved: String = _resolve_default_formation(unit_id)
            if not resolved.is_empty():
                _emit_formation_update(unit_id, "default")
    var orphaned: Array = []
    for stored_id in _unit_formations.keys():
        if not _units_by_id.has(stored_id):
            orphaned.append(stored_id)
    for unit_id in orphaned:
        _unit_formations.erase(unit_id)

func get_last_resolution() -> Dictionary:
    return _last_resolution.duplicate(true)

func resolve_engagement(engagement: Dictionary) -> Dictionary:
    if engagement.is_empty():
        return {}

    var order_id: String = str(engagement.get("order_id", ""))
    var order_entry: Dictionary = _orders_by_id.get(order_id, {})

    var attacker_unit_ids: Array[String] = _normalise_id_array(engagement.get("attacker_unit_ids", []))
    var defender_unit_ids: Array[String] = _normalise_id_array(engagement.get("defender_unit_ids", []))
    var terrain_id: String = str(engagement.get("terrain", "plains"))
    var defender_posture: String = str(engagement.get("defender_posture", "hold"))
    if defender_posture.is_empty() or not DEFENDER_POSTURES.has(defender_posture):
        defender_posture = "hold"

    var weather_id: String = str(engagement.get("weather_id", _current_weather_id))
    if weather_id.is_empty():
        weather_id = _current_weather_id
    var weather_config: Dictionary = _weather_by_id.get(weather_id, {})
    var weather_modifiers: Dictionary = weather_config.get("combat_modifiers", {})

    var intel_confidence: float = _resolve_intel_confidence(engagement)
    var espionage_bonus: float = float(engagement.get("espionage_bonus", 0.0))
    var attacker_bonuses: Dictionary = engagement.get("attacker_bonus", {})
    var defender_bonuses: Dictionary = engagement.get("defender_bonus", {})

    var doctrine_effects: Dictionary = _doctrines_by_id.get(_current_doctrine_id, {}).get("effects", {})
    var doctrine_bonus: Dictionary = doctrine_effects.get("combat_bonus", {})

    var target_hex: String = str(engagement.get("target", engagement.get("target_hex", "")))
    var logistics_context: Dictionary = _logistics_context_for_target(target_hex)
    var attacker_logistics_factor: float = float(logistics_context.get("attacker_factor", 1.0))
    var defender_logistics_factor: float = float(logistics_context.get("defender_factor", 1.0))

    var attacker_base: Dictionary = _aggregate_unit_profile(attacker_unit_ids, "combat_profile", "attacker")
    var defender_base: Dictionary = _aggregate_unit_profile(defender_unit_ids, "combat_profile", "defender")
    var attacker_detection: float = _aggregate_unit_value(attacker_unit_ids, "recon_profile", "detection")
    var defender_counter: float = _aggregate_unit_value(defender_unit_ids, "recon_profile", "counter_intel")

    var attacker_formation_bonus: Dictionary = _formation_bonus_for_units(attacker_unit_ids)
    var defender_formation_bonus: Dictionary = _formation_bonus_for_units(defender_unit_ids)
    var attacker_competence_bonus: Dictionary = _competence_bonus_for_units(attacker_unit_ids)
    var defender_competence_bonus: Dictionary = _competence_bonus_for_units(defender_unit_ids)
    var attacker_formation_multiplier: Dictionary = _formation_multiplier_map(attacker_formation_bonus, attacker_unit_ids.size())
    var defender_formation_multiplier: Dictionary = _formation_multiplier_map(defender_formation_bonus, defender_unit_ids.size())

    var results: Dictionary = {}
    var attacker_wins: int = 0
    var defender_wins: int = 0
    var terrain_profile: Dictionary = _terrain_profile(terrain_id)
    var posture_bonus: Dictionary = DEFENDER_POSTURES.get(defender_posture, DEFENDER_POSTURES.get("hold"))
    var order_weights: Dictionary = order_entry.get("pillar_weights", {})
    var intel_profile: Dictionary = order_entry.get("intel_profile", {})
    var doctrine_focus: String = str(doctrine_effects.get("combat_pillar_focus", ""))

    for pillar in PILLARS:
        var pillar_context: Dictionary = {
            "terrain_factor": float(terrain_profile.get(pillar, 1.0)),
            "weather_factor": float(weather_modifiers.get(pillar, 1.0)),
            "order_weights": order_weights,
            "doctrine_bonus": doctrine_bonus,
            "attacker_bonus": attacker_bonuses,
            "defender_bonus": defender_bonuses,
            "posture_bonus": posture_bonus,
            "intel_confidence": intel_confidence,
            "espionage_bonus": espionage_bonus,
            "attacker_detection": attacker_detection,
            "defender_counter": defender_counter,
            "intel_profile": intel_profile,
            "doctrine_focus": doctrine_focus,
            "attacker_logistics_factor": attacker_logistics_factor,
            "defender_logistics_factor": defender_logistics_factor,
            "movement_cost": float(logistics_context.get("movement_cost", 1.0)),
            "logistics_severity": str(logistics_context.get("severity", "")),
            "attacker_formation_bonus": attacker_formation_bonus,
            "defender_formation_bonus": defender_formation_bonus,
            "attacker_competence_bonus": attacker_competence_bonus,
            "defender_competence_bonus": defender_competence_bonus,
            "attacker_formation_multiplier": attacker_formation_multiplier,
            "defender_formation_multiplier": defender_formation_multiplier,
        }

        var pillar_result: Dictionary = _resolve_pillar(
            pillar,
            float(attacker_base.get(pillar, 0.0)),
            float(defender_base.get(pillar, 0.0)),
            pillar_context
        )

        results[pillar] = pillar_result
        match pillar_result.get("winner", "stalemate"):
            "attacker":
                attacker_wins += 1
            "defender":
                defender_wins += 1
            _:
                pass

    var victor: String = "stalemate"
    if attacker_wins >= 2:
        victor = "attacker"
    elif defender_wins >= 2:
        victor = "defender"
    elif attacker_wins == defender_wins and attacker_wins == 1:
        victor = "contested"

    var intel_source: String = "baseline"
    if _recent_intel.has(target_hex):
        var intel_entry: Dictionary = _recent_intel.get(target_hex, {})
        intel_source = str(intel_entry.get("source", "baseline"))
    var pillar_summary: Dictionary = _summarise_pillars(results)
    var unit_states: Dictionary = _build_unit_states(attacker_unit_ids, defender_unit_ids, victor, pillar_summary, logistics_context)

    var payload: Dictionary = {
        "engagement_id": engagement.get("engagement_id", order_id if order_id != "" else "skirmish"),
        "order_id": order_id,
        "terrain": terrain_id,
        "weather_id": weather_id,
        "doctrine_id": _current_doctrine_id,
        "pillars": results,
        "pillar_summary": pillar_summary,
        "victor": victor,
        "intel": {
            "confidence": snapped(clamp(intel_confidence + espionage_bonus, 0.0, 1.0), 0.01),
            "source": intel_source,
        },
        "reason": engagement.get("reason", "resolution"),
        "logistics": logistics_context,
        "units": unit_states,
    }

    _last_resolution = payload.duplicate(true)

    if event_bus:
        event_bus.emit_combat_resolved(_last_resolution)
        _emit_combat_formation_events(_last_resolution)

    return _last_resolution

func _index_entries(entries: Array) -> Dictionary:
    var map: Dictionary = {}
    for entry in entries:
        if entry is Dictionary and entry.has("id"):
            map[str(entry.get("id"))] = entry
    return map

func _normalise_id_array(value) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for element in value:
            result.append(str(element))
    elif typeof(value) == TYPE_STRING and value != "":
        result.append(str(value))
    return result

func _aggregate_unit_profile(unit_ids: Array, field: String, _side: String = "attacker") -> Dictionary:
    var totals: Dictionary = {}
    for unit_id in unit_ids:
        var unit: Dictionary = _units_by_id.get(unit_id, {})
        var profile: Dictionary = unit.get(field, {})
        if profile is Dictionary:
            for key in profile.keys():
                totals[key] = float(totals.get(key, 0.0)) + float(profile.get(key, 0.0))

    return totals

func _aggregate_unit_value(unit_ids: Array, field: String, key: String) -> float:
    var total: float = 0.0
    for unit_id in unit_ids:
        var unit: Dictionary = _units_by_id.get(unit_id, {})
        var profile: Dictionary = unit.get(field, {})
        if profile is Dictionary:
            total += float(profile.get(key, 0.0))
    return total

func _formation_bonus_for_units(unit_ids: Array) -> Dictionary:
    var totals: Dictionary = {}
    for pillar in PILLARS:
        totals[pillar] = 0.0
    for unit_id in unit_ids:
        var formation_id: String = str(_unit_formations.get(unit_id, ""))
        if formation_id.is_empty() and _units_by_id.has(unit_id):
            formation_id = _resolve_default_formation(unit_id)
        var formation: Dictionary = _formations_by_id.get(formation_id, {})
        var modifiers: Dictionary = formation.get("pillar_modifiers", {})
        if modifiers is Dictionary:
            for pillar in modifiers.keys():
                totals[pillar] = float(totals.get(pillar, 0.0)) + float(modifiers.get(pillar, 0.0))
    return totals

func _formation_multiplier_map(bonus: Dictionary, unit_count: int) -> Dictionary:
    var multipliers: Dictionary = {}
    var count: int = max(unit_count, 1)
    for pillar in PILLARS:
        var total: float = float(bonus.get(pillar, 0.0))
        var average: float = total / float(count)
        multipliers[pillar] = clamp(1.0 + average * 0.25, 0.6, 1.4)
    return multipliers

func _competence_bonus_for_units(unit_ids: Array) -> Dictionary:
    var totals: Dictionary = {}
    for pillar in PILLARS:
        totals[pillar] = 0.0
    for unit_id in unit_ids:
        var unit: Dictionary = _units_by_id.get(unit_id, {})
        if unit.is_empty():
            continue
        var synergy: Dictionary = unit.get("competence_synergy", {})
        var formation_id: String = str(_unit_formations.get(unit_id, ""))
        var formation: Dictionary = _formations_by_id.get(formation_id, {})
        var formation_weight: Dictionary = formation.get("competence_weight", {})
        for category in COMPETENCE_CATEGORIES:
            var allocation: float = float(_competence_allocations.get(category, 0.0))
            if allocation <= 0.0:
                continue
            var synergy_value: float = float(synergy.get(category, 0.0))
            if synergy_value <= 0.0:
                continue
            var multiplier: float = 1.0 + float(formation_weight.get(category, 0.0))
            var contribution: float = allocation * synergy_value * multiplier * COMPETENCE_SCALAR
            match category:
                "tactics":
                    totals["impulse"] = float(totals.get("impulse", 0.0)) + contribution
                "strategy":
                    totals["information"] = float(totals.get("information", 0.0)) + contribution
                "logistics":
                    totals["position"] = float(totals.get("position", 0.0)) + contribution
    return totals

func _update_competence_ratios() -> void:
    for category in COMPETENCE_CATEGORIES:
        _competence_ratios[category] = _compute_competence_ratio(category)

func _compute_competence_ratio(category: String) -> float:
    var allocation: float = max(float(_competence_allocations.get(category, 0.0)), 0.0)
    var config: Dictionary = _competence_config.get(category, {}) if _competence_config.has(category) else {}
    var base_allocation: float = float(config.get("base_allocation", 0.0))
    if base_allocation <= 0.01:
        base_allocation = allocation if allocation > 0.0 else 1.0
    var ratio := allocation / base_allocation
    return clamp(ratio, 0.2, 3.0)

func _competence_ratio(category: String) -> float:
    return float(_competence_ratios.get(category, 1.0))

func _terrain_profile(terrain_id: String) -> Dictionary:
    if TERRAIN_PROFILES.has(terrain_id):
        return TERRAIN_PROFILES.get(terrain_id, {})
    return TERRAIN_PROFILES.get("plains", {})

func _resolve_default_formation(unit_id: String) -> String:
    var unit: Dictionary = _units_by_id.get(unit_id, {})
    var defaults: Array = unit.get("default_formations", [])
    for entry in defaults:
        var candidate: String = str(entry)
        if not candidate.is_empty() and _formations_by_id.has(candidate):
            _unit_formations[unit_id] = candidate
            return candidate
    var unit_class: String = str(unit.get("unit_class", ""))
    if not unit_class.is_empty() and data_loader:
        var class_formations: Array = data_loader.list_formations_for_unit_class(unit_class)
        for formation in class_formations:
            var fallback_id: String = str(formation.get("id", ""))
            if fallback_id.is_empty():
                continue
            if _formations_by_id.has(fallback_id):
                _unit_formations[unit_id] = fallback_id
                return fallback_id
    if not _formations_by_id.is_empty():
        var fallback: String = str(_formations_by_id.keys()[0])
        _unit_formations[unit_id] = fallback
        return fallback
    return ""

func _refresh_formation_unit_classes() -> void:
    _formation_unit_classes.clear()
    if data_loader == null:
        return
    for formation_id in _formations_by_id.keys():
        _formation_unit_classes[formation_id] = data_loader.get_unit_classes_for_formation(formation_id)

func _formation_payload(unit_id: String, reason: String) -> Dictionary:
    var formation_id: String = str(_unit_formations.get(unit_id, ""))
    var formation: Dictionary = _formations_by_id.get(formation_id, {})
    return {
        "unit_id": unit_id,
        "formation_id": formation_id,
        "formation_name": formation.get("name", formation_id),
        "posture": formation.get("posture", ""),
        "pillar_modifiers": formation.get("pillar_modifiers", {}),
        "competence_weight": formation.get("competence_weight", {}),
        "reason": reason,
    }

func _emit_formation_update(unit_id: String, reason: String, context: Dictionary = {}) -> void:
    if event_bus == null:
        return
    var payload := _formation_payload(unit_id, reason)
    if not context.is_empty():
        for key in context.keys():
            payload[key] = context.get(key)
    event_bus.emit_formation_changed(payload)

func _emit_combat_formation_events(resolution: Dictionary) -> void:
    if event_bus == null or resolution.is_empty():
        return
    var engagement_id := str(resolution.get("engagement_id", ""))
    var order_id := str(resolution.get("order_id", ""))
    var victor := str(resolution.get("victor", "stalemate"))
    var terrain_id := str(resolution.get("terrain", ""))
    var weather_id := str(resolution.get("weather_id", ""))
    var summary_variant: Variant = resolution.get("pillar_summary", {})
    var pillar_summary: Dictionary = {}
    if summary_variant is Dictionary:
        pillar_summary = (summary_variant as Dictionary).duplicate(true)
    var units_variant: Variant = resolution.get("units", {})
    if not (units_variant is Dictionary):
        return
    var units: Dictionary = units_variant as Dictionary
    for side_variant in units.keys():
        var side_id := str(side_variant)
        var entries_variant: Variant = units.get(side_variant, [])
        if not (entries_variant is Array):
            continue
        var entries: Array = entries_variant as Array
        for entry_variant in entries:
            if not (entry_variant is Dictionary):
                continue
            var unit_state: Dictionary = (entry_variant as Dictionary).duplicate(true)
            var unit_id := str(unit_state.get("unit_id", ""))
            if unit_id.is_empty():
                continue
            var context := {
                "side": side_id,
                "engagement_id": engagement_id,
                "order_id": order_id,
                "victor": victor,
                "terrain": terrain_id,
                "weather_id": weather_id,
                "pillar_summary": pillar_summary.duplicate(true),
                "unit_result": unit_state,
            }
            _emit_formation_update(unit_id, "combat", context)

func _resolve_intel_confidence(engagement: Dictionary) -> float:
    var confidence: float = float(engagement.get("intel_confidence", _default_intel_confidence))
    var target: String = str(engagement.get("target", engagement.get("target_hex", "")))
    if _recent_intel.has(target):
        var intel: Dictionary = _recent_intel.get(target, {})
        confidence = max(confidence, float(intel.get("confidence", confidence)))
    return clamp(confidence, 0.0, 1.0)

func _recalculate_doctrine_confidence() -> void:
    var doctrine: Dictionary = _doctrines_by_id.get(_current_doctrine_id, {})
    var effects: Dictionary = doctrine.get("effects", {})
    var modifier: float = float(effects.get("intel_visibility_modifier", 0.0))
    _default_intel_confidence = clamp(0.5 + modifier, 0.1, 0.9)

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(
        collections.get("units", []),
        collections.get("orders", []),
        collections.get("doctrines", []),
        collections.get("weather", []),
        collections.get("formations", [])
    )

func _on_doctrine_selected(payload: Dictionary) -> void:
    var doctrine_id: String = str(payload.get("id", ""))
    if doctrine_id != "":
        _current_doctrine_id = doctrine_id
        _recalculate_doctrine_confidence()

func _on_weather_changed(payload: Dictionary) -> void:
    var weather_id: String = str(payload.get("weather_id", ""))
    if weather_id != "":
        _current_weather_id = weather_id

func _on_espionage_ping(payload: Dictionary) -> void:
    var target: String = str(payload.get("target", ""))
    if target == "":
        return
    _recent_intel[target] = payload.duplicate(true)

func _on_assistant_order_packet(packet: Dictionary) -> void:
    var engagements: Array = packet.get("expected_engagements", [])
    for engagement in engagements:
        if engagement is Dictionary:
            _resolve_assistant_engagement(engagement)

func _on_competence_reallocated(payload: Dictionary) -> void:
    var allocations: Dictionary = payload.get("allocations", {})
    for category in COMPETENCE_CATEGORIES:
        _competence_allocations[category] = float(allocations.get(category, 0.0))
    var config_variant: Variant = payload.get("config", {})
    if config_variant is Dictionary:
        _competence_config = (config_variant as Dictionary).duplicate(true)
    _update_competence_ratios()

func _on_logistics_update(payload: Dictionary) -> void:
    _last_logistics_payload = payload.duplicate(true)
    _logistics_lookup.clear()
    var zones_variant: Variant = payload.get("supply_zones", [])
    var zones: Array = zones_variant if zones_variant is Array else []
    for zone in zones:
        if not (zone is Dictionary):
            continue
        var tile_id: String = str(zone.get("tile_id", ""))
        if tile_id == "":
            continue
        _logistics_lookup[tile_id] = zone.duplicate(true)

    _logistics_deficits.clear()
    var deficits_variant: Variant = payload.get("supply_deficits", [])
    var deficits: Array = deficits_variant if deficits_variant is Array else []
    for entry in deficits:
        if not (entry is Dictionary):
            continue
        var deficit_tile: String = str(entry.get("tile_id", ""))
        if deficit_tile == "":
            continue
        _logistics_deficits[deficit_tile] = entry.duplicate(true)

func _on_order_execution_requested(order_id: String) -> void:
    _pending_order_id = order_id

func _on_order_issued(payload: Dictionary) -> void:
    _last_order_payload = payload.duplicate(true)
    var issued_id: String = str(payload.get("order_id", ""))
    if issued_id == _pending_order_id:
        _pending_order_id = ""

func _resolve_assistant_engagement(engagement: Dictionary) -> void:
    var enriched: Dictionary = _enrich_engagement(engagement)
    resolve_engagement(enriched)

func _enrich_engagement(engagement: Dictionary) -> Dictionary:
    var enriched: Dictionary = engagement.duplicate(true)
    var target_hex: String = str(enriched.get("target", enriched.get("target_hex", "")))
    if target_hex != "":
        enriched["target_hex"] = target_hex
        if not enriched.has("terrain") or str(enriched.get("terrain", "")).is_empty():
            var zone: Dictionary = _logistics_lookup.get(target_hex, {})
            if not zone.is_empty():
                enriched["terrain"] = zone.get("terrain", enriched.get("terrain", "plains"))
    if not enriched.has("weather_id") or str(enriched.get("weather_id", "")).is_empty():
        enriched["weather_id"] = _current_weather_id
    return enriched

func _logistics_context_for_target(target_hex: String) -> Dictionary:
    if target_hex.is_empty():
        return {
            "attacker_factor": 1.0,
            "defender_factor": 1.0,
            "logistics_flow": 1.0,
            "supply_level": "",
            "severity": "",
            "turn": int(_last_logistics_payload.get("turn", -1)),
            "logistics_id": str(_last_logistics_payload.get("logistics_id", "")),
            "target_hex": target_hex,
            "movement_cost": 1.0,
        }

    var zone: Dictionary = _logistics_lookup.get(target_hex, {})
    var flow: float = float(zone.get("logistics_flow", 1.0))
    var supply_level: String = str(zone.get("supply_level", ""))
    var movement_cost: float = float(zone.get("movement_cost", 1.0))
    var deficit: Dictionary = _logistics_deficits.get(target_hex, {}) if _logistics_deficits.has(target_hex) else {}
    var severity: String = str(deficit.get("severity", "")) if deficit is Dictionary else ""

    var attacker_factor: float = clamp(flow, 0.2, 1.5)
    match severity:
        "warning":
            attacker_factor *= 0.85
        "critical":
            attacker_factor *= 0.65
        _:
            pass

    var defender_factor: float = 1.0
    match severity:
        "warning":
            defender_factor *= 0.95
        "critical":
            defender_factor *= 0.8
        _:
            pass

    return {
        "attacker_factor": snapped(attacker_factor, 0.01),
        "defender_factor": snapped(defender_factor, 0.01),
        "logistics_flow": snapped(flow, 0.01),
        "supply_level": supply_level,
        "severity": severity,
        "movement_cost": snapped(movement_cost, 0.01),
        "turn": int(_last_logistics_payload.get("turn", -1)),
        "logistics_id": str(_last_logistics_payload.get("logistics_id", "")),
        "target_hex": target_hex,
    }

func _resolve_pillar(pillar: String, attacker_base: float, defender_base: float, context: Dictionary) -> Dictionary:
    var order_weights: Dictionary = context.get("order_weights", {})
    var doctrine_bonus: Dictionary = context.get("doctrine_bonus", {})
    var attacker_bonus: Dictionary = context.get("attacker_bonus", {})
    var defender_bonus: Dictionary = context.get("defender_bonus", {})
    var posture_bonus: Dictionary = context.get("posture_bonus", {})
    var attacker_formation_bonus: Dictionary = context.get("attacker_formation_bonus", {})
    var defender_formation_bonus: Dictionary = context.get("defender_formation_bonus", {})
    var attacker_competence_bonus: Dictionary = context.get("attacker_competence_bonus", {})
    var defender_competence_bonus: Dictionary = context.get("defender_competence_bonus", {})
    var attacker_formation_multiplier: Dictionary = context.get("attacker_formation_multiplier", {})
    var defender_formation_multiplier: Dictionary = context.get("defender_formation_multiplier", {})

    var attacker_strength: float = attacker_base
    attacker_strength += float(order_weights.get(pillar, 0.0))
    attacker_strength += float(doctrine_bonus.get(pillar, 0.0))
    attacker_strength += float(attacker_bonus.get(pillar, 0.0))
    attacker_strength += float(attacker_formation_bonus.get(pillar, 0.0))
    attacker_strength += float(attacker_competence_bonus.get(pillar, 0.0))
    attacker_strength = max(attacker_strength, 0.0)

    var defender_strength: float = defender_base
    defender_strength += float(posture_bonus.get(pillar, 0.0))
    defender_strength += float(defender_bonus.get(pillar, 0.0))
    defender_strength += float(defender_formation_bonus.get(pillar, 0.0))
    defender_strength += float(defender_competence_bonus.get(pillar, 0.0))
    defender_strength = max(defender_strength, 0.0)

    var terrain_factor: float = float(context.get("terrain_factor", 1.0))
    var weather_factor: float = float(context.get("weather_factor", 1.0))
    attacker_strength *= float(attacker_formation_multiplier.get(pillar, 1.0))
    defender_strength *= float(defender_formation_multiplier.get(pillar, 1.0))
    attacker_strength *= terrain_factor * weather_factor
    defender_strength *= terrain_factor * weather_factor

    var doctrine_focus: String = str(context.get("doctrine_focus", ""))
    if doctrine_focus == pillar:
        attacker_strength *= 1.1
    elif doctrine_focus != "" and doctrine_focus != pillar:
        attacker_strength *= 0.98

    var attacker_logistics_factor: float = float(context.get("attacker_logistics_factor", 1.0))
    var defender_logistics_factor: float = float(context.get("defender_logistics_factor", 1.0))
    attacker_strength *= attacker_logistics_factor
    defender_strength *= defender_logistics_factor

    match pillar:
        "position":
            attacker_strength *= _position_multiplier(context)
            defender_strength *= _position_defender_multiplier(context)
        "impulse":
            attacker_strength *= _impulse_multiplier(context)
            defender_strength *= _impulse_defender_multiplier(context)
        "information":
            attacker_strength *= _information_multiplier(context)
            defender_strength *= _information_defender_multiplier(context)
        _:
            pass

    var jitter: float = _rng.randf_range(-0.05, 0.05)
    attacker_strength = max(attacker_strength + jitter, 0.0)
    defender_strength = max(defender_strength - jitter, 0.0)

    var margin: float = snapped(attacker_strength - defender_strength, 0.01)
    var pillar_winner: String = "stalemate"
    if margin > 0.05:
        pillar_winner = "attacker"
    elif margin < -0.05:
        pillar_winner = "defender"

    return {
        "attacker": snapped(attacker_strength, 0.01),
        "defender": snapped(defender_strength, 0.01),
        "margin": margin,
        "winner": pillar_winner,
    }

func _position_multiplier(context: Dictionary) -> float:
    var movement_cost: float = float(context.get("movement_cost", 1.0))
    var severity: String = str(context.get("logistics_severity", ""))
    var espionage_bonus: float = float(context.get("espionage_bonus", 0.0))
    var modifier: float = clamp(1.0 - ((movement_cost - 1.0) * 0.25), 0.6, 1.3)
    match severity:
        "warning":
            modifier *= 0.9
        "critical":
            modifier *= 0.75
        _:
            pass
    modifier += espionage_bonus * 0.05
    return clamp(modifier, 0.4, 1.5)

func _position_defender_multiplier(context: Dictionary) -> float:
    var posture_bonus: Dictionary = context.get("posture_bonus", {})
    var intel_confidence: float = float(context.get("intel_confidence", 0.5))
    var severity: String = str(context.get("logistics_severity", ""))
    var modifier: float = 1.0 + float(posture_bonus.get("position", 0.0)) * 0.5
    modifier *= clamp(1.0 - (intel_confidence - 0.5) * 0.3, 0.7, 1.3)
    match severity:
        "warning":
            modifier *= 0.95
        "critical":
            modifier *= 0.85
        _:
            pass
    return clamp(modifier, 0.5, 1.6)

func _impulse_multiplier(context: Dictionary) -> float:
    var intel_confidence: float = float(context.get("intel_confidence", 0.5))
    var espionage_bonus: float = float(context.get("espionage_bonus", 0.0))
    var logistics_factor: float = float(context.get("attacker_logistics_factor", 1.0))
    var bonus: float = (intel_confidence - 0.5) * 0.5
    bonus += espionage_bonus * 0.35
    bonus += (logistics_factor - 1.0) * 0.4
    bonus += (_competence_ratio("tactics") - 1.0) * 0.45
    return clamp(1.0 + bonus, 0.5, 1.8)

func _impulse_defender_multiplier(context: Dictionary) -> float:
    var posture_bonus: Dictionary = context.get("posture_bonus", {})
    var defender_counter: float = float(context.get("defender_counter", 0.0))
    var espionage_bonus: float = float(context.get("espionage_bonus", 0.0))
    var intel_confidence: float = float(context.get("intel_confidence", 0.5))
    var modifier: float = 1.0 + float(posture_bonus.get("impulse", 0.0)) * 0.6
    modifier += defender_counter * 0.2
    modifier -= espionage_bonus * 0.2
    modifier *= clamp(1.0 - (intel_confidence - 0.5) * 0.25, 0.7, 1.3)
    return clamp(modifier, 0.4, 1.8)

func _information_multiplier(context: Dictionary) -> float:
    var intel_confidence: float = float(context.get("intel_confidence", 0.5))
    var espionage_bonus: float = float(context.get("espionage_bonus", 0.0))
    var attacker_detection: float = float(context.get("attacker_detection", 0.0))
    var defender_counter: float = float(context.get("defender_counter", 0.0))
    var intel_profile: Dictionary = context.get("intel_profile", {})
    var signal_strength: float = float(intel_profile.get("signal_strength", 0.0))
    var detection_delta: float = attacker_detection - defender_counter
    var modifier: float = 0.6 + intel_confidence + espionage_bonus + signal_strength + detection_delta * 0.4
    return clamp(modifier, 0.2, 2.4)

func _information_defender_multiplier(context: Dictionary) -> float:
    var defender_counter: float = float(context.get("defender_counter", 0.0))
    var espionage_bonus: float = float(context.get("espionage_bonus", 0.0))
    var intel_profile: Dictionary = context.get("intel_profile", {})
    var counter_profile: float = float(intel_profile.get("counter_intel", 0.0))
    var modifier: float = 0.9 + defender_counter + counter_profile - espionage_bonus * 0.4
    return clamp(modifier, 0.3, 2.2)

func _summarise_pillars(pillars: Dictionary) -> Dictionary:
    var attacker_total: float = 0.0
    var defender_total: float = 0.0
    for pillar_key in pillars.keys():
        var pillar_entry: Dictionary = pillars.get(pillar_key, {})
        if not (pillar_entry is Dictionary):
            continue
        attacker_total += float(pillar_entry.get("attacker", 0.0))
        defender_total += float(pillar_entry.get("defender", 0.0))

    var combined: float = attacker_total + defender_total
    var margin_score: float = 0.0
    if combined > 0.0:
        margin_score = clamp((attacker_total - defender_total) / combined, -1.0, 1.0)

    var decisive: Array = []
    for pillar_id in PILLARS:
        var pillar_entry: Dictionary = pillars.get(pillar_id, {})
        if not (pillar_entry is Dictionary):
            continue
        var winner: String = str(pillar_entry.get("winner", "stalemate"))
        if winner == "attacker" or winner == "defender":
            decisive.append({
                "pillar": pillar_id,
                "winner": winner,
                "margin": float(pillar_entry.get("margin", 0.0)),
            })

    return {
        "attacker_total": snapped(attacker_total, 0.01),
        "defender_total": snapped(defender_total, 0.01),
        "margin_score": snapped(margin_score, 0.01),
        "decisive_pillars": decisive,
    }

func _build_unit_states(attacker_ids: Array, defender_ids: Array, victor: String, summary: Dictionary, logistics_context: Dictionary) -> Dictionary:
    var attacker_margin: float = float(summary.get("margin_score", 0.0))
    var attacker_casualties: float = _estimate_casualty_ratio("attacker", victor, attacker_margin, logistics_context)
    var defender_casualties: float = _estimate_casualty_ratio("defender", victor, attacker_margin, logistics_context)

    var attacker_states: Array = []
    for unit_id in attacker_ids:
        attacker_states.append(_unit_state_payload(str(unit_id), "attacker", attacker_casualties, victor, logistics_context))

    var defender_states: Array = []
    for unit_id in defender_ids:
        defender_states.append(_unit_state_payload(str(unit_id), "defender", defender_casualties, victor, logistics_context))

    return {
        "attacker": attacker_states,
        "defender": defender_states,
    }

func _estimate_casualty_ratio(side: String, victor: String, attacker_margin_score: float, logistics_context: Dictionary) -> float:
    var advantage: float = attacker_margin_score
    if side == "defender":
        advantage = -attacker_margin_score

    var base: float = 0.22 - advantage * 0.12
    match victor:
        "stalemate":
            base = 0.18
        "contested":
            base = 0.26 - advantage * 0.08
        _:
            if victor == side:
                base = 0.12 - advantage * 0.15
            else:
                base = 0.32 - advantage * 0.05

    var severity: String = str(logistics_context.get("severity", ""))
    var factor_key: String = "attacker_factor" if side == "attacker" else "defender_factor"
    var logistics_factor: float = float(logistics_context.get(factor_key, 1.0))

    match severity:
        "warning":
            if side == "attacker":
                base += 0.05
        "critical":
            if side == "attacker":
                base += 0.12
    if logistics_factor < 0.8:
        base += 0.08
    elif logistics_factor > 1.1:
        base -= 0.05

    return clamp(snapped(base, 0.01), 0.02, 0.9)

func _unit_state_payload(unit_id: String, side: String, casualties: float, victor: String, logistics_context: Dictionary) -> Dictionary:
    var unit_entry: Dictionary = _units_by_id.get(unit_id, {})
    var formation_id: String = get_unit_formation(unit_id)
    var formation: Dictionary = _formations_by_id.get(formation_id, {})
    var pillar_profile: Dictionary = _unit_pillar_profile(unit_entry, formation)
    var status: Dictionary = _determine_unit_status(side, victor, casualties, logistics_context)

    return {
        "unit_id": unit_id,
        "name": str(unit_entry.get("name", unit_id.capitalize())),
        "side": side,
        "formation_id": formation_id,
        "formation_name": str(formation.get("name", formation_id)),
        "status": status.get("label", "steady"),
        "casualties": casualties,
        "strength_remaining": snapped(clamp(1.0 - casualties, 0.0, 1.0), 0.01),
        "notes": status.get("notes", ""),
        "pillar_profile": pillar_profile,
    }

func _determine_unit_status(side: String, victor: String, casualties: float, logistics_context: Dictionary) -> Dictionary:
    var status: String = "steady"
    var notes: Array = []

    if victor == side:
        if casualties <= 0.08:
            status = "pressing"
        elif casualties <= 0.18:
            status = "steady"
        else:
            status = "exhausted"
    elif victor == "stalemate":
        status = "contested" if casualties >= 0.2 else "steady"
    elif victor == "contested":
        status = "locked"
    else:
        if casualties >= 0.45:
            status = "routed"
        elif casualties >= 0.25:
            status = "shaken"
        else:
            status = "holding"

    var severity: String = str(logistics_context.get("severity", ""))
    if side == "attacker":
        match severity:
            "warning":
                notes.append("Supply warning at target hex.")
            "critical":
                notes.append("Critical supply deficit on approach.")

    var factor_key: String = "attacker_factor" if side == "attacker" else "defender_factor"
    var logistics_factor: float = float(logistics_context.get(factor_key, 1.0))
    if logistics_factor < 0.9:
        notes.append("Logistics factor %.2f" % logistics_factor)
    elif logistics_factor > 1.1:
        notes.append("Logistics surge %.2f" % logistics_factor)

    return {
        "label": status,
        "notes": ", ".join(notes) if not notes.is_empty() else "",
    }

func _unit_pillar_profile(unit_entry: Dictionary, formation: Dictionary) -> Dictionary:
    var profile: Dictionary = {}
    var base_profile: Dictionary = unit_entry.get("combat_profile", {})
    if base_profile is Dictionary:
        for key in base_profile.keys():
            profile[key] = float(base_profile.get(key, 0.0))

    var modifiers: Dictionary = formation.get("pillar_modifiers", {})
    if modifiers is Dictionary:
        for key in modifiers.keys():
            profile[key] = float(profile.get(key, 0.0)) + float(modifiers.get(key, 0.0))

    return profile
