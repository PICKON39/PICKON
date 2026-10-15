-- 유령: 은신 / 분신
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local PURPLE = Color3.fromRGB(170, 120, 255)

local DECOY_TIME = 6

local M = { Abilities = {} }

function M.Abilities.Cloak(data)
	Status.Add(data, "Invisible", 5)
	Status.Add(data, "Hasted", 5, 0.15)
	return true
end

function M.Abilities.Decoy(data)
	local decoy = Visuals.Decoy(data.Model, data.Def.SprintSpeed, DECOY_TIME)
	if not decoy then
		return false
	end
	-- 살인마가 분신을 때리면 분신이 사라지고 살인마가 둔화
	Combat.RegisterTarget(decoy, function(attacker)
		if not attacker or attacker.Role ~= "Killer" or not decoy.Parent then
			return false
		end
		Combat.UnregisterTarget(decoy)
		Visuals.Burst(decoy:GetPivot().Position, PURPLE, 5, 0.4)
		decoy:Destroy()
		Status.Add(attacker, "Slowed", 2, 0.5)
		Common.Message(attacker, "분신이었다!", PURPLE, 2)
		return true
	end)
	return true
end

return M
