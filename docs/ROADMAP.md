# Roadmap

## Phase 1 — Parity (1-for-1 copy)

Goal: our experience plays exactly like RoWorld. No gameplay or rule changes.

- [x] Playable copy running in Studio (2026-11-05: tutorial, expansion, attacks, alliances, building)
- [ ] Everything else in [SETUP.md](SETUP.md) sections 1–6
- [ ] Side-by-side check against the live RoWorld: title screen, tutorial, matchmaking, a full match
      vs AI, structures, naval, nukes, alliances, shop/crates/Arsenal, game over
- [ ] Run the Luau test suites in `tests/` and keep them green

## Phase 2 — Space version

Goal: the same game, re-themed for space. The simulation (`src/shared/Core`) stays untouched where
possible; the theme lives in names, art, sound and maps. Keeping rules identical makes upstream
merges easy and keeps balance proven.

### The vision (from the owner, 2026-11-05)

Players control different parts of the universe and fight in space: missiles, rocketships that
launch troops — called **aliens** — to other parts of the universe, and shooting down enemy rockets
and ships. Not warships and boats.

### Decisions (2026-11-05)

- **Maps:** both, as map choices — a big **galaxy map** (sectors claimable, the void between them
  crossed only by rocketships) and a **solar-system map** (planets as small claimable worlds).
- **Warship →** **Battlecruiser**.
- **Order:** space names and unit/building art first, then the maps.

### How the vision maps onto the game's systems

The simulation already has every mechanic the vision needs; the space version renames and redraws
them. Every row keeps its rules, so balance stays proven and upstream merges stay easy.

| Game system (code) | RoWorld | Galaxy Takeover |
|---|---|---|
| Territory tiles (land) | Countries' land | **Star sectors** — claimable space (nebulae, star clusters, planets) |
| Impassable tiles (ocean) | Sea | **The void** — deep space between sectors; only rocketships cross it |
| Troops | Troops | **Aliens** |
| `U_TRANSPORT` (carries troops over sea) | Transport boat | **Alien rocketship** — launches aliens to another part of the universe |
| `U_WARSHIP` (hunts boats, patrols) | Warship | **Battlecruiser** — shoots down enemy rocketships |
| `U_TRADE` (gold between ports) | Trade ship | **Cargo freighter** |
| `U_TRUCK` (rail traffic) | Train | **Hyperlane shuttle** |
| `S_CITY` | City | **Colony** |
| `S_PORT` (launches boats/warships) | Port | **Starport** |
| `S_FACTORY` (rails) | Factory | **Fabricator** |
| `S_DEFENSE` | Defense Post | **Shield Generator** |
| `S_SAM` (intercepts nukes) | SAM Launcher | **Laser Turret** — shoots down incoming missiles |
| `S_SILO` | Missile Silo | **Missile Silo** |
| `S_ARTILLERY` / `S_AIRFIELD` / `S_RAILGUN` | Artillery / Airfield / Railgun | **Plasma Cannon** / **Hangar Bay** / **Mass Driver** |
| `N_ATOM` / `N_HYDROGEN` / `N_MIRV` | Atom bomb / Hydrogen bomb / MIRV | **Photon Missile** / **Antimatter Missile** / **Cluster Missile** |
| `N_MEGA` / `N_SCATTER` | Mega Nuke / Scattershot | **Nova Bomb** / **Meteor Swarm** |
| `N_SHELL` / `N_AIRSTRIKE` / `N_SLUG` | Shell / Air strike / Slug | **Plasma Bolt** / **Fighter Strike** / **Mass Driver Round** |
| Rails | Railways | **Hyperlanes** |
| Fallout | Fallout | **Radiation zone** |
| Nations / flags | Real countries, country flags | **Alien factions**, faction insignia |

Names are display text (`Defs.STRUCT_TITLES`, `Defs.NUKE_TITLES`, UI strings, tutorial, help);
internal ids (`"port"`, `"atom"`…) stay so saved data and upstream merges keep working.

### Work items

- [ ] **Maps** — star-system/galaxy maps built with `tools/maps/` in the same tile format
      (`Core/MapCodec.luau`); replace the continent maps in `src/server/MapData/`
