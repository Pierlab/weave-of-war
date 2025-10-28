extends RefCounted
class_name GdUnitLiteAssertions

var failures: Array[String] = []

func is_true(condition: bool, message: String = "") -> void:
    if not condition:
        failures.append(message if message != "" else "Expected condition to be true.")

func is_not_null(value, message: String = "") -> void:
    if value == null:
        failures.append(message if message != "" else "Value is unexpectedly null.")

func is_instance(value, class_name: String, message: String = "") -> void:
    if value == null or not value.is_class(class_name):
        var default_message := "Expected instance of %s" % class_name
        failures.append(message if message != "" else default_message)

func is_equal(expected, actual, message: String = "") -> void:
    if expected != actual:
        var default_message := "Expected %s but got %s" % [str(expected), str(actual)]
        failures.append(message if message != "" else default_message)

func summary() -> Dictionary:
    return {
        "passed": failures.is_empty(),
        "messages": failures.duplicate(),
    }
