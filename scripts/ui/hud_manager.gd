extends Control

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const UTILS := preload("res://scripts/core/utils.gd")
const PILLAR_DISPLAY_NAMES := {
    "position": "Position",
    "impulse": "Impulsion",
    "information": "Information",
}
const VICTOR_LABELS := {
    "attacker": "attaquant",
    "defender": "défenseur",
    "stalemate": "indécise",
    "contested": "contestée",
}
const PILLAR_WINNER_COLORS := {
    "attacker": Color(0.37, 0.75, 0.56, 1.0),
    "defender": Color(0.86, 0.46, 0.46, 1.0),
    "stalemate": Color(0.7, 0.7, 0.7, 1.0),
    "contested": Color(0.82, 0.72, 0.45, 1.0),
}
const PILLAR_NEUTRAL_COLOR := Color(0.55, 0.6, 0.7, 1.0)
const PILLAR_BACKGROUND_COLOR := Color(0.18, 0.2, 0.24, 0.9)
const INTEL_INTENTION_NAMES := {
    "offense": "Offensive",
    "defense": "Défensive",
    "deception": "Dissimulation",
    "support": "Soutien",
    "intel": "Renseignement",
    "unknown": "Inconnue",
}
const INTEL_INTENTION_COLORS := {
    "offense": Color(0.86, 0.46, 0.46, 1.0),
    "defense": Color(0.37, 0.75, 0.56, 1.0),
    "deception": Color(0.82, 0.72, 0.45, 1.0),
    "support": Color(0.55, 0.6, 0.7, 1.0),
    "intel": Color(0.45, 0.62, 0.88, 1.0),
    "unknown": Color(0.7, 0.7, 0.7, 1.0),
}
const MAX_INTEL_EVENTS := 6
const COMPETENCE_CATEGORIES := ["tactics", "strategy", "logistics"]
const COMPETENCE_HOTKEY_LABELS := {
    "tactics": "[1]",
    "strategy": "[2]",
    "logistics": "[3]",
}
const COMPETENCE_ACTIONS := {
    "tactics": "competence_focus_tactics",
    "strategy": "competence_focus_strategy",
    "logistics": "competence_focus_logistics",
}
const COMPETENCE_DEFAULT_STEP := 0.1

@onready var next_turn_button: Button = $MarginContainer/VBoxContainer/NextTurnButton
@onready var toggle_logistics_button: Button = $MarginContainer/VBoxContainer/ToggleLogisticsButton
@onready var weather_icon: ColorRect = $MarginContainer/VBoxContainer/WeatherPanel/WeatherIcon
@onready var weather_label: Label = $MarginContainer/VBoxContainer/WeatherPanel/WeatherLabel
@onready var doctrine_selector: OptionButton = $MarginContainer/VBoxContainer/DoctrineSelector
@onready var doctrine_status_label: Label = $MarginContainer/VBoxContainer/DoctrineStatusLabel
@onready var inertia_label: Label = $MarginContainer/VBoxContainer/InertiaLabel
@onready var order_selector: OptionButton = $MarginContainer/VBoxContainer/OrderSelector
@onready var execute_order_button: Button = $MarginContainer/VBoxContainer/ExecuteOrderButton
@onready var elan_label: Label = $MarginContainer/VBoxContainer/ElanLabel
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var feedback_player: AudioStreamPlayer = $FeedbackPlayer
@onready var intel_panel: PanelContainer = $MarginContainer/VBoxContainer/IntelPanel
@onready var intel_summary_label: Label = $MarginContainer/VBoxContainer/IntelPanel/VBoxContainer/IntelSummaryLabel
@onready var intel_log: RichTextLabel = $MarginContainer/VBoxContainer/IntelPanel/VBoxContainer/IntelLog
@onready var combat_panel: PanelContainer = $MarginContainer/VBoxContainer/CombatPanel
@onready var combat_summary_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/CombatSummaryLabel
@onready var combat_logistics_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/CombatLogisticsLabel
@onready var combat_elan_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/CombatElanLabel
@onready var competence_panel: PanelContainer = $MarginContainer/VBoxContainer/CompetencePanel
@onready var competence_available_label: Label = $MarginContainer/VBoxContainer/CompetencePanel/VBoxContainer/CompetenceAvailableLabel
@onready var competence_rows_container: VBoxContainer = $MarginContainer/VBoxContainer/CompetencePanel/VBoxContainer/CompetenceRows
@onready var position_meter: ProgressBar = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/PositionRow/PositionMeter
@onready var position_result_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/PositionRow/PositionResultLabel
@onready var impulse_meter: ProgressBar = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/ImpulseRow/ImpulseMeter
@onready var impulse_result_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/ImpulseRow/ImpulseResultLabel
@onready var information_meter: ProgressBar = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/InformationRow/InformationMeter
@onready var information_result_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/InformationRow/InformationResultLabel
@onready var formation_panel: PanelContainer = $MarginContainer/VBoxContainer/FormationPanel
@onready var formation_rows_container: VBoxContainer = $MarginContainer/VBoxContainer/FormationPanel/VBoxContainer/FormationRows

const FEEDBACK_SAMPLE_RATE := 44100.0
const FEEDBACK_DURATION := 0.12
const FEEDBACK_VOLUME := 0.2
const WEATHER_COLORS := {
    "sunny": Color(1.0, 0.84, 0.25, 1.0),
    "rain": Color(0.35, 0.55, 0.9, 1.0),
    "mist": Color(0.7, 0.75, 0.85, 1.0),
    "default": Color(0.8, 0.8, 0.8, 1.0),
}

var event_bus: EventBus
var data_loader: DataLoader

var _doctrine_lookup: Dictionary = {}
var _doctrine_names: Dictionary = {}
var _order_lookup: Dictionary = {}
var _order_costs: Dictionary = {}
var _elan_state: Dictionary = {
    "current": 0.0,
    "max": 0.0,
    "income": 0.0,
    "upkeep": 0.0,
}
var _doctrine_state: Dictionary = {}
var _feedback_generator: AudioStreamGenerator
var _pending_feedback_pitches: Array = []
var _feedback_flush_scheduled := false
var _suppress_doctrine_selector_signal := false
var _current_weather: Dictionary = {}
var _last_order_payloads: Dictionary = {}
var _last_combat_payload: Dictionary = {}
var _pillar_rows: Dictionary = {}
var _elan_adjustments: Dictionary = {}
var _last_elan_gain: Dictionary = {}
var _last_elan_event: Dictionary = {}
var _competence_state: Dictionary = {}
var _competence_rows: Dictionary = {}
var _active_competence_category: String = ""
var _suppress_competence_slider_signal := false
var _competence_active_style: StyleBoxFlat
var _competence_inactive_style: StyleBoxFlat
var _intel_events: Array[Dictionary] = []
var _formation_catalog: Dictionary = {}
var _formation_rows: Dictionary = {}
var _formation_status: Dictionary = {}
var _formation_available_elan: float = 0.0
var _suppress_formation_signal: Dictionary = {}

func _ready() -> void:
    event_bus = EVENT_BUS.get_instance()
    data_loader = DATA_LOADER.get_instance()

    if event_bus == null or data_loader == null:
        await get_tree().process_frame
        if event_bus == null:
            event_bus = EVENT_BUS.get_instance()
        if data_loader == null:
            data_loader = DATA_LOADER.get_instance()

    _wire_ui()
    _ensure_competence_actions_registered()
    _init_competence_styles()
    _setup_competence_panel()
    _connect_event_bus()
    _populate_from_data_loader()
    _initialise_combat_panel()
    _set_feedback("", true)
    _update_intel_panel()

func _wire_ui() -> void:
    if next_turn_button:
        next_turn_button.pressed.connect(_on_next_turn_pressed)
    if toggle_logistics_button:
        toggle_logistics_button.pressed.connect(_on_toggle_logistics_pressed)
        _refresh_terrain_tooltip([], [])
    if doctrine_selector:
        doctrine_selector.item_selected.connect(_on_doctrine_selector_item_selected)
    if order_selector:
        order_selector.item_selected.connect(_on_order_selector_item_selected)
    if execute_order_button:
        execute_order_button.pressed.connect(_on_execute_order_pressed)

func _connect_event_bus() -> void:
    if event_bus == null:
        return
    if not event_bus.logistics_toggled.is_connected(_on_logistics_toggled):
        event_bus.logistics_toggled.connect(_on_logistics_toggled)
    if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
        event_bus.data_loader_ready.connect(_on_data_loader_ready)
    if not event_bus.doctrine_selected.is_connected(_on_doctrine_selected):
        event_bus.doctrine_selected.connect(_on_doctrine_selected)
    if not event_bus.elan_updated.is_connected(_on_elan_updated):
        event_bus.elan_updated.connect(_on_elan_updated)
    if not event_bus.order_issued.is_connected(_on_order_issued):
        event_bus.order_issued.connect(_on_order_issued)
    if not event_bus.order_execution_failed.is_connected(_on_order_execution_failed):
        event_bus.order_execution_failed.connect(_on_order_execution_failed)
    if not event_bus.weather_changed.is_connected(_on_weather_changed):
        event_bus.weather_changed.connect(_on_weather_changed)
    if not event_bus.combat_resolved.is_connected(_on_combat_resolved):
        event_bus.combat_resolved.connect(_on_combat_resolved)
    if not event_bus.elan_spent.is_connected(_on_elan_spent):
        event_bus.elan_spent.connect(_on_elan_spent)
    if not event_bus.elan_gained.is_connected(_on_elan_gained):
        event_bus.elan_gained.connect(_on_elan_gained)
    if not event_bus.competence_reallocated.is_connected(_on_competence_reallocated):
        event_bus.competence_reallocated.connect(_on_competence_reallocated)
    if not event_bus.competence_allocation_failed.is_connected(_on_competence_allocation_failed):
        event_bus.competence_allocation_failed.connect(_on_competence_allocation_failed)
    if not event_bus.espionage_ping.is_connected(_on_espionage_ping):
        event_bus.espionage_ping.connect(_on_espionage_ping)
    if not event_bus.intel_intent_revealed.is_connected(_on_intel_intent_revealed):
        event_bus.intel_intent_revealed.connect(_on_intel_intent_revealed)
    if not event_bus.formation_status_updated.is_connected(_on_formation_status_updated):
        event_bus.formation_status_updated.connect(_on_formation_status_updated)
    if not event_bus.formation_change_failed.is_connected(_on_formation_change_failed):
        event_bus.formation_change_failed.connect(_on_formation_change_failed)
    if not event_bus.formation_changed.is_connected(_on_formation_changed):
        event_bus.formation_changed.connect(_on_formation_changed)

