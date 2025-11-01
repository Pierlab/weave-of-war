extends GdUnitLiteTestCase

const DOCTRINE_SYSTEM := preload("res://scripts/systems/doctrine_system.gd")
const ELAN_SYSTEM := preload("res://scripts/systems/elan_system.gd")
const ASSISTANT_AI := preload("res://scripts/core/assistant_ai.gd")

class StubCommandEventBus:
    var doctrine_payloads: Array = []
    var doctrine_failures: Array = []
    var elan_updates: Array = []
    var elan_spent_events: Array = []
    var elan_gained_events: Array = []
    var orders_issued: Array = []
    var orders_rejected: Array = []
    var assistant_packets: Array = []

    func emit_doctrine_selected(payload: Dictionary) -> void:
        doctrine_payloads.append(payload)

    func emit_order_execution_failed(payload: Dictionary) -> void:
        doctrine_failures.append(payload)

    func emit_elan_updated(payload: Dictionary) -> void:
        elan_updates.append(payload)

    func emit_elan_spent(payload: Dictionary) -> void:
        elan_spent_events.append(payload)

    func emit_elan_gained(payload: Dictionary) -> void:
        elan_gained_events.append(payload)

    func emit_order_issued(payload: Dictionary) -> void:
        orders_issued.append(payload)

    func emit_order_rejected(payload: Dictionary) -> void:
        orders_rejected.append(payload)

    func emit_assistant_order_packet(payload: Dictionary) -> void:
        assistant_packets.append(payload)

class StubDataLoader:
    var orders: Dictionary = {}

    func set_order(order_id: String, data: Dictionary) -> void:
        orders[order_id] = data

    func get_order(order_id: String) -> Dictionary:
        return orders.get(order_id, {})

func test_doctrine_selection_respects_inertia() -> void:
    var doctrine_system: DoctrineSystem = DOCTRINE_SYSTEM.new()
    var doctrines := [
        {
            "id": "force",
            "name": "Force",
            "inertia_lock_turns": 2,
            "elan_upkeep": 1,
            "command_profile": {
                "cp_cap_delta": 2,
                "swap_token_budget": 1,
                "inertia_multiplier": 1.25,
                "elan_cap_bonus": 2,
                "allowed_order_tags": ["assault"],
            },
        },
        {
            "id": "maniement",
            "name": "Maniement",
            "inertia_lock_turns": 1,
            "elan_upkeep": 0,
            "command_profile": {
                "cp_cap_delta": 0,
                "swap_token_budget": 1,
                "inertia_multiplier": 0.75,
                "elan_cap_bonus": 0,
                "allowed_order_tags": ["flank"],
            },
        }
    ]
    var orders := [
        {
            "id": "advance",
            "name": "Advance",
            "base_elan_cost": 1,
            "inertia_impact": 1,
            "inertia_profile": {"doctrine_multipliers": {"force": 1.0}},
            "allowed_doctrines": ["force"],
        },
        {
            "id": "flank",
            "name": "Flank",
            "base_elan_cost": 2,
            "inertia_impact": 2,
            "inertia_profile": {"doctrine_multipliers": {"maniement": 0.5}},
            "allowed_doctrines": ["maniement"],
        },
    ]

    doctrine_system.configure(doctrines, orders)
    asserts.is_equal("force", doctrine_system.get_active_doctrine_id(), "Initial doctrine should be the first entry.")
    asserts.is_equal(2, doctrine_system.get_inertia_turns_remaining(), "Base inertia should match the doctrine lock.")

    var changed := doctrine_system.select_doctrine("maniement")
    asserts.is_true(not changed, "Inertia should prevent switching doctrine immediately.")

    doctrine_system.advance_turn()
    asserts.is_equal(1, doctrine_system.get_inertia_turns_remaining(), "Inertia should tick down each turn.")

    doctrine_system.register_order_inertia("advance", 1.0)
    asserts.is_equal(2, doctrine_system.get_inertia_turns_remaining(), "Force multiplier should extend inertia above the base lock.")

    doctrine_system.advance_turn()
    asserts.is_equal(1, doctrine_system.get_inertia_turns_remaining(), "Order inertia should decay per turn.")

    doctrine_system.advance_turn()
    asserts.is_equal(0, doctrine_system.get_inertia_turns_remaining(), "Inertia should reach zero after enough turns.")

    changed = doctrine_system.select_doctrine("maniement")
    asserts.is_true(changed, "Switching doctrine should succeed once inertia is cleared.")
    asserts.is_equal(["flank"], doctrine_system.get_allowed_order_ids(), "Allowed orders should update with the active doctrine.")

    doctrine_system.register_order_inertia("flank", 2.0)
    asserts.is_equal(1, doctrine_system.get_inertia_turns_remaining(), "Defensive doctrine multiplier should shorten inertia impact.")

