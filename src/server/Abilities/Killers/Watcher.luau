-- 감시자: 대량 감염 / 칼날 투척
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local INFECTION_RADIUS = 22
local INFECTION_DELAY = 0.9

local M = { Abilities = {} }

function M.Abilities.MassInfection(data, ability)
	Status.Add(data, "Rooted", INFECTION_DELAY)
	Visuals.Label(data.Model, "!!", data.Def.Color, INFECTION_DELAY)
	Common.Delay(data, INFECTION_DELAY, function()
		if Status.Has(data, "Stunned") then
			return
		end
		local center = data.Root.Position
		Visuals.Burst(center, data.Def.Color, INFECTION_RADIUS, 0.6)
		local info = { Kind = "Ability", Ability = ability.Id }
		for _, s in ipairs(Common.SurvivorsNear(center, INFECTION_RADIUS)) do
			if Combat.Damage(data, s, 15, info) then
				Status.Add(s, "Slowed", 3, 0.4)
			end
		end
	end)
	return true
end

function M.Abilities.HurledBlade(data, ability)
	local dir = Common.FlatLook(data)
	local info = { Kind = "Projectile", Ability = ability.Id }
	Common.Projectile({
		Owner = data,
		Origin = data.Root.Position + dir * 2.5,
		Direction = dir,
		Speed = 120,
		MaxDistance = 90,
		Size = Vector3.new(0.6, 0.6, 4),
		Color = data.Def.Color,
		-- 처음 맞은 대상에서 멈춤
		OnHit = function(_, model)
			Combat.HitModel(data, model, 25, function(target)
				Status.Add(target, "Slowed", 2.5, 0.35)
			end, info)
			return false
		end,
	})
	return true
end

return M
