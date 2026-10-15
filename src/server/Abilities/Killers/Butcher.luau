-- 도살자: 분노 / 돌진
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local LUNGE_STEPS = 8
local LUNGE_STEP_DIST = 3
local LUNGE_DAMAGE = 30

local M = { Abilities = {} }

function M.Abilities.Rage(data)
	Status.Add(data, "Hasted", 5, 0.3)
	Visuals.Highlight(data.Model, data.Def.Color, 5, 0.7)
	Visuals.Label(data.Model, "분노!", data.Def.Color, 1.5)
	return true
end

function M.Abilities.Lunge(data, ability)
	local info = { Kind = "Ability", Ability = ability.Id }
	task.spawn(function()
		local hit = false
		for _ = 1, LUNGE_STEPS do
			if not Common.Alive(data) or Status.Has(data, "Stunned") then
				return
			end
			if Common.DashForward(data, LUNGE_STEP_DIST) < 2 then
				break
			end
			for _, model in ipairs(Combat.QueryFront(data, 4, 3.5)) do
				if Combat.HitModel(data, model, LUNGE_DAMAGE, nil, info) then
					hit = true
				end
			end
			if hit then
				break
			end
			task.wait(0.025)
		end
		-- 빗나가면 잠시 둔화
		if not hit and Common.Alive(data) then
			Status.Add(data, "Slowed", 1.2, 0.5)
		end
	end)
	return true
end

return M