func _populate_from_data_loader() -> void:
    if data_loader == null or not data_loader.is_ready():
        return
    _populate_doctrines(data_loader.list_doctrines())
    _populate_orders(data_loader.list_orders())
    _refresh_terrain_tooltip(data_loader.list_terrain_definitions(), data_loader.list_terrain_tiles())
    _setup_formation_panel()
    _update_weather_panel()

func _ensure_competence_actions_registered() -> void:
    var action_map := {
        "competence_focus_tactics": [
            _make_key_event(KEY_1),
            _make_key_event(KEY_Q),
            _make_joy_button_event(JOY_BUTTON_X),
        ],
        "competence_focus_strategy": [
            _make_key_event(KEY_2),
            _make_key_event(KEY_W),
            _make_joy_button_event(JOY_BUTTON_Y),
        ],
        "competence_focus_logistics": [
            _make_key_event(KEY_3),
            _make_key_event(KEY_E),
            _make_joy_button_event(JOY_BUTTON_B),
        ],
        "competence_increase": [
            _make_key_event(KEY_RIGHT),
            _make_key_event(KEY_D),
            _make_joy_button_event(JOY_BUTTON_DPAD_RIGHT),
        ],
        "competence_decrease": [
            _make_key_event(KEY_LEFT),
            _make_key_event(KEY_A),
            _make_joy_button_event(JOY_BUTTON_DPAD_LEFT),
        ],
    }

    for action_name in action_map.keys():
        _register_action_if_missing(action_name, action_map.get(action_name, []))

func _register_action_if_missing(action_name: String, events: Array) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    for event in events:
        if event == null:
            continue
        if not InputMap.action_has_event(action_name, event):
            InputMap.action_add_event(action_name, event)

