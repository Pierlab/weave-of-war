class_name DataLoaderAutoload
extends Node

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")

const DATA_FILES := {
    "doctrines": "res://data/doctrines.json",
    "orders": "res://data/orders.json",
    "units": "res://data/units.json",
    "weather": "res://data/weather.json",
    "logistics": "res://data/logistics.json",
    "formations": "res://data/formations.json",
}

const COMBAT_PILLARS := ["position", "impulse", "information"]
const ORDER_INTENTIONS := ["offense", "defense", "deception", "support"]
const ORDER_TARGET_SCOPES := ["frontline", "flank", "rear", "logistics", "global", "support"]
const ORDER_RISK_LEVELS := ["low", "moderate", "high", "critical"]
const LOGISTICS_ROUTE_TYPES := ["ring", "road", "convoy", "river", "airlift"]
const SUPPLY_STATES := ["stable", "flexible", "surged", "strained"]
const CONVOY_USAGE := ["optional", "required", "forbidden"]
const FORMATION_POSTURES := ["defensive", "aggressive", "balanced", "fluid", "recon", "ranged", "support"]

static var _instance: DataLoaderAutoload

var _collections: Dictionary = {}
var _indexed: Dictionary = {}
var _is_ready: bool = false

func _ready() -> void:
    _instance = self
    var result: Dictionary = load_all()
    call_deferred("_notify_event_bus", result)

static func get_instance() -> DataLoaderAutoload:
    return _instance

func is_ready() -> bool:
    return _is_ready

func load_all(emit_signals := false) -> Dictionary:
    var errors: Array = []
    _collections.clear()
    _indexed.clear()

    for key in DATA_FILES.keys():
        var path: String = DATA_FILES[key]
        var load_result: Dictionary = _load_json_array(path, key)
        if load_result.success:
            _collections[key] = load_result.data
            _indexed[key] = _index_by_id(load_result.data, key)
        else:
            errors.append(load_result.error)
            _collections[key] = []
            _indexed[key] = {}

    if errors.is_empty():
        var cross_errors: Array = _validate_cross_references()
        if not cross_errors.is_empty():
            errors += cross_errors

    _is_ready = errors.is_empty()

    var summary: Dictionary = {
        "collections": _collections.duplicate(true),
        "errors": errors,
        "ready": _is_ready,
    }

    if emit_signals:
        _notify_event_bus(summary)

    return summary

func list_doctrines() -> Array:
    return _collections.get("doctrines", [])

func get_doctrine(id: String) -> Dictionary:
    return _indexed.get("doctrines", {}).get(id, {})

func list_orders() -> Array:
    return _collections.get("orders", [])

func get_order(id: String) -> Dictionary:
    return _indexed.get("orders", {}).get(id, {})

func list_units() -> Array:
    return _collections.get("units", [])

func get_unit(id: String) -> Dictionary:
    return _indexed.get("units", {}).get(id, {})

func list_weather_states() -> Array:
    return _collections.get("weather", [])

func get_weather(id: String) -> Dictionary:
    return _indexed.get("weather", {}).get(id, {})

func list_logistics_states() -> Array:
    return _collections.get("logistics", [])

func get_logistics(id: String) -> Dictionary:
    return _indexed.get("logistics", {}).get(id, {})

func list_formations() -> Array:
    return _collections.get("formations", [])

func get_formation(id: String) -> Dictionary:
    return _indexed.get("formations", {}).get(id, {})

func get_summary() -> Dictionary:
    return {
        "ready": _is_ready,
        "counts": {
            "doctrines": list_doctrines().size(),
            "orders": list_orders().size(),
            "units": list_units().size(),
            "weather": list_weather_states().size(),
            "logistics": list_logistics_states().size(),
            "formations": list_formations().size(),
        }
    }

func _notify_event_bus(result: Dictionary) -> void:
    var event_bus: EventBusAutoload = EVENT_BUS.get_instance()
    if event_bus == null:
        return

    if result.get("errors", []).is_empty():
        var collections: Dictionary = result.get("collections", {})
        var counts: Dictionary = {}
        for key in collections.keys():
            var value: Variant = collections.get(key)
            if value is Array:
                counts[key] = value.size()
            else:
                counts[key] = 0

        event_bus.emit_data_loader_ready({
            "counts": counts,
            "collections": collections,
        })
        var counts_json := JSON.stringify(counts)
        print("[Autoload] DataLoaderAutoload ready → counts=%s" % counts_json)
    else:
        event_bus.emit_data_loader_error({
            "errors": result.get("errors"),
        })

