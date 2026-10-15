-- 할로우: 부패의 가시 / 글리치 스텝
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local SPIKE_COUNT = 7
local SPIKE_GAP = 4.5
local SPIKE_DELAY = 0.07

local M = { Abilities = {} }

function M.Abilities.CorruptSpikes(data, ability)
	local dir = Common.FlatLook(data)
	local origin = data.Root.Position
	local y = Common.GroundY(data)
	local color = data.Def.Color
	local info = { Kind = "Ability", Ability = ability.Id }
	local alreadyHit = {}
	Status.Add(data, "Rooted", 0.4)

	-- 전방 일직선으로 차례차례 솟는 가시
	for i = 1, SPIKE_COUNT do
		Common.Delay(data, i * SPIKE_DELAY, function()
			local p = origin + dir * (i * SPIKE_GAP)
			local ground = Vector3.new(p.X, y, p.Z)
			Visuals.Spike(ground, color)
			local center = ground + Vector3.new(0, 2.5, 0)
			for _, model in ipairs(Combat.QueryRadius(center, 4, { data.Model, Visuals.Folder })) do
				if not alreadyHit[model] then
					alreadyHit[model] = true
					Combat.HitModel(data, model, 20, function(target)
						Status.Add(target, "Slowed", 2, 0.35)
					end, info)
				end
			end
		end)
	end
	return true
end

function M.Abilities.GlitchStep(data)
	local from = data.Root.Position
	if Common.DashForward(data, 20) < 3 then
		return false
	end
	Visuals.Burst(from, data.Def.Color, 4, 0.3)
	Visuals.Burst(data.Root.Position, data.Def.Color, 4, 0.3)
	return true
end

return M
