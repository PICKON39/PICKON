-- 봇 생존자 AI: 살인마가 가까우면 도망, 아니면 가장 가까운 발전기를 수리, 할 일이 없으면 배회
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Server = script.Parent.Parent
local State = require(Server.State)
local Status = require(Server.Status)
local Combat = require(Server.Combat)
local GeneratorService = require(Server.GeneratorService)
local AbilityService = require(Server.Abilities)
local Nav = require(script.Parent.Nav)

local SurvivorBrain = {}

local TICK = 0.2
local FLEE_RADIUS = 35 -- 살인마가 이 거리 안이면 도망
local FLEE_REPICK = 2 -- 도망칠 지점 재선택 간격(초)
local CLOSE_ABILITY_RANGE = 10
local WANDER_TIMEOUT = 10
local ABILITY_KEYS = { "Q", "E", "R" }

local function aliveKiller()
	local killer = State.GetKiller()
	if killer and State.IsAlive(killer) then
		return killer
	end
	return nil
end

-- 살인마에게서 가장 먼 순찰 지점
local function fleePoint(map, killerPos: Vector3): Vector3?
	local best, bestDist = nil, -1
	for _, p in ipairs(map and map.PatrolPoints or {}) do
		local d = Nav.FlatDistance(p, killerPos)
		if d > bestDist then
			best, bestDist = p, d
		end
	end
	return best
end

local function randomPoint(map): Vector3?
	local points = map and map.PatrolPoints
	if not points or #points == 0 then
		return nil
	end
	return points[math.random(1, #points)]
end

-- 가끔 무작위 능력 사용 (가까우면 살인마를 바라보고 사용)
local function maybeUseAbility(data, killer, dist: number)
	local abilities = data.Def.Abilities
	if not abilities then
		return
	end
	local chance = dist < CLOSE_ABILITY_RANGE and 0.12 or 0.03
	if math.random() >= chance then
		return
	end
	local key = ABILITY_KEYS[math.random(1, #ABILITY_KEYS)]
	if not abilities[key] or Combat.OnCooldown(data, key) then
		return
	end
	if dist < CLOSE_ABILITY_RANGE then
		Nav.Face(data, killer.Root.Position)
	end
	AbilityService.Use(data, key)
end

local function alive(data, session): boolean
	return session.Active and State.IsAlive(data)
end

function SurvivorBrain.Run(data, session, map)
	local nav = Nav.new(data)
	local fleeGoal, fleeSince = nil, 0
	local wanderGoal, wanderSince = nil, 0
	local lastTick = os.clock()

	local function stopRepair()
		if data.RepairingGen then
			GeneratorService.StopWork(data)
		end
	end

	local function step(dt: number)
		nav:Animate()
		if Status.Has(data, "Stunned") then
			return
		end
		local killer = aliveKiller()
		local killerDist = killer and (killer.Root.Position - data.Root.Position).Magnitude or math.huge

		if killer and killerDist <= FLEE_RADIUS then
			-- 도망
			stopRepair()
			wanderGoal = nil
			data.Sprinting = true
			if not fleeGoal or os.clock() - fleeSince > FLEE_REPICK then
				fleeGoal = fleePoint(map, killer.Root.Position)
				fleeSince = os.clock()
			end
			maybeUseAbility(data, killer, killerDist)
			if fleeGoal and alive(data, session) then
				nav:MoveTo(fleeGoal)
			end
			return
		end
		fleeGoal = nil
		data.Sprinting = false

		-- 발전기 수리
		local gen, genDist = GeneratorService.NearestIncomplete(data.Root.Position)
		if gen then
			wanderGoal = nil
			if genDist > Config.GENERATOR_REPAIR_RANGE - 3 then
				stopRepair()
				nav:MoveTo(gen.Position)
				return
			end
			nav:Stop()
			Nav.Face(data, gen.Position)
			if data.RepairingGen ~= gen.Id then
				stopRepair()
				GeneratorService.StartWork(data, gen.Id)
			end
			GeneratorService.BotWork(data, gen, dt)
			return
		end

		-- 할 일이 없으면 배회
		stopRepair()
		local reached = wanderGoal and Nav.FlatDistance(wanderGoal, data.Root.Position) < 6
		if not wanderGoal or reached or os.clock() - wanderSince > WANDER_TIMEOUT then
			wanderGoal = randomPoint(map)
			wanderSince = os.clock()
		end
		if wanderGoal then
			nav:MoveTo(wanderGoal)
		else
			nav:Stop()
		end
	end

	local lastWarn = 0
	while alive(data, session) do
		local t = os.clock()
		local ok, err = pcall(step, t - lastTick)
		lastTick = t
		if not ok and os.clock() - lastWarn > 5 then
			lastWarn = os.clock()
			warn("봇 생존자 AI 오류:", err)
		end
		task.wait(TICK)
	end
	data.Sprinting = false
	nav:Destroy()
end

return SurvivorBrain
