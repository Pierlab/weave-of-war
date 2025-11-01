extends GdUnitLiteTestCase

const FORMATION_OVERLAY := preload("res://scenes/map/formation_overlay.gd")

func test_abbreviate_label_extracts_initials() -> void:
    # Ensure the script is loaded for static access
    _ = FORMATION_OVERLAY
    asserts.is_equal("SW", FormationOverlay.abbreviate_label("Shield Wall"))
    asserts.is_equal("AC", FormationOverlay.abbreviate_label("advance column"))
    asserts.is_equal("I", FormationOverlay.abbreviate_label("Infantry"))
    asserts.is_equal("", FormationOverlay.abbreviate_label("   "))

func test_posture_color_returns_consistent_palette() -> void:
    _ = FORMATION_OVERLAY
    var aggressive := FormationOverlay.posture_color("aggressive")
    asserts.is_equal(Color(0.88, 0.32, 0.32, 1.0), aggressive, "Aggressive posture should use the warm assault tint")
    var defensive := FormationOverlay.posture_color("defensive")
    asserts.is_equal(Color(0.32, 0.58, 0.86, 1.0), defensive, "Defensive posture should use the cool shield tint")
    var fallback := FormationOverlay.posture_color("unknown")
    asserts.is_equal(FormationOverlay.posture_color(""), fallback, "Unknown postures should fall back to the neutral color")
