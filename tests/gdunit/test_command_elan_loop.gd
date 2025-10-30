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
        },
        {
            "id": "maniement",
            "name": "Maniement",
            "inertia_lock_turns": 1,
            "elan_upkeep": 0,
        }
    ]
    var orders := [
        {
            "id": "advance",
            "name": "Advance",
            "base_elan_cost": 1,
            "inertia_impact": 1,
            "allowed_doctrines": ["force"],
        },
        {
            "id": "flank",
            "name": "Flank",
            "base_elan_cost": 2,
            "inertia_impact": 2,
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

    doctrine_system.advance_turn()
    asserts.is_equal(0, doctrine_system.get_inertia_turns_remaining(), "Inertia should reach zero after enough turns.")

    changed = doctrine_system.select_doctrine("maniement")
    asserts.is_true(changed, "Switching doctrine should succeed once inertia is cleared.")
    asserts.is_equal(["flank"], doctrine_system.get_allowed_order_ids(), "Allowed orders should update with the active doctrine.")

func test_elan_system_spend_and_income_flow() -> void:
    var elan_system: ElanSystem = ELAN_SYSTEM.new()
    var orders := [
        {
            "id": "advance",
            "name": "Advance",
            "base_elan_cost": 1,
            "inertia_impact": 1,
        },
        {
            "id": "flank",
            "name": "Flank",
            "base_elan_cost": 3,
            "inertia_impact": 2,
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