func _load_json_array(path: String, label: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {
            "success": false,
            "error": {
                "label": label,
                "path": path,
                "reason": "missing_file",
            }
        }

    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {
            "success": false,
            "error": {
                "label": label,
                "path": path,
                "reason": "open_failed",
                "error_code": FileAccess.get_open_error(),
            }
        }

    var content: String = file.get_as_text()
    var parsed: Variant = JSON.parse_string(content)
    if parsed == null or typeof(parsed) != TYPE_ARRAY:
        return {
            "success": false,
            "error": {
                "label": label,
                "path": path,
                "reason": "invalid_json",
            }
        }

    var schema_errors := DataLoaderAutoload.validate_collection(label, parsed)
    if not schema_errors.is_empty():
        return {
            "success": false,
            "error": {
                "label": label,
                "path": path,
                "reason": "schema_validation_failed",
                "issues": schema_errors,
            }
        }

    return {
        "success": true,
        "data": parsed,
    }

func _index_by_id(entries: Array, label: String) -> Dictionary:
    var indexed: Dictionary = {}
    for entry in entries:
        if entry is Dictionary and entry.has("id"):
            indexed[entry.get("id")] = entry
        else:
            push_warning("%s entry missing id field" % label)
    return indexed

static func validate_collection(label: String, entries: Array) -> Array:
    if typeof(entries) != TYPE_ARRAY:
        return [_error(label, label, "invalid_collection_type", "Collection must be an array")]

    var errors: Array = []
    for index in entries.size():
        var entry := entries[index]
        var context := _entry_context(label, entry, index)
        if typeof(entry) != TYPE_DICTIONARY:
            errors.append(_error(label, context, "invalid_type", "Entry must be a dictionary"))
            continue

        errors += _validate_entry(label, entry, context)

    return errors

static func _validate_entry(label: String, entry: Dictionary, context: String) -> Array:
    match label:
        "doctrines":
            return _validate_doctrine(entry, context)
        "orders":
            return _validate_order(entry, context)
        "units":
            return _validate_unit(entry, context)
        "weather":
            return _validate_weather(entry, context)
        "logistics":
            return _validate_logistics(entry, context)
        "formations":
            return _validate_formation(entry, context)
        _:
            return []

static func _validate_doctrine(entry: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("doctrines", entry, [
        "id",
        "name",
        "description",
        "tags",
        "inertia_lock_turns",
        "elan_upkeep",
        "elan_spend_modifiers",
        "logistics_requirements",
        "effects",
        "command_profile",
    ], context)
    errors += _ensure_strings("doctrines", entry, ["id", "name", "description"], context)
    errors += _ensure_array_of_strings("doctrines", entry, "tags", context)
    errors += _ensure_integerish("doctrines", entry, ["inertia_lock_turns", "elan_upkeep"], context)
    errors += _ensure_dictionaries("doctrines", entry, ["elan_spend_modifiers", "logistics_requirements", "effects", "command_profile"], context)

    if entry.has("elan_spend_modifiers") and entry.get("elan_spend_modifiers") is Dictionary:
        errors += _ensure_numeric_dictionary("doctrines", entry.get("elan_spend_modifiers"), context + ".elan_spend_modifiers")
    if entry.has("logistics_requirements") and entry.get("logistics_requirements") is Dictionary:
        errors += _validate_doctrine_logistics(entry.get("logistics_requirements"), context + ".logistics_requirements")
    if entry.has("effects") and entry.get("effects") is Dictionary:
        errors += _validate_doctrine_effects(entry.get("effects"), context + ".effects")
    if entry.has("command_profile") and entry.get("command_profile") is Dictionary:
        errors += _validate_doctrine_command_profile(entry.get("command_profile"), context + ".command_profile")

    return errors

static func _validate_doctrine_effects(effects: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("doctrines", effects, ["combat_pillar_focus", "combat_bonus"], context)
    if effects.has("combat_pillar_focus"):
        var focus := effects.get("combat_pillar_focus")
        if typeof(focus) != TYPE_STRING:
            errors.append(_error("doctrines", context + ".combat_pillar_focus", "invalid_type", "string"))
        elif not COMBAT_PILLARS.has(focus):
            errors.append(_error("doctrines", context + ".combat_pillar_focus", "invalid_enum", String(focus)))
    if effects.has("combat_bonus"):
        var bonus := effects.get("combat_bonus")
        if typeof(bonus) != TYPE_DICTIONARY:
            errors.append(_error("doctrines", context + ".combat_bonus", "invalid_type", "dictionary"))
        else:
            for pillar in COMBAT_PILLARS:
                if not bonus.has(pillar):
                    errors.append(_error("doctrines", context + ".combat_bonus", "missing_key", pillar))
                else:
                    errors += _ensure_numeric_value("doctrines", bonus.get(pillar), context + ".combat_bonus." + pillar)
    return errors

static func _validate_doctrine_command_profile(profile: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("doctrines", profile, [
        "cp_cap_delta",
        "swap_token_budget",
        "inertia_multiplier",
        "allowed_order_tags",
        "elan_cap_bonus",
    ], context)
    errors += _ensure_integerish("doctrines", profile, ["cp_cap_delta", "swap_token_budget"], context)
    if profile.has("swap_token_budget"):
        var tokens := profile.get("swap_token_budget")
        if typeof(tokens) in [TYPE_INT, TYPE_FLOAT] and int(tokens) < 0:
            errors.append(_error("doctrines", context + ".swap_token_budget", "invalid_range", "value_must_be_non_negative"))
    if profile.has("inertia_multiplier"):
        errors += _ensure_numeric_value("doctrines", profile.get("inertia_multiplier"), context + ".inertia_multiplier")
    if profile.has("elan_cap_bonus"):
        errors += _ensure_numeric_value("doctrines", profile.get("elan_cap_bonus"), context + ".elan_cap_bonus")
    errors += _ensure_array_of_strings("doctrines", profile, "allowed_order_tags", context)
    return errors

static func _validate_doctrine_logistics(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("doctrines", data, ["minimum_supply_state", "supply_ring_bonus"], context)
    if data.has("minimum_supply_state"):
        var state := data.get("minimum_supply_state")
        if typeof(state) != TYPE_STRING:
            errors.append(_error("doctrines", context + ".minimum_supply_state", "invalid_type", "string"))
        elif not SUPPLY_STATES.has(state):
            errors.append(_error("doctrines", context + ".minimum_supply_state", "invalid_enum", state))
    if data.has("supply_ring_bonus"):
        var bonus := data.get("supply_ring_bonus")
        if typeof(bonus) == TYPE_INT:
            pass
        elif typeof(bonus) == TYPE_FLOAT and is_equal_approx(bonus, round(bonus)):
            pass
        else:
            errors.append(_error("doctrines", context + ".supply_ring_bonus", "invalid_type", "integer"))
    return errors

static func _validate_order(entry: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", entry, [
        "id",
        "name",
        "tags",
        "description",
        "cp_cost",
        "base_elan_cost",
        "inertia_impact",
        "base_delay_turns",
        "allowed_doctrines",
        "doctrine_requirements",
        "logistics_demand",
        "inertia_profile",
        "targeting",
        "posture_requirements",
        "resolution_effects",
        "intention",
        "pillar_weights",
        "intel_profile",
        "assistant_metadata",
    ], context)
    errors += _ensure_strings("orders", entry, ["id", "name", "description", "intention"], context)
    errors += _ensure_integerish("orders", entry, ["cp_cost", "base_elan_cost", "inertia_impact", "base_delay_turns"], context)
    errors += _ensure_array_of_strings("orders", entry, "tags", context)
    errors += _ensure_array_of_strings("orders", entry, "allowed_doctrines", context)
    errors += _ensure_dictionaries("orders", entry, [
        "doctrine_requirements",
        "logistics_demand",
        "inertia_profile",
        "targeting",
        "posture_requirements",
        "resolution_effects",
        "pillar_weights",
        "intel_profile",
        "assistant_metadata",
    ], context)

    if entry.has("intention"):
        var intention := entry.get("intention")
        if typeof(intention) == TYPE_STRING and not ORDER_INTENTIONS.has(intention):
            errors.append(_error("orders", context + ".intention", "invalid_enum", intention))

    if entry.has("doctrine_requirements") and entry.get("doctrine_requirements") is Dictionary:
        errors += _validate_order_doctrine_requirements(entry.get("doctrine_requirements"), context + ".doctrine_requirements")
    if entry.has("logistics_demand") and entry.get("logistics_demand") is Dictionary:
        errors += _validate_order_logistics(entry.get("logistics_demand"), context + ".logistics_demand")
    if entry.has("inertia_profile") and entry.get("inertia_profile") is Dictionary:
        errors += _validate_order_inertia_profile(entry.get("inertia_profile"), context + ".inertia_profile")
    if entry.has("targeting") and entry.get("targeting") is Dictionary:
        errors += _validate_order_targeting(entry.get("targeting"), context + ".targeting")
    if entry.has("posture_requirements") and entry.get("posture_requirements") is Dictionary:
        errors += _validate_order_posture_requirements(entry.get("posture_requirements"), context + ".posture_requirements")
    if entry.has("resolution_effects") and entry.get("resolution_effects") is Dictionary:
        errors += _validate_order_resolution(entry.get("resolution_effects"), context + ".resolution_effects")
    if entry.has("pillar_weights") and entry.get("pillar_weights") is Dictionary:
        errors += _validate_pillar_distribution("orders", entry.get("pillar_weights"), context + ".pillar_weights")
    if entry.has("intel_profile") and entry.get("intel_profile") is Dictionary:
        errors += _validate_intel_profile(entry.get("intel_profile"), context + ".intel_profile")
    if entry.has("assistant_metadata") and entry.get("assistant_metadata") is Dictionary:
        errors += _validate_assistant_metadata(entry.get("assistant_metadata"), context + ".assistant_metadata")

    return errors

static func _validate_order_doctrine_requirements(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["required_tags", "minimum_swap_tokens", "command_profile"], context)
    errors += _ensure_array_of_strings("orders", data, "required_tags", context)
    errors += _ensure_integerish("orders", data, ["minimum_swap_tokens"], context)
    if data.has("minimum_swap_tokens"):
        var tokens := data.get("minimum_swap_tokens")
        if typeof(tokens) in [TYPE_INT, TYPE_FLOAT]:
            if float(tokens) < 0.0:
                errors.append(_error("orders", context + ".minimum_swap_tokens", "invalid_range", "value_must_be_non_negative"))
    if data.has("command_profile") and typeof(data.get("command_profile")) != TYPE_STRING:
        errors.append(_error("orders", context + ".command_profile", "invalid_type", "string"))
    return errors

static func _validate_order_logistics(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["minimum_supply_state", "convoy_usage"], context)
    if data.has("minimum_supply_state"):
        var state := data.get("minimum_supply_state")
        if typeof(state) != TYPE_STRING:
            errors.append(_error("orders", context + ".minimum_supply_state", "invalid_type", "string"))
        elif not SUPPLY_STATES.has(state):
            errors.append(_error("orders", context + ".minimum_supply_state", "invalid_enum", state))
    if data.has("convoy_usage"):
        var usage := data.get("convoy_usage")
        if typeof(usage) != TYPE_STRING:
            errors.append(_error("orders", context + ".convoy_usage", "invalid_type", "string"))
        elif not CONVOY_USAGE.has(usage):
            errors.append(_error("orders", context + ".convoy_usage", "invalid_enum", usage))
    return errors

static func _validate_order_inertia_profile(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["doctrine_multipliers", "logistics_state_multipliers", "competence_offsets"], context)
    errors += _ensure_dictionaries("orders", data, ["doctrine_multipliers", "logistics_state_multipliers", "competence_offsets"], context)
    if data.has("doctrine_multipliers") and data.get("doctrine_multipliers") is Dictionary:
        errors += _ensure_numeric_dictionary("orders", data.get("doctrine_multipliers"), context + ".doctrine_multipliers")
    if data.has("logistics_state_multipliers") and data.get("logistics_state_multipliers") is Dictionary:
        var multipliers: Dictionary = data.get("logistics_state_multipliers")
        errors += _ensure_numeric_dictionary("orders", multipliers, context + ".logistics_state_multipliers")
        for state in multipliers.keys():
            if typeof(state) == TYPE_STRING and not SUPPLY_STATES.has(state):
                errors.append(_error("orders", context + ".logistics_state_multipliers", "invalid_enum", String(state)))
    if data.has("competence_offsets") and data.get("competence_offsets") is Dictionary:
        errors += _ensure_numeric_dictionary("orders", data.get("competence_offsets"), context + ".competence_offsets")
    return errors

static func _validate_order_targeting(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["scope", "requires_line_of_sight", "preferred_unit_classes", "allowed_postures", "max_concurrent"], context)
    if data.has("scope"):
        var scope := data.get("scope")
        if typeof(scope) != TYPE_STRING:
            errors.append(_error("orders", context + ".scope", "invalid_type", "string"))
        elif not ORDER_TARGET_SCOPES.has(scope):
            errors.append(_error("orders", context + ".scope", "invalid_enum", scope))
    if data.has("requires_line_of_sight"):
        errors += _ensure_boolean("orders", data, "requires_line_of_sight", context)
    errors += _ensure_array_of_strings("orders", data, "preferred_unit_classes", context)
    errors += _ensure_array_of_strings("orders", data, "allowed_postures", context)
    if data.has("allowed_postures") and data.get("allowed_postures") is Array:
        for posture in data.get("allowed_postures"):
            if typeof(posture) == TYPE_STRING and not FORMATION_POSTURES.has(posture):
                errors.append(_error("orders", context + ".allowed_postures", "invalid_enum", posture))
    errors += _ensure_integerish("orders", data, ["max_concurrent"], context)
    if data.has("max_concurrent"):
        var concurrent := data.get("max_concurrent")
        if typeof(concurrent) in [TYPE_INT, TYPE_FLOAT] and int(concurrent) < 1:
            errors.append(_error("orders", context + ".max_concurrent", "invalid_range", "value_must_be_positive"))
    return errors

static func _validate_order_posture_requirements(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["required_postures", "incompatible_postures"], context)
    errors += _ensure_array_of_strings("orders", data, "required_postures", context)
    errors += _ensure_array_of_strings("orders", data, "incompatible_postures", context)
    for key in ["required_postures", "incompatible_postures"]:
        if data.has(key) and data.get(key) is Array:
            for posture in data.get(key):
                if typeof(posture) == TYPE_STRING and not FORMATION_POSTURES.has(posture):
                    errors.append(_error("orders", context + "." + key, "invalid_enum", posture))
    return errors

static func _validate_assistant_metadata(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["intent_profile", "risk_level", "recommended_followups", "telemetry_tags"], context)
    errors += _ensure_dictionaries("orders", data, ["intent_profile"], context)
    if data.has("intent_profile") and data.get("intent_profile") is Dictionary:
        errors += _ensure_numeric_dictionary("orders", data.get("intent_profile"), context + ".intent_profile")
    if data.has("risk_level"):
        var risk := data.get("risk_level")
        if typeof(risk) != TYPE_STRING:
            errors.append(_error("orders", context + ".risk_level", "invalid_type", "string"))
        elif not ORDER_RISK_LEVELS.has(risk):
            errors.append(_error("orders", context + ".risk_level", "invalid_enum", risk))
    errors += _ensure_array_of_strings("orders", data, "recommended_followups", context)
    errors += _ensure_array_of_strings("orders", data, "telemetry_tags", context)
    return errors

static func _validate_order_resolution(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["position_bias", "intel_reveal"], context)
    if data.has("position_bias"):
        errors += _ensure_numeric_value("orders", data.get("position_bias"), context + ".position_bias")
    if data.has("intel_reveal"):
        var reveal := data.get("intel_reveal")
        if typeof(reveal) != TYPE_STRING:
            errors.append(_error("orders", context + ".intel_reveal", "invalid_type", "string"))
    return errors

static func _validate_pillar_distribution(label: String, data: Dictionary, context: String) -> Array:
    var errors: Array = []
    for pillar in COMBAT_PILLARS:
        if not data.has(pillar):
            errors.append(_error(label, context, "missing_key", pillar))
        else:
            errors += _ensure_numeric_value(label, data.get(pillar), context + "." + pillar)
    return errors

static func _validate_intel_profile(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("orders", data, ["signal_strength", "counter_intel"], context)
    if data.has("signal_strength"):
        errors += _ensure_numeric_value("orders", data.get("signal_strength"), context + ".signal_strength")
    if data.has("counter_intel"):
        errors += _ensure_numeric_value("orders", data.get("counter_intel"), context + ".counter_intel")
    return errors

static func _validate_recon_profile(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("units", data, ["detection", "counter_intel"], context)
    if data.has("detection"):
        errors += _ensure_numeric_value("units", data.get("detection"), context + ".detection")
    if data.has("counter_intel"):
        errors += _ensure_numeric_value("units", data.get("counter_intel"), context + ".counter_intel")
    return errors

static func _validate_unit(entry: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("units", entry, [
        "id",
        "name",
        "role",
        "unit_class",
        "competence_synergy",
        "elan_generation",
        "logistics_load",
        "default_formations",
        "combat_profile",
        "recon_profile",
    ], context)
    errors += _ensure_strings("units", entry, ["id", "name", "role", "unit_class"], context)
    errors += _ensure_dictionaries("units", entry, ["competence_synergy", "elan_generation", "logistics_load", "combat_profile", "recon_profile"], context)
    errors += _ensure_array_of_strings("units", entry, "default_formations", context)

    if entry.has("competence_synergy") and entry.get("competence_synergy") is Dictionary:
        errors += _ensure_numeric_dictionary("units", entry.get("competence_synergy"), context + ".competence_synergy")
    if entry.has("elan_generation") and entry.get("elan_generation") is Dictionary:
        errors += _ensure_numeric_dictionary("units", entry.get("elan_generation"), context + ".elan_generation")
    if entry.has("logistics_load") and entry.get("logistics_load") is Dictionary:
        errors += _validate_unit_logistics(entry.get("logistics_load"), context + ".logistics_load")
    if entry.has("combat_profile") and entry.get("combat_profile") is Dictionary:
        errors += _validate_pillar_distribution("units", entry.get("combat_profile"), context + ".combat_profile")
    if entry.has("recon_profile") and entry.get("recon_profile") is Dictionary:
        errors += _validate_recon_profile(entry.get("recon_profile"), context + ".recon_profile")

    return errors

static func _validate_unit_logistics(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("units", data, ["supply_consumption", "movement_profile"], context)
    if data.has("supply_consumption"):
        errors += _ensure_numeric_value("units", data.get("supply_consumption"), context + ".supply_consumption")
    if data.has("movement_profile") and typeof(data.get("movement_profile")) != TYPE_STRING:
        errors.append(_error("units", context + ".movement_profile", "invalid_type", "string"))
    return errors

static func _validate_weather(entry: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("weather", entry, [
        "id",
        "name",
        "effects",
        "movement_modifier",
        "logistics_flow_modifier",
        "intel_noise",
        "duration_turns",
        "elan_regeneration_bonus",
        "combat_modifiers",
    ], context)
    errors += _ensure_strings("weather", entry, ["id", "name", "effects"], context)
    errors += _ensure_numeric("weather", entry, ["movement_modifier", "logistics_flow_modifier", "intel_noise", "elan_regeneration_bonus"], context)
    if entry.has("duration_turns"):
        var duration := entry.get("duration_turns")
        if typeof(duration) != TYPE_ARRAY:
            errors.append(_error("weather", context + ".duration_turns", "invalid_type", "array"))
        elif duration.size() != 2:
            errors.append(_error("weather", context + ".duration_turns", "invalid_length", "Duration must include min and max"))
        else:
            for value in duration:
                if typeof(value) == TYPE_INT:
                    continue
                if typeof(value) == TYPE_FLOAT and is_equal_approx(value, round(value)):
                    continue
                errors.append(_error("weather", context + ".duration_turns", "invalid_type", "integer"))
    if entry.has("combat_modifiers") and entry.get("combat_modifiers") is Dictionary:
        errors += _validate_pillar_distribution("weather", entry.get("combat_modifiers"), context + ".combat_modifiers")
    return errors

static func _validate_logistics(entry: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("logistics", entry, [
        "id",
        "description",
        "supply_radius",
        "route_types",
        "convoy_spawn_threshold",
        "intercept_chance",
        "elan_penalty_on_break",
        "recovery_per_turn",
        "links",
        "map",
    ], context)
    errors += _ensure_strings("logistics", entry, ["id", "description"], context)
    errors += _ensure_integerish("logistics", entry, ["supply_radius", "convoy_spawn_threshold", "elan_penalty_on_break", "recovery_per_turn"], context)
    if entry.has("intercept_chance"):
        errors += _ensure_numeric_value("logistics", entry.get("intercept_chance"), context + ".intercept_chance")
    if entry.has("deficit_flow_threshold"):
        errors += _ensure_numeric_value("logistics", entry.get("deficit_flow_threshold"), context + ".deficit_flow_threshold")
    errors += _ensure_array_of_strings("logistics", entry, "route_types", context)
    errors += _ensure_dictionaries("logistics", entry, ["links", "map"], context)

    if entry.has("route_types"):
        for route in entry.get("route_types"):
            if typeof(route) == TYPE_STRING and not LOGISTICS_ROUTE_TYPES.has(route):
                errors.append(_error("logistics", context + ".route_types", "invalid_enum", route))

    if entry.has("links") and entry.get("links") is Dictionary:
        errors += _validate_logistics_links(entry.get("links"), context + ".links")
    if entry.has("map") and entry.get("map") is Dictionary:
        errors += _validate_logistics_map(entry.get("map"), context + ".map")
    return errors

static func _validate_logistics_links(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("logistics", data, ["doctrine_synergy", "weather_modifiers"], context)
    if data.has("doctrine_synergy"):
        errors += _ensure_array_of_strings("logistics", data, "doctrine_synergy", context)
    if data.has("weather_modifiers"):
        var modifiers := data.get("weather_modifiers")
        if typeof(modifiers) != TYPE_DICTIONARY:
            errors.append(_error("logistics", context + ".weather_modifiers", "invalid_type", "dictionary"))
        else:
            for weather_id in modifiers.keys():
                if typeof(weather_id) != TYPE_STRING:
                    errors.append(_error("logistics", context + ".weather_modifiers", "invalid_type", "string"))
                    continue
                errors += _ensure_numeric_value("logistics", modifiers.get(weather_id), context + ".weather_modifiers." + weather_id)
    return errors

static func _validate_logistics_map(data: Dictionary, context: String) -> Array:
    var errors: Array = []
    if data.has("columns") or data.has("rows"):
        errors += _ensure_integerish("logistics", data, ["columns", "rows"], context)

    if not data.has("supply_centers"):
        errors.append(_error("logistics", context, "missing_key", "supply_centers"))
    elif typeof(data.get("supply_centers")) != TYPE_ARRAY:
        errors.append(_error("logistics", context + ".supply_centers", "invalid_type", "array"))
    else:
        var centers: Array = data.get("supply_centers")
        if centers.is_empty():
            errors.append(_error("logistics", context + ".supply_centers", "missing_value", "at least one supply center"))
        for index in range(centers.size()):
            var entry := centers[index]
            if typeof(entry) != TYPE_DICTIONARY:
                errors.append(_error("logistics", "%s.supply_centers[%d]" % [context, index], "invalid_type", "dictionary"))
                continue
            var entry_context := "%s.supply_centers[%s]" % [context, entry.get("id", String(index))]
            if not entry.has("id"):
                errors.append(_error("logistics", entry_context, "missing_key", "id"))
            if not entry.has("type"):
                errors.append(_error("logistics", entry_context, "missing_key", "type"))
            if not entry.has("q") or not entry.has("r"):
                errors.append(_error("logistics", entry_context, "missing_key", "q/r"))
            errors += _ensure_strings("logistics", entry, ["id", "type"], entry_context)
            errors += _ensure_integerish("logistics", entry, ["q", "r"], entry_context)
            if str(entry.get("id", "")).is_empty():
                errors.append(_error("logistics", entry_context + ".id", "missing_value", "non-empty"))

    if not data.has("routes"):
        errors.append(_error("logistics", context, "missing_key", "routes"))
        return errors
    if typeof(data.get("routes")) != TYPE_ARRAY:
        errors.append(_error("logistics", context + ".routes", "invalid_type", "array"))
        return errors

    var routes: Array = data.get("routes")
    if routes.is_empty():
        errors.append(_error("logistics", context + ".routes", "missing_value", "at least one route"))
    for index in range(routes.size()):
        var route := routes[index]
        if typeof(route) != TYPE_DICTIONARY:
            errors.append(_error("logistics", "%s.routes[%d]" % [context, index], "invalid_type", "dictionary"))
            continue
        var route_context := "%s.routes[%s]" % [context, route.get("id", String(index))]
        if not route.has("id"):
            errors.append(_error("logistics", route_context, "missing_key", "id"))
        if not route.has("type"):
            errors.append(_error("logistics", route_context, "missing_key", "type"))
        errors += _ensure_strings("logistics", route, ["id", "type"], route_context)
        if route.has("type"):
            var route_type := route.get("type")
            if typeof(route_type) == TYPE_STRING and not LOGISTICS_ROUTE_TYPES.has(route_type):
                errors.append(_error("logistics", route_context + ".type", "invalid_enum", String(route_type)))
        if route.has("origin"):
            errors += _ensure_strings("logistics", route, ["origin"], route_context)
        if route.has("destination"):
            errors += _ensure_strings("logistics", route, ["destination"], route_context)
        if not route.has("path"):
            errors.append(_error("logistics", route_context, "missing_key", "path"))
            continue
        var path := route.get("path")
        if typeof(path) != TYPE_ARRAY:
            errors.append(_error("logistics", route_context + ".path", "invalid_type", "array"))
            continue
        if path.size() < 2:
            errors.append(_error("logistics", route_context + ".path", "missing_value", "at least two nodes"))
        for node_index in range(path.size()):
            var node := path[node_index]
            if typeof(node) != TYPE_DICTIONARY:
                errors.append(_error("logistics", "%s.path[%d]" % [route_context, node_index], "invalid_type", "dictionary"))
                continue
            var node_context := "%s.path[%d]" % [route_context, node_index]
            errors += _ensure_integerish("logistics", node, ["q", "r"], node_context)
    return errors

static func _validate_formation(entry: Dictionary, context: String) -> Array:
    var errors: Array = []
    errors += _require_keys("formations", entry, [
        "id",
        "name",
        "posture",
        "pillar_modifiers",
        "competence_weight",
    ], context)
    errors += _ensure_strings("formations", entry, ["id", "name", "posture"], context)
    if entry.has("posture"):
        var posture := entry.get("posture")
        if typeof(posture) == TYPE_STRING and not FORMATION_POSTURES.has(posture):
            errors.append(_error("formations", context + ".posture", "invalid_enum", posture))
    errors += _ensure_dictionaries("formations", entry, ["pillar_modifiers", "competence_weight"], context)

    if entry.has("pillar_modifiers") and entry.get("pillar_modifiers") is Dictionary:
        errors += _validate_pillar_distribution("formations", entry.get("pillar_modifiers"), context + ".pillar_modifiers")
    if entry.has("competence_weight") and entry.get("competence_weight") is Dictionary:
        errors += _ensure_numeric_dictionary("formations", entry.get("competence_weight"), context + ".competence_weight")

    return errors

func _validate_cross_references() -> Array:
    var errors: Array = []
    var formation_ids := _collect_ids(_collections.get("formations", []))
    var weather_ids := _collect_ids(_collections.get("weather", []))

    var units := _collections.get("units", [])
    for index in range(units.size()):
        var unit_entry := units[index]
        if unit_entry is Dictionary and unit_entry.has("default_formations"):
            var unit_context := _entry_context("units", unit_entry, index)
            for formation_id in unit_entry.get("default_formations"):
                if typeof(formation_id) == TYPE_STRING and not formation_ids.has(formation_id):
                    errors.append(_error("units", unit_context + ".default_formations", "unknown_reference", formation_id))

    var logistics := _collections.get("logistics", [])
    for index in range(logistics.size()):
        var logistics_entry := logistics[index]
        if logistics_entry is Dictionary and logistics_entry.has("links"):
            var log_context := _entry_context("logistics", logistics_entry, index)
            var links := logistics_entry.get("links")
            if typeof(links) == TYPE_DICTIONARY:
                if links.has("weather_modifiers") and links.get("weather_modifiers") is Dictionary:
                    for weather_id in links.get("weather_modifiers").keys():
                        if typeof(weather_id) == TYPE_STRING and not weather_ids.has(weather_id):
                            errors.append(_error("logistics", log_context + ".links.weather_modifiers", "unknown_reference", weather_id))

    return errors

static func _collect_ids(entries: Array) -> Array:
    var ids: Array = []
    for entry in entries:
        if entry is Dictionary and entry.has("id"):
            ids.append(entry.get("id"))
    return ids

static func _entry_context(label: String, entry: Variant, index: int) -> String:
    if entry is Dictionary and entry.has("id"):
        return "%s[%s]" % [label, entry.get("id")]
    return "%s[%d]" % [label, index]

static func _require_keys(label: String, entry: Dictionary, keys: Array, context: String) -> Array:
    var errors: Array = []
    for key in keys:
        if not entry.has(key):
            errors.append(_error(label, context, "missing_key", key))
    return errors

static func _ensure_strings(label: String, entry: Dictionary, keys: Array, context: String) -> Array:
    var errors: Array = []
    for key in keys:
        if entry.has(key) and typeof(entry.get(key)) != TYPE_STRING:
            errors.append(_error(label, context + "." + key, "invalid_type", "string"))
    return errors

static func _ensure_dictionaries(label: String, entry: Dictionary, keys: Array, context: String) -> Array:
    var errors: Array = []
    for key in keys:
        if entry.has(key) and typeof(entry.get(key)) != TYPE_DICTIONARY:
            errors.append(_error(label, context + "." + key, "invalid_type", "dictionary"))
    return errors

static func _ensure_array_of_strings(label: String, entry: Dictionary, key: String, context: String) -> Array:
    if not entry.has(key):
        return []
    var value := entry.get(key)
    if typeof(value) != TYPE_ARRAY:
        return [_error(label, context + "." + key, "invalid_type", "array")]
    var errors: Array = []
    for element in value:
        if typeof(element) != TYPE_STRING:
            errors.append(_error(label, context + "." + key, "invalid_type", "string"))
    return errors

static func _ensure_integerish(label: String, entry: Dictionary, keys: Array, context: String) -> Array:
    var errors: Array = []
    for key in keys:
        if not entry.has(key):
            continue
        var value := entry.get(key)
        if typeof(value) == TYPE_INT:
            continue
        if typeof(value) == TYPE_FLOAT and is_equal_approx(value, round(value)):
            continue
        errors.append(_error(label, context + "." + key, "invalid_type", "integer"))
    return errors

static func _ensure_boolean(label: String, entry: Dictionary, key: String, context: String) -> Array:
    if not entry.has(key):
        return []
    var value := entry.get(key)
    if typeof(value) != TYPE_BOOL:
        return [_error(label, context + "." + key, "invalid_type", "boolean")]
    return []

static func _ensure_numeric(label: String, entry: Dictionary, keys: Array, context: String) -> Array:
    var errors: Array = []
    for key in keys:
        if entry.has(key):
            errors += _ensure_numeric_value(label, entry.get(key), context + "." + key)
    return errors

static func _ensure_numeric_dictionary(label: String, data: Dictionary, context: String) -> Array:
    var errors: Array = []
    for key in data.keys():
        errors += _ensure_numeric_value(label, data.get(key), context + "." + String(key))
    return errors

static func _ensure_numeric_value(label: String, value: Variant, context: String) -> Array:
    var type := typeof(value)
    if type == TYPE_INT or type == TYPE_FLOAT:
        return []
    return [_error(label, context, "invalid_type", "number")]

static func _error(label: String, context: String, reason: String, detail: String = "") -> Dictionary:
    return {
        "label": label,
        "context": context,
        "reason": reason,
        "detail": detail,
    }
