# KaguraBachiRoblox

Roblox sword fighting game, synced into Studio with Rojo (`default.project.json`).

- **Read [`DESIGN.md`](DESIGN.md) first.** It holds the game's direction and key values.
  Keep it in sync when changing mechanics or numbers.
- All tunables live in `src/shared/CombatConfig.luau`. Never hard-code combat numbers elsewhere.
- Combat is server-authoritative (`src/server/CombatService.luau`). Clients send intent only.
  Client movement (dodge, sprint, momentum, shift lock) runs locally for responsiveness.
- Server-to-client state is replicated through attributes on character models.
- Players and NPCs use R6 rigs.
- Code style: Luau, tabs, `--!strict`-friendly type annotations, small modules.
