extends GdUnitLiteTestCase

const TURN_MANAGER := preload("res://scripts/core/turn_manager.gd")
const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const COMBAT_SYSTEM := preload("res://scripts/systems/combat_system.gd")

func test_turn_manager_competence_budget_and_penalties() -> void:
    var event_bus: EventBus = EVENT_BUS.new()
    event_bus._ready()

    var manager: TurnManager = TURN_MANAGER.new()
    manager.configure_sliders([
        {
            "id": "tactics",
            "base_allocation": 2.0,
            "min_allocation": 0.5,
            "max_allocation": 6.0,
            "max_delta_per_turn": 1.0,
            "inertia_lock_turns": 2,
            "logistics_penalty_multiplier": 1.0,
        },
        {
            "id": "strategy",
            "base_allocation": 2.0,
            "min_allocation": 0.5,
            "max_allocation": 6.0,
            "max_delta_per_turn": 0.75,
            "inertia_lock_turns": 1,
            "logistics_penalty_multiplier": 0.8,
        },
        {
            "id": "logistics",
            "base_allocation": 2.0,
            "min_allocation": 0.5,
            "max_allocation": 6.0,
            "max_delta_per_turn": 1.0,
            "inertia_lock_turns": 1,
            "logistics_penalty_multiplier": 1.2,
        }
    ])
    manager.setup(event_bus)

    var events: Array = []
    event_bus.competence_reallocated.connect(func(payload: Dictionary) -> void:
        events.append(payload)
    )

    manager.start_game()
    asserts.is_true(events.size() >= 2, "Turn start should emit competence telemetry events")

    var allocation_result := manager.set_competence_allocations({
        "tactics": 3.0,
        "strategy": 2.0,
        "logistics": 1.0,
    })
    asserts.is_true(allocation_result.get("success", false), "Manual competence allocation should succeed within budget")
    var baseline_available := float(allocation_result.get("available", 0.0))

    event_bus.emit_logistics_update({
        "turn": manager.current_turn,
        "breaks": [
            {
                "type": "convoy_intercept",
                "route_id": "test_route",
                "turn": manager.current_turn,
                "competence_penalty": 2.0,
            }
        ]
    })

    var payload := manager.get_competence_payload()
    asserts.is_true(float(payload.get("available", baseline_available)) < baseline_available,
        "Logistics breaks should reduce available competence points")
    var modifiers: Variant = payload.get("modifiers", {})
    asserts.is_true(modifiers is Dictionary, "Competence payload should expose modifier state")
    asserts.is_true(float((modifiers as Dictionary).get("logistics_penalty", 0.0)) > 0.0,
        "Modifier state should accumulate logistics penalty for the current turn")
    var inertia_variant: Variant = payload.get("inertia", {})
    asserts.is_true(inertia_variant is Dictionary, "Competence payload should expose inertia state")

func test_turn_manager_enforces_competence_inertia() -> void:
    var event_bus: EventBus = EVENT_BUS.new()
    event_bus._ready()

    var manager: TurnManager = TURN_MANAGER.new()
    manager.configure_sliders([
        {
            "id": "tactics",
            "base_allocation": 2.0,
            "min_allocation": 0.5,
            "max_allocation": 6.0,
            "max_delta_per_turn": 1.0,
            "inertia_lock_turns": 2,
            "logistics_penalty_multiplier": 1.0,
        },
        {
            "id": "strategy",
            "base_allocation": 2.0,
            "min_allocation": 0.5,
            "max_allocation": 6.0,
            "max_delta_per_turn": 0.75,
            "inertia_lock_turns": 1,
            "logistics_penalty_multiplier": 0.8,
        },
        {
            "id": "logistics",
            "base_allocation": 2.0,
            "min_allocation": 0.5,
            "max_allocation": 6.0,
            "max_delta_per_turn": 1.0,
            "inertia_lock_turns": 1,
            "logistics_penalty_multiplier": 1.2,
        }
    ])
    manager.setup(event_bus)
    manager.start_game()

    var first_allocation := manager.set_competence_allocations({
        "tactics": 3.0,
        "strategy": 2.0,
        "logistics": 1.0,
    })
    asserts.is_true(first_allocation.get("success", false), "Initial reallocation should respect slider caps")

    var over_delta := manager.set_competence_allocations({
        "tactics": 4.2,
        "strategy": 1.3,
        "logistics": 0.5,
    })
    asserts.is_false(over_delta.get("success", true), "Competence change exceeding delta cap should fail in the same turn")
    asserts.is_equal("delta_exceeds_cap", over_delta.get("reason", ""), "Reason should cite delta limit overflow")

    manager.advance_turn()

    var locked_attempt := manager.set_competence_allocations({
        "tactics": 2.4,
        "strategy": 2.4,
        "logistics": 1.2,
    })
    asserts.is_false(locked_attempt.get("success", true), "Inertia lock should block adjustments on the following turn")
    asserts.is_equal("inertia_locked", locked_attempt.get("reason", ""), "Reason should cite inertia lock status")

    var inertia_state: Dictionary = manager.get_competence_payload().get("inertia", {})
    asserts.is_true(inertia_state.has("tactics"), "Inertia payload should report remaining lock state for each category")

func test_combat_system_applies_competence_bonus() -> void:
    var system: CombatSystem = COMBAT_SYSTEM.new()
    system.set_rng_seed(5)
    system.configure(
        [
            {
                "id": "infantry",
                "combat_profile": {"position": 1.0, "impulse": 0.8, "information": 0.5},
                "recon_profile": {"detection": 0.2, "counter_intel": 0.1},
                "competence_synergy": {"tactics": 2, "strategy": 1, "logistics": 1},
                "default_formations": ["shield_wall", "advance_column"],
            }
        ],
        [
            {
                "id": "advance",
                "pillar_weights": {"position": 0.35, "impulse": 0.6, "information": 0.25},
                "intel_profile": {"signal_strength": 0.65, "counter_intel": 0.1},
            }
        ],
        [
            {
                "id": "force",
                "effects": {"combat_bonus": {"position": 0.05, "impulse": 0.1, "information": 0.05}},
            }
        ],
        [
            {
                "id": "sunny",
                "combat_modifiers": {"position": 1.0, "impulse": 1.0, "information": 1.0},
            }
        ],
        [
            {
                "id": "shield_wall",
                "pillar_modifiers": {"position": 0.4, "impulse": -0.2, "information": -0.1},
                "posture": "defensive",
                "competence_weight": {"logistics": 0.2},
            },
            {
                "id": "advance_column",
                "pillar_modifiers": {"position": -0.1, "impulse": 0.3, "information": 0.0},
                "posture": "aggressive",
                "competence_weight": {"tactics": 0.1},
            }
        ]
    )

    var engagement := {
        "engagement_id": "solo_test",
        "order_id": "advance",
        "attacker_unit_ids": ["infantry"],
        "defender_unit_ids": [],
        "terrain": "plains",
    }

    var baseline := system.resolve_engagement(engagement)
    var baseline_impulse := baseline.get("pillars", {}).get("impulse", {}).get("attacker", 0.0)

    system._on_competence_reallocated({"allocations": {"tactics": 4.0, "strategy": 1.0, "logistics": 1.0}})
    system.set_unit_formation("infantry", "advance_column")
    system.set_rng_seed(5)
    var boosted := system.resolve_engagement(engagement)
    var boosted_impulse := boosted.get("pillars", {}).get("impulse", {}).get("attacker", 0.0)

    asserts.is_true(boosted_impulse > baseline_impulse, "Competence allocation should increase impulse pillar strength")
