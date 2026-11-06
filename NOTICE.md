# Notice

## Origin

Galaxy Takeover is a modified version of RoWorld, which is itself a modified version of OpenFront.

- **OpenFront** — © OpenFront and Contributors. GNU AGPL v3 with additional terms.
- **RoWorld** — changes © 2026 Snick Co. / Luke Chatton (https://github.com/lukechatton/roworld).
  GNU AGPL v3 with the same additional terms.

The full licence is in [LICENSE](LICENSE).

## Additional terms we must follow (LICENSE, AGPL v3 Section 7)

- **Keep the copyright notice visible:** "© OpenFront and Contributors" must stay in a reasonably
  visible place in the game (main menu, loading/splash screen or credits). It is on the in-game
  Help & Credits card (`src/client/UI/HelpOverlay.luau`, `HelpOverlay.LEGAL`) — never remove it.
- **No misrepresentation:** Galaxy Takeover must not claim to be OpenFront, use "OpenFront" as its
  title, or suggest OpenFront (or RoWorld) endorses it.

## This fork

Galaxy Takeover — a modified version of RoWorld. Modifications are released under the same licence
(GNU AGPL v3). The git history records which changes were made, by whom and when; every commit
before this fork's first commit is the original RoWorld work.

This program is distributed WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
details.

## Third-party material

- **Music and sound effects (Galaxy Takeover)** — public Roblox Creator Store audio from Roblox's
  licensed libraries (APM Music via APMOfficial, ProSoundEffects) and Roblox's own uploads, which any
  Roblox experience may use. Every asset id, with its title, is in `src/shared/Assets/AudioSpace.luau`.
- **Music (RoWorld's, no longer played)** — Rodrigo Flores (Orchestral Ambients bundle), CC BY 4.0
  (https://creativecommons.org/licenses/by/4.0/), listed in `src/shared/Assets/Soundtrack.luau`.
  If these tracks are ever used again, their credit must return to the game.
- **Space Pass icons and insignia** — Noto Emoji by Google, Apache License 2.0
  (https://github.com/googlefonts/noto-emoji, https://www.apache.org/licenses/LICENSE-2.0), taken
  from the `@iconify-json/noto` package and rendered to PNG in `assets/embedded/bp/` and
  `assets/embedded/insignia/` (`tools/assets/make_pass_cosmetics.py`). Fleet and territory skins are
  Galaxy Takeover' own designs.
- **Country flags** — Wikimedia Commons, public domain or CC0 files; see `assets/flags/SOURCE.txt`.
- **World map** — built from public-domain geographic data (see the RoWorld history, 2026-10-26).
- Other flags, map icons, sprites and effects are RoWorld's own work under the AGPL.

Any new third-party assets added for the space version (sounds, music, art) must be listed here
with their author and licence.
