extends GdUnitLiteTestCase

const COMBAT_SYSTEM := preload("res://scripts/systems/combat_system.gd")

func _build_minimal_formations() -> Array:
    return [
        {
            "id": "line",
            "name": "Ligne",
            "posture": "balanced",
            "pillar_modifiers": {"position": 0.0, "impulse": 0.0, "information": 0.0},
            "competence_weight": {},
        }
    ]

func _build_default_orders() -> Array:
    return [
        {
            "id": "skirmish",
            "pillar_weights": {"position": 0.1, "impulse": 0.2, "information": 0.0},
            "intel_profile": {"signal_strength": 0.4, "counter_intel": 0.1},
        }
    ]

func _build_default_doctrines() -> Array:
    return [
        {
            "id": "balanced",
            "effects": {
                "intel_visibility_modifier": 0.0,
                "combat_bonus": {"position": 0.0, "impulse": 0.0, "information": 0.0},
                "combat_pillar_focus": "",
            },
        }
    ]

func _build_default_weather() -> Array:
    return [
        {
            "id": "clear",
            "combat_modifiers": {"position": 1.0, "impulse": 1.0, "information": 1.0},
        }
    ]

func _build_units_for_repro() -> Array:
    return [
        {
            "id": "alpha",
            "name": "Alpha Cohort",
            "combat_profile": {"position": 1.4, "impulse": 0.8, "information": 0.5},
            "recon_profile": {"detection": 0.25, "counter_intel": 0.15},
            "competence_synergy": {"tactics": 0.6, "strategy": 0.5, "logistics": 0.4},
            "default_formations": ["line"],
        },
        {
            "id": "bravo",
            "name": "Bravo Riders",
            "combat_profile": {"position": 0.7, "impulse": 1.6, "information": 0.4},
            "recon_profile": {"detection": 0.2, "counter_intel": 0.2},
            "competence_synergy": {"tactics": 0.7, "strategy": 0.3, "logistics": 0.2},
            "default_formations": ["line"],
        }
    ]

func _build_units_for_tie_breaker() -> Array:
    return [
        {
            "id": "attacker",
            "combat_profile": {"position": 1.6, "impulse": 0.4, "information": 0.2},
            "recon_profile": {"detection": 0.0, "counter_intel": 0.0},
            "competence_synergy": {},
            "default_formations": ["line"],
        },
        {
            "id": "defender",
            "combat_profile": {"position": 0.4, "impulse": 1.4, "information": 0.2},
            "recon_profile": {"detection": 0.0, "counter_intel": 0.0},
            "competence_synergy": {},
            "default_formations": ["line"],
        }
    ]

func _initialise_system(unit_entries: Array) -> CombatSystem:
    var system: CombatSystem = COMBAT_SYSTEM.new()
    system.configure(
        unit_entries,
        _build_default_orders(),
        _build_default_doctrines(),
        _build_default_weather(),
        _build_minimal_formations()
    )
    system.set_active_doctrine("balanced")
    system.set_current_weather("clear")
    return system

func test_resolve_engagement_is_seed_reproducible() -> void:
    var system := _initialise_system(_build_units_for_repro())
    var engagement := {
        "engagement_id": "seed_baseline",
        "order_id": "skirmish",
        "attacker_unit_ids": ["alpha", "bravo"],
        "defender_unit_ids": ["bravo"],
        "terrain": "plains",
        "target_hex": "0,0",
        "intel_confidence": 0.55,
        "espionage_bonus": 0.15,
        "defender_posture": "hold",
    }

    system.set_rng_seed(11)
    var first := system.resolve_engagement(engagement)
    system.set_rng_seed(11)
    var second := system.resolve_engagement(engagement)

    for pillar in ["position", "impulse", "information"]:
        var first_pillar: Dictionary = first.get("pillars", {}).get(pillar, {})
        var second_pillar: Dictionary = second.get("pillars", {}).get(pillar, {})
        var first_attacker := float(first_pillar.get("attacker", 0.0))
        var second_attacker := float(second_pillar.get("attacker", 0.0))
        var first_defender := float(first_pillar.get("defender", 0.0))
        var second_defender := float(second_pillar.get("defender", 0.0))
        asserts.is_true(is_equal_approx(first_attacker, second_attacker), "%s attacker strength should be reproducible" % pillar)
        asserts.is_true(is_equal_approx(first_defender, second_defender), "%s defender strength should be reproducible" % pillar)
        asserts.is_equal(first_pillar.get("winner"), second_pillar.get("winner"), "%s winner should be reproducible" % pillar)

    asserts.is_equal(first.get("victor"), second.get("victor"), "Combat victor should remain stable with the same seed")
    asserts.is_true(is_equal_approx(
        float(first.get("pillar_summary", {}).get("margin_score", 0.0)),
        float(second.get("pillar_summary", {}).get("margin_score", 0.0))
    ), "Margin score should remain identical when reseeding")

    var first_units: Array = first.get("units", {}).get("attacker", [])
    var second_units: Array = second.get("units", {}).get("attacker", [])
    asserts.is_true(first_units.size() == second_units.size(), "Attacker roster should stay stable between runs")
    if first_units.size() > 0:
        asserts.is_equal(first_units[0].get("status", ""), second_units[0].get("status", ""), "Unit status labels should be reproducible")