func test_elan_system_spend_and_income_flow() -> void:
    var elan_system: ElanSystem = ELAN_SYSTEM.new()
    var orders := [
        {
            "id": "advance",
            "name": "Advance",
            "base_elan_cost": 1,
            "inertia_impact": 1,
            "inertia_profile": {"doctrine_multipliers": {"force": 1.0}},
        },
        {
            "id": "flank",
            "name": "Flank",
            "base_elan_cost": 3,
            "inertia_impact": 2,
            "inertia_profile": {"doctrine_multipliers": {"maniement": 0.5}},
        },
    ]
    var units := [
        {
            "id": "infantry",
            "elan_generation": {"base": 1.0},
        }
    ]

    elan_system.configure(orders, units)
    elan_system.set_allowed_orders(["advance"])
    elan_system.add_elan(2.0)

    var state := elan_system.get_state_payload()
    asserts.is_equal(2.0, state.get("current", 0.0), "Current Élan should match the injected value.")

    var result := elan_system.issue_order("advance")
    asserts.is_true(result.get("success", false), "Issuing an allowed order with enough Élan should succeed.")
    state = elan_system.get_state_payload()
    asserts.is_equal(1.0, state.get("current", 0.0), "Spending Élan should reduce the pool by the order cost.")

    var failure := elan_system.issue_order("flank")
    asserts.is_true(not failure.get("success", false), "Orders outside the allowed set should be blocked.")

    elan_system.set_doctrine_upkeep(0.5)
    elan_system._on_turn_started(2)
    state = elan_system.get_state_payload()
    asserts.is_equal(1.5, state.get("current", 0.0), "Turn upkeep then income should apply before clamping to the maximum.")

func test_elan_cap_decay_and_bonus() -> void:
    var elan_system: ElanSystem = ELAN_SYSTEM.new()
    elan_system.max_elan = 5.0
    elan_system.decay_amount = 1.0
    elan_system.configure([], [])
    elan_system.set_allowed_orders([])
    elan_system.add_elan(10.0)
    var state := elan_system.get_state_payload()
    asserts.is_equal(5.0, state.get("current", 0.0), "Élan should clamp to the base cap.")

    elan_system._on_turn_ended(1)
    elan_system._on_turn_started(2)
    state = elan_system.get_state_payload()
    asserts.is_equal(4.0, state.get("current", 0.0), "Cap decay should subtract the configured amount after a full round at cap.")

    elan_system._apply_doctrine_cap_bonus(2.0)
    state = elan_system.get_state_payload()
    asserts.is_equal(7.0, state.get("max", 0.0), "Doctrine bonus should raise the Élan cap.")

func test_doctrine_change_emits_success_and_failure_events() -> void:
    var event_bus := StubCommandEventBus.new()
    var doctrine_system: DoctrineSystem = DOCTRINE_SYSTEM.new()
    doctrine_system.event_bus = event_bus
    doctrine_system.configure(
        [
            {
                "id": "force",
                "name": "Force",
                "inertia_lock_turns": 2,
                "elan_upkeep": 1,
                "command_profile": {
                    "cp_cap_delta": 2,
                    "swap_token_budget": 1,
                    "inertia_multiplier": 1.25,
                    "elan_cap_bonus": 2,
                    "allowed_order_tags": ["assault"],
                },
            },
            {
                "id": "maniement",
                "name": "Maniement",
                "inertia_lock_turns": 1,
                "elan_upkeep": 0,
                "command_profile": {
                    "cp_cap_delta": 0,
                    "swap_token_budget": 1,
                    "inertia_multiplier": 0.75,
                    "elan_cap_bonus": 0,
                    "allowed_order_tags": ["flank"],
                },
            },
        ],
        [
            {
                "id": "advance",
                "name": "Advance",
                "base_elan_cost": 1,
                "inertia_impact": 1,
                "allowed_doctrines": ["force"],
                "inertia_profile": {"doctrine_multipliers": {"force": 1.0}},
            },
            {
                "id": "flank",
                "name": "Flank",
                "base_elan_cost": 2,
                "inertia_impact": 2,
                "allowed_doctrines": ["maniement"],
                "inertia_profile": {"doctrine_multipliers": {"maniement": 0.5}},
            },
        ]
    )

    asserts.is_equal(1, event_bus.doctrine_payloads.size(), "Initial configure should broadcast the starting doctrine.")
    doctrine_system._on_doctrine_change_requested("maniement")
    asserts.is_equal(1, event_bus.doctrine_failures.size(), "Failed doctrine swap should emit an order failure payload.")
    var failure_payload: Dictionary = event_bus.doctrine_failures.back()
    asserts.is_equal("doctrine_locked", failure_payload.get("reason", ""), "Failure reason should describe the inertia lock.")
    asserts.is_equal("force", doctrine_system.get_active_doctrine_id(), "Doctrine should remain locked on Force during inertia.")

    doctrine_system.advance_turn()
    doctrine_system.advance_turn()
    doctrine_system._on_doctrine_change_requested("maniement")
    asserts.is_equal("maniement", doctrine_system.get_active_doctrine_id(), "Doctrine should switch once inertia expires.")
    asserts.is_equal(2, event_bus.doctrine_payloads.size(), "Successful swap should broadcast a new doctrine payload.")
    var success_payload: Dictionary = event_bus.doctrine_payloads.back()
    asserts.is_equal("selected", success_payload.get("reason", ""), "Broadcast should mark the payload reason as selected.")
    asserts.is_equal(["flank"], doctrine_system.get_allowed_order_ids(), "Allowed orders should match the new doctrine.")

