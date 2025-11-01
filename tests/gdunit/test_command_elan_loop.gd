extends GdUnitLiteTestCase

const DOCTRINE_SYSTEM := preload("res://scripts/systems/doctrine_system.gd")
const ELAN_SYSTEM := preload("res://scripts/systems/elan_system.gd")

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
