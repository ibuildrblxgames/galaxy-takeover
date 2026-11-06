--!strict
-- An owner's weapon effect (Data/Galactic, kind "fx"; 2026-11-06): the colours their nukes explode
-- in and their missiles trail (Map/FxLayer, Map/UnitLayer), from GameState.cosmetics. Everyone in the
-- match sees them.
--
--   FxColors.of(state, owner) -> (color: Color3?, color2: Color3?)   nil, nil: the default look
local RS = game:GetService("ReplicatedStorage")
local Data = RS:WaitForChild("Airfront"):WaitForChild("Data")
local Cosmetics = require(Data:WaitForChild("Cosmetics")) :: any
local Galactic = require(Data:WaitForChild("Galactic")) :: any

local FxColors = {}

local cache: { [string]: { any } } = {}

function FxColors.of(st: any, owner: number?): (Color3?, Color3?)
	if st == nil or owner == nil or st.cosmetics == nil then
		return nil, nil
	end
	local cz = st.cosmetics[owner]
	local id = if cz ~= nil then cz.fx else nil
	if type(id) ~= "string" then
		return nil, nil
	end
	local c = cache[id]
	if c == nil then
		local a, b = Galactic.fx_colors(Cosmetics.item(id))
		c = { a or false, b or false }
		cache[id] = c
	end
	return (c[1] or nil) :: Color3?, (c[2] or nil) :: Color3?
end

return FxColors
