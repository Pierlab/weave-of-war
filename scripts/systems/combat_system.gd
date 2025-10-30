extends Node
class_name CombatSystem

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

var event_bus: EventBus
var data_loader: DataLoader

var _orders_by_id: Dictionary = {}
var _units_by_id: Dictionary = {}
var _doctrines_by_id: Dictionary = {}
var _weather_by_id: Dictionary = {}
var _current_doctrine_id := ""
var _current_weather_id := ""
var _last_resolution: Dictionary = {}
var _recent_intel: Dictionary = {}
var _default_intel_confidence := 0.5
var _rng := RandomNumberGenerator.new()

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
            data_loader.list_weather_states()
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
        if not event_bus.assistant_order_packet.is_connected(_on_assistant_packet):
            event_bus.assistant_order_packet.connect(_on_assistant_packet)

func configure(unit_entries: Array, order_entries: Array, doctrine_entries: Array, weather_entries: Array) -> void:
    _units_by_id = _index_entries(unit_entries)
    _orders_by_id = _index_entries(order_entries)
    _doctrines_by_id = _index_entries(doctrine_entries)
    _weather_by_id = _index_entries(weather_entries)

    if _current_doctrine_id.is_empty() and not _doctrines_by_id.is_empty():
        _current_doctrine_id = str(_doctrines_by_id.keys()[0])
    elif not _doctrines_by_id.has(_current_doctrine_id) and not _doctrines_by_id.is_empty():
        _current_doctrine_id = str(_doctrines_by_id.keys()[0])

    if _current_weather_id.is_empty() and not _weather_by_id.is_empty():
        _current_weather_id = str(_weather_by_id.keys()[0])
    elif not _weather_by_id.has(_current_weather_id) and not _weather_by_id.is_empty():
        _current_weather_id = str(_weather_by_id.keys()[0])

    _recalculate_doctrine_confidence()

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

func get_last_resolution() -> Dictionary:
    return _last_resolution.duplicate(true)

func resolve_engagement(engagement: Dictionary) -> Dictionary:
    if engagement.is_empty():
        return {}

    var order_id := str(engagement.get("order_id", ""))
    var order_entry: Dictionary = _orders_by_id.get(order_id, {})

    var attacker_unit_ids := _normalise_id_array(engagement.get("attacker_unit_ids", []))
    var defender_unit_ids := _normalise_id_array(engagement.get("defender_unit_ids", []))
    var terrain_id := str(engagement.get("terrain", "plains"))
    var defender_posture := str(engagement.get("defender_posture", "hold"))
    if defender_posture.is_empty() or not DEFENDER_POSTURES.has(defender_posture):
        defender_posture = "hold"

    var weather_id := str(engagement.get("weather_id", _current_weather_id))
    if weather_id.is_empty():
        weather_id = _current_weather_id
    var weather_config: Dictionary = _weather_by_id.get(weather_id, {})
    var weather_modifiers: Dictionary = weather_config.get("combat_modifiers", {})

    var intel_confidence := _resolve_intel_confidence(engagement)
    var espionage_bonus := float(engagement.get("espionage_bonus", 0.0))
    var attacker_bonuses: Dictionary = engagement.get("attacker_bonus", {})
    var defender_bonuses: Dictionary = engagement.get("defender_bonus", {})

    var doctrine_effects := _doctrines_by_id.get(_current_doctrine_id, {}).get("effects", {})
    var doctrine_bonus: Dictionary = doctrine_effects.get("combat_bonus", {})

    var attacker_base := _aggregate_unit_profile(attacker_unit_ids, "combat_profile")
    var defender_base := _aggregate_unit_profile(defender_unit_ids, "combat_profile")
    var attacker_detection := _aggregate_unit_value(attacker_unit_ids, "recon_profile", "detection")
    var defender_counter := _aggregate_unit_value(defender_unit_ids, "recon_profile", "counter_intel")

    var results := {}
    var attacker_wins := 0
    var defender_wins := 0
    var terrain_profile := _terrain_profile(terrain_id)
    var posture_bonus: Dictionary = DEFENDER_POSTURES.get(defender_posture, DEFENDER_POSTURES.get("hold"))
    var order_weights: Dictionary = order_entry.get("pillar_weights", {})
    var intel_profile: Dictionary = order_entry.get("intel_profile", {})

    for pillar in PILLARS:
        var attacker_strength := float(attacker_base.get(pillar, 0.0))
        attacker_strength += float(order_weights.get(pillar, 0.0))
        attacker_strength += float(doctrine_bonus.get(pillar, 0.0))
        attacker_strength += float(attacker_bonuses.get(pillar, 0.0))
        attacker_strength = max(attacker_strength, 0.0)

        var defender_strength := float(defender_base.get(pillar, 0.0))
        defender_strength += float(posture_bonus.get(pillar, 0.0))
        defender_strength += float(defender_bonuses.get(pillar, 0.0))
        defender_strength = max(defender_strength, 0.0)

        var terrain_factor := float(terrain_profile.get(pillar, 1.0))
        var weather_factor := float(weather_modifiers.get(pillar, 1.0))

        if pillar == "information":
            var intel_multiplier := clamp(intel_confidence + espionage_bonus + attacker_detection, 0.1, 1.75)
            var counter_multiplier := clamp(1.0 + defender_counter + float(intel_profile.get("counter_intel", 0.0)), 0.1, 2.0)
            attacker_strength *= intel_multiplier
            defender_strength *= counter_multiplier
        elif pillar == "impulse":
            var momentum := clamp(intel_confidence + float(order_weights.get("impulse", 0.0)), 0.5, 2.0)
            attacker_strength *= momentum
            defender_strength *= clamp(1.0 + float(posture_bonus.get("impulse", 0.0)) - espionage_bonus, 0.4, 2.0)

        attacker_strength *= terrain_factor * weather_factor
        defender_strength *= terrain_factor * weather_factor

        var jitter := _rng.randf_range(-0.05, 0.05)
        attacker_strength = max(attacker_strength + jitter, 0.0)
        defender_strength = max(defender_strength - jitter, 0.0)

        var margin := snapped(attacker_strength - defender_strength, 0.01)
        var pillar_winner := "stalemate"
        if margin > 0.05:
            pillar_winner = "attacker"
            attacker_wins += 1
        elif margin < -0.05:
            pillar_winner = "defender"
            defender_wins += 1

        results[pillar] = {
            "attacker": snapped(attacker_strength, 0.01),
            "defender": snapped(defender_strength, 0.01),
            "margin": margin,
            "winner": pillar_winner,
        }

    var victor := "stalemate"
    if attacker_wins >= 2:
        victor = "attacker"
    elif defender_wins >= 2:
        victor = "defender"
    elif attacker_wins == defender_wins and attacker_wins == 1:
        victor = "contested"

    var target_hex := str(engagement.get("target", engagement.get("target_hex", "")))
    var intel_source := _recent_intel.get(target_hex, {}).get("source", "baseline") if _recent_intel.has(target_hex) else "baseline"
    var payload := {
        "engagement_id": engagement.get("engagement_id", order_id if order_id != "" else "skirmish"),
        "order_id": order_id,
        "terrain": terrain_id,
        "weather_id": weather_id,
        "doctrine_id": _current_doctrine_id,
        "pillars": results,
        "victor": victor,
        "intel": {
            "confidence": snapped(clamp(intel_confidence + espionage_bonus, 0.0, 1.0), 0.01),
            "source": intel_source,
        },
        "reason": engagement.get("reason", "resolution"),
    }

    _last_resolution = payload.duplicate(true)

    if event_bus:
        event_bus.emit_combat_resolved(_last_resolution)

    return _last_resolution