func test_elan_system_emits_updates_and_blocks_invalid_orders() -> void:
    var event_bus := StubCommandEventBus.new()
    var elan_system: ElanSystem = ELAN_SYSTEM.new()
    elan_system.event_bus = event_bus
    elan_system.max_elan = 3.0
    elan_system.configure(
        [
            {
                "id": "advance",
                "name": "Advance",
                "base_elan_cost": 1,
                "inertia_impact": 1,
            },
            {
                "id": "assault",
                "name": "Assault",
                "base_elan_cost": 3,
                "inertia_impact": 2,
            },
        ],
        []
    )
    elan_system.set_allowed_orders(["advance"])
    elan_system.add_elan(2.0)

    asserts.is_equal("gain", event_bus.elan_updates.back().get("reason", ""), "Adding Élan should emit a gain payload.")
    asserts.is_equal(1, event_bus.elan_gained_events.size(), "Gaining Élan should emit a telemetry payload.")
    var gain_payload: Dictionary = event_bus.elan_gained_events.back()
    asserts.is_equal(2.0, gain_payload.get("amount", 0.0), "Telemetry payload should record the gained amount.")
    asserts.is_equal("manual", gain_payload.get("reason", ""), "Manual injections should mark the gain reason.")

    elan_system._on_order_execution_requested("assault")
    asserts.is_equal(1, event_bus.doctrine_failures.size(), "Blocked orders should emit a failure payload.")
    var doctrine_failure := event_bus.doctrine_failures.back()
    asserts.is_equal("doctrine_locked", doctrine_failure.get("reason", ""), "Failure reason should flag doctrine gating.")
    asserts.is_equal(1, event_bus.orders_rejected.size(), "Blocked orders should emit a telemetry rejection payload.")
    var rejection_payload: Dictionary = event_bus.orders_rejected.back()
    asserts.is_equal("assault", rejection_payload.get("order_id", ""), "Telemetry payload should include the blocked order id.")
    asserts.is_false(rejection_payload.get("allowed", true), "Doctrine-locked orders should report allowed = false.")

    elan_system._on_order_execution_requested("advance")
    asserts.is_equal(1, event_bus.elan_spent_events.size(), "Successful order execution should emit an Élan spend event.")
    var spend_payload: Dictionary = event_bus.elan_spent_events.back()
    asserts.is_equal("order_cost", spend_payload.get("reason", ""), "Spend payload should mark the order cost reason.")
    asserts.is_equal("advance", event_bus.orders_issued.back().get("order_id", ""), "Issued payload should echo the order id.")

    elan_system.set_allowed_orders(["advance", "assault"])
    elan_system._on_order_execution_requested("assault")
    asserts.is_equal(2, event_bus.doctrine_failures.size(), "Insufficient Élan should emit another failure payload.")
    var insufficient_payload := event_bus.doctrine_failures.back()
    asserts.is_equal("insufficient_elan", insufficient_payload.get("reason", ""), "Failure should report insufficient Élan.")
    asserts.is_equal(3.0, insufficient_payload.get("required", 0.0), "Payload should expose the required Élan amount.")
    asserts.is_equal(2, event_bus.orders_rejected.size(), "Each blocked order should emit a telemetry rejection payload.")

func test_assistant_ai_acknowledges_order_packets() -> void:
    var event_bus := StubCommandEventBus.new()
    var data_loader := StubDataLoader.new()
    data_loader.set_order("advance", {
        "id": "advance",
        "name": "Advance",
        "intention": "offense",
        "pillar_weights": {"position": 0.4, "impulse": 0.5, "information": 0.2},
        "intel_profile": {"signal_strength": 0.75},
    })

    var assistant: AssistantAIAutoload = ASSISTANT_AI.new()
    assistant._event_bus = event_bus
    assistant._data_loader = data_loader

    assistant._on_order_issued({
        "order_id": "advance",
        "order_name": "Advance",
        "cost": 1.0,
        "target": "ridge",
    })

    asserts.is_equal(1, event_bus.assistant_packets.size(), "Assistant AI should emit an enriched packet when orders fire.")
    var packet: Dictionary = event_bus.assistant_packets.back()
    asserts.is_true(packet.has("orders"), "Packet should include the enriched orders array.")
    asserts.is_equal("offense", packet.get("intents", {}).get("advance", {}).get("intention", ""), "Intention should mirror data loader metadata.")
    asserts.is_equal(1, assistant.get_recent_packets().size(), "Assistant AI should retain the packet in its rolling history.")
