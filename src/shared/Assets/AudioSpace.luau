--!strict
-- Galaxy Takeover' sounds and soundtrack: public Creator Store audio from Roblox's licensed libraries
-- (APMOfficial, ProSoundEffects) and Roblox's own uploads, so they play in any experience without
-- uploading. Chosen 2026-11-05 with the store's search API (see NOTICE.md). AudioDirector lays these
-- over Assets/Audio, AudioExtra and AudioUI (same names), and plays `soundtrack` instead of
-- Assets/Soundtrack. Lengths are the store's whole-second durations.
local function a(id: number, length: number): { id: string, length: number }
	return { id = "rbxassetid://" .. tostring(id), length = length }
end

return {
	sfx = {
		-- the war
		attack_launch = a(9118782788, 1), -- Sci-Fi Weapon 7 (laser shot)
		expand = a(9125397351, 1), -- Blip Tone Single High Pitch Synth Blip
		expand_pop = a(16480579431, 1), -- Roblox 8-bit blip (faint tile tick, trimmed)
		boat_launch = a(12222065, 2), -- Launching rocket (Roblox)
		warship = a(9125902006, 1), -- Scrambled sci-fi beeps (battlecruiser order)
		build = a(9117297453, 3), -- Phasey synth power-up rise
		conquer = a(1839901345, 5), -- Powered Up Chimes (APM)
		nuke_launch = a(9117089319, 5), -- New Super Missile Pass By 2
		nuke_alarm = a(9118781307, 6), -- Sci-fi siren, varied alarms 1
		nuke_explosion = a(9126102254, 6), -- Time warp big explosion blast
		sam_launch = a(9116225257, 3), -- Laser Blast 101 (laser turret)
		sam_intercept = a(9119236749, 2), -- Small Explosion 1
		shell_fire = a(9118792593, 1), -- Sci-Fi Weapon 12 (plasma cannon)
		shell_hit = a(9117405979, 1), -- Plasma Swish 1
		shell_splash = a(9117406326, 1), -- Plasma Swish 5
		ship_sink = a(9113058196, 3), -- Short metallic air-burst explosion (ship shot down)
		eliminate = a(9119236757, 3), -- Small Explosion 2
		under_attack = a(9118805558, 7), -- Sci-fi alarm klaxon
		order_ack = a(9126132982, 1), -- Soft beep tone burst
		spawn_confirm = a(9120057087, 2), -- Time warp build-up (capital lands)
		game_start = a(9119438663, 6), -- Spaceship warp out
		countdown_gamestart = a(9119438663, 6),
		queue_start = a(9125973984, 1), -- Spaceship energy charge-up
		victory = a(1836473422, 10), -- Victory Fanfare Sting (APM)
		defeat = a(9045918379, 4), -- Seconds Til Defeat (APM)
		-- diplomacy
		alliance = a(9116395089, 2), -- Soft chiming hits
		ally_request = a(17208361335, 2), -- Roblox GUI notification high
		betrayal = a(1846902656, 3), -- Drama Sting 16 (APM)
		-- countdown
		countdown_tick = a(9125397825, 1),
		countdown_tick_1 = a(9125397359, 1),
		countdown_tick_2 = a(9125397532, 1),
		countdown_tick_3 = a(9125397823, 1),
		countdown_tick_4 = a(9125397272, 1),
		countdown_tick_5 = a(9125397533, 1),
		spectate_switch = a(9126229255, 1), -- fast whoosh
		-- interface (Roblox's UI kit)
		ui_click = a(15675059323, 1),
		ui_hover = a(15675032796, 1),
		ui_tab = a(15675032796, 1),
		ui_open = a(15674975792, 1),
		ui_back = a(15675012262, 1),
		ui_confirm = a(17208319162, 1),
		ui_error = a(16480558943, 1),
		ui_locked = a(16480558759, 1),
		buy_spend = a(127645268874265, 2), -- Roblox coin transfer
		star_get = a(9126073001, 1), -- synth sparkle ding
		star_tick = a(16480580213, 1),
		unlock = a(9116395085, 4),
		-- crates and reveals
		crate_drop = a(9125805579, 1),
		crate_land = a(9113058067, 3),
		crate_rattle = a(9118138693, 1),
		crate_shimmer = a(9126076030, 1),
		crate_open = a(9116395085, 4),
		crate_preview_common = a(9116394545, 1),
		crate_preview_rare = a(9116394876, 2),
		crate_preview_epic = a(9116394756, 3),
		crate_preview_legendary = a(9116395085, 4),
		reveal_common = a(9126072453, 1),
		reveal_rare = a(9126073318, 2),
		reveal_epic = a(1836860398, 6), -- Winning Spirit (APM)
		reveal_legendary = a(1836473422, 10),
		card_flip = a(15674975792, 1),
		card_whoosh = a(15675024286, 1),
	},
	soundtrack = {
		credit = "Music: APM Music (Roblox Creator Store)",
		license = "Roblox Creator Store",
		tracks = {
			life_begins = { id = "rbxassetid://9045936432", length = 179, title = "Life Begins", pack = "APM" },
			galaxies = { id = "rbxassetid://1836406945", length = 185, title = "Galaxies", pack = "APM" },
			the_night_sky = { id = "rbxassetid://9045933593", length = 172, title = "The Night Sky", pack = "APM" },
			calm_galaxy = { id = "rbxassetid://1836707954", length = 103, title = "Calm Galaxy", pack = "APM" },
			cosmic_dust = { id = "rbxassetid://1844477817", length = 114, title = "Cosmic Dust", pack = "APM" },
			deep_space = { id = "rbxassetid://9045934862", length = 231, title = "Deep Space", pack = "APM" },
			blue_planet = { id = "rbxassetid://9045936798", length = 169, title = "Blue Planet", pack = "APM" },
			ice_world = { id = "rbxassetid://9045935780", length = 169, title = "Ice World", pack = "APM" },
			orbiting_saturn = { id = "rbxassetid://9045937176", length = 151, title = "Orbiting Saturn", pack = "APM" },
			journey_into_space = { id = "rbxassetid://9045938173", length = 146, title = "Journey Into Space", pack = "APM" },
			seventh_galaxy = { id = "rbxassetid://1846384380", length = 156, title = "Seventh Galaxy", pack = "APM" },
			space_battlefield = { id = "rbxassetid://1835943821", length = 154, title = "Space Battlefield", pack = "APM" },
			dark_star = { id = "rbxassetid://9045179809", length = 111, title = "Dark Star", pack = "APM" },
			big_threat = { id = "rbxassetid://1847718983", length = 120, title = "Big Threat", pack = "APM" },
			run_or_die = { id = "rbxassetid://1843357769", length = 126, title = "Run or Die", pack = "APM" },
			metal_scifi_universe = { id = "rbxassetid://9038252619", length = 154, title = "Metal Sci-Fi Universe", pack = "APM" },
			massive_black_hole = { id = "rbxassetid://9045936046", length = 154, title = "Massive Black Hole", pack = "APM" },
			volcanoes_on_mars = { id = "rbxassetid://9045937563", length = 177, title = "Volcanoes On Mars", pack = "APM" },
			rocket_launch = { id = "rbxassetid://9045934083", length = 137, title = "Rocket Launch", pack = "APM" },
		},
		moods = {
			title = { "life_begins", "galaxies", "the_night_sky" },
			wait = { "calm_galaxy", "cosmic_dust" },
			calm = { "deep_space", "blue_planet", "ice_world", "orbiting_saturn", "journey_into_space", "seventh_galaxy", "the_night_sky", "cosmic_dust" },
			war = { "space_battlefield", "dark_star", "big_threat", "run_or_die", "metal_scifi_universe", "massive_black_hole", "volcanoes_on_mars", "rocket_launch" },
			victory = { "rocket_launch" },
			defeat = { "calm_galaxy" },
		},
	},
}
