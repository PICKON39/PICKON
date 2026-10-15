-- 검객: 베기 / 치킨
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local BLADE = Color3.fromRGB(220, 230, 255)
local GRAY = Color3.fromRGB(200, 200, 200)

local M = { Abilities = {} }

function M.Abilities.Slash(data, ability)
	Visuals.Slash(data.Root.CFrame, BLADE, 8)
	local killer = Combat.FindKillerIn(Combat.QueryFront(data, 8))
	if killer then
		Combat.Stun(data, killer, 2.25, { Ability = ability.Id })
	end
	return true
end

function M.Abilities.Chicken(data)
	if data.Humanoid.Health >= data.Humanoid.MaxHealth then
		Common.Message(data, "배가 부르다.", GRAY, 1.5)
		return false
	end
	Status.Add(data, "Slowed", 3, 0.5)
	Visuals.Label(data.Model, "🍗", Color3.new(1, 1, 1), 3)
	-- 3초에 걸쳐 10씩 회복
	for i = 1, 3 do
		Common.Delay(data, i, function()
			Combat.Heal(data, data, 10)
		end)
	end
	return true
end

return M
