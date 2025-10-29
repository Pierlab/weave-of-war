extends Control

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")

@onready var next_turn_button: Button = $PanelContainer/MarginContainer/VBoxContainer/NextTurnButton
@onready var toggle_logistics_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ToggleLogisticsButton
@onready var spawn_unit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SpawnUnitButton

var event_bus: EventBus

func _ready() -> void:
    event_bus = EVENT_BUS.get_instance()
    if event_bus == null:
        await get_tree().process_frame
        event_bus = EVENT_BUS.get_instance()

    if next_turn_button:
        next_turn_button.pressed.connect(_on_next_turn_pressed)
    if toggle_logistics_button:
        toggle_logistics_button.pressed.connect(_on_toggle_logistics_pressed)
    if spawn_unit_button:
        spawn_unit_button.pressed.connect(_on_spawn_unit_pressed)

    if event_bus:
        event_bus.logistics_toggled.connect(_on_logistics_toggled)

func _on_next_turn_pressed() -> void:
    if event_bus:
        event_bus.request_next_turn()

func _on_toggle_logistics_pressed() -> void:
    if event_bus:
        event_bus.toggle_logistics()

func _on_spawn_unit_pressed() -> void:
    if event_bus:
        event_bus.request_spawn_unit()

func _on_logistics_toggled(should_show: bool) -> void:
    if toggle_logistics_button:
        toggle_logistics_button.text = "Hide Logistics" if should_show else "Show Logistics"
