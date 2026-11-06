# Setup: making the 1-for-1 copy ours

The code is a complete copy of RoWorld, but a few things in it are tied to the original author's
Roblox account, servers and computer. This is the checklist for re-creating each one under our own
account. Work top to bottom — the first section gets a playable copy, the rest restore every feature.

## 1. Playable in Studio (do first)

- [ ] Install Rojo, run `rojo serve`, connect from Studio, press Play.
      Matches against AI nations, the map, the simulation and the UI all run from code alone.
- [ ] Create our own Roblox experience and publish the synced place to it (File → Publish to Roblox).
- [ ] Enable **Studio Access to API Services** in Game Settings → Security so DataStores work in Studio.

## 2. Assets (art and sound)

The code points at **272 `rbxassetid://` IDs** uploaded by the original author.

- [ ] **Images and meshes** — public on Roblox, so most should load in our game as they are. Any that
      don't: the source files are in `assets/` and the generators in `tools/assets/make_*.py`
      re-create and re-upload them (`tools/upload.py`, which uploads through Studio's MCP server).
- [ ] **Sound effects and music** — Roblox audio is usually private to the account that uploaded it,
      so expect these to be silent in our game. The source WAVs are *not* in the repo
      (`assets/audio/` is gitignored), so they must be re-sourced:
      - Music: Rodrigo Flores' *Orchestral Ambients* packs (CC BY 4.0) — download, upload to our
        account, update the IDs in `src/shared/Assets/Soundtrack.luau`.
      - SFX: `src/shared/Assets/Audio.luau`, `AudioUI.luau`, `AudioExtra.luau` list every key and
        length. Re-source and re-upload — or skip ahead, since phase 2 replaces these with space
        sounds anyway.
- [ ] Track every new asset's author and licence in `NOTICE.md`.

## 3. Purchases (Robux developer products)

Product IDs only work inside the experience that created them.

- [ ] In Creator Dashboard → Monetization, create our own developer products (takeover, crates,
      Arsenal items, starter packs, General, …) and passes (`Data/Subscription.luau`).
- [ ] Put our IDs in `src/shared/Data/Products.luau` (and `staging` IDs if we keep a staging game).
      An `id = 0` hides that offer — the safe value until a product exists.
- [ ] `tools/assets/make_arsenal_products.py` can create/reprice them in bulk.

## 4. Lobby service (matchmaking, parties, team lobbies)

`src/server/Lobbies/LobbyHttp.luau` points at the original author's server (`rofront.snick.co`).
Our copy can't use it: requests are signed with a secret that isn't in the repo
(`src/server/Lobbies/Secret.luau`, gitignored). Without that file the game skips the lobby service
and still runs.

- [ ] Deploy `services/lobbies` (Node/TypeScript, pm2 config included) to our own host with HTTPS.
- [ ] Generate our own shared secret; put it in the service's environment and in
      `src/server/Lobbies/Secret.luau` (never commit it).
- [ ] Change `BASE_URL` and remove/replace `FALLBACK_URL` in `LobbyHttp.luau`.
- [ ] Enable **Allow HTTP Requests** in Game Settings → Security.

## 5. Owner-specific tooling

- [ ] `tools/publish.staging.json` holds the original staging universe/place IDs — replace with ours.
- [ ] `tools/publish.sh` is a macOS/zsh script driving the author's Studio window with personal
      helpers; use Studio's Publish button or `tools/publish.py` (Open Cloud API key in
      `.secrets/roblox_api_key`) instead.
- [ ] `.mcp.json` points at the macOS Roblox Studio MCP server; adjust the path on Windows.
- [ ] Admins = the experience owner (or high-rank group members) automatically — nothing to change.

## 6. Licence obligations (AGPL)

- [ ] Point `HelpOverlay.SOURCE_REPO` (`src/client/UI/HelpOverlay.luau`) at this repo, so players
      can find the source of the version they play.
- [ ] Keep the Credits & Licence card, `LICENSE` and `NOTICE.md`.
- [ ] Keep the CC BY 4.0 music credit while those tracks are used.
