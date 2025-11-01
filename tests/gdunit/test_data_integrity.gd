extends GdUnitLiteTestCase

const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

const COMBAT_PILLARS := ["position", "impulse", "information"]

func test_doctrines_json_schema() -> void:
    var doctrines := _load_json_array("res://data/doctrines.json", "doctrines")
    asserts.is_true(doctrines.size() > 0, "doctrines should contain at least one entry")
    for entry in doctrines:
        var context := _entry_context(entry, "Doctrine")
        _assert_is_dictionary(entry, context)
        _assert_has_keys(entry, [
            "id",
            "name",
            "description",
            "tags",
            "inertia_lock_turns",
            "elan_upkeep",
            "elan_spend_modifiers",
            "logistics_requirements",
            "effects",
        ], context)
        _assert_string(entry.get("id"), context, "id")
        _assert_string(entry.get("name"), context, "name")
        _assert_string(entry.get("description"), context, "description")
        _assert_array_of_strings(entry.get("tags"), context, "tags")
        _assert_integerish(entry.get("inertia_lock_turns"), context, "inertia_lock_turns")
        _assert_integerish(entry.get("elan_upkeep"), context, "elan_upkeep")
        _assert_dictionary(entry.get("elan_spend_modifiers"), context, "elan_spend_modifiers")
        _assert_dictionary(entry.get("logistics_requirements"), context, "logistics_requirements")
        _assert_dictionary(entry.get("effects"), context, "effects")
        var effects: Dictionary = entry.get("effects")
        if effects is Dictionary:
            _assert_string(effects.get("combat_pillar_focus"), context + ".effects", "combat_pillar_focus")
            var combat_bonus := effects.get("combat_bonus")
            _assert_dictionary(combat_bonus, context + ".effects", "combat_bonus")
            if combat_bonus is Dictionary:
                for pillar in COMBAT_PILLARS:
                    _assert_number(combat_bonus.get(pillar), context + ".effects.combat_bonus", pillar)

