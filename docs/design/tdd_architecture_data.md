# TDD — Data-Driven Architecture Plan (Vertical Slice P0)

## Purpose & Scope
This technical design document lays out how the vertical slice will stay data-driven while coordinating Godot components, the
central event bus, and the assistant AI responsible for interpreting player intent. It focuses on the eight P0 systems
(Command Model, Élan, Logistics, Combat 3 Pillars, Espionage, Terrain & Weather, Competence Sliders, Unit Formations) and the
supporting telemetry/automation needed for our checklists.

## Design Goals
- Keep gameplay rules and balancing outside of code via structured JSON definitions so designers can iterate without GDScript
  edits.
- Decouple systems through `EventBus` signals and typed payloads to preserve testability and allow future agents to add systems
  without touching core loops.
- Ensure the assistant AI that interprets doctrine + orders can run deterministic simulations for previews and emit telemetry
  events for later analytics dashboards.
- Preserve headless compatibility for CI by restricting runtime dependencies to resources that load cleanly without the editor.

## High-level Architecture
```
JSON configs (data/) → DataLoader (autoload) → Runtime caches (Resources)
                                  ↓
                          EventBus (autoload)
                                  ↓
        Systems (scripts/systems/*.gd) + Managers (scripts/core/*.gd)
                                  ↓
                    Assistant AI Interpreter (scripts/core/assistant_ai.gd)
                                  ↓
                Telemetry Sink (scripts/core/telemetry.gd / gdUnit hooks)
```

### Core Autoloads
| Node | Path | Responsibilities |
| --- | --- | --- |
| `EventBus` | `scripts/core/event_bus.gd` | Defines typed signals for system interactions (`doctrine_selected`, `elan_spent`, `logistics_update`, `combat_resolved`, `espionage_ping`, etc.). Holds utility dispatch helpers so systems do not assume each other’s presence. |
| `DataLoader` (new) | `scripts/core/data_loader.gd` | Loads JSON assets on project start, validates them against schemas, exposes typed accessors (e.g. `get_doctrine(id)`, `list_orders()`). Emits `data_loader_ready` on success and `data_loader_error` on failure with validation context. |
| `Telemetry` (new) | `scripts/core/telemetry.gd` | Receives game events from `EventBus` and queues payloads for analytics/testing. Provides helpers like `log_event(name: StringName, payload: Dictionary)` that forward to file appenders or in-memory collectors during tests. |
| `AssistantAI` (new) | `scripts/core/assistant_ai.gd` | Interprets player-issued orders and doctrine context. Subscribes to `EventBus` signals, pulls data from `DataLoader`, and outputs `assistant_order_packet` events used by combat/logistics systems. |

## Data Pipeline
1. **File layout** (all under `data/`):
   - `doctrines.json`: doctrine definitions with modifiers, Élan costs, inertia values.
   - `orders.json`: command order metadata, prerequisites, AI resolution hints.
   - `units.json`: unit archetypes, formation modifiers, base stats.
   - `weather.json`: weather states, duration ranges, modifiers on logistics/combat.
   - `logistics.json`: zone templates, route archetypes, convoy behaviours.
2. **Schemas** live in `data/schemas/` (to add) as JSON Schema drafts. Each runtime file is validated during load.
3. `DataLoader` converts JSON dictionaries into lightweight `Resource` subclasses (e.g. `DoctrineConfig`, `OrderConfig`) stored in caches so systems can request typed data.
4. Systems observe `EventBus.data_ready` before using the caches. If validation fails, a global `ProjectState` flag marks the build as unsafe, causing headless checks to fail fast.

## Event Bus Contracts
| Signal | Emitter | Payload | Consumers |
| --- | --- | --- | --- |
| `doctrine_selected` | HUD / Player input → `GameManager` | `{ doctrine_id, previous_id, turn_number }` | `AssistantAI`, `ElanSystem`, `LogisticsSystem` |
| `order_issued` | HUD → `GameManager` | `{ order_id, unit_ids, target_hex, elan_cost }` | `AssistantAI`, `LogisticsSystem`, `CombatSystem` |
| `assistant_order_packet` | `AssistantAI` | `{ orders: Array, intents: Dictionary, expected_outcomes: Dictionary }` | `CombatSystem`, `LogisticsSystem`, `Telemetry` |
| `elan_spent` | `ElanSystem` | `{ amount, reason, remaining }` | `Telemetry`, `HUDManager`, `DebugOverlay` |
| `logistics_update` | `LogisticsSystem` | `{ zone_id, supply_level, convoy_status }` | `Telemetry`, `HUDManager`, `EspionageSystem` |
| `combat_resolved` | `CombatSystem` | `{ engagement_id, pillars, victor, casualties }` | `Telemetry`, `HUDManager`, `TurnManager` |
| `espionage_ping` | `EspionageSystem` | `{ source_hex, target_hex, confidence, revealed_intent }` | `Telemetry`, `HUDManager` |
| `weather_changed` | `TerrainWeatherSystem` | `{ weather_id, duration, modifiers }` | `HUDManager`, `Telemetry`, `LogisticsSystem`, `CombatSystem` |
| `competence_reallocated` | `TurnManager` | `{ sliders: Dictionary, inertia_spent }` | `Telemetry`, `LogisticsSystem`, `AssistantAI` |

## Assistant AI Interaction Model
- Subscribes to `doctrine_selected`, `order_issued`, `competence_reallocated`, and `espionage_ping`.
- Pulls contextual data from `DataLoader` (e.g. doctrine modifiers, unit stats, logistics routes).
- Generates `assistant_order_packet` messages that systems use to drive animations/resolutions.
- Emits telemetry traces (`assistant_intent_evaluated`, `assistant_prediction_delta`) so UX can surface accuracy/confidence to players.
- Provides deterministic simulations for HUD previews by running resolution functions in a sandboxed state (no side effects) before publishing the packet.

## Telemetry & Testing Hooks
- `Telemetry` autoload buffers events and can write to `user://telemetry.log` during local runs. In tests it exposes `Telemetry.get_buffer()` so gdUnit cases can assert on sequences.
- Headless CI checks subscribe to `Telemetry` and assert that critical events (`elan_spent`, `combat_resolved`, `logistics_update`) fire at least once during smoke scenarios.
- Each system test seeds fixtures through `DataLoader` by loading JSON from `res://data/test/*.json`.

## Roadmap & Follow-ups
1. Implement autoload singletons for `DataLoader`, `Telemetry`, and `AssistantAI` (including `.tscn` configuration).
2. Create JSON Schemas and validation routines under `data/schemas/`.
3. Wire systems to request data via `DataLoader` instead of hard-coded dictionaries.
4. Extend gdUnit smoke tests to load sample JSON fixtures and verify event emission counts.
5. Document additional ADRs if architecture deviates (e.g. introducing ECS or third-party tooling).

