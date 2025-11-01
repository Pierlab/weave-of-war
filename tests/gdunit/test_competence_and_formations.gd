extends GdUnitLiteTestCase

const TURN_MANAGER := preload("res://scripts/core/turn_manager.gd")
const EVENT_BUS := preload("res://scripts/core/event_bus.gd")
const COMBAT_SYSTEM := preload("res://scripts/systems/combat_system.gd")
const ELAN_SYSTEM := preload("res://scripts/systems/elan_system.gd")
const FORMATION_SYSTEM := preload("res://scripts/systems/formation_system.gd")
const DATA_LOADER := preload("res://scripts/core/data_loader.gd")

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

func test_turn_manager_emits_failure_signal_when_request_exceeds_delta() -> void:
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

    var reallocation_events: Array = []
    event_bus.competence_reallocated.connect(func(payload: Dictionary) -> void:
        reallocation_events.append(payload)
    )
    var failure_payloads: Array = []
    event_bus.competence_allocation_failed.connect(func(payload: Dictionary) -> void:
        failure_payloads.append(payload)
    )

    manager.start_game()
    var initial_events := reallocation_events.size()

    event_bus.request_competence_allocation({
        "tactics": 5.0,
        "strategy": 2.0,
        "logistics": 2.0,
    })

    asserts.is_equal(initial_events, reallocation_events.size(), "Invalid requests should not emit new competence events")
    asserts.is_equal(1, failure_payloads.size(), "Invalid delta should emit a single failure payload")
    var payload: Dictionary = failure_payloads[0]
    asserts.is_equal("delta_exceeds_cap", payload.get("reason", ""), "Failure payload should report the delta overflow reason")
    asserts.is_equal("tactics", payload.get("category", ""), "Failure payload should identify the offending category")
    asserts.is_true(payload.get("requested", {}) is Dictionary, "Failure payload should preserve requested allocations")

func test_turn_manager_processes_event_bus_competence_request() -> void:
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

    var reallocation_events: Array = []
    event_bus.competence_reallocated.connect(func(payload: Dictionary) -> void:
        reallocation_events.append(payload)
    )
    var failure_payloads: Array = []
    event_bus.competence_allocation_failed.connect(func(payload: Dictionary) -> void:
        failure_payloads.append(payload)
    )

    manager.start_game()
    reallocation_events.clear()

    event_bus.request_competence_allocation({
        "tactics": 2.5,
        "strategy": 1.75,
        "logistics": 1.75,
    })

    asserts.is_equal(0, failure_payloads.size(), "Valid allocation requests should not trigger failure payloads")
    asserts.is_equal(1, reallocation_events.size(), "Valid requests should emit a single competence event via the bus")
    var payload: Dictionary = reallocation_events[0]
    asserts.is_equal("manual", payload.get("reason", ""), "Manual requests should tag the competence payload with the manual reason")
    var allocations: Dictionary = payload.get("allocations", {})
    asserts.is_equal(2.5, float(allocations.get("tactics", 0.0)), "Payload should expose updated tactics allocation")
    asserts.is_equal(1.75, float(allocations.get("strategy", 0.0)), "Payload should expose updated strategy allocation")
    asserts.is_equal(1.75, float(allocations.get("logistics", 0.0)), "Payload should expose updated logistics allocation")

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

    system._on_competence_reallocated({
        "allocations": {"tactics": 4.0, "strategy": 1.0, "logistics": 1.0},
        "config": {
            "tactics": {"base_allocation": 2.0},
            "strategy": {"base_allocation": 2.0},
            "logistics": {"base_allocation": 2.0},
        },
    })
    system.set_unit_formation("infantry", "advance_column")
    system.set_rng_seed(5)
    var boosted := system.resolve_engagement(engagement)
    var boosted_impulse := boosted.get("pillars", {}).get("impulse", {}).get("attacker", 0.0)

    asserts.is_true(boosted_impulse > baseline_impulse, "Competence allocation should increase impulse pillar strength")