- [ ] **Look** — space palette and starfield background (`src/client/Map/MapSurface.luau`, `UI/UITheme.luau`),
      ship and station sprites (`tools/assets/make_map_sprites.py`), explosion/warp FX
- [ ] **Sound** — blaster, laser, torpedo, shield-hit, warp-jump and alarm SFX for every key in
      `Assets/Audio.luau`; space soundtrack in `Assets/Soundtrack.luau` (all with licences in NOTICE.md)
- [ ] **Text** — rename everything in the table above in UI, tutorial (`Data/Tutorial.luau`) and help
- [ ] **Branding** — title card, logo, icon, thumbnails (`Assets/Branding.luau`, `tools/assets/make_branding.py`)
- [ ] **Cosmetics/shop** — space skins, insignia and crate art

### Done

- [x] Name in game: Galaxy Takeover (title, General, credits)
- [x] Space loading screen on join (`src/first`), title tagline "Conquer the Universe"
- [x] Space names everywhere players read them (`tools/space_text.py`): aliens, rocketships,
      battlecruisers, Laser Turrets, missiles, the void, factions, universe
- [x] Space art drawn (`tools/assets/draw_space_glyphs.py`, unit pixel art) — **waiting on upload**:
      publish the place (private) so Studio can upload `assets/map_sprites`, then run the upload
      step to write the new ids into `Assets/MapSprites.luau`
- [x] Maps: the **Star System** (`tools/maps/make_space_maps.py system`) replaces the Earth maps —
      a sun, four inner planets linked by asteroid bridges, an asteroid belt, ~25 outer planets with
      moons, eight biomes, planet names in tooltips. (The spiral galaxy was tried and dropped:
      "a 2d copy of the milky way"; the owner wants planets to claim and invade.)
- [x] Bot names: half alien species, half space crews (`tools/data/make_bot_names.py`)
- [x] Planet resources: lava/crystal/desert worlds pay more gold, jungle/toxic/ocean grow aliens
      faster, terran/ice hold more (`WorldMap.RESOURCE_OF_BIOME`, `Rules.planet_mults`); explained
      in Help, a Coach tip and the tile tooltip. Fewer, bigger planets; faint planet names on the map
      (`Map/PlanetLayer.luau`); fainter background stars
- [x] Sound: public licensed Creator Store audio (APM, ProSoundEffects, Roblox) for lasers,
      missiles, alarms, expansion pops, UI clicks and a 19-track space soundtrack (`Assets/AudioSpace.luau`)
- [x] Icons shown in Studio without publishing: PNGs embedded in `Assets/Embedded.luau`
      (`tools/assets/embed_images.py`) and drawn with EditableImage (`UI/EmbeddedImage.luau`)
- [x] UI palette: indigo glass, cyan edges, violet accents; build slots show their names
- [x] **Space Pass** (battle pass, 299 Robux): 30 tiers, free + premium tracks paying Stars and
      crates, XP from every match (`Data/BattlePass.luau`, `server/Purchases.luau`,
      `UI/BattlePassUI.luau`). **Before launch:** create a 299 Robux developer product and put its
      id in `Data/Products.luau` (`battlepass.id`). Studio test hook: set workspace attribute
      `GW_DEV_BP_XP` (number) or `GW_DEV_BP_PREMIUM` (true) during Play
- [x] Space Pass season 1 cosmetics (`tools/assets/make_pass_cosmetics.py` →
      `Data/PassCosmetics.luau`, art in `assets/embedded/{ships,insignia}`): 5 fleet skins (a trim
      over your rocketships, battlecruisers and missiles; new Locker tab "Fleets"), 5 territory skins,
      8 insignia. Pace: 60-150 XP a match (a tenth of its Stars), 3,000 XP a season = 20-50 matches
- [x] Hotbar as a starship console: corner brackets, cyan-violet edge, BUILD / WEAPONS tabs, slot
      energy glow and status light, slots grow on hover with larger cards
- [x] Starports: a click anywhere on your territory snaps to your nearest planet edge
- [x] Help & Credits: the GitHub repo line is hidden (owner's request; `HelpOverlay.SHOW_SOURCE`)
- [ ] Tests in `tests/` still reference the Earth maps (world, europe…): update or retire them
