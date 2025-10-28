extends Node
class_name GdUnitLiteTestCase

var asserts: GdUnitLiteAssertions

func _init() -> void:
    _reset_asserts()

func _reset_asserts() -> void:
    asserts = GdUnitLiteAssertions.new()

func before_each() -> void:
    pass

func after_each() -> void:
    pass

func run_test(method_name: String) -> Dictionary:
    _reset_asserts()
    if has_method("before_each"):
        call("before_each")
    call(method_name)
    if has_method("after_each"):
        call("after_each")
    var result := asserts.summary()
    return {
        "passed": result["passed"],
        "messages": result["messages"],
    }