func test_orders_json_schema() -> void:
    var orders := _load_json_array("res://data/orders.json", "orders")
    asserts.is_true(orders.size() > 0, "orders should contain at least one entry")
    for entry in orders:
        var context := _entry_context(entry, "Order")
        _assert_is_dictionary(entry, context)
        _assert_has_keys(entry, [
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
        _assert_string(entry.get("id"), context, "id")
        _assert_string(entry.get("name"), context, "name")
        _assert_string(entry.get("description"), context, "description")
        _assert_array_of_strings(entry.get("tags"), context, "tags")
        _assert_integerish(entry.get("cp_cost"), context, "cp_cost")
        _assert_integerish(entry.get("base_elan_cost"), context, "base_elan_cost")
        _assert_integerish(entry.get("inertia_impact"), context, "inertia_impact")
        _assert_integerish(entry.get("base_delay_turns"), context, "base_delay_turns")
        _assert_array_of_strings(entry.get("allowed_doctrines"), context, "allowed_doctrines")

        var doctrine_requirements := entry.get("doctrine_requirements")
        _assert_dictionary(doctrine_requirements, context, "doctrine_requirements")
        if doctrine_requirements is Dictionary:
            _assert_array_of_strings(doctrine_requirements.get("required_tags"), context + ".doctrine_requirements", "required_tags")
            _assert_integerish(doctrine_requirements.get("minimum_swap_tokens"), context + ".doctrine_requirements", "minimum_swap_tokens")
            _assert_string(doctrine_requirements.get("command_profile"), context + ".doctrine_requirements", "command_profile")

        _assert_dictionary(entry.get("logistics_demand"), context, "logistics_demand")

        var inertia_profile := entry.get("inertia_profile")
        _assert_dictionary(inertia_profile, context, "inertia_profile")
        if inertia_profile is Dictionary:
            _assert_dictionary(inertia_profile.get("doctrine_multipliers"), context + ".inertia_profile", "doctrine_multipliers")
            var doctrine_multipliers := inertia_profile.get("doctrine_multipliers")
            if doctrine_multipliers is Dictionary:
                for key in doctrine_multipliers.keys():
                    _assert_number(doctrine_multipliers.get(key), context + ".inertia_profile.doctrine_multipliers", key)
            _assert_dictionary(inertia_profile.get("logistics_state_multipliers"), context + ".inertia_profile", "logistics_state_multipliers")
            var logistics_multipliers := inertia_profile.get("logistics_state_multipliers")
            if logistics_multipliers is Dictionary:
                for key in logistics_multipliers.keys():
                    _assert_number(logistics_multipliers.get(key), context + ".inertia_profile.logistics_state_multipliers", key)
            _assert_dictionary(inertia_profile.get("competence_offsets"), context + ".inertia_profile", "competence_offsets")
            var competence_offsets := inertia_profile.get("competence_offsets")
            if competence_offsets is Dictionary:
                for key in competence_offsets.keys():
                    _assert_number(competence_offsets.get(key), context + ".inertia_profile.competence_offsets", key)

        var targeting := entry.get("targeting")
        _assert_dictionary(targeting, context, "targeting")
        if targeting is Dictionary:
            _assert_string(targeting.get("scope"), context + ".targeting", "scope")
            _assert_boolean(targeting.get("requires_line_of_sight"), context + ".targeting", "requires_line_of_sight")
            _assert_array_of_strings(targeting.get("preferred_unit_classes"), context + ".targeting", "preferred_unit_classes")
            _assert_array_of_strings(targeting.get("allowed_postures"), context + ".targeting", "allowed_postures")
            _assert_integerish(targeting.get("max_concurrent"), context + ".targeting", "max_concurrent")

        var posture_requirements := entry.get("posture_requirements")
        _assert_dictionary(posture_requirements, context, "posture_requirements")
        if posture_requirements is Dictionary:
            _assert_array_of_strings(posture_requirements.get("required_postures"), context + ".posture_requirements", "required_postures")
            _assert_array_of_strings(posture_requirements.get("incompatible_postures"), context + ".posture_requirements", "incompatible_postures")

        _assert_dictionary(entry.get("resolution_effects"), context, "resolution_effects")
        _assert_string(entry.get("intention"), context, "intention")

        var pillar_weights := entry.get("pillar_weights")
        _assert_dictionary(pillar_weights, context, "pillar_weights")
        if pillar_weights is Dictionary:
            for pillar in COMBAT_PILLARS:
                _assert_number(pillar_weights.get(pillar), context + ".pillar_weights", pillar)

        var intel_profile := entry.get("intel_profile")
        _assert_dictionary(intel_profile, context, "intel_profile")
        if intel_profile is Dictionary:
            _assert_number(intel_profile.get("signal_strength"), context + ".intel_profile", "signal_strength")
            _assert_number(intel_profile.get("counter_intel"), context + ".intel_profile", "counter_intel")

        var assistant_metadata := entry.get("assistant_metadata")
        _assert_dictionary(assistant_metadata, context, "assistant_metadata")
        if assistant_metadata is Dictionary:
            _assert_dictionary(assistant_metadata.get("intent_profile"), context + ".assistant_metadata", "intent_profile")
            var intent_profile := assistant_metadata.get("intent_profile")
            if intent_profile is Dictionary:
                for key in intent_profile.keys():
                    _assert_number(intent_profile.get(key), context + ".assistant_metadata.intent_profile", key)
            _assert_string(assistant_metadata.get("risk_level"), context + ".assistant_metadata", "risk_level")
            _assert_array_of_strings(assistant_metadata.get("recommended_followups"), context + ".assistant_metadata", "recommended_followups")
            _assert_array_of_strings(assistant_metadata.get("telemetry_tags"), context + ".assistant_metadata", "telemetry_tags")

func test_units_json_schema() -> void:
    var units := _load_json_array("res://data/units.json", "units")
    asserts.is_true(units.size() > 0, "units should contain at least one entry")
    for entry in units:
        var context := _entry_context(entry, "Unit")
        _assert_is_dictionary(entry, context)
        _assert_has_keys(entry, [
            "id",
            "name",
            "role",
            "unit_class",
            "competence_synergy",
            "elan_generation",
            "logistics_load",
            "default_formations",
        ], context)
        _assert_string(entry.get("id"), context, "id")
        _assert_string(entry.get("name"), context, "name")
        _assert_string(entry.get("role"), context, "role")
        _assert_string(entry.get("unit_class"), context, "unit_class")
        _assert_dictionary(entry.get("competence_synergy"), context, "competence_synergy")
        _assert_dictionary(entry.get("elan_generation"), context, "elan_generation")
        _assert_dictionary(entry.get("logistics_load"), context, "logistics_load")
        _assert_array_of_strings(entry.get("default_formations"), context, "default_formations")
        var combat_profile := entry.get("combat_profile")
        _assert_dictionary(combat_profile, context, "combat_profile")
        if combat_profile is Dictionary:
            for pillar in COMBAT_PILLARS:
                _assert_number(combat_profile.get(pillar), context + ".combat_profile", pillar)
        var recon_profile := entry.get("recon_profile")
        _assert_dictionary(recon_profile, context, "recon_profile")
        if recon_profile is Dictionary:
            _assert_number(recon_profile.get("detection"), context + ".recon_profile", "detection")
            _assert_number(recon_profile.get("counter_intel"), context + ".recon_profile", "counter_intel")

func test_weather_json_schema() -> void:
    var weather_states := _load_json_array("res://data/weather.json", "weather")
    asserts.is_true(weather_states.size() > 0, "weather should contain at least one entry")
    for entry in weather_states:
        var context := _entry_context(entry, "Weather")
        _assert_is_dictionary(entry, context)
        _assert_has_keys(entry, [
            "id",
            "name",
            "effects",
            "movement_modifier",
            "logistics_flow_modifier",
            "intel_noise",
            "duration_turns",
            "elan_regeneration_bonus",
        ], context)
        _assert_string(entry.get("id"), context, "id")
        _assert_string(entry.get("name"), context, "name")
        _assert_string(entry.get("effects"), context, "effects")
        _assert_number(entry.get("movement_modifier"), context, "movement_modifier")
        _assert_number(entry.get("logistics_flow_modifier"), context, "logistics_flow_modifier")
        _assert_number(entry.get("intel_noise"), context, "intel_noise")
        _assert_number(entry.get("elan_regeneration_bonus"), context, "elan_regeneration_bonus")
        var duration := entry.get("duration_turns")
        _assert_array(duration, context, "duration_turns")
        if duration is Array:
            asserts.is_true(duration.size() == 2, "%s.duration_turns should contain a min and max" % context)
            for turn_value in duration:
                _assert_integerish(turn_value, context, "duration_turns[]")
        var combat_modifiers := entry.get("combat_modifiers")
        _assert_dictionary(combat_modifiers, context, "combat_modifiers")
        if combat_modifiers is Dictionary:
            for pillar in COMBAT_PILLARS:
                _assert_number(combat_modifiers.get(pillar), context + ".combat_modifiers", pillar)

func test_logistics_json_schema() -> void:
    var logistics_states := _load_json_array("res://data/logistics.json", "logistics")
    asserts.is_true(logistics_states.size() > 0, "logistics should contain at least one entry")
    for entry in logistics_states:
        var context := _entry_context(entry, "Logistics")
        _assert_is_dictionary(entry, context)
        _assert_has_keys(entry, [
            "id",
            "description",
            "supply_radius",
            "route_types",
            "convoy_spawn_threshold",
            "intercept_chance",
            "elan_penalty_on_break",
            "recovery_per_turn",
            "links",
        ], context)
        _assert_string(entry.get("id"), context, "id")
        _assert_string(entry.get("description"), context, "description")
        _assert_integerish(entry.get("supply_radius"), context, "supply_radius")
        _assert_array_of_strings(entry.get("route_types"), context, "route_types")
        _assert_integerish(entry.get("convoy_spawn_threshold"), context, "convoy_spawn_threshold")
        _assert_number(entry.get("intercept_chance"), context, "intercept_chance")
        _assert_integerish(entry.get("elan_penalty_on_break"), context, "elan_penalty_on_break")
        _assert_integerish(entry.get("recovery_per_turn"), context, "recovery_per_turn")
        _assert_dictionary(entry.get("links"), context, "links")
        var links := entry.get("links")
        if links is Dictionary:
            var doctrine_synergy := links.get("doctrine_synergy")
            _assert_array_of_strings(doctrine_synergy, context + ".links", "doctrine_synergy")
            var weather_modifiers := links.get("weather_modifiers")
            _assert_dictionary(weather_modifiers, context + ".links", "weather_modifiers")
            if weather_modifiers is Dictionary:
                for weather_id in weather_modifiers.keys():
                    _assert_string(weather_id, context + ".links.weather_modifiers", "key")
                    _assert_number(weather_modifiers.get(weather_id), context + ".links.weather_modifiers", weather_id)

func test_formations_json_schema() -> void:
    var formations := _load_json_array("res://data/formations.json", "formations")
    asserts.is_true(formations.size() > 0, "formations should contain at least one entry")
    for entry in formations:
        var context := _entry_context(entry, "Formation")
        _assert_is_dictionary(entry, context)
        _assert_has_keys(entry, [
            "id",
            "name",
            "posture",
            "pillar_modifiers",
            "competence_weight",
        ], context)
        _assert_string(entry.get("id"), context, "id")
        _assert_string(entry.get("name"), context, "name")
        _assert_string(entry.get("posture"), context, "posture")
        var modifiers := entry.get("pillar_modifiers")
        _assert_dictionary(modifiers, context, "pillar_modifiers")
        if modifiers is Dictionary:
            for pillar in COMBAT_PILLARS:
                _assert_number(modifiers.get(pillar, 0.0), context + ".pillar_modifiers", pillar)
        var competence_weight := entry.get("competence_weight")
        _assert_dictionary(competence_weight, context, "competence_weight")
        if competence_weight is Dictionary:
            for key in competence_weight.keys():
                _assert_number(competence_weight.get(key), context + ".competence_weight", key)

func test_data_loader_exposes_caches() -> void:
    var loader: DataLoaderAutoload = DATA_LOADER.new()
    var result := loader.load_all()
    asserts.is_true(result.get("ready", false), "DataLoader should report ready when assets load correctly")
    asserts.is_true(result.get("errors", []).is_empty(), "DataLoader should not surface schema errors with valid assets")

    var doctrine := loader.get_doctrine("force")
    asserts.is_true(doctrine.size() > 0, "Doctrine 'force' should be accessible via DataLoader cache")

    var orders := loader.list_orders()
    asserts.is_true(orders.size() > 0, "Orders collection should not be empty")

    var unit := loader.get_unit("infantry")
    asserts.is_true(unit.size() > 0, "Unit 'infantry' should be cached for quick lookups")

    var weather := loader.list_weather_states()
    asserts.is_true(weather.size() > 0, "Weather definitions should load into DataLoader")

    var logistics := loader.list_logistics_states()
    asserts.is_true(logistics.size() > 0, "Logistics configurations should load into DataLoader")

    var formations := loader.list_formations()
    asserts.is_true(formations.size() > 0, "Formations catalogue should load into DataLoader")

    var formation := loader.get_formation("shield_wall")
    asserts.is_true(formation.size() > 0, "Formation 'shield_wall' should be cached for quick lookups")

func test_data_loader_validation_reports_missing_keys() -> void:
    var errors := DataLoaderAutoload.validate_collection("orders", [{"id": "invalid_order"}])
    asserts.is_true(errors.size() > 0, "Validation should report missing required keys")
    var first_error := errors[0]
    asserts.is_equal("orders", first_error.get("label"), "Validation error should report the correct label")
    asserts.is_equal("missing_key", first_error.get("reason"), "Validation should identify missing keys")

func test_data_loader_validation_accepts_valid_payload() -> void:
    var orders := _load_json_array("res://data/orders.json", "orders")
    var errors := DataLoaderAutoload.validate_collection("orders", orders)
    asserts.is_true(errors.is_empty(), "Orders dataset should satisfy the hardened schema validation")

func _load_json_array(path: String, label: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    asserts.is_not_null(file, "Failed to open %s data file" % label)
    if file == null:
        return []
    var content := file.get_as_text()
    var parsed = JSON.parse_string(content)
    asserts.is_not_null(parsed, "Failed to parse %s JSON" % label)
    if typeof(parsed) != TYPE_ARRAY:
        asserts.is_true(false, "%s JSON should be an array" % label)
        return []
    return parsed

func _entry_context(entry, prefix: String) -> String:
    if entry is Dictionary and entry.has("id"):
        return "%s[%s]" % [prefix, entry.get("id")]
    return "%s[unknown]" % prefix

func _assert_has_keys(entry: Dictionary, keys: Array, context: String) -> void:
    for key in keys:
        var has_key := entry.has(key)
        asserts.is_true(has_key, "%s is missing required key '%s'" % [context, key])

func _assert_is_dictionary(value, context: String) -> void:
    asserts.is_true(typeof(value) == TYPE_DICTIONARY, "%s should be a dictionary" % context)

func _assert_dictionary(value, context: String, key: String) -> void:
    asserts.is_true(typeof(value) == TYPE_DICTIONARY, "%s.%s should be a dictionary" % [context, key])

func _assert_array(value, context: String, key: String) -> void:
    asserts.is_true(typeof(value) == TYPE_ARRAY, "%s.%s should be an array" % [context, key])

func _assert_array_of_strings(value, context: String, key: String) -> void:
    _assert_array(value, context, key)
    if value is Array:
        for element in value:
            asserts.is_true(typeof(element) == TYPE_STRING, "%s.%s entries must be strings" % [context, key])

func _assert_string(value, context: String, key: String) -> void:
    asserts.is_true(typeof(value) == TYPE_STRING, "%s.%s should be a string" % [context, key])

func _assert_number(value, context: String, key: String) -> void:
    var type := typeof(value)
    asserts.is_true(type == TYPE_INT or type == TYPE_FLOAT, "%s.%s should be numeric" % [context, key])

func _assert_boolean(value, context: String, key: String) -> void:
    asserts.is_true(typeof(value) == TYPE_BOOL, "%s.%s should be a boolean" % [context, key])

func _assert_integerish(value, context: String, key: String) -> void:
    var type := typeof(value)
    if type == TYPE_INT:
        return
    if type == TYPE_FLOAT:
        asserts.is_true(is_equal_approx(value, round(value)), "%s.%s should be an integer" % [context, key])
        return
    asserts.is_true(false, "%s.%s should be an integer" % [context, key])