func test_combat_tie_breaker_marks_contested_outcome() -> void:
    var system := _initialise_system(_build_units_for_tie_breaker())
    var engagement := {
        "engagement_id": "tie_breaker",
        "order_id": "skirmish",
        "attacker_unit_ids": ["attacker"],
        "defender_unit_ids": ["defender"],
        "terrain": "plains",
        "target_hex": "1,1",
        "intel_confidence": 0.5,
        "defender_posture": "hold",
        "attacker_bonus": {"information": 0.2},
        "defender_bonus": {"information": 0.2},
    }

    system.set_rng_seed(17)
    var result := system.resolve_engagement(engagement)
    asserts.is_equal("contested", result.get("victor", ""), "One pillar each plus a stalemate should flag a contested battle")

    var pillars: Dictionary = result.get("pillars", {})
    asserts.is_equal("attacker", pillars.get("position", {}).get("winner", ""), "Attacker should capture the position pillar")
    asserts.is_equal("defender", pillars.get("impulse", {}).get("winner", ""), "Defender should capture the impulse pillar")
    asserts.is_equal("stalemate", pillars.get("information", {}).get("winner", ""), "Information pillar should remain undecided")

    var decisive: Array = result.get("pillar_summary", {}).get("decisive_pillars", [])
    var attackers := decisive.filter(func(entry): return entry.get("winner", "") == "attacker")
    var defenders := decisive.filter(func(entry): return entry.get("winner", "") == "defender")
    asserts.is_true(attackers.size() == 1, "Summary should record one decisive pillar for the attacker")
    asserts.is_true(defenders.size() == 1, "Summary should record one decisive pillar for the defender")

func test_logistics_severity_reduces_strength_and_increases_casualties() -> void:
    var system := _initialise_system(_build_units_for_repro())
    var engagement := {
        "engagement_id": "logistics_penalty",
        "order_id": "skirmish",
        "attacker_unit_ids": ["alpha"],
        "defender_unit_ids": ["bravo"],
        "terrain": "forest",
        "target_hex": "3,5",
        "intel_confidence": 0.6,
        "espionage_bonus": 0.1,
        "defender_posture": "hold",
    }

    system.set_rng_seed(23)
    var baseline := system.resolve_engagement(engagement)

    system._on_logistics_update({
        "turn": 6,
        "logistics_id": "northern_route",
        "supply_zones": [
            {"tile_id": "3,5", "logistics_flow": 0.6, "movement_cost": 1.4, "supply_level": "strained"}
        ],
        "supply_deficits": [
            {"tile_id": "3,5", "severity": "critical"}
        ],
    })

    system.set_rng_seed(23)
    var degraded := system.resolve_engagement(engagement)

    var baseline_position := float(baseline.get("pillars", {}).get("position", {}).get("attacker", 0.0))
    var degraded_position := float(degraded.get("pillars", {}).get("position", {}).get("attacker", 0.0))
    asserts.is_true(degraded_position < baseline_position, "Critical logistics penalties should reduce attacker position strength")

    var logistics := degraded.get("logistics", {})
    asserts.is_equal("critical", logistics.get("severity", ""), "Logistics payload should surface the critical severity")
    asserts.is_true(is_equal_approx(0.39, float(logistics.get("attacker_factor", 0.0))), "Attacker factor should include flow and severity penalties")
    asserts.is_true(is_equal_approx(1.0, float(logistics.get("defender_factor", 0.0))), "Defender factor remains neutral without supply strain")

    var baseline_units: Array = baseline.get("units", {}).get("attacker", [])
    var degraded_units: Array = degraded.get("units", {}).get("attacker", [])
    if baseline_units.size() > 0 and degraded_units.size() > 0:
        var base_casualties := float(baseline_units[0].get("casualties", 0.0))
        var degraded_casualties := float(degraded_units[0].get("casualties", 0.0))
        asserts.is_true(degraded_casualties > base_casualties, "Supply deficits should increase attacker casualties")
