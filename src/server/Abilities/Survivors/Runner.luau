-- 러너: 아드레날린 / 육감
local Common = require(script.Parent.Parent.Common)
local Status, Visuals = Common.Status, Common.Visuals

local YELLOW = Color3.fromRGB(255, 230, 80)
local RED = Color3.fromRGB(255, 80, 80)
local GRAY = Color3.fromRGB(200, 200, 200)

local M = { Abilities = {} }

function M.Abilities.Adrenaline(data)
	Status.Add(data, "Hasted", 4, 0.4)
	data.Stamina = math.min(data.MaxStamina, data.Stamina + 40)
	data.Exhausted = false
	Visuals.Highlight(data.Model, YELLOW, 4, 0.75)
	return true
end

function M.Abilities.SixthSense(data)
	local killer = Common.GetKiller()
	if not killer then
		return false
	end
	if not Common.Reveal(data, killer.Model, 5) then
		Common.Message(data, "살인마의 기척을 느낄 수 없다.", GRAY, 1.5)
		return false
	end
	Common.Message(data, "살인마의 기척이 느껴진다...", RED, 2)
	return true
end

return M
