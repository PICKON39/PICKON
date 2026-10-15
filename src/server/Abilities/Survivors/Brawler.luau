-- 싸움꾼: 막기 / 주먹
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local BLUE = Color3.fromRGB(120, 200, 255)

local M = { Abilities = {} }

function M.Abilities.Block(data)
	Status.Add(data, "Blocking", 1.2)
	Status.Add(data, "Slowed", 1.2, 0.6)
	Visuals.Highlight(data.Model, BLUE, 1.2, 0.5)
	return true
end

function M.Abilities.Punch(data, ability)
	Visuals.Slash(data.Root.CFrame, data.Def.Color, 6)
	local killer = Combat.FindKillerIn(Combat.QueryFront(data, 6))
	if killer then
		Combat.Stun(data, killer, 1.75, { Ability = ability.Id })
	end
	return true
end

return M
