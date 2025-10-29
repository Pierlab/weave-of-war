# SDS — Command Model

- **Owner:** Pierre / Systems Design Guild
- **Status:** Locked for review (Vertical Slice P0)
- **Last Updated:** 2025-10-29

## 1. Purpose & Intent
Deliver a doctrine-driven command framework that keeps strategic choices legible while enforcing pacing through inertia and
command point (CP) limits. The system must let players plan, queue, and adjust orders with clear trade-offs, reinforcing the
fantasy of winning engagements before they trigger.

## 2. Player-Facing Rules
1. The player selects exactly one active doctrine at all times; changing doctrine consumes a round-limited swap and may cost Élan.
2. Each round grants a finite CP budget. Issuing an order spends CP immediately; unspent CP partially converts to Élan at end of
   round.
3. Orders inherit an inertia delay based on distance from headquarters (HQ) and communication modifiers. Delay is shown before
   confirmation and respected during resolution.
4. Units refuse illegal orders (doctrine-locked or insufficient CP) with contextual HUD feedback; CP is refunded on cancellation
   before execution begins.
5. The command queue displays all pending orders with their expected arrival round so the player can reprioritise or cancel.

## 3. System Rules & Data Flows
- `CommandState` resource tracks active doctrine ID, CP pool, and queue metadata. It exposes signals for doctrine change,
  CP spending, refund, and order execution.
- Doctrines reference allowed order tags plus global modifiers (CP cap delta, inertia multiplier). Data source: `data/doctrines.json`.
- Orders reference target entities, required posture, CP cost, inertia base, and optional Élan surcharge. Data source:
  `data/orders.json`.
- Inertia duration = `base_delay * doctrine_multiplier * comms_modifier`. Comms modifier derives from HQ upgrades, slider
  bonuses, and active logistics state.
- At end of round the system emits `command_round_closed` with summary stats (CP spent, orders completed, conversions to Élan).
- Cancellation pipeline: pending orders can be removed if they have not reached execution; CP is refunded minus a configurable
  cancellation fee when doctrine discourages flip-flopping.

## 4. UI / UX Specification
- **HUD Command Dial:** Shows active doctrine crest, CP remaining, and next refresh timer. Hover reveals doctrine passive effects.
- **Order Planner Panel:** Drag units or regions into slots to open a contextual menu listing valid orders. Each entry displays CP
  cost, inertia delay, and resulting stance changes.
- **Queue Timeline:** Horizontal timeline anchored above the map that lists queued orders sorted by ETA. Icons pulse as orders
  advance through stages (queued → transmitting → executing).
- **Error States:** When an order is blocked (insufficient CP, doctrine mismatch, target saturated), the planner flashes red,
  plays a muted click, and displays a tooltip describing the blocker and suggested alternative.
- **Accessibility:** All doctrine and order icons must include textual labels and colour-safe variants. Timers also surface via
  optional numerical badges for screen-reader parsing.

## 5. Telemetry Requirements
- `doctrine_changed` event: `{previous_id, new_id, round_index, elan_cost}`.
- `order_issued` event: `{order_id, unit_ids, cp_cost, inertia_turns, doctrine_id, issued_round}`.
- `order_resolved` event: `{order_id, unit_ids, result, delay_turns, cp_spent_actual}`.
- `order_canceled` event: `{order_id, reason, cp_refunded, cancel_round}`.
- `command_round_summary` event: `{round_index, cp_spent, cp_refunded, cp_converted_to_elan, backlog_count}`.
- Emit heartbeat metric `command_queue_latency` storing rolling average inertia durations per theatre for pacing dashboards.

## 6. Acceptance Criteria
1. **Doctrine Gating:** With a mock dataset, switching doctrine updates the available orders list within one frame and prevents
   selection of orders that are no longer legal.
2. **Inertia Visibility:** When issuing an order to a distant unit, the HUD timeline surfaces an inertia delay that matches the
   computed `base_delay * multipliers`, and the order does not execute before that timer expires.
3. **CP Economy:** After ending a round with leftover CP, the telemetry stream logs `command_round_summary` showing the correct
   CP-to-Élan conversion, and the Élan pool increases accordingly.
4. **Cancellation Flow:** Canceling a queued order before execution emits `order_canceled` with the configured reason and refunds
   the CP minus any doctrine-specific fee.
5. **Error Feedback:** Attempting to issue an order with insufficient CP displays the error tooltip, plays the muted click, and
   leaves the CP pool unchanged.

## 7. Risks & Mitigations
- **Risk:** Inertia calculations become opaque when multiple modifiers stack.
  - *Mitigation:* Surface a breakdown tooltip (base, doctrine, comms) whenever the player inspects an order ETA.
- **Risk:** Telemetry volume from order events could flood analytics.
  - *Mitigation:* Batch emits per round when more than N orders resolve and include counts instead of per-unit payloads.
- **Risk:** Doctrine swaps might feel punitive if delays stack with Élan costs.
  - *Mitigation:* Offer one “free” swap token per scenario and visualise remaining tokens in the command dial.
- **Risk:** Cancellation abuse allows players to peek at responses without commitment.
  - *Mitigation:* Apply cancellation fee scaling with doctrine aggressiveness and limit cancellations per round.
