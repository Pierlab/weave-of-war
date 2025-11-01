# Telemetry Dashboard Starter Kit

This note anchors the newly instrumented gameplay events to concrete KPIs so vertical slice agents know how telemetry will be
used. Keep it updated when events evolve or dashboards shift.

## Event coverage (Checklist D)

| Event | Source | Key fields | Primary questions |
| --- | --- | --- | --- |
| `doctrine_selected` | `DoctrineSystem` | `id`, `inertia_remaining`, `allowed_orders[]` | Which doctrines stay active and how long do inertia locks persist? |
| `order_issued` | `ElanSystem` | `order_id`, `cost`, `remaining`, `inertia_impact` | Which orders consume Élan and how does inertia accumulate? |
| `order_rejected` | `ElanSystem` | `order_id`, `reason`, `required`, `available`, `doctrine_id` | Why are orders blocked (inertia vs. Élan) and which doctrines struggle most? |
| `elan_spent` | `ElanSystem` | `order_id`, `amount`, `remaining`, `reason` | How quickly do commanders burn Élan? Which orders drive the spend? |
| `elan_gained` | `ElanSystem` | `amount`, `previous`, `current`, `reason` | What sources replenish Élan and how often do caps throttle gains? |
| `combat_resolved` | `CombatSystem` | `pillars`, `pillar_summary`, `units[]`, `victor`, `weather_id`, `doctrine_id`, `logistics` | Quels piliers décident des engagements, quelles unités encaissent les pertes et comment météo/doctrine/supply déplacent-ils les victoires ? |
| `formation_changed` (combat) | `CombatSystem` / `FormationSystem` | `unit_id`, `formation_id`, `engagement_id`, `order_id`, `pillar_summary`, `unit_result`, `side` | Quelles postures sont alignées sur les victoires/défaites et comment l'inertie impacte-t-elle les retours combat ? |
| `weather_changed` | `WeatherSystem` | `weather_id`, `movement_modifier`, `logistics_flow_modifier`, `intel_noise`, `elan_regeneration_bonus`, `duration_remaining`, `reason` | How often does climate shift and how strong are the applied penalties/bonuses by scenario? |
| `logistics_break` (new) | `LogisticsSystem` | `type`, `tile_id`/`route_id`, `elan_penalty`, `competence_penalty`, `weather_id` | Where do supply chains fail and what are the resulting costs? |
| `espionage_ping` | `EspionageSystem` | `target`, `success`, `confidence`, `intention`, `visibility_before/after`, `noise` | When do pings reveal intentions and how reliable is intel noise? |
| `intel_intent_revealed` (new) | `EspionageSystem` | `target`, `intention`, `intention_confidence`, `confidence`, `source`, `turn` | Which probes confirm intentions and how closely does RNG confidence match the stored intel? |

## KPI seeds

- **Doctrine lock duration**: average number of turns each doctrine stays active and how quickly inertia decays, derived from `doctrine_selected`.
- **Order throughput**: ratio of `order_issued` vs. `order_rejected` by doctrine and reason to highlight blockers.
- **Élan burn rate**: average Élan spent per turn and per doctrine, derived from `elan_spent`.
- **Élan regeneration cadence**: amount and source mix of recovered Élan per turn using `elan_gained`.
- **Pillar victory distribution**: share of engagements where each pillar was decisive, split by weather using `combat_resolved`.
- **Logistics stability index**: total Élan/competence penalties from `logistics_break` over time and by route type.
- **Intel fidelity**: percentage of `espionage_ping` events that reveal intentions and the median confidence when they do.
- **Intent confirmation quality**: compare `intel_intent_revealed` confidence against the originating ping rolls to track how often probes over/under perform expectations.

## Dashboard sketches

1. **Operations Pulse** — Turn-level stacked bar showing Élan spent vs. recovered, annotated with `logistics_break` penalties.
2. **Battle Insight Board** — Heatmap of pillar victories (rows) by doctrine (columns) using `combat_resolved` payloads.
3. **Supply Chain Monitor** — Timeline chart of `logistics_break` events grouped by `type`, highlighting recurring tiles/routes.
4. **Intel Reliability Dial** — Gauge showing rolling success rate of `espionage_ping` reveals and average confidence, annotated with `intel_intent_revealed` confidence deltas when intentions surface.

Document blockers or new questions in `context_update.md` whenever the instrumentation or KPIs change.
