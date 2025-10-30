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

### AT-08: Overlay logistique hybride
- **Given** la scène principale est en cours d'exécution et `LogisticsSystem` a chargé les données JSON enrichies
- **When** j'active le bouton "Show Logistics"
- **Then** la console (ou le debug overlay) affiche un payload `logistics_update` listant anneaux `core/fringe/isolated`, routes actives et l'état des convois (progression, interception, livraisons)

### AT-09: Rotation météo et impacts mouvement/logistique
- **Given** la partie progresse sur plusieurs tours
- **When** j'observe les événements `weather_changed`
- **Then** les états `sunny`, `rain`, puis `mist` se succèdent et les payloads `logistics_update` reflètent les multiplicateurs de mouvement/flux associés

### AT-10: Interceptions sur routes exposées
- **Given** un convoi démarre sur la route avant (config "forward_operating")
- **When** plusieurs tours s'écoulent sous pluie ou brume
- **Then** au moins un payload `logistics_update` signale `last_event = intercepted`, la télémétrie archive l'événement `logistics_update`, et un événement dédié `logistics_break` est présent dans le buffer

### AT-11: Résolution Combat 3 Piliers
- **Given** la boucle de commandement déclenche un ordre offensif
- **When** `CombatSystem` reçoit un engagement avec doctrine active et météo en cours
- **Then** un payload `combat_resolved` est émis avec les trois piliers (`position`, `impulse`, `information`) et une victoire déterminée par majorité

### AT-12: Pings d'espionnage et intentions révélées
- **Given** la carte dispose d'un brouillard initial et de niveaux de logistique hétérogènes
- **When** `EspionageSystem` exécute un ping sous météo claire puis brumeuse
- **Then** la télémétrie `espionage_ping` reflète la confiance, le bruit météo, et révèle les intentions connues lorsque le ping réussit

### AT-13: Compétences et formations actives
- **Given** la scène principale est en cours d'exécution avec les curseurs de compétences visibles et les unités dotées de formations par défaut
- **When** je redistribue les points (`competence_reallocated`) puis déclenche une rupture logistique qui intercepte un convoi
- **Then** la télémétrie enregistre la baisse de budget compétence, un événement `formation_changed` apparaît lorsque je sélectionne une nouvelle posture, et la résolution de combat suivante reflète les bonus/malus de la formation choisie

All tests must pass without Godot warnings or errors in the console.
