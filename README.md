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
| M1 | Attack (4-hit combo, the last hit is a heavier finisher) |
| F (tap) | Parry: the first 0.2s of a block deflects a hit and stuns the attacker |
| F (hold) | Block: no HP damage, but fills posture. A full posture bar breaks your guard |
| Q | Dash in your movement direction (forward if standing still), with brief i-frames |
| W W | Double-tap W to sprint |

Missing a parry ("whiffing") locks parry out for a moment, so spamming F only blocks.

## Training dummies

Three dummies spawn in front of the spawn point:

- **Training Dummy**: stands still.
- **Blocker Dummy**: always blocks. Use it to test posture and guard breaks.
- **Swordsman Dummy**: swings at you every 2s. Press F when its blade glints white to parry.

## Layout

```
src/shared/CombatConfig.luau    all tunable numbers (timings, damage, speeds)
src/shared/Remotes.luau         RemoteEvent setup
src/server/CombatService.luau   server-authoritative hit resolution: parry, block, posture, stun
src/server/CombatServer.server  character registration and input routing
src/server/Dummies.luau         training dummies
src/server/Fx.luau              placeholder visuals (highlights, slash trail)
src/server/Sword.luau           placeholder katana welded to the right hand
src/client/Movement.luau        sprint, dash, WalkSpeed from combat state
src/client/CombatInput.client   keybinds
```
