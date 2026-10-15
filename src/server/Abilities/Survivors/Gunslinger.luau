-- 총잡이: 동전 던지기 / 사격
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local YELLOW = Color3.fromRGB(255, 230, 80)
local ORANGE = Color3.fromRGB(255, 120, 40)
local GRAY = Color3.fromRGB(180, 180, 180)

local SHOT_RANGE = 90
local SHOT_ANGLE = 20
local MISFIRE_DAMAGE = 20

local M = { Abilities = {} }

function M.Abilities.CoinFlip(data, ability)
	local max = ability.MaxCharges or 3
	Status.Add(data, "Rooted", 0.5)
	if math.random() < 0.5 then
		Common.SetCharges(data, math.min(max, data.Charges + 1))
		Common.Message(data, ("앞면! 행운 %d/%d"):format(data.Charges, max), YELLOW, 1.5)
	else
		Common.Message(data, ("뒷면... 행운 %d/%d"):format(data.Charges, max), GRAY, 1.5)
	end
	return true
end

function M.Abilities.Shoot(data, ability)
	local chance = math.min(0.95, 0.35 + 0.2 * data.Charges)
	Common.SetCharges(data, 0)
	Status.Add(data, "Rooted", 0.4)

	local origin = data.Root.Position + Vector3.new(0, 1, 0)
	local look = Common.FlatLook(data)

	if math.random() > chance then
		-- 오발
		Combat.Damage(data, data, MISFIRE_DAMAGE, { Kind = "Self", Ability = ability.Id })
		Status.Add(data, "Slowed", 2, 0.5)
		Visuals.Burst(origin + look * 2, ORANGE, 3, 0.3)
		Common.Message(data, "오발! 총이 터졌다!", ORANGE, 2)
		return true
	end

	-- 정면 20도 / 90칸 안의 살인마를 노린다
	local killer = Common.GetKiller()
	if killer then
		local toKiller = killer.Root.Position - data.Root.Position
		local dist = Vector3.new(toKiller.X, 0, toKiller.Z).Magnitude
		if
			dist <= SHOT_RANGE
			and dist > 0.1
			and Common.IsInFront(data, killer.Root.Position, SHOT_ANGLE)
			and Combat.HasLineOfSight(origin, killer)
		then
			Combat.Stun(data, killer, 3.5, { Ability = ability.Id })
			Visuals.Beam(origin, killer.Root.Position, YELLOW)
			return true
		end
	end
	Visuals.Beam(origin, origin + look * SHOT_RANGE, YELLOW)
	Common.Message(data, "빗나갔다!", Color3.fromRGB(200, 200, 200), 1.5)
	return true
end

return M