func _make_key_event(keycode: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.physical_keycode = keycode
    event.pressed = false
    return event

func _make_joy_button_event(button_index: int) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.button_index = button_index
    event.pressed = false
    return event

func _init_competence_styles() -> void:
    if _competence_active_style == null:
        _competence_active_style = StyleBoxFlat.new()
        _competence_active_style.bg_color = Color(0.26, 0.36, 0.48, 0.95)
        _competence_active_style.corner_radius_top_left = 6
        _competence_active_style.corner_radius_top_right = 6
        _competence_active_style.corner_radius_bottom_left = 6
        _competence_active_style.corner_radius_bottom_right = 6
        _competence_active_style.content_margin_left = 8
        _competence_active_style.content_margin_right = 8
        _competence_active_style.content_margin_top = 6
        _competence_active_style.content_margin_bottom = 8
    if _competence_inactive_style == null:
        _competence_inactive_style = StyleBoxFlat.new()
        _competence_inactive_style.bg_color = Color(0.16, 0.18, 0.22, 0.9)
        _competence_inactive_style.corner_radius_top_left = 6
        _competence_inactive_style.corner_radius_top_right = 6
        _competence_inactive_style.corner_radius_bottom_left = 6
        _competence_inactive_style.corner_radius_bottom_right = 6
        _competence_inactive_style.content_margin_left = 8
        _competence_inactive_style.content_margin_right = 8
        _competence_inactive_style.content_margin_top = 6
        _competence_inactive_style.content_margin_bottom = 8

func _setup_competence_panel() -> void:
    if competence_rows_container == null:
        return
    for child in competence_rows_container.get_children():
        child.queue_free()
    _competence_rows.clear()

    var config_map := _extract_competence_config()
    for category in COMPETENCE_CATEGORIES:
        var config: Dictionary = config_map.get(category, {})
        _build_competence_row(category, config)

    if _active_competence_category.is_empty() and not COMPETENCE_CATEGORIES.is_empty():
        _active_competence_category = COMPETENCE_CATEGORIES[0]
    _highlight_competence_row(_active_competence_category)
    _update_competence_panel()

func _extract_competence_config() -> Dictionary:
    var config_map: Dictionary = {}
    var state_config: Variant = _competence_state.get("config", {})
    if state_config is Dictionary:
        for key in (state_config as Dictionary).keys():
            var entry_variant: Variant = (state_config as Dictionary).get(key)
            if entry_variant is Dictionary:
                config_map[key] = (entry_variant as Dictionary).duplicate(true)
    if config_map.is_empty() and data_loader and data_loader.is_ready():
        for entry in data_loader.list_competence_sliders():
            if not (entry is Dictionary):
                continue
            var identifier := str(entry.get("id", ""))
            if identifier.is_empty():
                continue
            config_map[identifier] = entry.duplicate(true)
    if config_map.is_empty():
        for category in COMPETENCE_CATEGORIES:
            config_map[category] = {
                "id": category,
                "name": category.capitalize(),
                "description": "",
                "min_allocation": 0.0,
                "max_allocation": 6.0,
                "max_delta_per_turn": 1.0,
                "inertia_lock_turns": 1,
            }
    return config_map

func _build_competence_row(category: String, config: Dictionary) -> void:
    if competence_rows_container == null:
        return

    var panel := PanelContainer.new()
    panel.name = "%sCompetencePanel" % category.capitalize()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_FILL
    var inactive_style := _competence_inactive_style.duplicate()
    panel.set("theme_override_styles/panel", inactive_style)

    var wrapper := VBoxContainer.new()
    wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wrapper.size_flags_vertical = Control.SIZE_FILL
    wrapper.theme_override_constants["separation"] = 4
    panel.add_child(wrapper)

    var header := HBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.theme_override_constants["separation"] = 6
    wrapper.add_child(header)

    var hotkey_label := Label.new()
    hotkey_label.text = COMPETENCE_HOTKEY_LABELS.get(category, "")
    hotkey_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    hotkey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(hotkey_label)

    var name_label := Label.new()
    name_label.text = str(config.get("name", category.capitalize()))
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    header.add_child(name_label)

    var status_label := Label.new()
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    wrapper.add_child(status_label)

    var slider := HSlider.new()
    slider.focus_mode = Control.FOCUS_ALL
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.size_flags_vertical = Control.SIZE_FILL
    slider.min_value = float(config.get("min_allocation", 0.0))
    slider.max_value = float(config.get("max_allocation", slider.min_value))
    slider.step = COMPETENCE_DEFAULT_STEP
    slider.tooltip_text = str(config.get("description", ""))
    wrapper.add_child(slider)

    slider.value_changed.connect(func(value: float) -> void:
        _on_competence_slider_changed(category, value)
    )
    slider.focus_entered.connect(func() -> void:
        _highlight_competence_row(category)
    )

    competence_rows_container.add_child(panel)
    _competence_rows[category] = {
        "panel": panel,
        "hotkey_label": hotkey_label,
        "name_label": name_label,
        "status_label": status_label,
        "slider": slider,
        "styles": {
            "active": _competence_active_style.duplicate(),
            "inactive": inactive_style,
        },
    }

func _setup_formation_panel() -> void:
    if formation_rows_container == null:
        return
    for child in formation_rows_container.get_children():
        child.queue_free()
    _formation_rows.clear()
    _formation_catalog.clear()

    if data_loader == null or not data_loader.is_ready():
        return

    for entry_variant in data_loader.list_formations():
        if not (entry_variant is Dictionary):
            continue
        var formation: Dictionary = entry_variant
        var formation_id := str(formation.get("id", ""))
        if formation_id.is_empty():
            continue
        _formation_catalog[formation_id] = {
            "name": str(formation.get("name", formation_id)),
            "posture": str(formation.get("posture", "")),
            "elan_cost": float(formation.get("elan_cost", 0.0)),
            "inertia_lock_turns": int(formation.get("inertia_lock_turns", 0)),
            "description": str(formation.get("description", "")),
        }

    for unit_variant in data_loader.list_units():
        if not (unit_variant is Dictionary):
            continue
        _build_formation_row(unit_variant)

    _refresh_all_formation_rows()

func _build_formation_row(unit_entry: Dictionary) -> void:
    if formation_rows_container == null:
        return
    var unit_id := str(unit_entry.get("id", ""))
    if unit_id.is_empty():
        return
    var unit_name := str(unit_entry.get("name", unit_id.capitalize()))

    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_FILL

    var wrapper := VBoxContainer.new()
    wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wrapper.theme_override_constants["separation"] = 4
    panel.add_child(wrapper)

    var name_label := Label.new()
    name_label.text = unit_name
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    wrapper.add_child(name_label)

    var selector := OptionButton.new()
    selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    selector.focus_mode = Control.FOCUS_ALL
    wrapper.add_child(selector)

    var status_label := Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    wrapper.add_child(status_label)

    var mapping: Dictionary = {}
    var reverse: Dictionary = {}
    var index := 0
    for formation_variant in data_loader.list_formations_for_unit(unit_id):
        if not (formation_variant is Dictionary):
            continue
        var formation: Dictionary = formation_variant
        var formation_id := str(formation.get("id", ""))
        if formation_id.is_empty():
            continue
        var info: Dictionary = _formation_catalog.get(formation_id, {})
        selector.add_item(str(info.get("name", formation_id)))
        selector.set_item_tooltip(index, _format_formation_tooltip(formation_id))
        mapping[index] = formation_id
        reverse[formation_id] = index
        index += 1
    selector.item_selected.connect(func(idx: int) -> void:
        _on_formation_option_selected(unit_id, idx)
    )

    formation_rows_container.add_child(panel)
    _formation_rows[unit_id] = {
        "panel": panel,
        "selector": selector,
        "status_label": status_label,
        "mapping": mapping,
        "reverse": reverse,
        "unit_name": unit_name,
    }

func _format_formation_tooltip(formation_id: String) -> String:
    var info: Dictionary = _formation_catalog.get(formation_id, {})
    if info.is_empty():
        return ""
    var lines: Array[String] = []
    var posture := str(info.get("posture", ""))
    if not posture.is_empty():
        lines.append("Posture : %s" % posture)
    lines.append("Coût : %.1f Élan" % float(info.get("elan_cost", 0.0)))
    lines.append("Inertie : %d tour(s)" % int(info.get("inertia_lock_turns", 0)))
    var description := str(info.get("description", ""))
    if not description.is_empty():
        lines.append(description)
    return "\n".join(lines)

func _on_formation_option_selected(unit_id: String, index: int) -> void:
    if _suppress_formation_signal.get(unit_id, false):
        return
    if not _formation_rows.has(unit_id):
        return
    var row: Dictionary = _formation_rows.get(unit_id, {})
    var mapping: Dictionary = row.get("mapping", {})
    if not mapping.has(index):
        return
    var formation_id := str(mapping.get(index, ""))
    if formation_id.is_empty():
        return
    if event_bus:
        event_bus.request_formation_change({
            "unit_id": unit_id,
            "formation_id": formation_id,
            "source": "hud",
        })

func _on_formation_status_updated(payload: Dictionary) -> void:
    _formation_available_elan = float(payload.get("available_elan", _formation_available_elan))
    var units_variant: Variant = payload.get("units", {})
    if units_variant is Dictionary:
        var units: Dictionary = units_variant as Dictionary
        for unit_id_variant in units.keys():
            var unit_id := str(unit_id_variant)
            var status_variant: Variant = units.get(unit_id_variant, {})
            if status_variant is Dictionary:
                _formation_status[unit_id] = (status_variant as Dictionary).duplicate(true)
                _refresh_formation_row(unit_id)

func _refresh_all_formation_rows() -> void:
    for unit_id_variant in _formation_rows.keys():
        _refresh_formation_row(str(unit_id_variant))

func _refresh_formation_row(unit_id: String) -> void:
    if not _formation_rows.has(unit_id):
        return
    var row: Dictionary = _formation_rows.get(unit_id, {})
    var selector: OptionButton = row.get("selector")
    var status_label: Label = row.get("status_label")
    var reverse: Dictionary = row.get("reverse", {})
    var status: Dictionary = _formation_status.get(unit_id, {})
    var formation_id := str(status.get("formation_id", ""))
    if formation_id.is_empty() and reverse.size() > 0:
        for key in reverse.keys():
            formation_id = str(key)
            break

    _suppress_formation_signal[unit_id] = true
    if reverse.has(formation_id):
        selector.select(int(reverse.get(formation_id, -1)))
    _suppress_formation_signal[unit_id] = false

    var locked := bool(status.get("locked", false))
    selector.disabled = locked

    var info: Dictionary = _formation_catalog.get(formation_id, {})
    var cost := float(status.get("elan_cost", info.get("elan_cost", 0.0)))
    var lock_turns := int(status.get("inertia_lock_turns", info.get("inertia_lock_turns", 0)))
    var turns_remaining := int(status.get("turns_remaining", 0))
    var available := float(status.get("available_elan", _formation_available_elan))

    var text_parts: Array[String] = []
    text_parts.append("Coût %.1f Élan" % cost)
    text_parts.append("Inertie %d tour(s)" % lock_turns)
    if turns_remaining > 0:
        text_parts.append("Verrouillée %d tour(s)" % turns_remaining)
    if cost > available + 0.001:
        text_parts.append("Élan dispo %.1f" % available)
    status_label.text = " · ".join(text_parts)

    var tooltip_lines: Array[String] = []
    var posture := str(info.get("posture", status.get("posture", "")))
    if not posture.is_empty():
        tooltip_lines.append("Posture : %s" % posture)
    var description := str(info.get("description", status.get("description", "")))
    if not description.is_empty():
        tooltip_lines.append(description)
    status_label.tooltip_text = "\n".join(tooltip_lines)

func _formation_unit_name(unit_id: String) -> String:
    if _formation_rows.has(unit_id):
        return str(_formation_rows.get(unit_id, {}).get("unit_name", unit_id))
    if _formation_status.has(unit_id):
        return str(_formation_status.get(unit_id, {}).get("unit_name", unit_id))
    return unit_id

func _on_competence_slider_changed(category: String, value: float) -> void:
    if _suppress_competence_slider_signal:
        return
    if not _competence_rows.has(category):
        return
    var target_value := snapped(value, 0.01)
    var row: Dictionary = _competence_rows.get(category, {})
    var slider: HSlider = row.get("slider")
    if slider and abs(slider.value - target_value) > 0.0001:
        _suppress_competence_slider_signal = true
        slider.value = target_value
        _suppress_competence_slider_signal = false
    var allocations_variant: Variant = _competence_state.get("allocations", {})
    var current_allocation: float = target_value
    if allocations_variant is Dictionary:
        current_allocation = float((allocations_variant as Dictionary).get(category, target_value))
    if abs(current_allocation - target_value) <= 0.001:
        _update_competence_panel(true)
        return
    var requested := _gather_competence_allocations_from_sliders()
    requested[category] = target_value
    if event_bus:
        event_bus.request_competence_allocation(requested)
    _update_competence_panel(true)

func _gather_competence_allocations_from_sliders() -> Dictionary:
    var allocations: Dictionary = {}
    for category in _competence_rows.keys():
        var row: Dictionary = _competence_rows.get(category, {})
        var slider: HSlider = row.get("slider")
        if slider:
            allocations[category] = snapped(slider.value, 0.01)
    return allocations

func _highlight_competence_row(category: String) -> void:
    if category.is_empty() and not COMPETENCE_CATEGORIES.is_empty():
        category = COMPETENCE_CATEGORIES[0]
    _active_competence_category = category
    for entry in _competence_rows.keys():
        var row: Dictionary = _competence_rows.get(entry, {})
        var panel: PanelContainer = row.get("panel")
        var styles: Dictionary = row.get("styles", {})
        if panel and styles:
            var style_key := "active" if entry == category else "inactive"
            var style_box: StyleBox = styles.get(style_key)
            if style_box:
                panel.set("theme_override_styles/panel", style_box)
        var name_label: Label = row.get("name_label")
        var hotkey_label: Label = row.get("hotkey_label")
        var color := Color(0.92, 0.95, 1.0, 1.0) if entry == category else Color(0.82, 0.85, 0.9, 1.0)
        if name_label:
            name_label.add_theme_color_override("font_color", color)
        if hotkey_label:
            hotkey_label.add_theme_color_override("font_color", color)

func _focus_competence_slider(category: String) -> void:
    if category.is_empty():
        return
    _active_competence_category = category
    if not _competence_rows.has(category):
        _highlight_competence_row(category)
        return
    var row: Dictionary = _competence_rows.get(category, {})
    var slider: HSlider = row.get("slider")
    if slider:
        slider.grab_focus()
    else:
        _highlight_competence_row(category)

func _nudge_competence_slider(category: String, step_multiplier: float) -> void:
    if category.is_empty() or not _competence_rows.has(category):
        return
    var row: Dictionary = _competence_rows.get(category, {})
    var slider: HSlider = row.get("slider")
    if slider == null:
        return
    var step := slider.step if slider.step > 0.0 else COMPETENCE_DEFAULT_STEP
    var next_value := clamp(slider.value + step * step_multiplier, slider.min_value, slider.max_value)
    if abs(next_value - slider.value) <= 0.0001:
        return
    _suppress_competence_slider_signal = true
    slider.value = snapped(next_value, 0.01)
    _suppress_competence_slider_signal = false
    _on_competence_slider_changed(category, slider.value)

func _update_competence_panel(use_slider_values := false) -> void:
    if competence_panel == null:
        return
    if _competence_state.is_empty():
        competence_panel.visible = false
        return
    competence_panel.visible = true
    if _active_competence_category.is_empty() and not COMPETENCE_CATEGORIES.is_empty():
        _active_competence_category = COMPETENCE_CATEGORIES[0]

    var allocations_variant: Variant = _competence_state.get("allocations", {})
    var allocations: Dictionary = {}
    if allocations_variant is Dictionary:
        allocations = (allocations_variant as Dictionary)
    var inertia_variant: Variant = _competence_state.get("inertia", {})
    var inertia_map: Dictionary = {}
    if inertia_variant is Dictionary:
        inertia_map = (inertia_variant as Dictionary)
    var config_map := _extract_competence_config()

    _suppress_competence_slider_signal = true
    for category in COMPETENCE_CATEGORIES:
        if not _competence_rows.has(category):
            continue
        var row: Dictionary = _competence_rows.get(category, {})
        var slider: HSlider = row.get("slider")
        var name_label: Label = row.get("name_label")
        var hotkey_label: Label = row.get("hotkey_label")
        var status_label: Label = row.get("status_label")
        var config: Dictionary = config_map.get(category, {})
        if name_label:
            name_label.text = str(config.get("name", category.capitalize()))
        if hotkey_label:
            hotkey_label.text = COMPETENCE_HOTKEY_LABELS.get(category, "")
        if slider:
            slider.min_value = float(config.get("min_allocation", slider.min_value))
            slider.max_value = float(config.get("max_allocation", slider.max_value))
            slider.step = COMPETENCE_DEFAULT_STEP
            slider.tooltip_text = str(config.get("description", ""))
        var base_value := float(allocations.get(category, slider.value if slider else 0.0))
        var display_value := snapped(base_value, 0.01)
        if use_slider_values and slider:
            display_value = snapped(slider.value, 0.01)
        elif slider:
            slider.value = display_value
        var inertia_state: Dictionary = {}
        if inertia_map.has(category) and inertia_map.get(category) is Dictionary:
            inertia_state = inertia_map.get(category, {})
        if status_label:
            status_label.text = _format_competence_status(category, display_value, config, inertia_state)
    _suppress_competence_slider_signal = false

    _highlight_competence_row(_active_competence_category)

    var budget := float(_competence_state.get("budget", 0.0))
    var available := float(_competence_state.get("available", 0.0))
    var used := max(budget - available, 0.0)
    var modifiers_variant: Variant = _competence_state.get("modifiers", {})
    var penalty := 0.0
    if modifiers_variant is Dictionary:
        penalty = float((modifiers_variant as Dictionary).get("logistics_penalty", 0.0))
    var label_text := "Budget : %.2f pts (Utilisés %.2f · Restant %.2f)" % [budget, used, available]
    if penalty > 0.0:
        label_text += " | Pénalité logistique %.2f" % penalty
    if competence_available_label:
        competence_available_label.text = label_text

func _format_competence_status(category: String, allocation: float, config: Dictionary, inertia_state: Dictionary) -> String:
    var min_value := float(config.get("min_allocation", 0.0))
    var max_value := float(config.get("max_allocation", min_value))
    if max_value < min_value:
        max_value = min_value
    var parts: Array[String] = []
    parts.append("Allocation %.2f pts" % allocation)
    parts.append("Bornes %.2f–%.2f" % [min_value, max_value])
    var max_delta := float(inertia_state.get("max_delta_per_turn", config.get("max_delta_per_turn", 0.0)))
    var spent := float(inertia_state.get("spent_this_turn", 0.0))
    parts.append("Δ %.2f / %.2f" % [spent, max_delta])
    var turns := int(inertia_state.get("turns_remaining", 0))
    if turns > 0:
        parts.append("Verrou %dT" % turns)
    else:
        parts.append("Verrou 0T")
    return " | ".join(parts)

func _competence_display_name(category: String) -> String:
    if _competence_rows.has(category):
        var row: Dictionary = _competence_rows.get(category, {})
        var name_label: Label = row.get("name_label")
        if name_label:
            return name_label.text
    return category.capitalize()

func _unhandled_input(event: InputEvent) -> void:
    if competence_panel == null or not competence_panel.visible:
        return
    if event.is_echo():
        return
    if event.is_action_pressed("competence_focus_tactics"):
        _focus_competence_slider("tactics")
        accept_event()
        return
    if event.is_action_pressed("competence_focus_strategy"):
        _focus_competence_slider("strategy")
        accept_event()
        return
    if event.is_action_pressed("competence_focus_logistics"):
        _focus_competence_slider("logistics")
        accept_event()
        return
    if event.is_action_pressed("competence_increase"):
        if _active_competence_category.is_empty() and not COMPETENCE_CATEGORIES.is_empty():
            _active_competence_category = COMPETENCE_CATEGORIES[0]
        _nudge_competence_slider(_active_competence_category, 1.0)
        accept_event()
        return
    if event.is_action_pressed("competence_decrease"):
        if _active_competence_category.is_empty() and not COMPETENCE_CATEGORIES.is_empty():
            _active_competence_category = COMPETENCE_CATEGORIES[0]
        _nudge_competence_slider(_active_competence_category, -1.0)
        accept_event()
        return

func _populate_doctrines(entries: Array) -> void:
    if doctrine_selector == null:
        return
    doctrine_selector.clear()
    _doctrine_lookup.clear()
    _doctrine_names.clear()
    var index: int = 0
    for entry in entries:
        if entry is Dictionary:
            var id: String = str(entry.get("id", ""))
            if id.is_empty():
                continue
            var name: String = str(entry.get("name", id))
            doctrine_selector.add_item(name)
            doctrine_selector.set_item_metadata(index, id)
            _doctrine_lookup[id] = index
            _doctrine_names[id] = name
            index += 1
    _update_doctrine_selector_state()

func _populate_orders(entries: Array) -> void:
    _order_lookup.clear()
    _order_costs.clear()
    _last_order_payloads.clear()
    for entry in entries:
        if entry is Dictionary:
            var id: String = str(entry.get("id", ""))
            if id.is_empty():
                continue
            _order_lookup[id] = entry
            _order_costs[id] = float(entry.get("base_elan_cost", 0))
    _refresh_order_selector([])

func _refresh_terrain_tooltip(definitions: Array, tiles: Array) -> void:
    if toggle_logistics_button == null:
        return
    toggle_logistics_button.tooltip_text = UTILS.build_terrain_tooltip(definitions, tiles)

func _refresh_order_selector(allowed_entries: Array) -> void:
    if order_selector == null:
        return
    order_selector.clear()
    var index: int = 0
    for entry in allowed_entries:
        if entry is Dictionary:
            var id: String = str(entry.get("id", ""))
            if id.is_empty():
                continue
            var name: String = str(entry.get("name", id))
            var cost: float = float(entry.get("base_elan_cost", _order_costs.get(id, 0.0)))
            _order_costs[id] = cost
            var competence_variant: Variant = entry.get("competence_cost", {})
            var competence_label := _format_competence_cost(competence_variant)
            var item_label := "%s (%.1f Élan)" % [name, cost]
            if not competence_label.is_empty():
                item_label = "%s (%.1f Élan · %s)" % [name, cost, competence_label]
            order_selector.add_item(item_label)
            order_selector.set_item_metadata(index, id)
            index += 1
    if index == 0:
        if execute_order_button:
            execute_order_button.disabled = true
    else:
        order_selector.select(0)
    _refresh_order_button_state()

func _on_next_turn_pressed() -> void:
    if event_bus:
        event_bus.request_next_turn()

func _on_toggle_logistics_pressed() -> void:
    if event_bus:
        event_bus.toggle_logistics()

func _on_logistics_toggled(should_show: bool) -> void:
    if toggle_logistics_button:
        toggle_logistics_button.text = "Hide Logistics" if should_show else "Show Logistics"

func _on_weather_changed(payload: Dictionary) -> void:
    _current_weather = payload.duplicate(true)
    _update_weather_panel()

func _on_doctrine_selector_item_selected(index: int) -> void:
    if _suppress_doctrine_selector_signal:
        return
    if doctrine_selector == null:
        return
    var metadata: Variant = doctrine_selector.get_item_metadata(index)
    if typeof(metadata) != TYPE_STRING:
        return
    var doctrine_id := String(metadata)
    if doctrine_id.is_empty():
        return
    var current_id: String = str(_doctrine_state.get("id", ""))
    if doctrine_id == current_id:
        return
    var inertia_remaining: int = int(_doctrine_state.get("inertia_remaining", 0))
    if inertia_remaining > 0:
        _set_feedback("Doctrine verrouillée par l'inertie (%d tour(s))." % inertia_remaining, false)
        _play_feedback(200.0)
        _update_doctrine_selector_state(current_id)
        return
    if event_bus:
        event_bus.request_doctrine_change(doctrine_id)

func _on_order_selector_item_selected(_index: int) -> void:
    _refresh_order_button_state()

func _update_weather_panel() -> void:
    if weather_label == null or weather_icon == null:
        return
    var weather_id := str(_current_weather.get("weather_id", ""))
    if weather_id.is_empty():
        weather_label.text = "Weather : —"
        weather_icon.color = WEATHER_COLORS.get("default", Color(0.8, 0.8, 0.8, 1.0))
        weather_label.tooltip_text = "Aucune météo active."
        return
    var name := str(_current_weather.get("name", weather_id.capitalize()))
    var remaining := int(_current_weather.get("duration_remaining", 0))
    var range_variant: Variant = _current_weather.get("duration_range", [])
    var range_text := ""
    if range_variant is Array and remaining > 0:
        var minimum := int(range_variant[0]) if range_variant.size() > 0 else remaining
        var maximum := int(range_variant[1]) if range_variant.size() > 1 else minimum
        if minimum == maximum:
            range_text = " (%d tour%s restant%s)" % [remaining, "s" if remaining > 1 else "", "s" if remaining > 1 else ""]
        else:
            range_text = " (%d/%d restants)" % [remaining, maximum]
    elif remaining > 0:
        range_text = " (%d tour%s restant%s)" % [remaining, "s" if remaining > 1 else "", "s" if remaining > 1 else ""]
    weather_label.text = "Weather : %s%s" % [name, range_text]

    var icon_color: Color = WEATHER_COLORS.get(weather_id, WEATHER_COLORS.get("default"))
    weather_icon.color = icon_color

    var effects := str(_current_weather.get("effects", ""))
    var movement := float(_current_weather.get("movement_modifier", 1.0))
    var flow := float(_current_weather.get("logistics_flow_modifier", 1.0))
    var intel := float(_current_weather.get("intel_noise", 0.0))
    var elan_bonus := float(_current_weather.get("elan_regeneration_bonus", 0.0))
    var tooltip_lines: Array = []
    tooltip_lines.append("%s" % name)
    if not effects.is_empty():
        tooltip_lines.append(effects)
    tooltip_lines.append("Déplacement ×%.2f | Flux ×%.2f" % [movement, flow])
    tooltip_lines.append("Brouillard intel +%.2f | Bonus Élan %.2f" % [intel, elan_bonus])
    if remaining > 0:
        tooltip_lines.append("Encore %d tour%s" % [remaining, "s" if remaining > 1 else ""])
    weather_label.tooltip_text = "\n".join(tooltip_lines)

func _refresh_order_button_state() -> void:
    if execute_order_button == null:
        return
    var order_id: String = _get_selected_order_id()
    var cost: float = float(_order_costs.get(order_id, 0.0))
    var competence_ready := _has_competence_for_order(order_id)
    var can_execute: bool = not order_id.is_empty() and _elan_state.get("current", 0.0) >= cost and cost >= 0.0 and competence_ready
    execute_order_button.disabled = not can_execute
    var label_text := "Exécuter l'ordre"
    if cost > 0.0:
        label_text = "Exécuter (%.1f Élan)" % cost
    execute_order_button.text = label_text
    var tooltip_text := "Exécuter l'ordre sélectionné."
    if order_id.is_empty():
        tooltip_text = "Sélectionnez un ordre à exécuter."
    elif cost > _elan_state.get("current", 0.0):
        tooltip_text = "Élan insuffisant : %.1f requis, %.1f disponible." % [cost, _elan_state.get("current", 0.0)]
    elif not competence_ready:
        tooltip_text = _competence_shortfall_tooltip(order_id)
    execute_order_button.tooltip_text = tooltip_text

func _on_execute_order_pressed() -> void:
    if event_bus == null:
        return
    var order_id: String = _get_selected_order_id()
    if order_id.is_empty():
        _set_feedback("Choisissez un ordre à exécuter.", false)
        _play_feedback(200.0)
        return
    event_bus.request_order_execution(order_id)

func _on_data_loader_ready(payload: Dictionary) -> void:
    var collections: Dictionary = payload.get("collections", {})
    _populate_doctrines(collections.get("doctrines", []))
    _populate_orders(collections.get("orders", []))
    if data_loader:
        _refresh_terrain_tooltip(data_loader.list_terrain_definitions(), data_loader.list_terrain_tiles())
        _setup_formation_panel()

func _on_doctrine_selected(payload: Dictionary) -> void:
    var doctrine_id: String = payload.get("id", "")
    _update_doctrine_selector_state(doctrine_id)
    var name: String = _doctrine_names.get(doctrine_id, payload.get("name", doctrine_id))
    var inertia_remaining: int = int(payload.get("inertia_remaining", 0))
    var inertia_multiplier: float = float(payload.get("inertia_multiplier", 1.0))
    var swap_tokens: int = int(payload.get("swap_token_budget", 0))
    var elan_cap_bonus: float = float(payload.get("elan_cap_bonus", 0.0))
    _doctrine_state = {
        "id": doctrine_id,
        "name": name,
        "inertia_remaining": inertia_remaining,
        "inertia_multiplier": inertia_multiplier,
        "swap_tokens": swap_tokens,
        "elan_cap_bonus": elan_cap_bonus,
    }
    if doctrine_status_label:
        doctrine_status_label.text = "Doctrine : %s — Inertie %d tour(s)" % [name, inertia_remaining]
        doctrine_status_label.tooltip_text = "Tokens de swap restants : %d\nBonus de cap Élan : %.1f" % [swap_tokens, elan_cap_bonus]
    if inertia_label:
        inertia_label.text = "Inertie : %d tour(s) · x%.2f" % [
            max(inertia_remaining, 0),
            inertia_multiplier,
        ]
        inertia_label.tooltip_text = "Les ordres appliquent au minimum %d tour(s) d'inertie.\nMultiplicateur doctrine : x%.2f" % [
            max(inertia_remaining, 0),
            inertia_multiplier,
        ]
    var allowed: Array = payload.get("allowed_orders", [])
    _refresh_order_selector(allowed)
    _set_feedback("Doctrine active : %s" % name, true)
    _play_feedback(660.0)

func _on_elan_updated(payload: Dictionary) -> void:
    _elan_state = {
        "current": float(payload.get("current", 0.0)),
        "max": float(payload.get("max", 0.0)),
        "income": float(payload.get("income", 0.0)),
        "upkeep": float(payload.get("upkeep", 0.0)),
        "cap_bonus": float(payload.get("cap_bonus", 0.0)),
        "rounds_at_cap": int(payload.get("rounds_at_cap", 0)),
        "decay_amount": float(payload.get("decay_amount", 0.0)),
    }
    if elan_label:
        var income: float = _elan_state.get("income", 0.0)
        var upkeep: float = _elan_state.get("upkeep", 0.0)
        elan_label.text = "Élan : %.1f / %.1f (↗ %.1f | ↘ %.1f)" % [
            _elan_state.get("current", 0.0),
            max(_elan_state.get("max", 0.0), 0.0),
            income,
            upkeep,
        ]
        var base_cap: float = _elan_state.get("max", 0.0) - _elan_state.get("cap_bonus", 0.0)
        var rounds_at_cap: int = _elan_state.get("rounds_at_cap", 0)
        var decay_amount: float = _elan_state.get("decay_amount", 0.0)
        var tooltip_lines: Array[String] = [
            "Cap de base : %.1f" % max(base_cap, 0.0),
            "Bonus doctrine : %.1f" % _elan_state.get("cap_bonus", 0.0),
            "Tours passés au cap : %d" % max(rounds_at_cap, 0),
            "Décroissance programmée : %.1f" % max(decay_amount, 0.0),
        ]
        if rounds_at_cap > 0:
            tooltip_lines.append("Décay imminent au prochain tour si aucun Élan n'est dépensé.")
        elan_label.tooltip_text = "\n".join(tooltip_lines)
    _refresh_order_button_state()
    _formation_available_elan = _elan_state.get("current", _formation_available_elan)
    _refresh_all_formation_rows()

func _on_order_issued(payload: Dictionary) -> void:
    var order_id := str(payload.get("order_id", ""))
    if not order_id.is_empty():
        _last_order_payloads[order_id] = payload.duplicate(true)
    var name: String = payload.get("order_name", payload.get("order_id", ""))
    var remaining: float = float(payload.get("remaining", 0.0))
    _set_feedback("Ordre '%s' exécuté (%.1f Élan restant)" % [name, remaining], true)
    _play_feedback(520.0)

func _on_order_execution_failed(payload: Dictionary) -> void:
    var reason: String = str(payload.get("reason", "unknown"))
    match reason:
        "doctrine_locked":
            _set_feedback("Doctrine verrouillée par l'inertie (%d tour(s))." % int(payload.get("inertia_remaining", 0)), false)
            _update_doctrine_selector_state(str(_doctrine_state.get("id", "")))
        "insufficient_elan":
            var needed: float = float(payload.get("required", 0.0))
            var available: float = float(payload.get("available", 0.0))
            _set_feedback("Élan insuffisant : %.1f requis, %.1f disponible." % [needed, available], false)
        "insufficient_competence":
            var message := _competence_shortfall_tooltip(str(payload.get("order_id", "")))
            if message.is_empty():
                message = "Compétence insuffisante pour cet ordre."
            _set_feedback(message, false)
        _:
            _set_feedback("Ordre indisponible.", false)
    _play_feedback(220.0)

func _on_combat_resolved(payload: Dictionary) -> void:
    _last_combat_payload = payload.duplicate(true)
    _update_combat_panel()

func _on_espionage_ping(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var entry: Dictionary = payload.duplicate(true)
    _intel_events.append(entry)
    while _intel_events.size() > MAX_INTEL_EVENTS:
        _intel_events.remove_at(0)
    _update_intel_panel()
    var positive := bool(entry.get("success", false))
    _play_feedback(520.0 if positive else 180.0)

func _on_intel_intent_revealed(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var entry: Dictionary = payload.duplicate(true)
    entry["event_name"] = "intel_intent_revealed"
    if not entry.has("success"):
        entry["success"] = true
    if not entry.has("intent_category"):
        entry["intent_category"] = entry.get("intention", "unknown")
    _intel_events.append(entry)
    while _intel_events.size() > MAX_INTEL_EVENTS:
        _intel_events.remove_at(0)
    _update_intel_panel()
    _play_feedback(600.0)

func _on_formation_changed(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var reason := str(payload.get("reason", ""))
    if reason != "manual":
        return
    var unit_id := str(payload.get("unit_id", ""))
    var formation_name := str(payload.get("formation_name", payload.get("formation_id", "")))
    var unit_name := _formation_unit_name(unit_id)
    _set_feedback("%s adopte la formation %s." % [unit_name, formation_name], true)
    _play_feedback(560.0)

func _on_formation_change_failed(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var reason := str(payload.get("reason", "unknown"))
    var unit_id := str(payload.get("unit_id", ""))
    var unit_name := _formation_unit_name(unit_id)
    match reason:
        "insufficient_elan":
            var required := float(payload.get("required", payload.get("elan_cost", 0.0)))
            var available := float(payload.get("available", _formation_available_elan))
            _set_feedback("Élan insuffisant pour %s : %.1f requis, %.1f disponible." % [unit_name, required, available], false)
        "inertia_locked":
            var remaining := int(payload.get("turns_remaining", 0))
            _set_feedback("%s reste verrouillée %d tour(s) avant le prochain changement." % [unit_name, max(remaining, 0)], false)
        "formation_not_allowed":
            _set_feedback("%s ne peut pas adopter cette formation." % unit_name, false)
        "unknown_formation":
            _set_feedback("Formation inconnue.", false)
        "unknown_unit":
            _set_feedback("Unité inconnue pour le changement de formation.", false)
        "not_allowed":
            _set_feedback("Impossible d'appliquer la formation sélectionnée à %s." % unit_name, false)
        _:
            _set_feedback("Changement de formation refusé.", false)
    _refresh_formation_row(unit_id)
    _play_feedback(180.0)

func _on_elan_spent(payload: Dictionary) -> void:
    var amount: float = -abs(float(payload.get("amount", 0.0)))
    var entry: Dictionary = {
        "amount": amount,
        "remaining": float(payload.get("remaining", payload.get("current", 0.0))),
        "reason": str(payload.get("reason", "order_cost")),
        "order_id": str(payload.get("order_id", "")),
    }
    _last_elan_event = entry.duplicate(true)
    var order_id: String = str(entry.get("order_id", ""))
    if not order_id.is_empty():
        _elan_adjustments[order_id] = entry.duplicate(true)
    _update_combat_panel()

func _on_elan_gained(payload: Dictionary) -> void:
    _last_elan_gain = {
        "amount": max(float(payload.get("amount", 0.0)), 0.0),
        "reason": str(payload.get("reason", "")),
        "current": float(payload.get("current", 0.0)),
        "previous": float(payload.get("previous", 0.0)),
        "metadata": payload.get("metadata", {}).duplicate(true) if payload.has("metadata") and payload.get("metadata") is Dictionary else {},
    }
    _update_combat_panel()

func _on_competence_reallocated(payload: Dictionary) -> void:
    _competence_state = payload.duplicate(true)
    if _competence_rows.is_empty():
        _setup_competence_panel()
    else:
        _update_competence_panel()
    var reason := str(payload.get("reason", ""))
    if reason == "manual":
        _set_feedback("Compétence redistribuée.", true)
        _play_feedback(520.0)
    _refresh_order_button_state()

func _on_competence_allocation_failed(payload: Dictionary) -> void:
    var reason := str(payload.get("reason", "unknown"))
    var message := ""
    match reason:
        "inertia_locked":
            var category := str(payload.get("category", ""))
            var turns := int(payload.get("turns_remaining", 0))
            message = "Verrou d'inertie sur %s (%d tour(s) restant(s))." % [_competence_display_name(category), turns]
            _focus_competence_slider(category)
        "delta_exceeds_cap":
            var category_delta := str(payload.get("category", ""))
            var max_delta := float(payload.get("max_delta", 0.0))
            message = "Delta maximal dépassé pour %s (≤ %.2f pts/ tour)." % [_competence_display_name(category_delta), max_delta]
            _focus_competence_slider(category_delta)
        "over_budget":
            var requested := float(payload.get("requested", 0.0))
            var budget := float(payload.get("budget", 0.0))
            message = "Budget compétence dépassé : %.2f / %.2f pts." % [requested, budget]
        _:
            message = "Réallocation compétence refusée (%s)." % reason
    _set_feedback(message, false)
    _play_feedback(200.0)
    _update_competence_panel()

func _update_doctrine_selector_state(selected_id := "") -> void:
    if doctrine_selector == null:
        return
    _suppress_doctrine_selector_signal = true
    if selected_id.is_empty():
        if doctrine_selector.get_item_count() > 0:
            doctrine_selector.select(0)
    elif _doctrine_lookup.has(selected_id):
        doctrine_selector.select(int(_doctrine_lookup.get(selected_id)))
    _suppress_doctrine_selector_signal = false

func _get_selected_order_id() -> String:
    if order_selector == null or order_selector.get_item_count() == 0:
        return ""
    var index: int = order_selector.get_selected()
    if index < 0:
        return ""
    var metadata: Variant = order_selector.get_item_metadata(index)
    if typeof(metadata) == TYPE_STRING:
        return metadata
    return ""

func _set_feedback(message: String, positive: bool) -> void:
    if feedback_label == null:
        return
    feedback_label.text = message
    var color: Color = Color(0.7, 0.9, 1.0) if positive else Color(1.0, 0.65, 0.5)
    feedback_label.add_theme_color_override("font_color", color)

func _update_intel_panel() -> void:
    if intel_summary_label == null or intel_log == null:
        return
    if _intel_events.is_empty():
        intel_summary_label.text = "Aucun ping renseignement disponible."
        intel_summary_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
        intel_log.clear()
        return

    var latest: Dictionary = _intel_events.back()
    var intention_code := str(latest.get("intent_category", latest.get("intention", "unknown")))
    var summary := _format_intel_summary(latest)
    intel_summary_label.text = summary
    intel_summary_label.add_theme_color_override("font_color", _intention_color(intention_code))

    intel_log.clear()
    for entry in _intel_events:
        var line := _format_intel_log_entry(entry)
        if line.is_empty():
            continue
        intel_log.append_text("%s\n" % line)
    var line_count := intel_log.get_line_count()
    if line_count > 0:
        intel_log.scroll_to_line(line_count - 1)

func _format_intel_summary(entry: Dictionary) -> String:
    var order_id := str(entry.get("source", entry.get("order_id", "")))
    var order_name := _lookup_order_name(order_id)
    var target := _format_target(str(entry.get("target", "")))
    var success := bool(entry.get("success", false))
    var intention_code := str(entry.get("intent_category", entry.get("intention", "unknown")))
    var intention_label := _intention_label(intention_code)
    var confidence_percent := _format_percent(float(entry.get("confidence", 0.0)))
    var roll_percent := _format_percent(float(entry.get("roll", 0.0)))
    var headline := order_name if order_name != "" else "Ping"
    if success:
        return "%s : %s révélé sur %s (p=%s | jet=%s)" % [headline, intention_label, target, confidence_percent, roll_percent]
    return "%s : contre-mesures sur %s (p=%s | jet=%s)" % [headline, target, confidence_percent, roll_percent]

func _format_intel_log_entry(entry: Dictionary) -> String:
    var turn_number := int(entry.get("turn", 0))
    var target := _format_target(str(entry.get("target", "")))
    var success := bool(entry.get("success", false))
    var intention_code := str(entry.get("intent_category", entry.get("intention", "unknown")))
    var intention_label := _intention_label(intention_code)
    var confidence_display := _format_percent(float(entry.get("confidence", 0.0)))
    var intention_confidence := _format_percent(float(entry.get("intention_confidence", entry.get("confidence", 0.0))))
    var visibility_before := _format_percent(float(entry.get("visibility_before", 0.0)))
    var visibility_after := _format_percent(float(entry.get("visibility_after", entry.get("visibility_before", 0.0))))
    var noise_percent := _format_percent(float(entry.get("noise", 0.0)))
    var detection_bonus := _format_percent(float(entry.get("detection_bonus", 0.0)))
    var roll_display := _format_percent(float(entry.get("roll", 0.0)))
    var parts := []
    parts.append("T%02d" % turn_number)
    parts.append(target)
    parts.append("%s" % ("Succès" if success else "Échec"))
    if success:
        parts.append(intention_label)
    parts.append("Conf %s" % confidence_display)
    parts.append("Int %s" % intention_confidence)
    parts.append("Jet %s" % roll_display)
    parts.append("Vis %s→%s" % [visibility_before, visibility_after])
    parts.append("Bruit %s" % noise_percent)
    if detection_bonus != "0%":
        parts.append("Bonus %s" % detection_bonus)
    return " | ".join(parts)

func _lookup_order_name(order_id: String) -> String:
    if order_id.is_empty():
        return ""
    if _order_lookup.has(order_id):
        var entry: Dictionary = _order_lookup.get(order_id)
        return str(entry.get("name", order_id))
    return order_id

func _format_target(target: String) -> String:
    return target if not target.is_empty() else "hex inconnu"

func _format_percent(value: float) -> String:
    var percent := clamp(roundi(value * 100.0), -999, 999)
    return "%d%%" % percent

func _intention_label(code: String) -> String:
    var key := code if INTEL_INTENTION_NAMES.has(code) else "unknown"
    return str(INTEL_INTENTION_NAMES.get(key, "Inconnue"))

func _intention_color(code: String) -> Color:
    var key := code if INTEL_INTENTION_COLORS.has(code) else "unknown"
    return INTEL_INTENTION_COLORS.get(key, INTEL_INTENTION_COLORS.get("unknown"))

func _play_feedback(pitch_hz: float) -> void:
    if feedback_player == null:
        return
    _pending_feedback_pitches.append(pitch_hz)
    if _feedback_flush_scheduled:
        return
    _feedback_flush_scheduled = true
    call_deferred("_process_feedback_queue")

func _process_feedback_queue() -> void:
    _feedback_flush_scheduled = false
    if feedback_player == null:
        _pending_feedback_pitches.clear()
        return
    if _pending_feedback_pitches.is_empty():
        return
    var playback := _ensure_feedback_playback()
    if playback == null:
        _pending_feedback_pitches.clear()
        return
    if feedback_player.playing:
        feedback_player.stop()
    if playback.active:
        playback.stop()
        if playback.active:
            _feedback_flush_scheduled = true
            call_deferred("_process_feedback_queue")
            return
    playback.clear_buffer()
    var pitch: float = _pending_feedback_pitches.pop_front()
    _synth_feedback_tone(playback, pitch)
    feedback_player.play()
    if not _pending_feedback_pitches.is_empty():
        _feedback_flush_scheduled = true
        call_deferred("_process_feedback_queue")

func _ensure_feedback_playback() -> AudioStreamGeneratorPlayback:
    if feedback_player == null:
        return null
    if _feedback_generator == null or feedback_player.stream == null or feedback_player.stream != _feedback_generator:
        _feedback_generator = AudioStreamGenerator.new()
        _feedback_generator.mix_rate = FEEDBACK_SAMPLE_RATE
        _feedback_generator.buffer_length = FEEDBACK_DURATION * 2.0
        feedback_player.stream = _feedback_generator
    if not feedback_player.playing:
        feedback_player.play()
    var playback: AudioStreamPlayback = feedback_player.get_stream_playback()
    if playback is AudioStreamGeneratorPlayback:
        return playback
    return null

func _synth_feedback_tone(playback: AudioStreamGeneratorPlayback, pitch_hz: float) -> void:
    var generator := _feedback_generator
    if generator == null:
        return
    var mix_rate: float = max(generator.mix_rate, 1.0)
    var frame_count: int = int(mix_rate * FEEDBACK_DURATION)
    for i in frame_count:
        var t: float = float(i) / mix_rate
        var envelope: float = clamp(1.0 - t * 8.0, 0.0, 1.0)
        var sample: float = sin(TAU * pitch_hz * t) * FEEDBACK_VOLUME * envelope
        playback.push_frame(Vector2(sample, sample))

func _initialise_combat_panel() -> void:
    if combat_panel == null:
        return
    _pillar_rows = {
        "position": {
            "meter": position_meter,
            "label": position_result_label,
        },
        "impulse": {
            "meter": impulse_meter,
            "label": impulse_result_label,
        },
        "information": {
            "meter": information_meter,
            "label": information_result_label,
        },
    }
    for pillar_id in _pillar_rows.keys():
        var row: Dictionary = _pillar_rows.get(pillar_id, {})
        var meter: ProgressBar = row.get("meter", null)
        if meter:
            meter.min_value = 0.0
            meter.max_value = 100.0
            meter.step = 0.1
            meter.show_percentage = false
            meter.add_theme_color_override("fg_color", PILLAR_NEUTRAL_COLOR)
            meter.add_theme_color_override("bg_color", PILLAR_BACKGROUND_COLOR)
        _set_pillar_row_default(pillar_id)
    if combat_summary_label:
        combat_summary_label.text = "Aucun engagement résolu pour l'instant."
        combat_summary_label.tooltip_text = "Lancez un ordre pour afficher la dernière résolution."
    if combat_logistics_label:
        combat_logistics_label.text = "Logistique : en attente de données."
        combat_logistics_label.tooltip_text = "Les facteurs supply apparaîtront après la première résolution."
    if combat_elan_label:
        combat_elan_label.text = "Élan : aucune variation enregistrée."
        combat_elan_label.tooltip_text = "Les dépenses/gains liés au combat s'afficheront ici."

func _update_combat_panel() -> void:
    if combat_panel == null or _pillar_rows.is_empty():
        return
    if _last_combat_payload.is_empty():
        for pillar_id in _pillar_rows.keys():
            _set_pillar_row_default(pillar_id)
        if combat_summary_label:
            combat_summary_label.text = "Aucun engagement résolu pour l'instant."
            combat_summary_label.tooltip_text = "Lancez un ordre pour afficher la dernière résolution."
        if combat_logistics_label:
            combat_logistics_label.text = "Logistique : en attente de données."
            combat_logistics_label.tooltip_text = "Les facteurs supply apparaîtront après la première résolution."
        if combat_elan_label:
            var elan_defaults := _elan_summary_for_order("")
            combat_elan_label.text = elan_defaults.get("text", "Élan : aucune variation enregistrée.")
            combat_elan_label.tooltip_text = elan_defaults.get("tooltip", "")
        return

    var victor := str(_last_combat_payload.get("victor", "stalemate"))
    var order_id := str(_last_combat_payload.get("order_id", ""))
    var order_entry: Dictionary = _order_lookup.get(order_id, {})
    var order_payload: Dictionary = _last_order_payloads.get(order_id, {})
    var order_name := str(order_payload.get("order_name", order_entry.get("name", order_id))) if order_id != "" else ""
    var summary_lines: Array[String] = []
    var victor_label := _localize_victor(victor)
    if victor == "stalemate":
        summary_lines.append("Issue : confrontation %s" % victor_label)
    else:
        var base_line := "Victoire %s" % victor_label
        if not order_name.is_empty():
            base_line += " — ordre %s" % order_name
        summary_lines.append(base_line)
    if victor == "stalemate" and not order_name.is_empty():
        summary_lines[summary_lines.size() - 1] += " — ordre %s" % order_name

    var decisive: Array[String] = _decisive_pillars(_last_combat_payload.get("pillars", {}), victor)
    if not decisive.is_empty():
        summary_lines.append("Piliers décisifs : %s" % ", ".join(decisive))

    var intel_line := _format_intel_line(_last_combat_payload.get("intel", {}))
    if not intel_line.is_empty():
        summary_lines.append(intel_line)

    var context_bits: Array[String] = []
    var doctrine_id := str(_last_combat_payload.get("doctrine_id", ""))
    if not doctrine_id.is_empty():
        var doctrine_name: String = str(_doctrine_names.get(doctrine_id, doctrine_id.capitalize()))
        context_bits.append("Doctrine %s" % doctrine_name)
    var weather_id := str(_last_combat_payload.get("weather_id", ""))
    if not weather_id.is_empty():
        context_bits.append("Météo %s" % weather_id.capitalize())
    if not context_bits.is_empty():
        summary_lines.append("Contexte : %s" % ", ".join(context_bits))

    if combat_summary_label:
        combat_summary_label.text = "\n".join(summary_lines)
        var engagement_id := str(_last_combat_payload.get("engagement_id", "skirmish"))
        combat_summary_label.tooltip_text = "Engagement %s" % engagement_id

    var logistics_summary := _format_logistics_line(_last_combat_payload.get("logistics", {}))
    if combat_logistics_label:
        combat_logistics_label.text = logistics_summary.get("text", "Logistique : données indisponibles.")
        combat_logistics_label.tooltip_text = logistics_summary.get("tooltip", "")

    if combat_elan_label:
        var elan_summary := _elan_summary_for_order(order_id)
        combat_elan_label.text = elan_summary.get("text", "Élan : aucune variation enregistrée.")
        combat_elan_label.tooltip_text = elan_summary.get("tooltip", "")

    var pillars: Dictionary = _last_combat_payload.get("pillars", {})
    for pillar_id in PILLAR_DISPLAY_NAMES.keys():
        var result_dict: Dictionary = {}
        var result_variant: Variant = pillars.get(pillar_id, {})
        if result_variant is Dictionary:
            result_dict = result_variant
        if result_dict.is_empty():
            _set_pillar_row_default(pillar_id)
        else:
            _update_pillar_row(pillar_id, result_dict, victor)

func _set_pillar_row_default(pillar_id: String) -> void:
    var row: Dictionary = _pillar_rows.get(pillar_id, {})
    var meter: ProgressBar = row.get("meter", null)
    var label: Label = row.get("label", null)
    if meter:
        meter.value = 0.0
        meter.add_theme_color_override("fg_color", PILLAR_NEUTRAL_COLOR)
        meter.add_theme_color_override("bg_color", PILLAR_BACKGROUND_COLOR)
        meter.tooltip_text = "En attente de résolution."
    if label:
        label.text = "—"
        label.tooltip_text = "Aucun résultat disponible."

func _update_pillar_row(pillar_id: String, result: Dictionary, victor: String) -> void:
    var row: Dictionary = _pillar_rows.get(pillar_id, {})
    var meter: ProgressBar = row.get("meter", null)
    var label: Label = row.get("label", null)
    if meter == null or label == null:
        return
    var attacker: float = max(float(result.get("attacker", 0.0)), 0.0)
    var defender: float = max(float(result.get("defender", 0.0)), 0.0)
    var total: float = max(attacker + defender, 0.001)
    var ratio: float = attacker / total
    meter.value = clamp(ratio * meter.max_value, meter.min_value, meter.max_value)
    var winner: String = str(result.get("winner", "stalemate"))
    var winner_label: String = _localize_victor(winner)
    label.text = "Att %.2f / Def %.2f — %s" % [attacker, defender, winner_label]
    label.tooltip_text = "Marge : %.2f" % float(result.get("margin", 0.0))
    meter.add_theme_color_override("fg_color", _pillar_color_for_winner(winner))
    meter.tooltip_text = "%s — avantage %.1f%%" % [PILLAR_DISPLAY_NAMES.get(pillar_id, pillar_id.capitalize()), meter.value]

func _pillar_color_for_winner(winner: String) -> Color:
    if PILLAR_WINNER_COLORS.has(winner):
        return PILLAR_WINNER_COLORS.get(winner, PILLAR_NEUTRAL_COLOR)
    return PILLAR_NEUTRAL_COLOR

func _decisive_pillars(pillars: Dictionary, victor: String) -> Array[String]:
    var decisive: Array[String] = []
    for pillar_id in PILLAR_DISPLAY_NAMES.keys():
        var entry: Dictionary = pillars.get(pillar_id, {})
        if not (entry is Dictionary):
            continue
        var winner: String = str(entry.get("winner", "stalemate"))
        if victor == "attacker" or victor == "defender":
            if winner == victor:
                decisive.append(PILLAR_DISPLAY_NAMES.get(pillar_id, pillar_id.capitalize()))
        elif victor == "contested":
            if winner == "attacker" or winner == "defender":
                decisive.append("%s (%s)" % [PILLAR_DISPLAY_NAMES.get(pillar_id, pillar_id.capitalize()), _localize_victor(winner)])
        else:
            decisive.append("%s (%s)" % [PILLAR_DISPLAY_NAMES.get(pillar_id, pillar_id.capitalize()), _localize_victor(winner)])
    return decisive

func _localize_victor(value: String) -> String:
    return VICTOR_LABELS.get(value, value)

func _format_intel_line(intel: Dictionary) -> String:
    if intel.is_empty():
        return ""
    var confidence: float = clamp(float(intel.get("confidence", 0.0)), 0.0, 1.0)
    var source: String = str(intel.get("source", "baseline"))
    var pretty_source: String = source.replace("_", " ").capitalize()
    return "Intel : %.0f%% (%s)" % [confidence * 100.0, pretty_source]

func _format_logistics_line(logistics: Dictionary) -> Dictionary:
    if not (logistics is Dictionary) or logistics.is_empty():
        return {
            "text": "Logistique : données indisponibles.",
            "tooltip": "Aucune information supply transmise par `combat_resolved`.",
        }
    var flow: float = float(logistics.get("logistics_flow", 0.0))
    var severity_id: String = str(logistics.get("severity", ""))
    var severity: String = _localize_severity(severity_id)
    var movement: float = float(logistics.get("movement_cost", 1.0))
    var attacker_factor: float = float(logistics.get("attacker_factor", 1.0))
    var defender_factor: float = float(logistics.get("defender_factor", 1.0))
    var supply_level: String = str(logistics.get("supply_level", ""))
    var target_hex: String = str(logistics.get("target_hex", ""))
    var text: String = "Logistique : flow %.2f · sévérité %s · att %.2f / def %.2f" % [
        flow,
        severity,
        attacker_factor,
        defender_factor,
    ]
    var tooltip_lines: Array[String] = []
    if not supply_level.is_empty():
        tooltip_lines.append("Niveau supply : %s" % supply_level)
    tooltip_lines.append("Coût de mouvement : %.2f" % movement)
    if not severity_id.is_empty():
        tooltip_lines.append("Sévérité brute : %s" % severity_id)
    if not target_hex.is_empty():
        tooltip_lines.append("Hex cible : %s" % target_hex)
    var turn: int = int(logistics.get("turn", -1))
    if turn >= 0:
        tooltip_lines.append("Tour logistique : %d" % turn)
    var logistics_id: String = str(logistics.get("logistics_id", ""))
    if not logistics_id.is_empty():
        tooltip_lines.append("Scenario supply : %s" % logistics_id)
    return {
        "text": text,
        "tooltip": "\n".join(tooltip_lines),
    }

func _elan_summary_for_order(order_id: String) -> Dictionary:
    var text_lines: Array[String] = []
    var tooltip_lines: Array[String] = []
    if not order_id.is_empty():
        var adjustment: Dictionary = _elan_adjustments.get(order_id, {})
        if adjustment is Dictionary and not adjustment.is_empty():
            var amount: float = float(adjustment.get("amount", 0.0))
            var remaining: float = float(adjustment.get("remaining", 0.0))
            var direction: String = "-" if amount <= 0.0 else "+"
            var order_entry: Dictionary = _order_lookup.get(order_id, {})
            var order_payload: Dictionary = _last_order_payloads.get(order_id, {})
            var order_name: String = str(order_payload.get("order_name", order_entry.get("name", order_id)))
            text_lines.append("Élan dépensé : %s%.1f (%s). Reste %.1f." % [direction, abs(amount), order_name, remaining])
            tooltip_lines.append("Raison : %s" % _localize_reason(str(adjustment.get("reason", "order_cost"))))
        elif _last_elan_event is Dictionary and not _last_elan_event.is_empty():
            var event_amount: float = float(_last_elan_event.get("amount", 0.0))
            if not is_equal_approx(event_amount, 0.0):
                text_lines.append("Élan récent : %.1f (raison %s)." % [event_amount, _localize_reason(str(_last_elan_event.get("reason", "")))])
    if text_lines.is_empty():
        text_lines.append("Élan : aucune variation enregistrée pour cet engagement.")
    if _last_elan_gain is Dictionary and not _last_elan_gain.is_empty():
        var gain_amount: float = float(_last_elan_gain.get("amount", 0.0))
        if gain_amount > 0.0:
            var gain_reason: String = _localize_reason(str(_last_elan_gain.get("reason", "")))
            text_lines.append("Dernier gain : +%.1f (%s)." % [gain_amount, gain_reason])
            tooltip_lines.append("Gain courant : %.1f" % float(_last_elan_gain.get("current", 0.0)))
    return {
        "text": "\n".join(text_lines),
        "tooltip": "\n".join(tooltip_lines),
    }

func _localize_severity(severity: String) -> String:
    match severity:
        "warning":
            return "avertissement"
        "critical":
            return "critique"
        "":
            return "stable"
        _:
            return severity

func _localize_reason(reason: String) -> String:
    match reason:
        "order_cost":
            return "coût d'ordre"
        "decay":
            return "décroissance"
        "manual":
            return "ajustement manuel"
        _:
            return reason if not reason.is_empty() else "non spécifié"

func _has_competence_for_order(order_id: String) -> bool:
    if order_id.is_empty():
        return true
    var order: Dictionary = _order_lookup.get(order_id, {})
    var cost_variant: Variant = order.get("competence_cost", {})
    if not (cost_variant is Dictionary):
        return true
    var costs: Dictionary = cost_variant as Dictionary
    if costs.is_empty():
        return true
    var allocations_variant: Variant = _competence_state.get("allocations", {})
    var allocations: Dictionary = allocations_variant if allocations_variant is Dictionary else {}
    for category in costs.keys():
        var required: float = float(costs.get(category, 0.0))
        if required <= 0.0:
            continue
        var available: float = float(allocations.get(category, 0.0))
        if required > available + 0.001:
            return false
    return true

func _competence_shortfall_tooltip(order_id: String) -> String:
    if order_id.is_empty():
        return ""
    var order: Dictionary = _order_lookup.get(order_id, {})
    var cost_variant: Variant = order.get("competence_cost", {})
    if not (cost_variant is Dictionary):
        return ""
    var costs: Dictionary = cost_variant as Dictionary
    if costs.is_empty():
        return ""
    var allocations_variant: Variant = _competence_state.get("allocations", {})
    var allocations: Dictionary = allocations_variant if allocations_variant is Dictionary else {}
    if allocations.is_empty():
        return "Compétence indisponible : budget non alloué."
    var shortfalls: Array[String] = []
    for category in costs.keys():
        var required: float = float(costs.get(category, 0.0))
        if required <= 0.0:
            continue
        var available: float = float(allocations.get(category, 0.0))
        if required > available + 0.001:
            shortfalls.append("%s %.1f/%.1f" % [String(category).capitalize(), available, required])
    if shortfalls.is_empty():
        var summary := _format_competence_cost(costs)
        return "Budget compétence requis : %s" % summary if not summary.is_empty() else "Budget compétence requis."
    return "Compétence insuffisante (%s)." % ", ".join(shortfalls)

func _format_competence_cost(cost_variant: Variant) -> String:
    if not (cost_variant is Dictionary):
        return ""
    var costs: Dictionary = cost_variant as Dictionary
    if costs.is_empty():
        return ""
    var parts: Array[String] = []
    for category in costs.keys():
        var amount: float = float(costs.get(category, 0.0))
        if amount <= 0.0:
            continue
        parts.append("%s %.1f" % [String(category).capitalize(), amount])
    return ", ".join(parts)

func _stop_feedback_stream() -> void:
    _pending_feedback_pitches.clear()
    _feedback_flush_scheduled = false
    if feedback_player == null:
        return
    if feedback_player.playing:
        feedback_player.stop()
    var playback: AudioStreamPlayback = feedback_player.get_stream_playback()
    if playback is AudioStreamGeneratorPlayback:
        playback.stop()
        if not playback.active:
            playback.clear_buffer()

func _exit_tree() -> void:
    _stop_feedback_stream()
