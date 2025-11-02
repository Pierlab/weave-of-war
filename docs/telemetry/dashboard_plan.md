# Telemetry Dashboard Starter Kit

This note anchors the newly instrumented gameplay events to concrete KPIs so vertical slice agents know how telemetry will be
used. Keep it updated when events evolve or dashboards shift.

## Event coverage (Checklist D → Phase 7 refresh)

| Event | Source | Key fields | Primary questions |
| --- | --- | --- | --- |
| `data_loader_ready` | `DataLoaderAutoload` | `collections[]`, `errors[]`, `duration_ms` | How long does initialisation take and which datasets are fragile? |
| `data_loader_error` | `DataLoaderAutoload` | `collection_id`, `error`, `payload` | Where do schema drifts appear before gameplay boots? |
| `turn_started` / `turn_ended` | `TurnManager` | `turn_number`, `reason` | How long do turns last and which systems delay the loop? |
| `doctrine_selected` | `DoctrineSystem` | `id`, `inertia_remaining`, `allowed_orders[]`, `elan_cap_bonus` | Which doctrines stay active and how long do inertia locks persist? |
| `order_issued` | `ElanSystem` | `order_id`, `cost`, `remaining`, `inertia_impact`, `metadata` | Which orders consume Élan and how does inertia accumulate? |
| `order_rejected` | `ElanSystem` | `order_id`, `reason`, `required`, `available`, `doctrine_id`, `allowed` | Why are orders blocked (inertia vs. Élan) and which doctrines struggle most? |
| `elan_spent` | `ElanSystem` | `order_id`, `amount`, `remaining`, `reason` | How quickly do commanders burn Élan? Which orders drive the spend? |
| `elan_gained` | `ElanSystem` | `amount`, `previous`, `current`, `reason`, `metadata` | What sources replenish Élan and how often do caps throttle gains? |
| `assistant_order_packet` | `AssistantAIAutoload` | `order_id`, `intent`, `target`, `confidence`, `notes` | Which guidance packets lead to successful engagements or refusals? |
| `logistics_update` | `LogisticsSystem` | `flow_multiplier`, `competence_multiplier`, `weather_adjustments`, `reachable_tiles[]`, `breaks[]` | How do weather/scenario modifiers reshape supply reach, convoy risk, and competence penalties each turn? |
| `logistics_break` | `LogisticsSystem` | `type`, `tile_id`/`route_id`, `elan_penalty`, `competence_penalty`, `weather_id`, `turn` | Where do supply chains fail and what are the resulting costs? |
| `combat_resolved` | `CombatSystem` | `pillars`, `pillar_summary`, `units[]`, `victor`, `weather_id`, `doctrine_id`, `logistics`, `intel` | Quels piliers décident des engagements, quelles unités encaissent les pertes et comment météo/doctrine/supply déplacent-ils les victoires ? |
| `formation_changed` | `CombatSystem` / `FormationSystem` | `unit_id`, `formation_id`, `reason`, `engagement_id`, `pillar_summary`, `unit_result`, `side` | Quelles postures précèdent les victoires/défaites et comment l'inertie impacte-t-elle les retours combat ? |
| `weather_changed` | `WeatherSystem` | `weather_id`, `movement_modifier`, `logistics_flow_modifier`, `intel_noise`, `elan_regeneration_bonus`, `duration_remaining`, `reason`, `source` | How often does climate shift and how strong are the applied penalties/bonuses by scenario? |
| `competence_reallocated` | `TurnManager` | `turn_id`, `reason`, `allocations`, `before`/`after`, `modifiers`, `inertia`, `last_event` | How does the command staff rebalance tactics/strategy/logistics under pressure? |
| `competence_spent` | `TurnManager` | `costs`/`amount`, `remaining`, `reason`, `source` | Where is competence consumed (orders vs. penalties) and which categories drain fastest? |
| `espionage_ping` | `EspionageSystem` | `target`, `success`, `confidence`, `intention`, `visibility_before/after`, `roll`, `probe_strength`, `competence_remaining` | When do pings reveal intentions and how reliable is intel noise? |
| `intel_intent_revealed` | `EspionageSystem` | `target`, `intention`, `intention_confidence`, `confidence`, `turn`, `source`, `roll`, `noise` | Which probes confirm intentions and how closely does RNG confidence match the stored intel? |

## Schema review — 2025-12-30 cross-check

