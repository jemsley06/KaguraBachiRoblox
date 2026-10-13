# KaguraBachiRoblox

A Kagurabachi-inspired Roblox sword fighting game.

## Setup

The code is synced into Roblox Studio with [Rojo](https://rojo.space):

1. Install Rojo (`aftman add rojo-rbx/rojo` or the VS Code extension) and the Rojo Studio plugin.
2. Run `rojo serve` in this folder.
3. In Studio, open a Baseplate place, click **Connect** in the Rojo plugin, then press Play.

## Controls

| Input | Action |
| --- | --- |
| M1 | Attack (4-hit combo, hits stun so the chain can't be escaped. The last hit does 1.2x damage and knocks the target away) |
| M2 | Feint: cancel a swing during its windup (2s cooldown) |
| F (tap) | Parry: the first 0.2s of a block deflects a hit and stuns the attacker |
| F (hold) | Block: no HP damage, but fills posture. A full posture bar breaks your guard |
| Q | Dodge forward, back, left or right (2 charges, 0.3s i-frames). The forward dodge is a longer lunge ending in a dash attack that opens the combo |
| W W | Double-tap W to sprint |
| Left Shift | Toggle shift lock |

See [DESIGN.md](DESIGN.md) for the game's direction and all the key values.

## Training dummies

Three dummies spawn in front of the spawn point:

- **Training Dummy**: stands still.
- **Blocker Dummy**: always blocks. Use it to test posture and guard breaks.
- **Swordsman Dummy**: swings at you every 2s and sometimes feints. Press F when it actually commits.

## Layout

```
src/shared/CombatConfig.luau    all tunable numbers (timings, damage, speeds)
src/shared/Remotes.luau         RemoteEvent setup
src/server/CombatService.luau   server-authoritative hit resolution: parry, block, posture, stun
src/server/CombatServer.server  character registration and input routing
src/server/Dummies.luau         training dummies
src/server/Fx.luau              placeholder visuals (highlights, slash trail)
src/server/Sword.luau           placeholder katana welded to the right arm
src/client/Movement.luau        momentum, sprint, dodges
src/client/ShiftLock.luau       custom shift lock
src/client/SwordAnimator.luau   procedural placeholder swing animation
src/client/Hud.luau             dodge charges, feint cooldown, shift lock indicator
src/client/CombatInput.client   keybinds
```
