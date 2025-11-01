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
@onready var combat_panel: PanelContainer = $MarginContainer/VBoxContainer/CombatPanel
@onready var combat_summary_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/CombatSummaryLabel
@onready var combat_logistics_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/CombatLogisticsLabel
@onready var combat_elan_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/CombatElanLabel
@onready var position_meter: ProgressBar = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/PositionRow/PositionMeter
@onready var position_result_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/PositionRow/PositionResultLabel
@onready var impulse_meter: ProgressBar = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/ImpulseRow/ImpulseMeter
@onready var impulse_result_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/ImpulseRow/ImpulseResultLabel
@onready var information_meter: ProgressBar = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/InformationRow/InformationMeter
@onready var information_result_label: Label = $MarginContainer/VBoxContainer/CombatPanel/VBoxContainer/PillarContainer/InformationRow/InformationResultLabel

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
    _connect_event_bus()
    _populate_from_data_loader()
    _initialise_combat_panel()
    _set_feedback("", true)

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

func _populate_from_data_loader() -> void:
    if data_loader == null or not data_loader.is_ready():
        return
    _populate_doctrines(data_loader.list_doctrines())
    _populate_orders(data_loader.list_orders())
    _refresh_terrain_tooltip(data_loader.list_terrain_definitions(), data_loader.list_terrain_tiles())
    _update_weather_panel()

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
            order_selector.add_item("%s (%.1f Élan)" % [name, cost])
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
    var can_execute: bool = not order_id.is_empty() and _elan_state.get("current", 0.0) >= cost and cost >= 0.0
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
        _:
            _set_feedback("Ordre indisponible.", false)
    _play_feedback(220.0)

func _on_combat_resolved(payload: Dictionary) -> void:
    _last_combat_payload = payload.duplicate(true)
    _update_combat_panel()

func _on_elan_spent(payload: Dictionary) -> void:
    var amount := -abs(float(payload.get("amount", 0.0)))
    var entry := {
        "amount": amount,
        "remaining": float(payload.get("remaining", payload.get("current", 0.0))),
        "reason": str(payload.get("reason", "order_cost")),
        "order_id": str(payload.get("order_id", "")),
    }
    _last_elan_event = entry.duplicate(true)
    var order_id := str(entry.get("order_id", ""))
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
        var doctrine_name := _doctrine_names.get(doctrine_id, doctrine_id.capitalize())
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
    var attacker := max(float(result.get("attacker", 0.0)), 0.0)
    var defender := max(float(result.get("defender", 0.0)), 0.0)
    var total := max(attacker + defender, 0.001)
    meter.value = clamp((attacker / total) * meter.max_value, meter.min_value, meter.max_value)
    var winner := str(result.get("winner", "stalemate"))
    var winner_label := _localize_victor(winner)
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
        var winner := str(entry.get("winner", "stalemate"))
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
    var confidence := clamp(float(intel.get("confidence", 0.0)), 0.0, 1.0)
    var source := str(intel.get("source", "baseline"))
    var pretty_source := source.replace("_", " ").capitalize()
    return "Intel : %.0f%% (%s)" % [confidence * 100.0, pretty_source]

func _format_logistics_line(logistics: Dictionary) -> Dictionary:
    if not (logistics is Dictionary) or logistics.is_empty():
        return {
            "text": "Logistique : données indisponibles.",
            "tooltip": "Aucune information supply transmise par `combat_resolved`.",
        }
    var flow := float(logistics.get("logistics_flow", 0.0))
    var severity_id := str(logistics.get("severity", ""))
    var severity := _localize_severity(severity_id)
    var movement := float(logistics.get("movement_cost", 1.0))
    var attacker_factor := float(logistics.get("attacker_factor", 1.0))
    var defender_factor := float(logistics.get("defender_factor", 1.0))
    var supply_level := str(logistics.get("supply_level", ""))
    var target_hex := str(logistics.get("target_hex", ""))
    var text := "Logistique : flow %.2f · sévérité %s · att %.2f / def %.2f" % [
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
    var turn := int(logistics.get("turn", -1))
    if turn >= 0:
        tooltip_lines.append("Tour logistique : %d" % turn)
    var logistics_id := str(logistics.get("logistics_id", ""))
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
            var amount := float(adjustment.get("amount", 0.0))
            var remaining := float(adjustment.get("remaining", 0.0))
            var direction := "-" if amount <= 0.0 else "+"
            var order_entry: Dictionary = _order_lookup.get(order_id, {})
            var order_payload: Dictionary = _last_order_payloads.get(order_id, {})
            var order_name := str(order_payload.get("order_name", order_entry.get("name", order_id)))
            text_lines.append("Élan dépensé : %s%.1f (%s). Reste %.1f." % [direction, abs(amount), order_name, remaining])
            tooltip_lines.append("Raison : %s" % _localize_reason(str(adjustment.get("reason", "order_cost"))))
        elif _last_elan_event is Dictionary and not _last_elan_event.is_empty():
            var event_amount := float(_last_elan_event.get("amount", 0.0))
            if not is_equal_approx(event_amount, 0.0):
                text_lines.append("Élan récent : %.1f (raison %s)." % [event_amount, _localize_reason(str(_last_elan_event.get("reason", "")))])
    if text_lines.is_empty():
        text_lines.append("Élan : aucune variation enregistrée pour cet engagement.")
    if _last_elan_gain is Dictionary and not _last_elan_gain.is_empty():
        var gain_amount := float(_last_elan_gain.get("amount", 0.0))
        if gain_amount > 0.0:
            var gain_reason := _localize_reason(str(_last_elan_gain.get("reason", "")))
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