- **Autoload readiness.** `data_loader_ready` now records the collection counts (`doctrines`, `orders`, `formations`, `weather`, `competence_sliders`, etc.) and the elapsed milliseconds so we can spot slow or fragile loads before gameplay begins. Matching `data_loader_error` payloads include the offending collection and validation message to drive schema fixes.
- **Turn pacing.** `turn_started` / `turn_ended` events are lightweight (turn index + optional `reason`) and bracket every telemetry burst, which lets dashboards compute average decision time per turn or flag stuck loops when `turn_started` lacks a matching `turn_ended` within tolerance.
- **Command & Élan loop.** Command emissions (`doctrine_selected`, `order_issued`, `order_rejected`, `elan_spent`, `elan_gained`, `assistant_order_packet`) were verified against `TelemetryAutoload` serialisation: dictionaries are deep-copied, optional metadata remains dictionaries, and boolean fields (`allowed` on rejections) are preserved for filtering.
- **Logistics & weather.** `logistics_update` payloads retain the precomputed arrays for `supply_zones`, `routes`, `reachable_tiles`, `supply_deficits`, and convoy summaries while `weather_adjustments` nests the active modifiers. Companion `logistics_break` entries inherit `logistics_id`, `weather_id`, and per-break penalties so competence drains can be correlated with Élan fines.
- **Combat & formations.** `combat_resolved` is normalised through helper serializers ensuring floats (`margin_score`, pillar totals), arrays (`decisive_pillars`, `units.attacker[]/defender[]`), and nested dictionaries (`intel`, `logistics`) ship as analytics-friendly JSON. Follow-up `formation_changed` payloads carry the combat context (`engagement_id`, `order_id`, `pillar_summary`, `unit_result`) when triggered from combat, while manual swaps use `reason: "manual"`.
- **Competence economy.** `competence_reallocated` serialises `before`/`after` snapshots, inertia timers, modifiers (including the logistics penalty), and the last triggering event. `competence_spent` handles both aggregated spends (`amount`) and per-category costs (`costs`) so penalties and manual spends stay comparable.
- **Intel loop.** `espionage_ping` and `intel_intent_revealed` payloads align on shared keys (`target`, `order_id`, `probe_strength`, `detection_bonus`) to simplify joins. Visibility maps are emitted as arrays of `{tile_id, visibility, counter_intel}` dictionaries after deep copy to avoid Godot `Variant` bleed-through.

Document any schema drift in `context_update.md` and refresh this note whenever telemetry helpers change.

## KPI seeds

- **Doctrine lock duration** — Average turns per doctrine activation (from `doctrine_selected`) and the swap token burn rate; correlate with `order_rejected.allowed=false` spikes.
- **Order throughput** — Ratio of `order_issued` vs. `order_rejected` by doctrine, enriched with `assistant_order_packet.intent` to see where AI guidance diverges from commander actions.
- **Élan burn vs. regen** — Compare `elan_spent.amount` and `elan_gained.amount` per turn alongside `turn_started` pacing to flag attrition-heavy sessions.
- **Supply health & penalties** — Sum `logistics_break.elan_penalty` / `competence_penalty` and compare against the cumulative `competence_spent.amount` logged by logistics penalties.
- **Competence allocation agility** — Track deltas between `competence_reallocated.before.allocations` and `.after.allocations` to surface how often commanders reshuffle vs. react to penalties.
- **Pillar victory distribution** — Share of engagements where each pillar was decisive, split by weather (`combat_resolved.weather_id`) and active formation posture (`formation_changed.formation_id`).
- **Turn cadence** — Median wall-clock gap between `turn_started` and `turn_ended`; correlate spikes with complex combats (`combat_resolved`) or heavy reallocation bursts.
- **Intel fidelity** — Percentage of `espionage_ping.success` true events that also trigger `intel_intent_revealed`, along with average `confidence` delta.

## Dashboard sketches

1. **Operations Pulse** — Stacked bar per turn combining `elan_spent` vs. `elan_gained`, annotated with `logistics_break` penalties and `competence_spent.amount` to visualise resource attrition.
2. **Command Room Console** — Dual-axis chart mixing `doctrine_selected` dwell time, `order_rejected` reasons, and `assistant_order_packet.confidence` trends to highlight friction in the command loop.
3. **Supply Chain Monitor** — Timeline of `logistics_update.flow_multiplier` alongside break markers grouped by `type`, with tooltips pulling `reachable_tiles` counts for rapid regression checks.
4. **Formation & Pillar Matrix** — Heatmap crossing `formation_changed.formation_id` with `combat_resolved.pillar_summary.decisive_pillars[]` to see which postures decide battles under different weather IDs.
5. **Intel Reliability Dial** — Rolling gauge of `espionage_ping` reveal rate with overlays for `intel_intent_revealed.confidence` vs. originating `espionage_ping.roll` to quantify over/under performance.

Document blockers or new questions in `context_update.md` whenever the instrumentation or KPIs change.
