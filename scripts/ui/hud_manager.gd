extends Control

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const UTILS := preload("res://scripts/core/utils.gd")

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

const FEEDBACK_SAMPLE_RATE := 44100.0
const FEEDBACK_DURATION := 0.12
const FEEDBACK_VOLUME := 0.2
const WEATHER_COLORS := {
    "sunny": Color(1.0, 0.84, 0.25, 1.0),
    "rain": Color(0.35, 0.55, 0.9, 1.0),
    "mist": Color(0.7, 0.75, 0.85, 1.0),
    "default": Color(0.8, 0.8, 0.8, 1.0),
}

var event_bus: EventBusAutoload
var data_loader: DataLoaderAutoload

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
