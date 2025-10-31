@warning_ignore("class_name_hides_autoload")
class_name DataLoader
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

static var _instance: DataLoader

var _collections: Dictionary = {}
var _indexed: Dictionary = {}
var _is_ready: bool = false

func _ready() -> void:
    _instance = self
    var result: Dictionary = load_all()
    call_deferred("_notify_event_bus", result)

static func get_instance() -> DataLoader:
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
    var event_bus: EventBus = EVENT_BUS.get_instance()
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
