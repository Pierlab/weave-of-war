# Acceptance Tests — Weave of War Skeleton

These checks validate the initial Godot project skeleton. Run them alongside the automated gdUnit-style tests described in
`AGENTS.md` and the README.

## Automated smoke tests
- `godot --headless --path . --script res://scripts/ci/gd_lint_runner.gd`
- `godot --headless --path . --script res://scripts/ci/gd_build_check.gd`
- `godot --headless --path . --script res://scripts/ci/gdunit_runner.gd`

## Manual flow (AT series)
### AT-01: Main scene boots with hex map
- **Given** the project is opened in Godot 4.x
- **When** `scenes/main.tscn` runs
- **Then** a 10x10 hex grid is visible and the camera frames the map

### AT-02: HUD controls are available
- **Given** the main scene is running
- **When** I inspect the CanvasLayer
- **Then** I see buttons labelled "Next Turn" and "Show Logistics"

### AT-03: Debug overlay actions
- **Given** the main scene is running
- **When** I interact with the debug overlay
- **Then** buttons exist for "Next Turn", "Toggle Logistics", and "Spawn Unit"

### AT-04: Turn loop logging
- **Given** the main scene is running
- **When** the game starts or I press "Next Turn"
- **Then** the output console logs `Turn 1 started` followed by `Turn 1 ended` (incrementing on subsequent turns) without errors

### AT-05: Logistics toggle feedback
- **Given** the main scene is running
- **When** I press "Show Logistics"
- **Then** the console prints the new overlay state and the HUD button text flips between "Show Logistics" and "Hide Logistics"

### AT-06: Data loader readiness & telemetry capture
- **Given** the main scene is running from a clean boot
- **When** the game initialises
- **Then** the console prints a `DataLoader ready` summary and telemetry buffers contain an entry named `data_loader_ready`
  with doctrine/order/unit counts greater than zero

### AT-07: Boucle commandement/Élan interactif
- **Given** la scène principale est en cours d'exécution
- **When** je sélectionne une doctrine différente puis exécute un ordre autorisé via la HUD
- **Then** la HUD met à jour l'inertie, joue un signal sonore court, ajuste la jauge d'Élan et le journal console confirme l'émission de l'ordre

All tests must pass without Godot warnings or errors in the console.