func test_combat_system_applies_formation_modifiers_to_pillars() -> void:
    var system: CombatSystem = COMBAT_SYSTEM.new()
    system.set_rng_seed(11)
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
        "engagement_id": "formation_test",
        "order_id": "advance",
        "attacker_unit_ids": ["infantry"],
        "defender_unit_ids": [],
        "terrain": "plains",
    }

    system.set_unit_formation("infantry", "advance_column")
    system.set_rng_seed(42)
    var column_result := system.resolve_engagement(engagement)
    var column_pillars: Dictionary = column_result.get("pillars", {})
    var column_position: float = float(column_pillars.get("position", {}).get("attacker", 0.0))
    var column_impulse: float = float(column_pillars.get("impulse", {}).get("attacker", 0.0))
    var column_information: float = float(column_pillars.get("information", {}).get("attacker", 0.0))

    system.set_unit_formation("infantry", "shield_wall")
    system.set_rng_seed(42)
    var shield_result := system.resolve_engagement(engagement)
    var shield_pillars: Dictionary = shield_result.get("pillars", {})
    var shield_position: float = float(shield_pillars.get("position", {}).get("attacker", 0.0))
    var shield_impulse: float = float(shield_pillars.get("impulse", {}).get("attacker", 0.0))
    var shield_information: float = float(shield_pillars.get("information", {}).get("attacker", 0.0))

    asserts.is_true(shield_position > column_position, "Shield wall should improve the attacker's position pillar")
    asserts.is_true(shield_impulse < column_impulse, "Shield wall should reduce impulse in exchange for resilience")
    asserts.is_true(shield_information < column_information, "Shield wall should trade information gains for protection")

func test_formation_system_enforces_cost_and_inertia() -> void:
    var event_bus: EventBus = EVENT_BUS.new()
    event_bus._ready()

    var loader: DataLoader = DATA_LOADER.new()
    loader.load_all()

    var turn_manager: TurnManager = TURN_MANAGER.new()
    turn_manager.setup(event_bus)

    var elan_system: ElanSystem = ELAN_SYSTEM.new()
    elan_system.setup(event_bus, loader)
    elan_system.set_turn_manager(turn_manager)
    elan_system.add_elan(3.0)

    var combat_system: CombatSystem = COMBAT_SYSTEM.new()
    combat_system.setup(event_bus, loader)

    var formation_system: FormationSystem = FORMATION_SYSTEM.new()
    formation_system.setup(event_bus, loader, combat_system, elan_system, turn_manager)

    turn_manager.start_game()

    var status_payloads: Array = []
    event_bus.formation_status_updated.connect(func(payload: Dictionary) -> void:
        status_payloads.append(payload)
    )
    var changes: Array = []
    event_bus.formation_changed.connect(func(payload: Dictionary) -> void:
        changes.append(payload)
    )
    var failures: Array = []
    event_bus.formation_change_failed.connect(func(payload: Dictionary) -> void:
        failures.append(payload)
    )

    status_payloads.clear()
    changes.clear()
    failures.clear()

    event_bus.request_formation_change({
        "unit_id": "infantry",
        "formation_id": "advance_column",
        "source": "test",
    })

    asserts.is_true(changes.size() > 0, "Formation change should emit a change payload")
    var change_payload: Dictionary = changes[0]
    asserts.is_equal("manual", change_payload.get("reason", ""), "Formation change should be tagged as manual")
    asserts.is_equal("advance_column", change_payload.get("formation_id", ""), "Infantry should adopt advance column")

    asserts.is_true(status_payloads.size() > 0, "Formation status should update after a change")
    var last_status: Dictionary = status_payloads.back()
    var units: Dictionary = last_status.get("units", {})
    var infantry_status: Dictionary = {}
    if units.has("infantry"):
        infantry_status = units.get("infantry", {})
    asserts.is_true(bool(infantry_status.get("locked", false)), "Infantry should be locked after the change")

    failures.clear()
    event_bus.request_formation_change({
        "unit_id": "infantry",
        "formation_id": "shield_wall",
        "source": "test",
    })
    asserts.is_true(failures.size() > 0, "A second change in the same turn should fail due to inertia")
    var failure_payload: Dictionary = failures.back()
    asserts.is_equal("inertia_locked", failure_payload.get("reason", ""), "Failure reason should cite inertia lock")

    turn_manager.advance_turn()
    turn_manager.advance_turn()

    changes.clear()
    event_bus.request_formation_change({
        "unit_id": "infantry",
        "formation_id": "shield_wall",
        "source": "test",
    })
    asserts.is_true(changes.size() > 0, "Formation change should succeed after inertia expires")
    change_payload = changes.back()
    asserts.is_equal("shield_wall", change_payload.get("formation_id", ""), "Infantry should adopt shield wall")

    var elan_state: Dictionary = elan_system.get_state_payload()
    var available_elan: float = float(elan_state.get("current", 0.0))
    asserts.is_true(available_elan < 1.0, "Élan should be deducted after two formation changes")

    var spend_amount := max(available_elan - 0.4, 0.0)
    if spend_amount > 0.0:
        elan_system.spend_elan(spend_amount)

    failures.clear()
    event_bus.request_formation_change({
        "unit_id": "cavalry",
        "formation_id": "screen",
        "source": "test",
    })
    asserts.is_true(failures.size() > 0, "Insufficient Élan should prevent the formation change")
    failure_payload = failures.back()
    asserts.is_equal("insufficient_elan", failure_payload.get("reason", ""), "Failure reason should cite Élan shortage")
