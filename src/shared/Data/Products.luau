--!strict
-- Robux developer products (Creator Dashboard → Monetization → Developer Products). `id` is the
-- product's id; 0 = not created yet (its offer stays hidden). Each purchase is a saved credit of kind
-- `grants` (default: the key), `count` of them (default 1) (server/Purchases.luau): bought credits are
-- never lost if the moment passes. A `grants` of "unlock:<key>" is not a credit: it unlocks that
-- Arsenal item for good (Data/Arsenal).
--
-- Product ids belong to one experience. `staging` is the same product in Rofront Staging (2026-10-04:
-- a separate experience where a build is tested before it goes to prod); in that experience it
-- replaces `id`. Create or reprice them with
-- tools/assets/make_arsenal_products.py.
local PRODUCTS: { [string]: any } = {
	--- The Space Pass's premium track for a season (Data/BattlePass; Galaxy Takeover, 2026-11-05).
	--- 0 until the product exists in Galaxy Takeover' experience: the pass shows, its buy button says so.
	battlepass = { id = 3728683484, robux = 299, grants = "battlepass" },
	--- Solo / public: take over the AI nation that eliminated you (2026-09-28).
	takeover = { id = 3728683807, robux = 25 },
	--- A cosmetic crate (Data/Cosmetics; 2026-09-29: 49 Robux, the first one 15).
	crate = { id = 3728683983, robux = 49 },
	--- The first crate a player buys (offered only before their first crate).
	crate_first = { id = 3728683988, robux = 15, grants = "crate", first_only = true },
	--- Three crates at once (2026-10-19: 100 Robux instead of 120,
	--- three crates being 3 x 40 at their price): `count` crate credits for one receipt.
	crate3 = { id = 3728683995, robux = 100, grants = "crate", count = 3 },
	--- Ten crates at once (2026-10-27: a buy to come back to above 100 Robux; a paying player spent 89
	--- Robux on average, top experiences about 600): 299, about 30 a crate.
	crate10 = { id = 3728684002, robux = 299, grants = "crate", count = 10 },
	--- The Arsenal (Data/Arsenal; 2026-10-04), at Pixel Conquest's prices.
	unlock_mega = { id = 3728684009, robux = 39, grants = "unlock:mega" },
	unlock_scatter = { id = 3728684017, robux = 67, grants = "unlock:scatter" },
	unlock_reinforce = { id = 3728684023, robux = 149, grants = "unlock:reinforce" },
	unlock_artillery = { id = 3728684029, robux = 99, grants = "unlock:artillery" },
	unlock_airfield = { id = 3728684038, robux = 349, grants = "unlock:airfield" },
	unlock_railgun = { id = 3728684044, robux = 999, grants = "unlock:railgun" },
	unlock_stars2x = { id = 3728684051, robux = 59, grants = "unlock:stars2x" },
	unlock_reload2x = { id = 3728684060, robux = 129, grants = "unlock:reload2x" },
	--- The starter pack (Data/Starter; 2026-10-15: 39 Robux, limited time): Mega Nuke, Scattershot
	--- and 2x Stars, once, for a player who never paid. Its receipt is refused outside its offer.
	starter_pack = { id = 3728684067, robux = 39, grants = "starter" },
}

--- The flag shop (Data/Shop; 2026-10-22): one product per flag, made by
--- tools/assets/make_shop_flags.py (the ids live in Assets/ShopFlags), each granting "shopflag:<key>".
--- `shop_flag` marks them: UI/Prices asks Roblox for these only when the shop shows them.
local Shop: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.Shop)
	else (require :: any)("./Shop")
for _, f in Shop.flags() do
	PRODUCTS["shop_" .. f.key] = {
		id = f.product or 0,
		robux = Shop.price(f),
		grants = "shopflag:" .. f.key,
		staging = f.staging or 0,
		shop_flag = f.key,
	}
end

--- A set's bundle (Data/Shop.SETS `bundle`; 2026-10-24): all its flags in one product, granting
--- "shopset:<id>".
for sid, s in Shop.SETS do
	if s.bundle ~= nil then
		local prod, staging = Shop.bundle_ids(sid)
		PRODUCTS["shopset_" .. sid] = {
			id = prod,
			robux = s.bundle,
			grants = "shopset:" .. sid,
			staging = staging,
			shop_set = sid,
		}
	end
end

--- Rofront Staging (Data/Staging): there every product is its `staging` one.
local Staging: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.Staging)
	else (require :: any)("./Staging")

if Staging.here() then
	for _, p in PRODUCTS do
		p.id = p.staging or 0
	end
end

return PRODUCTS
