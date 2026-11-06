--!strict
-- Images shipped inside the place (Assets/Embedded, written by tools/assets/embed_images.py) drawn into
-- EditableImages on the client, so new art shows without uploading it to Roblox.
--
--   EmbeddedImage.content("ui/city")              -> Content? (nil if it can't be drawn here)
--   EmbeddedImage.apply(label, "ui/city", fallback) -- ImageContent when embedded, else Image = fallback
--
-- Each image is decoded once and cached. Any failure (no EditableImage on this device, memory)
-- falls back to the uploaded asset id, so nothing ever goes blank because of this module.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmbeddedImage = {}

local Airfront = ReplicatedStorage:WaitForChild("Airfront")
local MapCodec = require(Airfront:WaitForChild("Core"):WaitForChild("MapCodec")) :: any
local data: { [string]: any }? = nil
local cache: { [string]: any } = {}
local failed: { [string]: boolean } = {}

local function blobs(): { [string]: any }
	if data == nil then
		local ok, m = pcall(function()
			return require(Airfront:WaitForChild("Assets"):WaitForChild("Embedded")) :: any
		end)
		data = if ok and type(m) == "table" then m else {}
	end
	return data :: { [string]: any }
end

--- True when `name` is an embedded image.
function EmbeddedImage.has(name: string?): boolean
	return name ~= nil and blobs()[name] ~= nil
end

--- The image `name` as Content for ImageContent, or nil.
function EmbeddedImage.content(name: string?): any
	if name == nil or failed[name] then
		return nil
	end
	local c = cache[name]
	if c ~= nil then
		return c
	end
	local e = blobs()[name]
	if e == nil then
		return nil
	end
	local ok, res = pcall(function()
		local px = MapCodec.zstd_decompress(MapCodec.b64decode(e.data))
		local size = Vector2.new(e.w, e.h)
		local img = AssetService:CreateEditableImage({ Size = size })
		img:WritePixelsBuffer(Vector2.zero, size, px)
		return Content.fromObject(img)
	end)
	if not ok or res == nil then
		failed[name] = true
		warn("[GalacticWars] embedded image " .. name .. " unavailable: " .. tostring(res))
		return nil
	end
	cache[name] = res
	return res
end

--- Shows embedded image `name` on `label`, or `fallback` (an asset id) when it can't be drawn.
function EmbeddedImage.apply(label: ImageLabel | ImageButton, name: string?, fallback: string?)
	local c = EmbeddedImage.content(name)
	if c ~= nil then
		label.Image = ""
		label.ImageContent = c
	else
		label.Image = fallback or ""
	end
end

--- Shows flag item `it` (Data/Cosmetics: a country flag, a shop flag, a Space Pass insignia) on
--- `label` with its rect: the embedded copy when there is one, else the uploaded sheet. `big`: a shop
--- flag's large card art.
local Cosmetics: any = nil
function EmbeddedImage.flag(label: ImageLabel | ImageButton, it: any, big: boolean?)
	if Cosmetics == nil then
		Cosmetics = require(Airfront:WaitForChild("Data"):WaitForChild("Cosmetics")) :: any
	end
	local name, x, y, w, h = Cosmetics.flag_embedded(it, big)
	if name ~= nil and EmbeddedImage.content(name) ~= nil then
		EmbeddedImage.apply(label, name, "")
	else
		local image
		if big then
			image, x, y, w, h = Cosmetics.flag_big(it)
		else
			image, x, y, w, h = Cosmetics.flag_image(it), it.x, it.y, it.w, it.h
		end
		label.Image = image or ""
	end
	label.ImageRectOffset = Vector2.new(x or 0, y or 0)
	label.ImageRectSize = Vector2.new(w or 0, h or 0)
end

return EmbeddedImage
