# Telemetry Dashboard Starter Kit

This note anchors the newly instrumented gameplay events to concrete KPIs so vertical slice agents know how telemetry will be
used. Keep it updated when events evolve or dashboards shift.

## Event coverage (Checklist D)

| Event | Source | Key fields | Primary questions |
| --- | --- | --- | --- |
| `elan_spent` | `ElanSystem` | `order_id`, `amount`, `remaining` | How quickly do commanders burn Élan? Which orders drive the spend? |
| `combat_resolved` | `CombatSystem` | `pillars`, `victor`, `weather_id`, `doctrine_id` | Which pillars decide engagements? Does weather/doctrine skew victories? |
| `logistics_break` (new) | `LogisticsSystem` | `type`, `tile_id`/`route_id`, `elan_penalty`, `competence_penalty`, `weather_id` | Where do supply chains fail and what are the resulting costs? |
| `espionage_ping` | `EspionageSystem` | `target`, `success`, `confidence`, `intention` | When do pings reveal intentions and how reliable is intel noise? |

## KPI seeds

- **Élan burn rate**: average Élan spent per turn and per doctrine, derived from `elan_spent`.
- **Pillar victory distribution**: share of engagements where each pillar was decisive, split by weather using `combat_resolved`.
- **Logistics stability index**: total Élan/competence penalties from `logistics_break` over time and by route type.
- **Intel fidelity**: percentage of `espionage_ping` events that reveal intentions and the median confidence when they do.

## Dashboard sketches

1. **Operations Pulse** — Turn-level stacked bar showing Élan spent vs. recovered, annotated with `logistics_break` penalties.
2. **Battle Insight Board** — Heatmap of pillar victories (rows) by doctrine (columns) using `combat_resolved` payloads.
3. **Supply Chain Monitor** — Timeline chart of `logistics_break` events grouped by `type`, highlighting recurring tiles/routes.
4. **Intel Reliability Dial** — Gauge showing rolling success rate of `espionage_ping` reveals and average confidence.

Document blockers or new questions in `context_update.md` whenever the instrumentation or KPIs change.
