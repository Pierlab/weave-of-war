extends Control

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const TELEMETRY := preload("res://scripts/core/telemetry.gd")
const UTILS := preload("res://scripts/core/utils.gd")
const MAX_ASSISTANT_LOG_ENTRIES := 10
const MAX_INTEL_LOG_ENTRIES := 12
const MAX_REASONING_LOG_ENTRIES := 12
const MAX_TELEMETRY_LOG_ENTRIES := 120

@onready var next_turn_button: Button = $PanelContainer/MarginContainer/VBoxContainer/NextTurnButton
@onready var toggle_logistics_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ToggleLogisticsButton
@onready var spawn_unit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SpawnUnitButton
@onready var assistant_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/AssistantSection/AssistantLog
@onready var command_reasoning_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/AssistantSection/CommandReasoningLog
@onready var espionage_reasoning_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/AssistantSection/EspionageReasoningLog
@onready var logistics_reasoning_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/AssistantSection/LogisticsReasoningLog
@onready var intel_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/IntelSection/IntelLog
@onready var telemetry_status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TelemetrySection/TelemetryStatus
@onready var telemetry_event_filter: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TelemetrySection/TelemetryControls/TelemetryFilter
@onready var telemetry_refresh_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TelemetrySection/TelemetryControls/TelemetryRefreshButton
@onready var telemetry_copy_session_path_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TelemetrySection/TelemetryControls/CopySessionPathButton
@onready var telemetry_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/TelemetrySection/TelemetryLog

var event_bus: EventBus
var assistant_ai: AssistantAI
var data_loader: DataLoader
var telemetry: Telemetry
var _assistant_packets: Array[Dictionary] = []
var _intel_events: Array[Dictionary] = []
var _reasoning_history: Dictionary = {
    "orders": [],
    "espionage": [],
    "logistics": [],
}
var _selected_telemetry_event: StringName = StringName("")

func _ready() -> void:
    event_bus = EVENT_BUS.get_instance()
    if event_bus == null:
        await get_tree().process_frame
        event_bus = EVENT_BUS.get_instance()

    assistant_ai = AssistantAI.get_instance()
    if assistant_ai == null:
        await get_tree().process_frame
        assistant_ai = AssistantAI.get_instance()
    if assistant_ai:
        _ingest_assistant_history(assistant_ai.get_recent_packets())
        _refresh_assistant_log()
        _ingest_reasoning_history(assistant_ai.get_reasoning_history())
        _refresh_reasoning_logs()

    data_loader = DATA_LOADER.get_instance()
    if data_loader == null:
        await get_tree().process_frame
        data_loader = DATA_LOADER.get_instance()
    if data_loader and data_loader.is_ready():
        _refresh_terrain_tooltip(data_loader.list_terrain_definitions(), data_loader.list_terrain_tiles())
    else:
        _refresh_terrain_tooltip([], [])

    telemetry = TELEMETRY.get_instance()
    if telemetry == null:
        await get_tree().process_frame
        telemetry = TELEMETRY.get_instance()

    if next_turn_button:
        next_turn_button.pressed.connect(_on_next_turn_pressed)
    if toggle_logistics_button:
        toggle_logistics_button.pressed.connect(_on_toggle_logistics_pressed)
    if spawn_unit_button:
        spawn_unit_button.pressed.connect(_on_spawn_unit_pressed)
    _initialise_telemetry_section()

    if event_bus:
        event_bus.logistics_toggled.connect(_on_logistics_toggled)
        if not event_bus.assistant_order_packet.is_connected(_on_assistant_packet):
            event_bus.assistant_order_packet.connect(_on_assistant_packet)
        if not event_bus.data_loader_ready.is_connected(_on_data_loader_ready):
            event_bus.data_loader_ready.connect(_on_data_loader_ready)
        if not event_bus.espionage_ping.is_connected(_on_espionage_ping):
            event_bus.espionage_ping.connect(_on_espionage_ping)
        if not event_bus.intel_intent_revealed.is_connected(_on_intel_intent_revealed):
            event_bus.intel_intent_revealed.connect(_on_intel_intent_revealed)
        if not event_bus.logistics_break.is_connected(_on_logistics_break):
            event_bus.logistics_break.connect(_on_logistics_break)

    _refresh_intel_log()

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

func _on_data_loader_ready(_payload: Dictionary) -> void:
    if data_loader == null:
        data_loader = DATA_LOADER.get_instance()
    if data_loader:
        _refresh_terrain_tooltip(data_loader.list_terrain_definitions(), data_loader.list_terrain_tiles())

