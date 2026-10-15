-- 봇 살인마 AI: 가장 가까운 생존자를 추격하고, 사거리 안이면 공격 / 능력 사용, 목표가 없으면 순찰
local Server = script.Parent.Parent
local State = require(Server.State)
local Status = require(Server.Status)
local Combat = require(Server.Combat)
local AbilityService = require(Server.Abilities)
local Nav = require(script.Parent.Nav)

local KillerBrain = {}

local TICK = 0.15
local SPRINT_DISTANCE = 70 -- 이 거리 안의 목표는 달려서 추격
local UNDETECTABLE_RANGE = 25 -- Undetectable 생존자는 이 거리 밖이면 무시
local PATROL_TIMEOUT = 12

-- 능력 사용 규칙: 거리 범위 / 틱당 확률 / 시야 필요 여부
local ABILITY_RULES = {
	Q = { Min = 0, Max = 22, Chance = 0.06, NeedSight = false },
	E = { Min = 10, Max = 35, Chance = 0.05, NeedSight = true },
	R = { Min = 6, Max = 45, Chance = 0.03, NeedSight = true },
}

local function nearestSurvivor(data)
	local best, bestDist = nil, math.huge
	local pos = data.Root.Position
	for _, s in ipairs(State.AliveList("Survivor")) do
		if not Status.Has(s, "Invisible") then
			local dist = (s.Root.Position - pos).Magnitude
			if dist < bestDist and not (Status.Has(s, "Undetectable") and dist > UNDETECTABLE_RANGE) then
				best, bestDist = s, dist
			end
		end
	end
	return best, bestDist
end

local function tryAbilities(data, target, dist: number, sight: boolean)
	for key, rule in pairs(ABILITY_RULES) do
		if
			data.Def.Abilities
			and data.Def.Abilities[key]
			and dist >= rule.Min
			and dist <= rule.Max
			and (sight or not rule.NeedSight)
			and not Combat.OnCooldown(data, key)
			and math.random() < rule.Chance
		then
			Nav.Face(data, target.Root.Position)
			AbilityService.Use(data, key)
			return
		end
	end
end

local function randomPatrolPoint(map, exclude: Vector3?): Vector3?
	local points = map and map.PatrolPoints
	if not points or #points == 0 then
		return nil
	end
	for _ = 1, 4 do
		local p = points[math.random(1, #points)]
		if p ~= exclude then
			return p
		end
	end
	return points[1]
end

local function alive(data, session): boolean
	return session.Active and State.IsAlive(data)
end

function KillerBrain.Run(data, session, map)
	local nav = Nav.new(data)
	local patrolGoal, patrolSince = nil, 0
	local attackRange = (data.Def.AttackRange or 6) + 1.5

	local function step()
		nav:Animate()
		local target, dist = nearestSurvivor(data)
		if Status.Has(data, "Stunned") then
			nav:Stop()
		elseif target then
			patrolGoal = nil
			data.Sprinting = dist < SPRINT_DISTANCE
			local tpos = target.Root.Position
			local sight = Combat.HasLineOfSight(data.Root.Position, target)

			if dist <= attackRange then
				Nav.Face(data, tpos)
				Combat.KillerAttack(data)
			else
				tryAbilities(data, target, dist, sight)
			end
			if alive(data, session) then
				nav:MoveTo(tpos)
			end
		else
			-- 목표가 없으면 순찰 지점 사이를 걸어 다님
			data.Sprinting = false
			local reached = patrolGoal and Nav.FlatDistance(patrolGoal, data.Root.Position) < 6
			if not patrolGoal or reached or os.clock() - patrolSince > PATROL_TIMEOUT then
				patrolGoal = randomPatrolPoint(map, patrolGoal)
				patrolSince = os.clock()
			end
			if patrolGoal then
				nav:MoveTo(patrolGoal)
			else
				nav:Stop()
			end
		end
	end

	local lastWarn = 0
	while alive(data, session) do
		local ok, err = pcall(step)
		if not ok and os.clock() - lastWarn > 5 then
			lastWarn = os.clock()
			warn("봇 살인마 AI 오류:", err)
		end
		task.wait(TICK)
	end
	data.Sprinting = false
	nav:Destroy()
end

return KillerBrain
