# Weave of War Glossary

This living glossary defines the core terms used throughout the Weave of War vertical slice. Update it whenever systems, data
schemas, or telemetry payloads introduce new vocabulary so mission briefs and checklists stay aligned with gameplay reality.

## Strategic resources & pacing

### Élan
Global momentum resource earned through successful logistics and engagements. Élan is capped, spent in tactical pulses (assault
boosts, forced marches, inspiration), and drives audio/visual feedback whenever it is consumed or regained.

### Inertia
Represents the resistance to changing doctrines or competence allocations. Inertia constrains how often sliders, formations, and
doctrines can change within a turn, preserving readability of the strategic rhythm.

## Command model

### Doctrine
Global stance selected once per turn. Each doctrine unlocks a subset of orders, modifies Élan gain/spend rules, and influences
combat pillars alongside telemetry events such as `doctrine_changed`.

### Orders
Player directives interpreted by the assistant AI (Advance, Hold, Fortify, Harass, Intercept, Feint). Orders are validated
against the active doctrine and current inertia, emit `order_issued` telemetry, and may consume Élan on execution.

## Logistics & terrain

### Logistics zone
Supply coverage projected from cities or key hubs. Tiles inside a logistics zone receive full supply; tiles outside accrue
penalties and can trigger `logistics_break` telemetry.

### Logistics route
Animated pipes and convoy paths that extend supply between zones. Routes react to weather and terrain modifiers, updating
`logistics_update` payloads with flow strength and disruption risk.

### Weather cycle
Rotating states (Sunny, Rain, Mist) that adjust logistics efficiency, visibility, and combat modifiers each turn through
`weather_changed` events.

## Intelligence & conflict

### Pillar (Combat pillar)
One of the three combat resolution axes: Manoeuvre, Feu, Moral. Engagement outcomes depend on winning at least two pillars.
Telemetry captures results via `combat_resolved` events for analytics and HUD feedback.

### Ping (Espionage ping)
Probabilistic intel packet emitted by the espionage system. Pings reveal likelihoods of enemy presence or intentions and can
upgrade to explicit intention reveals when supported by logistics or weather advantages.

## Unit posture & competence

### Posture (Formation posture)
Current formation stance for a unit group (Attack, Defense, March). Postures apply bonuses or penalties to combat pillars and can
require Élan to change, emitting `formation_changed` telemetry.

### Competence sliders
Turn-based allocation of command focus across Tactics, Strategy, and Logistics. Adjustments consume limited competence points,
may be restricted by inertia, and are logged through `competence_reallocated` events.
