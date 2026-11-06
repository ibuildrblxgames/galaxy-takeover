# Galaxy Takeover

A Roblox real-time territory-conquest strategy game — expand your nation, build cities, ports and
defences, launch fleets and missiles, ally or betray other players and AI nations.

This project is a fork of **[RoWorld](https://github.com/lukechatton/roworld)** by Luke Chatton (itself a modified
version of OpenFront, © OpenFront and Contributors),
used under the GNU AGPL v3. The plan has two phases:

1. **Parity** — run an exact 1-for-1 copy of RoWorld in our own Roblox experience.
2. **Space** — re-theme the same game for space: star maps instead of continents, starships instead
   of warships, blaster and torpedo sounds instead of shells and bombs. Same rules, same depth.

See [docs/ROADMAP.md](docs/ROADMAP.md) for the phase breakdown and
[docs/SETUP.md](docs/SETUP.md) for everything that must be re-created under our own Roblox account
before the copy works end to end.

## Layout

| Path | What it is |
|---|---|
| `src/shared` | Simulation core (`Core/`), networking (`Net/`), game data (`Data/`), asset ID tables (`Assets/`) — synced to `ReplicatedStorage.Airfront` |
| `src/server` | Match server, lobbies, purchases, analytics, handoff — synced to `ServerScriptService.AirfrontServer` |
| `src/client` | Map renderer (`Map/`), UI (`UI/`), audio director (`Audio/`) — synced to `StarterPlayerScripts.AirfrontClient` |
| `assets/` | Source art (PNG/SVG/GLB) that gets uploaded to Roblox |
| `tools/` | Python/Luau tooling: asset generation and upload, map building, publishing |
| `tests/` | Luau test suites |
| `services/lobbies` | Node/TypeScript lobby service the game servers talk to over HTTP |

## Getting started

1. Install [Rojo](https://rojo.space) (and optionally [Selene](https://github.com/Kampfkarren/selene) for linting).
2. `rojo serve` from the repo root, then connect from the Rojo plugin in Roblox Studio
   (or `rojo build -o build/game.rbxl` and open the file).
3. Work through [docs/SETUP.md](docs/SETUP.md) — until the lobby service, products and assets are
   re-created under our account, some features (lobbies, purchases, some sounds) won't work.

## Staying in sync with RoWorld

The original repo is the `upstream` remote:

```sh
git fetch upstream
git merge upstream/main
```

## Licence and credits

GNU Affero General Public License v3 — see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
Because this is a network game under the AGPL, players must be able to get the source of the version
they play; the in-game Help & Credits card points to this repository.
