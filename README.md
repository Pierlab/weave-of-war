# Weave of War

Weave of War is a strategy game prototype built with Godot 4.x that focuses on logistics, doctrines, and Élan-driven momentum.
This repository now bundles the rituals and automation needed for agent-driven vibe coding.

## Getting Started
1. Install [Godot 4.5.1](https://godotengine.org/) (headless-capable builds are required for CI parity).
2. Open the project by launching Godot and selecting the `project.godot` file in this repository.
3. Read [`AGENTS.md`](AGENTS.md) for the workflow rules, required documents, and test commands.
4. Review the current mission briefs in [`docs/agents/missions/`](docs/agents/missions/)—start with
   [`vertical_slice_p0.md`](docs/agents/missions/vertical_slice_p0.md) to align on the vertical slice scope—and the latest
   [`context_snapshot.md`](context_snapshot.md).
5. Review the refreshed Vertical Slice P0 execution plan in [`CHECKLISTS.md`](CHECKLISTS.md) (2025 detailed checklist) and follow its numbered steps sequentially—the checklist is now an execution script rather than a loose backlog. The previous milestone summary now lives in [`docs/agents/archive/CHECKLISTS_2024-vertical_slice_snapshot.md`](docs/agents/archive/CHECKLISTS_2024-vertical_slice_snapshot.md).
   Use the one-page GDD summary in [`docs/gdd_vertical_slice.md`](docs/gdd_vertical_slice.md) to stay aligned on vision, pillars, loops,
   and risks. Structural decisions are archived in Architecture Decision Records (ADRs); start with
   [`docs/ADR_0002_event_bus_and_telemetry_autoloads.md`](docs/ADR_0002_event_bus_and_telemetry_autoloads.md) for the autoload
   signal contract governing Checklist C systems.
6. Familiarise yourself with the autoload singletons listed below—they provide the shared data, telemetry, and assistant hooks
   required to deliver Checklist C systems without additional plumbing.

### Launching the project locally

When launching the editor on Windows, the following PowerShell command opens the project from its workspace directory while
capturing verbose logs (update the base path if you installed Godot elsewhere):

```powershell
c:\Users\plab7\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe -v --path 'C:\Users\plab7\Desktop\Weave of War\weave-of-war'
```

The logs above are mirrored in `errors.log` at the repository root to help future agents diagnose renderer/device warnings.

## Core autoloads

| Autoload (project.godot) | Class name | Script | Responsibilities |
| --- | --- | --- | --- |
| `EventBusAutoload` | `EventBus` | `scripts/core/event_bus.gd` | Global signal hub for turn flow, checklist C system events (Élan, logistics, combat, espionage, weather, competence sliders) and new data-loader notifications. |
| `DataLoaderAutoload` | `DataLoader` | `scripts/core/data_loader.gd` | Loads the JSON datasets in `data/`, enforces schema/enum validation via `validate_collection()`, caches collections by id, and defers its readiness/error payloads so telemetry + assistant hooks capture the initial `data_loader_ready` signal (see `tests/gdunit/test_autoload_preparation.gd`). |
| `TelemetryAutoload` | `Telemetry` | `scripts/core/telemetry.gd` | Records gameplay telemetry with normalised payloads for doctrine selection, order issuance/rejection, Élan spend/gain, logistics, combat, and espionage signals. Exposes `log_event`, `get_buffer`, and `clear` helpers so tests can assert Checklist C flows. |
| `AssistantAIAutoload` | `AssistantAI` | `scripts/core/assistant_ai.gd` | Subscribes to doctrine/order/competence signals and publishes placeholder `assistant_order_packet` payloads that future iterations will enrich with simulations. |

The autoloads initialise automatically when the project starts (and during headless test runs). Systems being developed for
Checklist C should request dependencies from these singletons instead of reading JSON files or crafting their own signal buses.
Startup instrumentation now prints readiness logs for all four services; the latest excerpt lives in
[`docs/logs/autoload_readiness_2025-11-04.log`](docs/logs/autoload_readiness_2025-11-04.log) and is locked by
`tests/gdunit/test_autoload_preparation.gd`, which also validates that the project registers the renamed singletons in
`project.godot`.

## Command & Élan loop (Semaine 0–1)
- The doctrine catalogue in [`data/doctrines.json`](data/doctrines.json) now locks the five SDS-approved stances (Force/Ruse/Patience/Vitesse/Équilibre) with command profiles covering CP cap deltas, swap token budgets, and inertia multipliers for downstream systems.
- The command orders dataset in [`data/orders.json`](data/orders.json) now captures CP costs, base delay turns, doctrine requirements, targeting scopes, posture gates, and assistant intent metadata so Command Model, Élan, and Assistant AI flows consume a single contract aligned with the SDS.
- The HUD now exposes a doctrine selector tied to the `DoctrineSystem`, displays inertia locks, surfaces doctrine-specific
  inertia multipliers, and lists the orders authorised by the active doctrine.
- Order execution routes through the Élan system, enforcing Élan caps, doctrine-based restrictions, and inertia impacts before
  emitting `order_issued` telemetry.
- `AssistantAI` now records the latest order packets, emits enriched `assistant_order_packet` payloads, and the debug overlay
  surfaces a scrollable log (order, target, intent, confidence) so designers can verify the propagation loop without leaving
  the HUD.
- Targeted gdUnit coverage in [`tests/gdunit/test_command_elan_loop.gd`](tests/gdunit/test_command_elan_loop.gd) now exercises doctrine swap failures, Élan spend success/error states, and the Assistant AI acknowledgement to keep the command loop locked while the HUD evolves.
- Doctrine swaps and order execution now scale inertia using the SDS multipliers (`command_profile.inertia_multiplier` plus
  `orders[].inertia_profile.doctrine_multipliers`), guaranteeing at least one full turn of lock when orders are issued while
  reporting the remaining inertia through HUD tooltips and telemetry payloads.
- `ElanSystem` clamps the pool to the configured cap, applies doctrine-driven cap bonuses, and schedules automatic decay when
  the gauge stays maxed for consecutive rounds. Decay emits `elan_spent` events with a `reason="decay"` flag so telemetry can
  distinguish voluntary spends.
- `EventBus` et `Telemetry` consignent désormais des payloads normalisés `doctrine_selected`, `order_issued`, `order_rejected`,
  `elan_spent` et `elan_gained`, donnant aux dashboards/tests une vision fidèle des décisions de commandement et du flux d'Élan.
- A lightweight audio cue (generated on the fly) and status label provide immediate visual/sonore feedback when doctrines or
  orders change.
- `GameManager` now waits for the deferred `data_loader_ready` signal before wiring `DoctrineSystem`/`ElanSystem` and kicking off the first turn, printing the collection counts to confirm the handshake.
- The procedural audio generator now queues tone requests, waits for the playback instance to go inactive, then clears and
  refills the buffer before replaying. This deferred guard removes the recurring `AudioStreamGeneratorPlayback.clear_buffer`
  warnings/leaks that previously spammed the console during rapid doctrine/order swaps and on shutdown.

### HUD UX copy & feedback
- **Doctrine selector** — Each entry mirrors the doctrine `name` from `data/doctrines.json`. Selecting a doctrine updates the status label with the template `Doctrine : {Nom} — Inertie {N} tour(s)` so players see how many turns remain before the stance can change again, while the tooltip lists remaining swap tokens and the current Élan cap bonus granted by the doctrine. When the selector is locked by inertia, the HUD now restores the previous choice automatically and surfaces the validation message inline instead of silently ignoring the input.
- **Inertie label** — A dedicated `Inertie : {N} tour(s) · x{M}` line surfaces the doctrine multiplier qui sera appliquée au prochain ordre, avec une infobulle rappelant que toute commande ajoutera au minimum la durée d'inertie affichée.
- **Order selector** — Orders are rendered as `{Nom} (X.X Élan)` using the `base_elan_cost` from `data/orders.json`. The HUD refreshes the list whenever the doctrine changes so only authorised orders appear.
- **Execute button** — The primary call-to-action reads `Exécuter l'ordre` when no cost applies and switches to `Exécuter (X.X Élan)` when Élan is required. The button is disabled automatically if the selected order is unaffordable or missing, and its tooltip now explains whether an order must be selected or how much Élan is missing so keyboard users receive the same inline validation as the feedback label.
- **Feedback label** — Success messages adopt a cool blue tint (`Color(0.7, 0.9, 1.0)`) and include copy such as `Doctrine active : {Nom}` or `Ordre '{Nom}' exécuté (X.X Élan restant)`. Validation errors reuse warm amber (`Color(1.0, 0.65, 0.5)`) with explicit guidance: `Doctrine verrouillée par l'inertie`, `Élan insuffisant : X.X requis, X.X disponible`, or `Choisissez un ordre à exécuter.`
- **Audio cues** — Positive actions (doctrine swap, order execution) trigger short sine tones at 660 Hz and 520 Hz, while validation warnings play 200 Hz or 220 Hz cues. All tones last 0.12 s at volume 0.2, share a 44.1 kHz sample rate, and fade with a fast attack envelope to avoid harsh peaks.
- **Logistics toggle** — The logistics overlay button swaps between `Show Logistics` and `Hide Logistics`, keeping the action verb front-loaded for screen-reader clarity and future localisation keys.
- **Weather panel** — A compact colour-coded icon sits next to the logistics toggle, updating whenever `WeatherSystem` broadcasts
  a `weather_changed` payload. The label lists the current weather name and remaining turns while the tooltip summarises movement,
  logistics flow, intel noise, and Élan regeneration modifiers for fast reference.
- **Accessibility notes** — Élan totals show both absolute (`Élan : X.X / Y.Y`) and trend indicators (`↗` income, `↘` upkeep). A context-rich tooltip on the Élan label lists base cap, active doctrine bonus, turns spent at cap, and the decay scheduled for the next round so keyboard and screen-reader users receive the same warnings surfaced by colour shifts. All feedback strings avoid colour-only messaging by embedding the validation reason in text, while the paired positive/negative hues exceed WCAG contrast guidelines against the HUD's neutral background.

## Logistics backbone & terrain feedback (Semaine 2–3)
- `LogisticsSystem` now simulates hybrid rings, overland roads, and harbor convoys, emitting rich `logistics_update` payloads
  that describe supply levels, terrain-driven flow modifiers, convoy progress/interruptions, the list of reachable tiles, and
  any supply deficits flagged for command follow-up.
- The logistics overlay renders pulsing supply rings and animated convoy markers driven directly by those payloads, tinting
  `core`, `fringe`, and `isolated` tiles differently and swapping convoy icons to red crosses when interceptions occur so the
  map immediately reflects supply health.
- `GameManager` instantiates `LogisticsSystem` after `DataLoader` readiness so `turn_started` and `logistics_toggled` signals
  immediately drive supply payloads, with gdUnit coverage guarding the bootstrap path.
- Logistics disruptions now raise a dedicated `logistics_break` event for analytics, capturing the disrupted tile/route, Élan and
  competence penalties, and current weather/logistics contexts for downstream dashboards.
- Dedicated gdUnit cases in [`tests/gdunit/test_logistics_system.gd`](tests/gdunit/test_logistics_system.gd) now lock storm-driven reachability shrinkage, single-fire convoy interception breaks,
  and the cadence of logistics-controlled weather rotations so downstream HUD and telemetry consumers stay in sync.
- `WeatherSystem` now orchestrates the rotation of `sunny`/`rain`/`mist` states using the `duration_turns` ranges in
  [`data/weather.json`](data/weather.json), emitting deterministic `weather_changed` payloads with modifiers and remaining
  turns so logistics, combat, espionage, and UI consumers stay in sync without bespoke plumbing.
- `Telemetry` capture désormais chaque `weather_changed` avec un schéma normalisé (modificateurs de mouvement, flux logistique,
  bruit d'intel, bonus d'Élan, durée restante), ce qui alimente directement les dashboards météo/logistique sans devoir
  réhydrater les dictionnaires Godot côté analytique.
- Weather-driven penalties now feed directly into logistics throughput: `LogisticsSystem` publishes a `weather_adjustments`
  summary and per-route `intercept_risk` blocks so QA/debug overlays can trace how rain or mist slow convoys and heighten
  interceptions across the hybrid supply network.
- Terrain layout and biome definitions now live in [`data/terrain.json`](data/terrain.json); the hex map consumes those entries to
  display Plains/Forest/Hill names directly on tiles while HUD and debug overlay tooltips summarise movement costs and tile
  counts for quick reference.
- Terrain defaults cloned from `TerrainData` are now merged into the runtime dictionary before applying DataLoader overrides, so
  designers can safely tweak biome names, descriptions, and movement costs without tripping Godot's read-only dictionary guard.
- Terrain defaults derived from `TerrainData` are combined with supply-center distance calculations to label tiles as `core`,
  `fringe`, or `isolated`, ensuring movement costs and convoy interception odds reflect both geography and climate, even before
  bespoke terrain layouts are provided.

## Combat pillars & espionage intelligence (Semaine 4–5)
- `CombatSystem` now resolves Manoeuvre/Feu/Moral contests by combining unit combat profiles, doctrine bonuses, terrain and
  weather multipliers, and the latest espionage confidence. Each resolution emits a `combat_resolved` payload for telemetry and
  upcoming HUD combat panels.
- Pillar calculations follow the SDS outline and blend additive profiles with multiplicative context:
  - **Position** multiplies the summed unit/formation/doctrine/order bonuses by terrain, weather, doctrine focus, logistics flow,
    movement-cost penalties, and espionage edge (+5%). Supply warnings reduce the total to 90%; critical deficits clamp at 75%.
  - **Impulse** applies terrain, weather, doctrine focus, and logistics flow, then scales by `[1 + 0.5*(intel_confidence-0.5) +
    0.35*espionage_bonus + 0.4*(logistics_factor-1)]`.
  - **Information** scales the additive profile by terrain, weather, doctrine focus, logistics, and `[0.6 + intel_confidence +
    espionage_bonus + signal_strength + 0.4*(detection-counter_intel)]`.
  - Defenders receive posture bonuses before multipliers plus bespoke dampeners: supply warnings/critical (×0.95/×0.8), intel
    clamp for Position, `[1 + 0.6*posture_impulse + 0.2*counter_intel - 0.2*espionage_bonus]` for Impulse, and `[0.9 +
    counter_intel + order.counter_intel - 0.4*espionage_bonus]` for Information.
- `GameManager` now instantiates `CombatSystem` with the other core loops and routes live `logistics_update` data into combat
  resolutions. Engagement telemetry embeds a `logistics` block (flow, supply level, deficit severity) so HUD panels and
  dashboards can explain how supply health shifted pillar results.
- `EspionageSystem` maintains fog of war at the tile level, ingests logistics payloads to boost visibility, and fires
  probabilistic pings that can reveal enemy intentions via `espionage_ping`. The dedicated gdUnit coverage in
  `tests/gdunit/test_combat_and_espionage_systems.gd` locks behaviour under sunny vs. misty weather noise.

## Competence sliders & formations (Semaine 6)
- `TurnManager` now maintains a per-turn competence budget across the `tactics`, `strategy`, and `logistics` sliders. Manual
  reallocations emit `competence_reallocated` telemetry and logistics breaks consume available points automatically, keeping the
  command economy responsive to convoy disruptions.
- Unit formations are described in the new [`data/formations.json`](data/formations.json) catalogue. `CombatSystem` tracks the
  active formation for each unit, publishes `formation_changed` events, and folds formation posture bonuses into pillar
  resolution alongside competence allocations.
- `DataLoader` exposes the formations dataset, while `Telemetry` records competence and formation events so gdUnit tests can
  assert on the complete Semaine 6 loop.

## Running automated checks
All headless commands assume the Godot executable is available on your `PATH`. When switching branches or updating Godot, remove
the `.godot/` metadata folder to avoid stale parser caches before running the commands below.
```bash
godot --headless --path . --script res://scripts/ci/gd_lint_runner.gd
godot --headless --path . --script res://scripts/ci/gd_build_check.gd
godot --headless --path . --script res://scripts/ci/gdunit_runner.gd
```
If your environment does not yet provide a `godot` executable, run the following Python snippet to confirm every vertical slice
JSON file still parses cleanly while you provision the engine:

```bash
python - <<'PY'
import json, os
for root, _, files in os.walk("data"):
    for name in files:
        if name.endswith(".json"):
            with open(os.path.join(root, name)) as fh:
                json.load(fh)
print("All JSON data files parsed successfully")
PY
```
The gdUnit suite now includes data integrity coverage that loads each JSON data file under `data/` and validates required keys and types before gameplay logic consumes them. `tests/gdunit/test_data_integrity.gd` now asserts both positive (`test_data_loader_validation_accepts_valid_payload`) and negative (`test_data_loader_validation_reports_missing_keys`) paths for the hardened `DataLoaderAutoload.validate_collection()` helper.
These scripts now extend `SceneTree` directly so they can be executed with `--script` in both local shells and CI runners.
They power local validation and the GitHub Actions workflow defined in `.github/workflows/ci.yml`.

### Godot resource UID sidecars
Godot 4.2+ stores stable resource identifiers in sidecar files that mirror the resource path with a `.uid` suffix (for example
`scripts/ui/hud_manager.gd.uid`). These files must stay alongside their parent resources in version control—the engine uses them
to resolve references when scenes or scripts are renamed. Do not delete them unless you also remove the associated resource.

### Troubleshooting build parsing
- If the build smoke check reports missing class names (for example `HexTile` or `EventBus`), preload the corresponding script
  resource before using it for type annotations or `is` checks. See `scenes/map/map.gd` and the UI scripts under
  `scripts/ui/` for reference on the preferred preload pattern.
- If Godot reports `Could not find type "EventBus"` (or similar) after adjusting an autoload script, remove the `.godot/`
  folder or regenerate the project class cache so `.godot/global_script_class_cache.cfg` picks up the new `class_name`
  identifiers.
- Godot 4.5 removed the `condition ? a : b` ternary helper. Replace those expressions with the Python-style
  `a if condition else b` form to avoid parse errors when opening the project or running the headless build script.
- If you encounter `Unexpected "class_name" here` parse errors, declare the `class_name` **before** the `extends` line. The
  core systems and autoloads (for example `scripts/core/event_bus.gd`) now follow this order for compatibility with older
  editor builds that still read the project.
- Treating warnings as errors is intentional. Godot 4.6+ now blocks scripts whose `class_name` matches the autoload singleton
  name, so the four core scripts expose distinct classes (`EventBus`, `DataLoader`, `Telemetry`, `AssistantAI`) while the
  `project.godot` entries keep the `*Autoload` suffix. Use the class names for type hints and the autoload keys when accessing
  the singletons via the global scope.
- When you pull structured data from dictionaries (doctrines, orders, etc.), provide explicit type hints instead of relying on
  `:=` inference. Godot 4.5 infers such values as `Variant`, which now triggers blocking parse errors. Inspect
  `scripts/core/data_loader.gd`, `scripts/systems/elan_system.gd`, and `scripts/ui/hud_manager.gd` for the preferred explicit
  typing pattern, including casting results from helpers such as `clamp()`.

### Expected Windows startup warnings
- **SDL controller mappings** — Godot surfaces `Unrecognized output string "misc2" in mapping` when newer Nintendo/Hori Switch
  pads are connected. The SDL mapping database ships with extra button aliases (`misc2`, `paddleX`) that the Godot 4.5 input
  stack ignores; the warning does not impact gameplay, and no project-side changes are required. To silence it locally, edit
  `%APPDATA%\Godot\godot.controller.db` and remove the `misc2` fields, but doing so is optional and not tracked in version
  control.
- **Vulkan loader noise** — Windows Store copies of *Microsoft D3D Mapping Layers* currently ship JSON manifests without a
  `layer` entry. The Vulkan loader prints warnings such as `loader_add_layer_properties: Can not find 'layer' object in manifest`
  and `windows_read_data_files_in_registry: Registry lookup failed to get layer manifest files.` when starting Godot. These
  diagnostics only affect optional debugging layers and are safe to ignore. Installing the optional **Graphics Tools** feature or
  removing the broken `Microsoft.D3DMappingLayers_*` package from `winget` will stop the warning if desired.
- **Optional extensions not found** — Lines reporting missing extensions (for example `VK_EXT_fragment_density_map`) simply mean
  your GPU/driver does not expose those optional capabilities. Godot already falls back to supported rendering paths.

## Maintaining context for agents
- After each iteration, run `python scripts/generate_context_snapshot.py` to refresh [`context_snapshot.md`](context_snapshot.md).
- Document branch-level progress in [`context_update.md`](context_update.md) so the next agent can resume smoothly.
- Append notable entries to [`CHANGELOG.md`](CHANGELOG.md) before requesting review.
- Reference the draft SDS outlines for the eight P0 systems in [`docs/design/sds_outlines.md`](docs/design/sds_outlines.md) when
  planning gameplay or telemetry changes.
- Align telemetry instrumentation and KPI tracking with the dashboard starter kit outlined in
  [`docs/telemetry/dashboard_plan.md`](docs/telemetry/dashboard_plan.md) to keep analytics expectations visible during iteration.
- Use the locked SDS packages for [`Command Model`](docs/design/sds_command_model.md) and
  [`Élan`](docs/design/sds_elan.md) as the source of truth for acceptance criteria and telemetry requirements during the
  vertical slice build.
- Consult the data-driven architecture TDD in
  [`docs/design/tdd_architecture_data.md`](docs/design/tdd_architecture_data.md) when wiring systems to the event bus, data
  loader, or assistant AI interpreter, and follow the JSON→runtime mapping table when adding new fields or scripts. Les ADRs
  (`docs/ADR_0002_event_bus_and_telemetry_autoloads.md`, etc.) enregistrent les décisions structurantes à prendre en compte
  lors de toute extension de ces contrats. The new autoloads mirror this architecture so future Checklist C work can focus on
  behaviour, not plumbing.
- Review the canonical JSON schemas in `data/` for doctrines, orders, units, formations, weather, and logistics to keep inertia locks, Élan costs, and supply interactions aligned with gameplay scripts.
- Logistics scenarios now declare supply centers, rings, and convoy paths inside [`data/logistics.json`](data/logistics.json); keep the graphs connected and documented whenever the map or supply rules evolve.
- Track outstanding data gaps documented under Phase 0 in [`docs/agents/missions/vertical_slice_p0.md`](docs/agents/missions/vertical_slice_p0.md#phase-0-findings) before extending any dataset so SDS expectations stay visible.
- Reference the one-page GDD summary in [`docs/gdd_vertical_slice.md`](docs/gdd_vertical_slice.md) when communicating vision,
  fantasy, pillars, loops, and risks for the vertical slice.
- Maintain shared vocabulary in the living glossary ([`docs/glossary.md`](docs/glossary.md)) so mission briefs, telemetry,
  and data schemas stay consistent as systems evolve.
- Align production pacing with the Semaine 0–6 milestone plan documented in
  [`docs/agents/missions/vertical_slice_p0.md`](docs/agents/missions/vertical_slice_p0.md#delivery-timeline-semaine-0%E2%80%936)
  so every iteration advances a tracked objective.

## Acceptance Checks
The high-level manual acceptance flow lives in [`docs/tests/acceptance_tests.md`](docs/tests/acceptance_tests.md). Keep it in sync
with the Godot scenes and systems as they evolve. Les cas AT-08 à AT-10 ont été mis à jour pour couvrir :

- La double bascule HUD/debug du overlay logistique avec traces `logistics_overlay_toggled`.
- Les tooltips terrain dynamiques qui reflètent le nombre de tuiles atteignables selon la météo.
- Les impacts de la rotation `weather_changed` (Sunny/Rain/Mist) sur les payloads `logistics_update` et la télémétrie associée.
