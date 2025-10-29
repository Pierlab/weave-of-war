# SDS — Élan System

- **Owner:** Pierre / Systems Design Guild
- **Status:** Locked for review (Vertical Slice P0)
- **Last Updated:** 2025-10-29

## 1. Purpose & Intent
Provide a single momentum resource that rewards proactive play, communicates team morale, and fuels decisive surges without
creating runaway snowball effects. The Élan system should encourage timely spending, integrate with doctrines and combat, and
broadcast its state clearly through UI and telemetry.

## 2. Player-Facing Rules
1. The player controls one global Élan pool with a configurable cap. Gains come from victories, logistical harmony, surplus CP,
   and scripted narrative beats.
2. If the pool remains at cap for more than one round, Élan decays automatically at the start of the next round.
3. Surge actions and doctrine upgrades consume Élan instantly; each surge has its own cooldown window and eligible unit classes.
4. When Élan drops below defined thresholds, passive bonuses (e.g., morale auras) deactivate until the pool recovers.
5. The player may bank a limited number of "edge tokens" each representing a guaranteed +1 pillar advantage; tokens cost Élan
   and expire after the current chapter.

## 3. System Rules & Data Flows
- `ElanState` resource tracks `current_value`, `max_value`, decay counters, surge cooldowns, and token inventory.
- Surge definitions live in `data/elan_surges.json` and expose cost, duration, affected stats, and cooldown length.
- Gains pipeline listens to combat resolution, logistics stability, espionage intel breakthroughs, and CP conversion events.
- Decay logic triggers when `current_value == max_value` for >1 round or if global morale drops due to consecutive defeats.
- Cooldown scheduler stores surge IDs with the round index when they become available again and emits signals for the HUD.
- Edge tokens are stored as lightweight structs `{id, expires_round}` and validated each round during combat pillar calculations.

## 4. UI / UX Specification
- **Momentum Gauge:** Circular gauge adjacent to the command dial showing current Élan, cap, and delta arrows for the last turn.
  Gauge colour shifts (gold → amber → red) as Élan approaches decay state.
- **Surge Radial Menu:** Triggered via unit selection; displays available surges with cost, effect summary, and cooldown timers.
  Disabled surges include tooltips describing unmet requirements.
- **Streak Banner:** Above the HUD timeline, display a streak indicator highlighting recent gains/losses and passive bonus status.
- **Edge Token Tray:** Row of token icons with expiry round labels; tokens animate when earned or spent to reinforce value.
- **Notifications:** Toast messages (text + icon) fire when Élan decays, hits cap, or when decay is imminent, guiding the player to
  surge opportunities.

## 5. Telemetry Requirements
- `elan_delta` event: `{round_index, delta, source, current_value, max_value}` for every gain/loss outside of passive decay.
- `elan_decay` event: `{round_index, decay_amount, reason}` when automatic decay fires.
- `surge_triggered` event: `{surge_id, unit_ids, elan_cost, cooldown_round, success}` tied to combat outcomes.
- `edge_token_updated` event: `{change, total_tokens, expires_rounds}` whenever tokens are gained or spent.
- `elan_alert_interaction` event: `{alert_type, time_to_spend}` measuring how quickly players respond to cap/decay warnings.

## 6. Acceptance Criteria
1. **Cap Management:** Filling the Élan gauge to cap and ending a round triggers `elan_delta` (gain) followed by `elan_decay`
   (loss) on the next round if no Élan is spent, with the UI reflecting the drop within one frame.
2. **Surge Execution:** Activating a surge applies the defined buff to eligible units, logs `surge_triggered` with success state,
   and starts the cooldown timer visible in the radial menu.
3. **Cross-System Sync:** Winning a combat pillar contest emits an Élan gain proportional to configured values, updates the
   gauge, and records the source as `combat_victory` in telemetry.
4. **Edge Token Lifecycle:** Purchasing an edge token decreases Élan, adds a token icon to the tray, and expires it automatically
   on the configured round with a corresponding telemetry update.
5. **Passive Bonus Toggle:** Dropping Élan below the morale threshold disables the passive aura indicator and re-enables it when
   the pool recovers, ensuring status changes propagate to both HUD and combat calculations.

## 7. Risks & Mitigations
- **Risk:** Players hoard Élan waiting for perfect surges, causing decay frustration.
  - *Mitigation:* Add predictive hints in notifications suggesting effective surges based on current theatre status.
- **Risk:** Surge spam overwhelms UX and balance.
  - *Mitigation:* Enforce per-unit cooldowns and layer diminishing returns for repeated surges within a short window.
- **Risk:** Edge tokens complicate combat resolution telemetry.
  - *Mitigation:* Include token application metadata in combat logs and limit simultaneous tokens to a small count (≤3).
- **Risk:** Telemetry noise from frequent small Élan adjustments.
  - *Mitigation:* Batch multiple low-value gains into a single `elan_delta` event per round when total change stays under a
    configurable threshold.