func _on_assistant_packet(packet: Dictionary) -> void:
    if packet.is_empty():
        return
    var packet_copy: Dictionary = packet.duplicate(true)
    _assistant_packets.append(packet_copy)
    while _assistant_packets.size() > MAX_ASSISTANT_LOG_ENTRIES:
        _assistant_packets.remove_at(0)
    _refresh_assistant_log()
    _refresh_reasoning_logs()

func _on_espionage_ping(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var entry: Dictionary = payload.duplicate(true)
    _intel_events.append(entry)
    while _intel_events.size() > MAX_INTEL_LOG_ENTRIES:
        _intel_events.remove_at(0)
    _refresh_intel_log()
    _refresh_reasoning_logs()

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
    while _intel_events.size() > MAX_INTEL_LOG_ENTRIES:
        _intel_events.remove_at(0)
    _refresh_intel_log()
    _refresh_reasoning_logs()

func _on_logistics_break(_payload: Dictionary) -> void:
    _refresh_reasoning_logs()

func _ingest_assistant_history(entries: Array) -> void:
    _assistant_packets.clear()
    for entry in entries:
        if entry is Dictionary:
            _assistant_packets.append((entry as Dictionary).duplicate(true))
    while _assistant_packets.size() > MAX_ASSISTANT_LOG_ENTRIES:
        _assistant_packets.remove_at(0)

func _ingest_reasoning_history(history: Dictionary) -> void:
    for key in _reasoning_history.keys():
        _reasoning_history[key] = []
    for domain in history.keys():
        var entries_variant: Variant = history.get(domain, [])
        if not (entries_variant is Array):
            continue
        var collected: Array = []
        for entry in (entries_variant as Array):
            if entry is Dictionary:
                collected.append((entry as Dictionary).duplicate(true))
        while collected.size() > MAX_REASONING_LOG_ENTRIES:
            collected.remove_at(0)
        _reasoning_history[domain] = collected

func _refresh_assistant_log() -> void:
    if assistant_log == null:
        return
    assistant_log.clear()
    for packet in _assistant_packets:
        var line := _format_assistant_packet(packet)
        if line.is_empty():
            continue
        assistant_log.append_text("%s\n" % line)
    var line_count := assistant_log.get_line_count()
    if line_count > 0:
        assistant_log.scroll_to_line(line_count - 1)

func _refresh_reasoning_logs() -> void:
    if assistant_ai == null:
        return
    _ingest_reasoning_history(assistant_ai.get_reasoning_history())
    _render_reasoning_log(command_reasoning_log, _reasoning_history.get("orders", []), Callable(self, "_format_order_reasoning"))
    _render_reasoning_log(espionage_reasoning_log, _reasoning_history.get("espionage", []), Callable(self, "_format_espionage_reasoning"))
    _render_reasoning_log(logistics_reasoning_log, _reasoning_history.get("logistics", []), Callable(self, "_format_logistics_reasoning"))

func _render_reasoning_log(target: RichTextLabel, entries: Variant, formatter: Callable) -> void:
    if target == null:
        return
    target.clear()
    if not (entries is Array):
        return
    var array_entries: Array = entries
    if array_entries.is_empty():
        target.append_text("Aucune entrée enregistrée.\n")
        return
    for entry in array_entries:
        if not (entry is Dictionary):
            continue
        var line := formatter.call(entry)
        if line.is_empty():
            continue
        target.append_text("%s\n" % line)
    var line_count := target.get_line_count()
    if line_count > 0:
        target.scroll_to_line(line_count - 1)

func _format_assistant_packet(packet: Dictionary) -> String:
    var orders_variant: Variant = packet.get("orders", [])
    if orders_variant is Array and orders_variant.size() > 0:
        var order_entry: Variant = orders_variant[0]
        if order_entry is Dictionary:
            var order_dict: Dictionary = order_entry
            var order_id := str(order_dict.get("order_id", order_dict.get("id", "")))
            var order_name := str(order_dict.get("order_name", order_dict.get("name", order_id)))
            var target_value := str(order_dict.get("target", order_dict.get("target_hex", "frontline")))
            var cost_value := float(order_dict.get("cost", order_dict.get("base_elan_cost", 0.0)))
            var intention := str(order_dict.get("intention", "unknown"))
            var intents_variant: Variant = packet.get("intents", {})
            var confidence_percent := 0
            if intents_variant is Dictionary and order_id != "":
                var intent_entry: Variant = intents_variant.get(order_id, {})
                if intent_entry is Dictionary:
                    var intent_dict: Dictionary = intent_entry
                    if intention == "unknown":
                        intention = str(intent_dict.get("intention", intention))
                    confidence_percent = roundi(float(intent_dict.get("confidence", 0.0)) * 100.0)
            var engagement_variant: Variant = packet.get("expected_engagements", [])
            var engagement_id := ""
            if engagement_variant is Array and engagement_variant.size() > 0:
                var engagement_entry: Variant = engagement_variant[0]
                if engagement_entry is Dictionary:
                    engagement_id = str(engagement_entry.get("engagement_id", ""))
            var formatted_target := target_value if target_value != "" else "frontline"
            if confidence_percent < 0:
                confidence_percent = 0
            if confidence_percent > 100:
                confidence_percent = 100
            var parts := [
                "%s (%s)" % [order_name, order_id if order_id != "" else "n/a"],
                "→ %s" % formatted_target,
                "Élan %.1f" % cost_value,
                "Intent %s" % intention,
                "Confidence %d%%" % confidence_percent,
            ]
            if engagement_id != "":
                parts.append("Engagement %s" % engagement_id)
            return " | ".join(parts)
    return ""

func _format_order_reasoning(entry: Dictionary) -> String:
    var order_id := str(entry.get("order_id", ""))
    var target := str(entry.get("target", "frontline"))
    var confidence_percent := roundi(float(entry.get("confidence", 0.0)) * 100.0)
    var base_percent := roundi(float(entry.get("base_signal", 0.0)) * 100.0)
    var alignment := float(entry.get("competence_alignment", 1.0))
    var elan_cost := float(entry.get("elan_cost", 0.0))
    var recommendation := str(entry.get("recommendation", ""))
    var parts := [
        "Ordre %s" % (order_id if order_id != "" else "(n/a)"),
        "→ %s" % (target if target != "" else "frontline"),
        "Confiance %d%% (base %d%%)" % [confidence_percent, base_percent],
        "Align %.2f" % alignment,
        "Élan %.1f" % elan_cost,
    ]
    if entry.has("competence_cost") and entry.get("competence_cost") is Dictionary:
        var cost_parts: Array = []
        for key in (entry.get("competence_cost") as Dictionary).keys():
            cost_parts.append("%s %.1f" % [str(key), float((entry.get("competence_cost") as Dictionary).get(key, 0.0))])
        if cost_parts.size() > 0:
            parts.append("Compétence %s" % ", ".join(cost_parts))
    if not recommendation.is_empty():
        parts.append(recommendation)
    return " | ".join(parts)

func _format_espionage_reasoning(entry: Dictionary) -> String:
    var target := str(entry.get("target", "unknown"))
    var confidence_percent := roundi(float(entry.get("confidence", 0.0)) * 100.0)
    var detection_percent := roundi(float(entry.get("detection_risk", 0.0)) * 100.0)
    var recommendation := str(entry.get("recommendation", ""))
    var status := "Succès" if bool(entry.get("success", false)) else "Échec"
    var intent := str(entry.get("intent", "unknown"))
    var probe_strength := float(entry.get("probe_strength", 0.0))
    var counter_intel := float(entry.get("counter_intel", 0.0))
    var parts := [
        "%s — %s" % [status, target],
        "Confiance %d%%" % confidence_percent,
        "Détection %d%%" % detection_percent,
        "Intention %s" % intent,
        "Probe %.2f" % probe_strength,
        "Counter-intel %.2f" % counter_intel,
    ]
    if not recommendation.is_empty():
        parts.append(recommendation)
    return " | ".join(parts)

func _format_logistics_reasoning(entry: Dictionary) -> String:
    var alert_type := str(entry.get("type", ""))
    var location := str(entry.get("location", ""))
    var recommendation := str(entry.get("recommendation", ""))
    var competence_penalty := float(entry.get("competence_penalty", 0.0))
    var elan_penalty := float(entry.get("elan_penalty", 0.0))
    var weather := str(entry.get("weather_id", ""))
    var turn_number := int(entry.get("turn", 0))
    var parts := [
        "%s @ %s" % [alert_type if alert_type != "" else "alerte", location if location != "" else "n/a"],
        "Tour %d" % turn_number,
        "Compétence %.1f" % competence_penalty,
        "Élan %.1f" % elan_penalty,
    ]
    if not weather.is_empty():
        parts.append("Météo %s" % weather)
    if entry.has("context") and entry.get("context") is Dictionary:
        var context: Dictionary = entry.get("context")
        if context.has("supply_level"):
            parts.append("Niveau %s" % str(context.get("supply_level")))
        if context.has("logistics_flow"):
            parts.append("Flux %.2f" % float(context.get("logistics_flow", 0.0)))
        if context.has("intercept_risk") and context.get("intercept_risk") is Dictionary:
            var risk: Dictionary = context.get("intercept_risk")
            parts.append("Risque %.0f%%" % roundi(float(risk.get("effective", 0.0)) * 100.0))
    if not recommendation.is_empty():
        parts.append(recommendation)
    return " | ".join(parts)

func _refresh_intel_log() -> void:
    if intel_log == null:
        return
    intel_log.clear()
    if _intel_events.is_empty():
        intel_log.append_text("Aucun ping renseignement enregistré.\n")
        return
    for entry in _intel_events:
        var line := _format_intel_entry(entry)
        if line.is_empty():
            continue
        intel_log.append_text("%s\n" % line)
    var line_count := intel_log.get_line_count()
    if line_count > 0:
        intel_log.scroll_to_line(line_count - 1)

func _format_intel_entry(entry: Dictionary) -> String:
    var turn_number := int(entry.get("turn", 0))
    var order_id := str(entry.get("source", entry.get("order_id", "")))
    var target := str(entry.get("target", ""))
    var success := bool(entry.get("success", false))
    var intention := str(entry.get("intent_category", entry.get("intention", "unknown")))
    var confidence := float(entry.get("confidence", 0.0))
    var roll := float(entry.get("roll", 0.0))
    var detection_bonus := float(entry.get("detection_bonus", 0.0))
    var noise := float(entry.get("noise", 0.0))
    var visibility_before := float(entry.get("visibility_before", 0.0))
    var visibility_after := float(entry.get("visibility_after", entry.get("visibility_before", 0.0)))
    var label := "succès" if success else "échec"
    var intention_label := intention if intention != "" else "unknown"
    var parts := [
        "T%02d" % turn_number,
        order_id if order_id != "" else "n/a",
        (target if target != "" else "?"),
        label,
        "intent=%s" % intention_label,
        "p=%d%%" % clamp(roundi(confidence * 100.0), -999, 999),
        "jet=%d%%" % clamp(roundi(roll * 100.0), -999, 999),
        "vis=%d→%d" % [roundi(visibility_before * 100.0), roundi(visibility_after * 100.0)],
        "bruit=%d%%" % clamp(roundi(noise * 100.0), -999, 999),
    ]
    if detection_bonus > 0.0:
        parts.append("bonus=%d%%" % clamp(roundi(detection_bonus * 100.0), -999, 999))
    return " | ".join(parts)

func _refresh_terrain_tooltip(definitions: Array, tiles: Array) -> void:
    if toggle_logistics_button == null:
        return
    toggle_logistics_button.tooltip_text = UTILS.build_terrain_tooltip(definitions, tiles)

func _initialise_telemetry_section() -> void:
    if telemetry_event_filter:
        telemetry_event_filter.item_selected.connect(_on_telemetry_event_selected)
    if telemetry_refresh_button:
        telemetry_refresh_button.pressed.connect(_on_telemetry_refresh_pressed)
    if telemetry_copy_session_path_button:
        telemetry_copy_session_path_button.pressed.connect(_on_copy_session_path_pressed)

    _rebuild_telemetry_event_filter()
    _refresh_telemetry_status()
    _refresh_telemetry_log()

    if telemetry and not telemetry.event_logged.is_connected(_on_telemetry_event_logged):
        telemetry.event_logged.connect(_on_telemetry_event_logged)

func _rebuild_telemetry_event_filter() -> void:
    if telemetry_event_filter == null:
        return

    var previous := _selected_telemetry_event
    telemetry_event_filter.clear()
    telemetry_event_filter.add_item("Tous les événements")
    telemetry_event_filter.set_item_metadata(0, StringName(""))

    var event_names: Array[StringName] = []
    if telemetry:
        event_names = telemetry.list_event_names()
    var target_index := 0
    var index := 1
    for event_name in event_names:
        telemetry_event_filter.add_item(String(event_name))
        telemetry_event_filter.set_item_metadata(index, event_name)
        if event_name == previous:
            target_index = index
        index += 1

    telemetry_event_filter.select(target_index)
    var metadata: Variant = telemetry_event_filter.get_item_metadata(target_index)
    if metadata is StringName:
        _selected_telemetry_event = metadata
    else:
        _selected_telemetry_event = StringName("")

func _refresh_telemetry_status(buffer_size: int = -1) -> void:
    if telemetry_status_label == null:
        return

    if telemetry == null:
        telemetry_status_label.text = "Télémetrie indisponible."
        telemetry_status_label.tooltip_text = "Aucun autoload détecté."
        if telemetry_copy_session_path_button:
            telemetry_copy_session_path_button.disabled = true
            telemetry_copy_session_path_button.tooltip_text = "Aucun fichier de session actif."
        return

    var total := buffer_size if buffer_size >= 0 else telemetry.get_buffer().size()
    var persistence_label := "activée" if telemetry.is_persistence_enabled() else "désactivée"
    var session_path := telemetry.get_session_file_path()
    telemetry_status_label.text = "Événements : %d · Persistance %s" % [total, persistence_label]
    telemetry_status_label.tooltip_text = session_path if not session_path.is_empty() else "Session non persistée."

    if telemetry_copy_session_path_button:
        telemetry_copy_session_path_button.disabled = session_path.is_empty()
        telemetry_copy_session_path_button.tooltip_text = session_path if not session_path.is_empty() else "Aucun fichier de session actif."

func _refresh_telemetry_log() -> void:
    if telemetry_log == null:
        return
    telemetry_log.clear()

    if telemetry == null:
        telemetry_log.append_text("La télémétrie n'est pas initialisée.\n")
        return

    var entries := _collect_filtered_telemetry_entries()

    if entries.is_empty():
        telemetry_log.append_text("Aucun événement enregistré pour ce filtre.\n")
        return

    for entry in entries:
        if not (entry is Dictionary):
            continue
        var line := _format_telemetry_entry(entry as Dictionary)
        if line.is_empty():
            continue
        telemetry_log.append_text("%s\n" % line)

    var line_count := telemetry_log.get_line_count()
    if line_count > 0:
        telemetry_log.scroll_to_line(line_count - 1)

func _collect_filtered_telemetry_entries() -> Array:
    if telemetry == null:
        return []

    var entries: Array = []
    if _selected_telemetry_event == StringName(""):
        entries = telemetry.get_buffer()
    else:
        entries = telemetry.get_history(_selected_telemetry_event)

    if entries.size() > MAX_TELEMETRY_LOG_ENTRIES:
        entries = entries.slice(entries.size() - MAX_TELEMETRY_LOG_ENTRIES, entries.size())
    return entries

func _format_telemetry_entry(entry: Dictionary) -> String:
    var event_name := String(entry.get("name", ""))
    var timestamp := int(entry.get("timestamp", 0))
    var payload_variant: Variant = entry.get("payload", {})
    var payload_preview := _format_payload_preview(payload_variant)
    var parts: Array[String] = []
    parts.append("%s — %s" % [_format_timestamp(timestamp), event_name if not event_name.is_empty() else "(inconnu)"])
    if not payload_preview.is_empty():
        parts.append(payload_preview)
    return " | ".join(parts)

func _format_payload_preview(payload: Variant) -> String:
    if payload == null:
        return ""
    if payload is Dictionary or payload is Array:
        var json := JSON.stringify(payload)
        if json.length() > 220:
            json = "%s…" % json.substr(0, 220)
        return json
    return String(payload)

func _format_timestamp(timestamp: int) -> String:
    if timestamp <= 0:
        return "t+0.000s"
    return "t+%.3fs" % (float(timestamp) / 1000.0)

func _on_telemetry_event_selected(index: int) -> void:
    if telemetry_event_filter == null:
        return
    var metadata: Variant = telemetry_event_filter.get_item_metadata(index)
    if metadata is StringName:
        _selected_telemetry_event = metadata
    else:
        _selected_telemetry_event = StringName("")
    _refresh_telemetry_log()

func _on_telemetry_refresh_pressed() -> void:
    _refresh_telemetry_status()
    _refresh_telemetry_log()

func _on_copy_session_path_pressed() -> void:
    if telemetry == null:
        return
    var session_path := telemetry.get_session_file_path()
    if session_path.is_empty():
        return
    DisplayServer.clipboard_set(session_path)

func _on_telemetry_event_logged(event_name: StringName, _payload: Dictionary, _timestamp: int, buffer_size: int) -> void:
    _refresh_telemetry_status(buffer_size)
    if not _has_event_in_filter(event_name):
        _rebuild_telemetry_event_filter()
    if _selected_telemetry_event == StringName("") or _selected_telemetry_event == event_name:
        _refresh_telemetry_log()

func _has_event_in_filter(event_name: StringName) -> bool:
    if telemetry_event_filter == null:
        return false
    var count := telemetry_event_filter.get_item_count()
    for index in count:
        var metadata: Variant = telemetry_event_filter.get_item_metadata(index)
        if metadata is StringName and metadata == event_name:
            return true
    return false
