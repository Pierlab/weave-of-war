extends GdUnitLiteTestCase

const WEATHER_SYSTEM := preload("res://scripts/systems/weather_system.gd")
const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const TELEMETRY := preload("res://scripts/core/telemetry.gd")

var _nodes_to_cleanup: Array = []

func after_each() -> void:
    var tree := Engine.get_main_loop()
    if tree is SceneTree:
        for node in _nodes_to_cleanup:
            if is_instance_valid(node):
                node.queue_free()
        _nodes_to_cleanup.clear()
        await tree.process_frame
    EventBus._instance = null
    Telemetry._instance = null

class MockEventBus:
    var events: Array = []

    func emit_weather_changed(payload: Dictionary) -> void:
        events.append(payload)

func _basic_weather_entries() -> Array:
    return [
        {
            "id": "sunny",
            "name": "Sunny",
            "effects": "Baseline visibility and movement.",
            "movement_modifier": 1.0,
            "logistics_flow_modifier": 1.0,
            "intel_noise": 0.0,
            "duration_turns": [1, 1],
            "elan_regeneration_bonus": 0.1,
        },
        {
            "id": "rain",
            "name": "Heavy Rain",
            "effects": "Convoys slow down and visibility drops.",
            "movement_modifier": 0.8,
            "logistics_flow_modifier": 0.7,
            "intel_noise": 0.2,
            "duration_turns": [1, 1],
            "elan_regeneration_bonus": -0.1,
        },
        {
            "id": "mist",
            "name": "Morning Mist",
            "effects": "Creates interception opportunities but shields advances.",
            "movement_modifier": 0.9,
            "logistics_flow_modifier": 0.8,
            "intel_noise": 0.35,
            "duration_turns": [1, 1],
            "elan_regeneration_bonus": 0.0,
        },
    ]

func _variable_duration_entries() -> Array:
    return [
        {
            "id": "sunny",
            "name": "Sunny",
            "movement_modifier": 1.0,
            "logistics_flow_modifier": 1.0,
            "intel_noise": 0.0,
            "duration_turns": [1, 3],
            "elan_regeneration_bonus": 0.1,
        },
        {
            "id": "rain",
            "name": "Heavy Rain",
            "movement_modifier": 0.8,
            "logistics_flow_modifier": 0.7,
            "intel_noise": 0.2,
            "duration_turns": [2, 3],
            "elan_regeneration_bonus": -0.1,
        },
        {
            "id": "mist",
            "name": "Morning Mist",
            "movement_modifier": 0.9,
            "logistics_flow_modifier": 0.8,
            "intel_noise": 0.35,
            "duration_turns": [1, 2],
            "elan_regeneration_bonus": 0.0,
        },
    ]

func test_configure_emits_initial_weather_state() -> void:
    var system: WeatherSystem = WEATHER_SYSTEM.new()
    var bus := MockEventBus.new()
    system.event_bus = bus
    system.set_rng_seed(1)
    system.configure(_basic_weather_entries())

    asserts.is_equal(1, bus.events.size(), "Initial configuration should emit one weather event")
    var payload: Dictionary = bus.events[0]
    asserts.is_equal("sunny", payload.get("weather_id"))
    asserts.is_equal("initial", payload.get("reason"))
    asserts.is_equal(1, payload.get("duration_remaining"))

func test_weather_rotates_through_sequence() -> void:
    var system: WeatherSystem = WEATHER_SYSTEM.new()
    var bus := MockEventBus.new()
    system.event_bus = bus
    system.set_rng_seed(7)
    system.configure(_basic_weather_entries())
    bus.events.clear()

    system.advance_turn(1)
    asserts.is_true(bus.events.size() > 0, "Weather rotation should emit an event when duration expires")
    var rain_event: Dictionary = bus.events.back()
    asserts.is_equal("rain", rain_event.get("weather_id"))
    asserts.is_equal("rotation", rain_event.get("reason"))

    bus.events.clear()
    system.advance_turn(2)
    var mist_event: Dictionary = bus.events.back()
    asserts.is_equal("mist", mist_event.get("weather_id"))
    asserts.is_equal("rotation", mist_event.get("reason"))

func test_seed_reproducibility_for_duration_rolls() -> void:
    var first := _simulate_weather_sequence(1337, _variable_duration_entries(), 6)
    var second := _simulate_weather_sequence(1337, _variable_duration_entries(), 6)
    asserts.is_equal(first, second, "Using the same seed should reproduce weather durations and reasons")

func test_weather_events_recorded_by_telemetry() -> void:
    var tree := Engine.get_main_loop()
    asserts.is_true(tree is SceneTree, "Telemetry capture requires a SceneTree main loop")
    if not (tree is SceneTree):
        return

    var root := tree.get_root()
    var event_bus: EventBus = EVENT_BUS.new()
    var telemetry: Telemetry = TELEMETRY.new()
    var system: WeatherSystem = WEATHER_SYSTEM.new()

    root.add_child(event_bus)
    root.add_child(telemetry)
    root.add_child(system)

    _nodes_to_cleanup.append_array([system, telemetry, event_bus])

    await tree.process_frame

    system.event_bus = event_bus
    system.set_rng_seed(11)
    system.configure(_basic_weather_entries())

    await tree.process_frame

    var buffer := telemetry.get_buffer()
    var weather_entries: Array = []
    for entry in buffer:
        if entry.get("name") == StringName("weather_changed"):
            weather_entries.append(entry)

    asserts.is_equal(1, weather_entries.size(), "Telemetry should capture the initial weather_changed payload")
    if weather_entries.is_empty():
        return

    var payload: Dictionary = weather_entries[0].get("payload", {})
    asserts.is_equal("sunny", payload.get("weather_id"))
    asserts.is_true(payload.has("movement_modifier"))
    asserts.is_true(payload.has("logistics_flow_modifier"))
    asserts.is_true(payload.has("duration_remaining"))
    asserts.is_equal("initial", payload.get("reason"))

func _simulate_weather_sequence(seed: int, entries: Array, turns: int) -> Array:
    var system: WeatherSystem = WEATHER_SYSTEM.new()
    var bus := MockEventBus.new()
    system.event_bus = bus
    system.set_rng_seed(seed)
    system.configure(entries)

    var snapshots: Array = []
    snapshots.append_array(_extract_events(bus.events))
    bus.events.clear()

    for turn in range(1, turns + 1):
        system.advance_turn(turn)
        snapshots.append_array(_extract_events(bus.events))
        bus.events.clear()
    return snapshots

func _extract_events(events: Array) -> Array:
    var result: Array = []
    for entry in events:
        if not (entry is Dictionary):
            continue
        result.append({
            "id": str(entry.get("weather_id", "")),
            "reason": str(entry.get("reason", "")),
            "remaining": int(entry.get("duration_remaining", 0)),
        })
    return result
