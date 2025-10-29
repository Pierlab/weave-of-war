# SDS Outlines — Vertical Slice P0 Systems

These outlines capture the initial structure required for full SDS (System Design Specification) deliverables across the eight
foundational systems for the Weave of War vertical slice. Each section highlights gameplay rules, UX intentions, and telemetry
hooks that future iterations must flesh out with diagrams, state machines, and balancing data.

## Command Model
- **Core Rules**
  - Doctrine selection gates the list of executable orders and modifies unit caps per theatre.
  - Orders consume command points (CP) that refresh at the start of each round; unspent CP converts partially into Élan.
  - Command inertia introduces a delay between issuing and resolving orders based on distance to headquarters.
- **Player UX**
  - Command dial in HUD summarises active doctrine, CP pool, and order queue timers.
  - Drag-and-drop order planner anchored to the tactical map with contextual tooltips for legality and costs.
  - Visual feedback for inertia via animated linkage between HQ and units; colour shifts indicate readiness vs. delay.
- **Telemetry Hooks**
  - Emit events when doctrines change, including previous/next doctrine IDs and timestamp.
  - Track order issuance/resolution with CP spent, affected unit IDs, and delay duration buckets.
  - Record command bottlenecks (orders waiting >2 rounds) for pacing analysis.

## Élan
- **Core Rules**
  - Shared Élan pool fuels surge actions and doctrine upgrades; gains from battlefield morale triggers and surplus CP.
  - Élan decays if the pool remains capped for more than one round to encourage proactive spending.
  - Surge actions temporarily override unit fatigue and terrain penalties within strict cooldown windows.
- **Player UX**
  - HUD gauge paired with momentum streak indicator showing gain/loss trends.
  - Surge action radial menu appears when selecting eligible units, highlighting bonuses and timers.
  - Notifications escalate when Élan approaches cap or decays, linking players to recommended spend actions.
- **Telemetry Hooks**
  - Log Élan deltas with contributing source (battle event, conversion, scripted) and sink (surge, upgrade, decay).
  - Measure surge usage frequency and success outcomes vs. baseline combat results.
  - Capture player response time between Élan cap warnings and subsequent spend.

## Logistics
- **Core Rules**
  - Supply rings radiate from depots; units outside coverage accrue attrition and slowed recovery.
  - Convoys traverse pre-defined routes with capacity limits; interception reroutes or delays supplies.
  - Weather and terrain modifiers adjust consumption rates and convoy speeds.
- **Player UX**
  - Layer toggle overlays supply rings, convoy paths, and vulnerability hotspots on the map.
  - Depot management panel summarises stockpiles, outgoing convoys, and imminent shortages.
  - Alert system categorises supply issues (capacity, disruption, attrition) with actionable recommendations.
- **Telemetry Hooks**
  - Emit supply status snapshots per round (in supply, strained, out) per unit.
  - Track convoy lifecycle events (dispatch, intercept, arrive) with timestamps and payload volumes.
  - Record weather/terrain modifiers applied to supply efficiency for balancing.

## Combat — Three Pillars
- **Core Rules**
  - Combat resolution balances Positioning, Force, and Morale pillars weighted by unit posture and support.
  - Dice-less deterministic resolution uses comparative scores with advantage modifiers from terrain, Élan, and intel.
  - Post-battle states include pursuit options and morale shock effects cascading to nearby units.
- **Player UX**
  - Combat preview panel shows pillar contributions before confirmation, including impact of optional surge actions.
  - Resolution summary card animates the three pillar bars and resulting casualties/position shifts.
  - Replay log accessible from the timeline for reviewing key engagements and decisions.
- **Telemetry Hooks**
  - Log per-engagement pillar scores, modifiers applied, and final outcome classification (decisive, marginal, stalemate).
  - Track use of optional modifiers (Élan surges, formations) to correlate with win rates.
  - Capture follow-up decisions (pursuit, regroup) to understand pacing.

## Espionage
- **Core Rules**
  - Recon assets generate probabilistic pings revealing enemy intent zones with confidence levels.
  - Counter-intel missions reduce enemy ping accuracy and extend fog-of-war regeneration speed.
  - Intel currency accrues from objectives and enables limited-time deep scans or sabotage actions.
- **Player UX**
  - Fog-of-war overlay fades to show ping heatmaps; colour saturation reflects confidence.
  - Intel command panel lists active missions, costs, and remaining durations with cancel options.
  - Alerts differentiate between genuine detections and suspected decoys to encourage deduction.
- **Telemetry Hooks**
  - Record ping generation with coordinates, confidence, and confirmation results.
  - Track intel currency flow and mission selections to surface popular strategies.
  - Measure false-positive vs. confirmed intel rates for tuning detection algorithms.

## Terrain & Weather
- **Core Rules**
  - Map tiles store terrain type and dynamic weather state influencing movement, visibility, and logistics.
  - Weather fronts advance along pre-set patterns but can be nudged by scripted events for pacing.
  - Terrain control grants passive bonuses (e.g., hills for spotting, forests for ambush) tied to formations.
- **Player UX**
  - Tactical map legend clarifies combined terrain/weather modifiers and highlights upcoming forecast shifts.
  - Turn summary banner lists weather changes and affected regions with quick-jump camera buttons.
  - Tooltip system shows unit-specific impacts when hovering over tiles.
- **Telemetry Hooks**
  - Snapshot terrain/weather state each round for units engaged in combat or logistics checks.
  - Track movement delays attributable to weather to validate pacing assumptions.
  - Record player interactions with forecast tools to gauge visibility of the system.

## Competence Sliders
- **Core Rules**
  - Leadership attributes (Strategy, Logistics, Espionage) adjustable via limited weekly budget.
  - Slider positions unlock passive bonuses and modify AI assistance behaviours.
  - Reallocation mid-campaign triggers morale repercussions and temporary debuffs.
- **Player UX**
  - Command dashboard hosts sliders with contextual hints about unlocked perks and trade-offs.
  - Confirmation modal summarises projected impacts before finalising adjustments.
  - Feedback notifications detail immediate buffs/debuffs and morale shifts after changes.
- **Telemetry Hooks**
  - Log slider adjustments with timestamps, new values, and triggered effects.
  - Measure correlation between slider profiles and win/loss outcomes per scenario.
  - Track frequency of reallocations to tune morale penalties.

## Unit Formations
- **Core Rules**
  - Each unit type (infantry, archers, cavalry) supports stance presets (aggressive, balanced, defensive) altering stats.
  - Formation compatibility bonuses apply when neighbouring units align stances appropriately.
  - Changing formation mid-engagement incurs a readiness penalty unless supported by command abilities.
- **Player UX**
  - Formation selector integrated into unit detail panel with preview of stat deltas and readiness impacts.
  - Map icons update silhouette to reflect stance for quick readability.
  - Advisor prompts suggest formation adjustments based on detected threats or synergies.
- **Telemetry Hooks**
  - Record formation changes including triggering context (manual, advisor suggestion, surge).
  - Track combat outcomes by formation posture to tune balance tables.
  - Capture readiness penalties applied and recovery time for pacing metrics.

## Next Steps
These outlines establish the shared vocabulary and measurement plans required to produce full SDS packages. Follow-up work will
add sequence diagrams, data schemas, and acceptance criteria per system while validating them through prototype spikes and gdUnit
scenarios.
