extends Control

const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")
const UTILS := preload("res://scripts/core/utils.gd")
const MAX_ASSISTANT_LOG_ENTRIES := 10
const MAX_INTEL_LOG_ENTRIES := 12

@onready var next_turn_button: Button = $PanelContainer/MarginContainer/VBoxContainer/NextTurnButton
@onready var toggle_logistics_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ToggleLogisticsButton
@onready var spawn_unit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SpawnUnitButton
@onready var assistant_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/AssistantSection/AssistantLog
@onready var intel_log: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/IntelSection/IntelLog

var event_bus: EventBus
var assistant_ai: AssistantAI
var data_loader: DataLoader
var _assistant_packets: Array[Dictionary] = []
var _intel_events: Array[Dictionary] = []

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

    data_loader = DATA_LOADER.get_instance()
    if data_loader == null:
        await get_tree().process_frame
        data_loader = DATA_LOADER.get_instance()
    if data_loader and data_loader.is_ready():
        _refresh_terrain_tooltip(data_loader.list_terrain_definitions(), data_loader.list_terrain_tiles())
    else:
        _refresh_terrain_tooltip([], [])

    if next_turn_button:
        next_turn_button.pressed.connect(_on_next_turn_pressed)
    if toggle_logistics_button:
        toggle_logistics_button.pressed.connect(_on_toggle_logistics_pressed)
    if spawn_unit_button:
        spawn_unit_button.pressed.connect(_on_spawn_unit_pressed)

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

func _on_espionage_ping(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    var entry: Dictionary = payload.duplicate(true)
    _intel_events.append(entry)
    while _intel_events.size() > MAX_INTEL_LOG_ENTRIES:
        _intel_events.remove_at(0)
    _refresh_intel_log()

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

func _ingest_assistant_history(entries: Array) -> void:
    _assistant_packets.clear()
    for entry in entries:
        if entry is Dictionary:
            _assistant_packets.append((entry as Dictionary).duplicate(true))
    while _assistant_packets.size() > MAX_ASSISTANT_LOG_ENTRIES:
        _assistant_packets.remove_at(0)

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
