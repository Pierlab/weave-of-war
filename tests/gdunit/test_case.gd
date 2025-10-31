class_name GdUnitLiteTestCase
extends Node

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
        var before_result = call("before_each")
        if before_result is GDScriptFunctionState:
            await before_result
    var test_result = call(method_name)
    if test_result is GDScriptFunctionState:
        await test_result
    if has_method("after_each"):
        var after_result = call("after_each")
        if after_result is GDScriptFunctionState:
            await after_result
    var result := asserts.summary()
    return {
        "passed": result["passed"],
        "messages": result["messages"],
    }
