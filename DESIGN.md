# KaguraBachi: Game Design

A **fast-paced, movement-based sword fighting game** inspired by Kagurabachi.
Fights are won by reading your opponent: parrying their swings, feinting to bait
their parries, and using dodges and momentum to control spacing.

This document records the intended direction and the key values. The numbers
live in code in [`src/shared/CombatConfig.luau`](src/shared/CombatConfig.luau);
if you change a value there, update this table too.

## Pillars

1. **Parrying is the core skill.** Every swing has a readable windup and can be
   parried. The attacker's counterplay is feinting and varying their timing.
2. **Movement is offense.** Dodges are fast and carry momentum, and dashing
   forward starts a combo. Standing still is a choice, not a default.
3. **Readable, not random.** Every attack has a visible tell (windup pose and
   blade glint). Outcomes come from timing, not luck.

## Controls

| Input | Action |
| --- | --- |
| M1 | Swing (4-hit combo) |
| M2 (during windup) | Feint: cancel the swing to bait a parry |
| F (tap) | Parry |
| F (hold) | Block |
| Q | Dodge forward, back, left or right (no diagonals). Forward dodge = dash attack |
| W W | Sprint |
| Left Shift | Toggle shift lock |

## Systems and key values

### Parry and block

| Value | Setting | Notes |
| --- | --- | --- |
| Parry window | 0.2s | Starts when F is pressed |
| Parried attacker stun | 1.0s | |
| Missed-parry lockout | 0.6s base | Tune via `getWhiffCooldown` |
| Posture max | 100 | Blocked hits fill posture. Full = guard break |
| Guard break stun | 1.5s | |
| Block/parry arc | 180° in front | Hits from behind ignore both |

### Swings

| Value | Setting | Notes |
| --- | --- | --- |
| Windup | 0.25s | The parry tell. Kept slight for pace |
| Combo length | 4 | The 4th hit is the finisher |
| Damage | 8 per hit | Finisher deals 1.2x (9.6) |
| Hitstun | 0.8s | Longer than the gap to the next hit, so a clean M1 chain is a guaranteed combo |
| Finisher | Knockback | Launches the target away (60 studs/s) with 1.0s stun |

### Feints

| Value | Setting | Notes |
| --- | --- | --- |
| Input | M2 during windup | Cancels the swing, which doesn't advance the combo |
| Cooldown | 2s | |
| Re-swing delay | 0.1s | Lets you feint and swing again with new timing |

### Dodge

| Value | Setting | Notes |
| --- | --- | --- |
| Charges | 2 | |
| Recharge | 1.5s | Every dodge restarts the timer. When it finishes, all charges refill |
| I-frames | 0.3s | |
| Directions | 4, relative to facing | Input snaps to forward, back, left or right, like Jujutsu Shenanigans |
| Side/back dodge | 0.22s at 70 studs/s | |
| Forward dodge | 0.38s at 65 studs/s | A longer lunge. The dash attack hits as it ends |
| Exit speed | Sprint speed | A dodge leaves you at max speed in that direction |
| Dash attack | Opens the combo | Counts as hit 1, so the next M1 is hit 2 |

**Recharge rule:** using one dodge and waiting refills it, so you never sit at
one charge after a pause. Using both empties you until the timer finishes, then
both come back at once.

### Movement

| Value | Setting | Notes |
| --- | --- | --- |
| Walk speed | 16 | |
| Sprint speed | 28 | Max ground speed |
| Acceleration | 40 studs/s² | Momentum ramp toward sprint |
| Deceleration | 35 studs/s² | Momentum bleed when slowing |
| Rig | R6 | Forced for all players |
| Camera | Optional shift lock | Character faces the camera |

## Current placeholders

- Sword: a simple part-built katana welded to the right arm.
- Swing animation: procedural. Each client rotates the right shoulder joint
  (raise for the windup, then sweep), so no uploaded animation assets are
  needed. Replace with real animations once they exist.
- VFX: highlight flashes and a short neon slash plane.

## Open questions

- Should parry also require facing, or only block?
- Knockback on finishers?
- Do dash attacks need their own cooldown beyond dodge charges?
- Kagurabachi-specific content: enchanted blades and techniques, characters.