func _index_entries(entries: Array) -> Dictionary:
    var map := {}
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

func _aggregate_unit_profile(unit_ids: Array, field: String) -> Dictionary:
    var totals := {}
    for unit_id in unit_ids:
        var unit: Dictionary = _units_by_id.get(unit_id, {})
        var profile := unit.get(field, {})
        if profile is Dictionary:
            for key in profile.keys():
                totals[key] = float(totals.get(key, 0.0)) + float(profile.get(key, 0.0))
    return totals

func _aggregate_unit_value(unit_ids: Array, field: String, key: String) -> float:
    var total := 0.0
    for unit_id in unit_ids:
        var unit: Dictionary = _units_by_id.get(unit_id, {})
        var profile := unit.get(field, {})
        if profile is Dictionary:
            total += float(profile.get(key, 0.0))
    return total

func _terrain_profile(terrain_id: String) -> Dictionary:
    if TERRAIN_PROFILES.has(terrain_id):
        return TERRAIN_PROFILES.get(terrain_id, {})
    return TERRAIN_PROFILES.get("plains", {})

func _resolve_intel_confidence(engagement: Dictionary) -> float:
    var confidence := float(engagement.get("intel_confidence", _default_intel_confidence))
    var target := str(engagement.get("target", engagement.get("target_hex", "")))
    if _recent_intel.has(target):
        var intel: Dictionary = _recent_intel.get(target, {})
        confidence = max(confidence, float(intel.get("confidence", confidence)))
    return clamp(confidence, 0.0, 1.0)

func _recalculate_doctrine_confidence() -> void:
    var doctrine := _doctrines_by_id.get(_current_doctrine_id, {})
    var effects := doctrine.get("effects", {})
    var modifier := float(effects.get("intel_visibility_modifier", 0.0))
    _default_intel_confidence = clamp(0.5 + modifier, 0.1, 0.9)

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    configure(
        collections.get("units", []),
        collections.get("orders", []),
        collections.get("doctrines", []),
        collections.get("weather", [])
    )

func _on_doctrine_selected(payload: Dictionary) -> void:
    var doctrine_id := str(payload.get("id", ""))
    if doctrine_id != "":
        _current_doctrine_id = doctrine_id
        _recalculate_doctrine_confidence()

func _on_weather_changed(payload: Dictionary) -> void:
    var weather_id := str(payload.get("weather_id", ""))
    if weather_id != "":
        _current_weather_id = weather_id

func _on_espionage_ping(payload: Dictionary) -> void:
    var target := str(payload.get("target", ""))
    if target == "":
        return
    _recent_intel[target] = payload.duplicate(true)

func _on_assistant_order_packet(packet: Dictionary) -> void:
    var engagements: Array = packet.get("expected_engagements", [])
    for engagement in engagements:
        if engagement is Dictionary:
            resolve_engagement(engagement)
