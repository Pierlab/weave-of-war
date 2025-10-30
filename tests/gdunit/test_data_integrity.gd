extends GdUnitLiteTestCase

const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

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

func test_orders_json_schema() -> void:
    var orders := _load_json_array("res://data/orders.json", "orders")
    asserts.is_true(orders.size() > 0, "orders should contain at least one entry")
    for entry in orders:
        var context := _entry_context(entry, "Order")
        _assert_is_dictionary(entry, context)
        _assert_has_keys(entry, [
            "id",
            "name",
            "description",
            "base_elan_cost",
            "inertia_impact",
            "allowed_doctrines",
            "logistics_demand",
            "resolution_effects",
        ], context)
        _assert_string(entry.get("id"), context, "id")
        _assert_string(entry.get("name"), context, "name")
        _assert_string(entry.get("description"), context, "description")
        _assert_integerish(entry.get("base_elan_cost"), context, "base_elan_cost")
        _assert_integerish(entry.get("inertia_impact"), context, "inertia_impact")
        _assert_array_of_strings(entry.get("allowed_doctrines"), context, "allowed_doctrines")
        _assert_dictionary(entry.get("logistics_demand"), context, "logistics_demand")
        _assert_dictionary(entry.get("resolution_effects"), context, "resolution_effects")

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

func test_data_loader_exposes_caches() -> void:
    var loader: DataLoader = DATA_LOADER.new()
    var result := loader.load_all()
    asserts.is_true(result.get("ready", false), "DataLoader should report ready when assets load correctly")

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

func _assert_integerish(value, context: String, key: String) -> void:
    var type := typeof(value)
    if type == TYPE_INT:
        return
    if type == TYPE_FLOAT:
        asserts.is_true(is_equal_approx(value, round(value)), "%s.%s should be an integer" % [context, key])
        return
    asserts.is_true(false, "%s.%s should be an integer" % [context, key])
