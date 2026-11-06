# Galaxy Takeover

Fork of lukechatton/roworld (itself a fork of OpenFront; AGPL v3), a Roblox territory-conquest strategy game written in Luau and
synced with Rojo (`default.project.json`). The code is a Luau port of a Godot game, so `src/shared/Core`
mirrors GDScript names and helpers (`Defs.luau`, `GodotRng.luau`).

## Phases

1. **Parity** — an exact 1-for-1 copy running in our own experience. Don't change gameplay, rules,
   balance or UI in this phase; only re-point things tied to the original owner (see docs/SETUP.md).
2. **Space** — re-theme to space (docs/ROADMAP.md). Prefer changing names, art, sound and maps over
   changing the simulation, so `git merge upstream/main` keeps working.

## Rules

- Origin: OpenFront → RoWorld → Galaxy Takeover. The LICENSE's additional terms require the in-game
  notice "© OpenFront and Contributors" to stay visible (HelpOverlay.LEGAL), and forbid using
  "OpenFront" as our title or implying endorsement. When rebranding, rewrite the LEGAL lines for
  Galaxy Takeover but keep both upstream copyright notices.
- Licence: keep `LICENSE`, `NOTICE.md` and the in-game Credits & Licence card. Every new third-party
  asset (sound, music, art) goes in NOTICE.md with its author and licence. CC BY music needs credit.
- Never commit secrets: `src/server/Lobbies/Secret.luau`, `.secrets/`, API keys.
- `src/shared/Assets/*.luau` files marked GENERATED are written by `tools/assets/*.py` — edit the
  generator, not the output.
- Upstream is the `upstream` remote (github.com/lukechatton/roworld).
