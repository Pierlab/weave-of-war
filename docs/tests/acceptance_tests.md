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

### AT-07: Boucle commandement/Élan interactive
- **Given** la scène principale est en cours d'exécution et les autoloads `EventBus`, `Telemetry`, `AssistantAI` et `DataLoader` ont émis leurs logs de démarrage
- **When** je suis les étapes ci-dessous
- **Then** la HUD met à jour l'inertie et l'Élan, les validations d'ordre s'affichent in-line, et la télémétrie enregistre les événements correspondants

**Étapes détaillées**
1. Ouvrir la scène principale dans l'éditeur Godot et lancer le jeu (`F5`). Attendre que la console affiche `DataLoader ready` et que la HUD affiche les doctrines disponibles.
2. Dans le panneau doctrine de la HUD, choisir une doctrine différente de celle active (ex. passer de **Force** à **Ruse**). Vérifier :
   - La ligne "Inertie" met à jour les tours restants.
   - Le tooltip du sélecteur rappelle le multiplicateur d'inertie de la doctrine sélectionnée.
   - Un court bip de feedback audio est joué.
3. Tenter immédiatement un nouveau changement de doctrine alors que l'inertie est verrouillée. Constater que :
   - La HUD restaure la doctrine précédente.
   - Un tooltip ou message d'erreur précise la raison du refus (ex. "Inertie restante: 1 tour").
4. Sélectionner un ordre autorisé dans la liste (ex. **Advance**) et survoler le bouton d'exécution pour vérifier l'infobulle indiquant le coût d'Élan actuel ainsi que l'Élan manquant le cas échéant.
5. Cliquer sur le bouton d'exécution de l'ordre lorsque l'Élan disponible est suffisant. Confirmer :
   - La jauge d'Élan diminue du montant attendu et affiche le total restant.
   - La console et la debug overlay consigne un paquet `assistant_order_packet` (nom de l'ordre, cible, intention, confiance).
6. Ouvrir le **Debug > Remote** dans l'éditeur Godot, sélectionner `TelemetryAutoload` puis inspecter la propriété `buffer`. Vérifier qu'une séquence d'événements `doctrine_selected`, `order_issued`, `elan_spent` (et `order_rejected` si l'étape 3 a été déclenchée) est présente avec des payloads renseignant l'identifiant, le coût et le reste d'Élan.

### AT-08: Overlay logistique hybride
- **Given** la scène principale est en cours d'exécution et `LogisticsSystem` a chargé les données JSON enrichies
- **When** j'active le bouton "Show Logistics" depuis la HUD **et** le panneau debug
- **Then** la console (ou le debug overlay) affiche un payload `logistics_update` listant les anneaux `core/fringe/isolated`, les tuiles atteignables et les convois avec leurs `last_event`
- **And** chaque bascule HUD/debug imprime une trace `logistics_overlay_toggled` confirmant l'état `shown/hidden`
- **And** les boutons "Show Logistics" exposent un tooltip récapitulant Plaines/Forêts/Collines avec leur coût de mouvement et le nombre de tuiles couvertes.

### AT-09: Rotation météo et impacts mouvement/logistique
- **Given** la partie progresse sur plusieurs tours
- **When** j'observe successivement trois payloads `weather_changed`
- **Then** les états `sunny`, `rain`, puis `mist` se succèdent et les payloads `logistics_update` reflètent les multiplicateurs de mouvement/flux et les blocs `weather_adjustments`
- **And** le panneau météo de la HUD actualise son icône colorée, le libellé affiche les tours restants, et le tooltip résume les modificateurs de mouvement, flux logistique, bruit intel et bonus d'Élan.
- **And** les tooltips logistics (HUD et debug) mettent à jour le nombre de tuiles atteignables lorsque la météo réduit la portée.

### AT-10: Interceptions sur routes exposées
- **Given** un convoi démarre sur la route avant (config "forward_operating")
- **When** plusieurs tours s'écoulent sous pluie ou brume
- **Then** au moins un payload `logistics_update` signale `last_event = intercepted`, la télémétrie archive l'événement `logistics_update`, et un événement dédié `logistics_break` est présent dans le buffer
- **And** l'état du tooltip HUD/debug met à jour le compteur de convois interceptés dans la section résumée.

### AT-11: Résolution Combat 3 Piliers
- **Given** la boucle de commandement déclenche un ordre offensif
- **When** `CombatSystem` reçoit un engagement avec doctrine active et météo en cours
- **Then** un payload `combat_resolved` est émis avec les trois piliers (`position`, `impulse`, `information`) et une victoire déterminée par majorité
- **And** le payload expose un bloc `logistics` (niveau d'approvisionnement, flow, sévérité, tour) pour expliquer l'impact de la supply sur la résolution
- **And** le panneau HUD "Dernier engagement" affiche les jauges des trois piliers, un résumé logistique (flow, sévérité, mouvement) et les ajustements d'Élan correspondants sans revenir à l'état par défaut.

### AT-12: Pings d'espionnage et intentions révélées
- **Given** la carte dispose d'un brouillard initial et de niveaux de logistique hétérogènes
- **When** `EspionageSystem` exécute un ping sous météo claire puis brumeuse
- **Then** la télémétrie `espionage_ping` reflète la confiance, le bruit météo, et révèle les intentions connues lorsque le ping réussit

### AT-13: Compétences et formations actives
- **Given** la scène principale est en cours d'exécution avec les curseurs de compétences visibles et les unités dotées de formations par défaut
- **When** je redistribue les points (`competence_reallocated`) puis déclenche une rupture logistique qui intercepte un convoi
- **Then** la télémétrie enregistre la baisse de budget compétence, un événement `formation_changed` apparaît lorsque je sélectionne une nouvelle posture, et la résolution de combat suivante reflète les bonus/malus de la formation choisie

All tests must pass without Godot warnings or errors in the console.
