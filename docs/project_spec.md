# Weave of War — Project North Star (project_spec.md)

> Version: 0.1 (VS scope) · Owner: Pierre · Engine: Godot 4.x · Repo: private
> Tagline: Strategy by flows, momentum, and deception.

## 1) Vision (What we’re building)
Weave of War is a PC strategy/management game inspired by Sun Tzu’s *Art of War*, blending:
- **Simplicity & tension (FTL)** — one central resource (Élan), readable decisions, sharp feedback.
- **Visible, living logistics (Settlers II)** — animated supply lines and territorial “weaves” of resources.
- **Tactical clarity (Vandal Hearts)** — clean, turn-based resolutions driven by position, momentum, and information.

### Player fantasy
Feel like a calm, lucid strategist who wins **before** the battle by creating the right conditions. The world is a living map of **flows**, **influence**, and **intentions**.

### Non‑negotiable pillars
1. **Animated flows** — supply & influence must be *seen* moving.
2. **Readability** — every state change is explicit and low-friction.
3. **Reactivity** — orders, doctrine swaps, and Élan spends respond instantly.

### Audience & tone
Casual-to-midcore PC strategy players who enjoy planning, watching systems react, and learning elegant depth without micro-chaos.

---

## 2) Core loops
**Core (30–90s)**: Observe flows → Set/adjust orders → Spend Élan for a pulse → Watch resolution → Small reward.
**Mid (5–20m)**: Expand networks → Manage fronts → Probe/feint with intel → Trigger decisive engagements.
**Meta (hours)**: Master doctrines, refine style, complete scenarios with different victory profiles (territory, attrition, morale/diplomacy).

**North Star Metric**: ≥ **30%** of players return daily.

---

## 3) Systems (VS scope)
**A. Command model (no cards)**  
- **Doctrines (1 active per turn)**: global stance that modulates rules (e.g., Force/Ruse/Patience/Vitesse/Équilibre).  
- **Orders**: *Advance / Hold / Fortify / Harass / Intercept / Feint* (interpreted by the assistant AI).  
- **Inertia**: doctrine & slider changes limited per turn to create readable rhythm.

**B. Élan (global)**  
- Single, capped team resource. Gained by successes and logistical harmony; spent in short pulses (assault boost, forced march, strategic reroll, regional inspiration). Strong audiovisual feedback.

**C. Logistics (hybrid, phased)**  
- **Zones** (baseline): cities project supply rings; outside rings = maluses.  
- **Pipes** (step 2): connect rings by roads for visible animated flows.  
- **Convoys** (optional): auto-spawn on long routes; can be intercepted → emergent stories.

**D. Combat (3 Pillars resolution)**  
- **Position** (terrain/formation/weather) + **Impulse** (Élan/morale) + **Information** (intel/recon).  
- Win ≥ 2 pillars to win the engagement. Parallel resolution with three animated gauges.

**E. Espionage (fog + probabilistic reads)**  
- Fog of War outside influence. Probes return **pings** (likelihoods). Intel can reveal **intent** categories (offense/logistics/hesitation) rather than exact plans.

**F. Terrain & Weather (minimal → extended)**  
- Minimal set: **Plains / Forest / Hill** and **Sunny / Rain / Mist**.  
- Extended: rare **Snow / Storm** events (scenario-tuned).

**G. Competence sliders (per turn)**  
- 6 points across **Tactics / Strategy / Logistics** (cap 3).  
- **Inertia**: move at most 2 pts/turn. Effects are instantly visible (supply radii, order range, Élan cap).

**H. Units & formations**  
- Unit archetypes: **Infantry / Archers / Cavalry**.  
- Postures: **Attack / Defense / March** (switch cost: Élan + delay).

---

## 4) UX & accessibility
- Clear iconography and color semantics: Logistics=green/blue, Élan=gold, Intel=indigo, Danger=red.  
- Micro-animations: anticipation → impact → residue (<200ms).  
- Options: font sizes, colorblind presets, remapping.  
- Debug overlay always available (learning tool).

---

## 5) Technical approach (Godot 4.x)
- **Architecture**: component-style nodes + **event_bus** (signals) + data-driven configs (JSON).  
- **Key scenes**: `main.tscn` (root), `map.tscn` (hex), `hud.tscn`, `debug_overlay.tscn`.  
- **Key scripts**: `game_manager.gd`, `turn_manager.gd`, `event_bus.gd`, systems (`elan_system.gd`, `logistics_system.gd`, `combat_system.gd`, `doctrine_system.gd`, `espionage_system.gd`).  
- **Data files** (VS): `doctrines.json`, `orders.json`, `units.json`, `weather.json`, `logistics.json`.  
- **Testing**: gdUnit4 (preferred) or light script assertions; GitHub Actions for lint/build smoke tests.

---

## 6) Milestones (Vertical Slice plan)
1. **VS-1 — Command & Élan**: sliders, one doctrine, Élan spend feedback; orders apply to units; turn loop stable.  
2. **VS-2 — Logistics (Zones)**: supply rings visualized; penalties outside rings; toggle overlay.  
3. **VS-3 — Combat (3P)**: pillar gauges; resolution & retreat rules; minimal SFX/VFX.  
4. **VS-4 — Espionage (A+B)**: fog + pings + intent categories; simple UI tooltips.  
5. **VS-5 — Polish**: small map scenario, two factions, tutorial prompts, telemetry events.

**Definition of Done (per feature)**  
- Tests green (unit/integration).  
- Performance within budget (60 FPS 1080p on mid PC).  
- Accessibility checks (readability, color contrast).  
- Telemetry events emitted.  
- No new warnings; CHANGELOG updated.

---

## 7) Telemetry (VS)
- `elan_spent`, `elan_gained_source`, `doctrine_changed`, `order_issued`, `logistics_broken/restored`, `combat_pillar_results`, `intel_ping`, `slider_moved`.

---

## 8) Risks & mitigations
- **AI credibility**: begin with rule-based interpretable decisions & logs (“why”) before ML.  
- **Visual overload**: layer toggles and LOD for overlays.  
- **Scope creep**: ADRs and this North Star doc are the guardrails.

---

## 9) Glossary
**Élan**: global momentum resource.  
**Doctrine**: temporary global stance affecting rules.  
**Orders**: player commands interpreted by assistant AI.  
**Pillars (Combat)**: Position / Impulse / Information.  
**Supply rings / Pipes / Convoys**: logistics layers.  
**Sliders**: Tactics / Strategy / Logistics allocation per turn.
