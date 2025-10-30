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
5. Utilise the vertical slice planning checklists in [`CHECKLISTS.md`](CHECKLISTS.md) to coordinate upcoming tasks and the
   one-page GDD summary in [`docs/gdd_vertical_slice.md`](docs/gdd_vertical_slice.md) to stay aligned on vision, pillars, loops,
   and risks. Structural decisions are archived in Architecture Decision Records (ADRs); start with
   [`docs/ADR_0002_event_bus_and_telemetry_autoloads.md`](docs/ADR_0002_event_bus_and_telemetry_autoloads.md) for the autoload
   signal contract governing Checklist C systems.
6. Familiarise yourself with the autoload singletons listed below—they provide the shared data, telemetry, and assistant hooks
   required to deliver Checklist C systems without additional plumbing.

## Core autoloads

| Autoload | Script | Responsibilities |
| --- | --- | --- |
| `EventBus` | `scripts/core/event_bus.gd` | Global signal hub for turn flow, checklist C system events (Élan, logistics, combat, espionage, weather, competence sliders) and new data-loader notifications. |
| `DataLoader` | `scripts/core/data_loader.gd` | Loads the JSON datasets in `data/`, caches them by id, and defers its readiness/error payloads so telemetry + assistant hooks capture the initial `data_loader_ready` signal (see `tests/gdunit/test_autoload_preparation.gd`). |
| `Telemetry` | `scripts/core/telemetry.gd` | Records emitted gameplay events for debugging and gdUnit assertions. Provides `log_event`, `get_buffer`, and `clear` helpers so tests can verify new Checklist C flows. |
| `AssistantAI` | `scripts/core/assistant_ai.gd` | Subscribes to doctrine/order/competence signals and publishes placeholder `assistant_order_packet` payloads that future iterations will enrich with simulations. |

The autoloads initialise automatically when the project starts (and during headless test runs). Systems being developed for
Checklist C should request dependencies from these singletons instead of reading JSON files or crafting their own signal buses.

## Command & Élan loop (Semaine 0–1)
- The HUD now exposes a doctrine selector tied to the `DoctrineSystem`, displays inertia locks, and lists the orders authorised
  by the active doctrine.
- Order execution routes through the Élan system, enforcing Élan caps, doctrine-based restrictions, and inertia impacts before
  emitting `order_issued` telemetry.
- A lightweight audio cue (generated on the fly) and status label provide immediate visual/sonore feedback when doctrines or
  orders change.

## Logistics backbone & terrain feedback (Semaine 2–3)
- `LogisticsSystem` now simulates hybrid rings, overland roads, and harbor convoys, emitting rich `logistics_update` payloads
  that describe supply levels, terrain-driven flow modifiers, and convoy progress/interruptions for the HUD and telemetry.
- Logistics disruptions now raise a dedicated `logistics_break` event for analytics, capturing the disrupted tile/route, Élan and
  competence penalties, and current weather/logistics contexts for downstream dashboards.
- Weather definitions (`sunny`, `rain`, `mist`) rotate automatically and apply movement/logistics multipliers sourced from
  `data/weather.json`, enabling future systems to subscribe to `weather_changed` signals without bespoke plumbing.
- Terrain defaults derived from `TerrainData` are combined with supply-center distance calculations to label tiles as `core`,
  `fringe`, or `isolated`, ensuring movement costs and convoy interception odds reflect both geography and climate.

## Combat pillars & espionage intelligence (Semaine 4–5)
- `CombatSystem` now resolves Manoeuvre/Feu/Moral contests by combining unit combat profiles, doctrine bonuses, terrain and
  weather multipliers, and the latest espionage confidence. Each resolution emits a `combat_resolved` payload for telemetry and
  upcoming HUD combat panels.
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
The gdUnit suite now includes data integrity coverage that loads each JSON data file under `data/` and validates required keys and types before gameplay logic consumes them.
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
- Godot 4.5 removed the `condition ? a : b` ternary helper. Replace those expressions with the Python-style
  `a if condition else b` form to avoid parse errors when opening the project or running the headless build script.
- Treating warnings as errors is intentional. When autoload singletons also declare a `class_name`, add
  `@warning_ignore("class_name_hides_autoload")` (see `scripts/core/event_bus.gd`) so Godot 4.5+ loads without aborting.
- When you pull structured data from dictionaries (doctrines, orders, etc.), provide explicit type hints instead of relying on
  `:=` inference. Godot 4.5 infers such values as `Variant`, which now triggers blocking parse errors. Inspect
  `scripts/core/data_loader.gd` and `scripts/ui/hud_manager.gd` for the preferred explicit typing pattern.

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
- Review the canonical JSON schemas in `data/` for doctrines, orders, units, formations, weather, and logistics to keep inertia locks, Élan
  costs, and supply interactions aligned with gameplay scripts.
- Reference the one-page GDD summary in [`docs/gdd_vertical_slice.md`](docs/gdd_vertical_slice.md) when communicating vision,
  fantasy, pillars, loops, and risks for the vertical slice.
- Maintain shared vocabulary in the living glossary ([`docs/glossary.md`](docs/glossary.md)) so mission briefs, telemetry,
  and data schemas stay consistent as systems evolve.
- Align production pacing with the Semaine 0–6 milestone plan documented in
  [`docs/agents/missions/vertical_slice_p0.md`](docs/agents/missions/vertical_slice_p0.md#delivery-timeline-semaine-0%E2%80%936)
  so every iteration advances a tracked objective.

## Acceptance Checks
The high-level manual acceptance flow lives in [`docs/tests/acceptance_tests.md`](docs/tests/acceptance_tests.md). Keep it in sync
with the Godot scenes and systems as they evolve.
