# Handoff Config

## Verification Commands
test:
typecheck: rojo build -o /tmp/handoff-check.rbxlx
lint:
build:

> No package manifest: this is a Rojo + Luau (Roblox) project. `rojo build` validates
> default.project.json and the src/ layout; it does not type-check Luau. Gameplay can only
> be verified by playtesting in Roblox Studio. Candidates to add later: `selene src` (lint),
> `luau-lsp analyze src` (typecheck), installed via Rokit/Aftman.

## Conventions
response_language: en
handoff_dir:       .handoff
commit_style:      conventional
convention_docs:   CLAUDE.md, DESIGN.md

## Project Documentation Index

### Agent guidance
- [CLAUDE.md](CLAUDE.md) — code conventions and architecture rules

### Project docs
- [README.md](README.md) — setup, controls, file layout
- [DESIGN.md](DESIGN.md) — game direction and key values

### Detected toolchain
- package manager: none
- monorepo: none
- frameworks: Rojo, Luau (Roblox)
