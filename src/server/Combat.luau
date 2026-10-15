-- 피해 / 기절 / 치료 / 히트박스 / 살인마 기본 공격
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local Status = require(script.Parent.Status)
local Visuals = require(script.Parent.Visuals)
local Net = require(script.Parent.Net)
local GeneratorService = require(script.Parent.GeneratorService)

local Combat = {}

local YELLOW = Color3.fromRGB(255, 230, 80)
local BLUE = Color3.fromRGB(120, 200, 255)
local RED = Color3.fromRGB(255, 40, 40)
local GREEN = Color3.fromRGB(90, 255, 120)

local ATTACK_RATE = 0.1 -- Attack 리모트 최소 간격(초)
local BLEED_INTERVAL = 1

-- 특수 피격 대상 (분신 / 설치물 / 소환수): [model] = { Fn, Role }
local targets: { [Model]: { Fn: (any, number, any) -> boolean, Role: string } } = {}

function Combat.Now(): number
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------- 쿨다운

local function replicateCooldown(data, key: string)
	if not data.IsBot then
		data.Owner:SetAttribute("CD_" .. key, data.Cooldowns[key] or 0)
	end
end

function Combat.SetCooldown(data, key: string, duration: number)
	data.Cooldowns[key] = Combat.Now() + duration
	replicateCooldown(data, key)
end

function Combat.ReduceCooldown(data, key: string, seconds: number)
	local expires = data.Cooldowns[key]
	if expires then
		data.Cooldowns[key] = math.max(Combat.Now(), expires - seconds)
		replicateCooldown(data, key)
	end
end

function Combat.ResetCooldown(data, key: string)
	data.Cooldowns[key] = nil
	replicateCooldown(data, key)
end

function Combat.OnCooldown(data, key: string): boolean
	return (data.Cooldowns[key] or 0) > Combat.Now()
end

---------------------------------------------------------------- 특수 대상

-- fn(attacker, damage, info) -> boolean (맞았으면 true)
-- role: 이 대상이 어느 편으로 취급되는지 (기본 "Survivor" = 살인마의 공격 대상)
function Combat.RegisterTarget(model: Model, fn: (any, number, any) -> boolean, role: string?)
	targets[model] = { Fn = fn, Role = role or "Survivor" }
	model.Destroying:Once(function()
		targets[model] = nil
	end)
end

function Combat.UnregisterTarget(model: Model)
	targets[model] = nil
end

function Combat.IsTarget(model: Instance): boolean
	return targets[model :: Model] ~= nil
end

-- 등록된 대상의 편 ("Survivor" | "Killer"), 없으면 nil
function Combat.TargetRole(model: Instance): string?
	local t = targets[model :: Model]
	return t and t.Role
end

---------------------------------------------------------------- 히트박스

local function hittable(model: Model): boolean
	if targets[model] then
		return true
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- 반경 안의 (살아 있는 Humanoid 를 가진 / 등록된) 모델 목록
function Combat.QueryRadius(center: Vector3, radius: number, ignore: { Instance }?): { Model }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local seen = {}
	local list = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not seen[model] and not hittable(model) do
			seen[model] = true
			model = model:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			table.insert(list, model)
		end
	end
	return list
end

-- 캐릭터 정면의 히트박스
function Combat.QueryFront(data, range: number, radius: number?): { Model }
	local cf = data.Root.CFrame
	local center = cf.Position + cf.LookVector * (range * 0.6)
	return Combat.QueryRadius(center, radius or range * 0.6, { data.Model, Visuals.Folder })
end

function Combat.FindKillerIn(models: { Model })
	for _, model in ipairs(models) do
		local data = State.FromModel(model)
		if data and data.Role == "Killer" and State.IsAlive(data) then
			return data
		end
	end
	return nil
end

function Combat.FindSurvivorsIn(models: { Model })
	local list = {}
	for _, model in ipairs(models) do
		local data = State.FromModel(model)
		if data and data.Role == "Survivor" and State.IsAlive(data) then
			table.insert(list, data)
		end
	end
	return list
end

-- 캐릭터 / 이펙트 / 라운드 오브젝트를 무시하는 벽 감지용 레이캐스트
local function wallParams(): RaycastParams
	local ignore: { Instance } = { Visuals.Folder, Visuals.RoundFolder }
	for _, data in pairs(State.All()) do
		table.insert(ignore, data.Model)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

function Combat.CastWalls(origin: Vector3, direction: Vector3): RaycastResult?
	return workspace:Raycast(origin, direction, wallParams())
end

-- fromPos 에서 대상 캐릭터까지 벽에 막히지 않는지
function Combat.HasLineOfSight(fromPos: Vector3, toData): boolean
	if not toData or not toData.Root then
		return false
	end
	return Combat.CastWalls(fromPos, toData.Root.Position - fromPos) == nil
end

---------------------------------------------------------------- 치료 / 피해 / 기절

-- 실제로 회복된 양을 반환하고 source.Stats.Heals 에 누적
function Combat.Heal(source, target, amount: number): number
	if not State.IsAlive(target) or amount <= 0 then
		return 0
	end
	local hum = target.Humanoid
	local before = hum.Health
	hum.Health = math.min(hum.MaxHealth, before + amount)
	local healed = math.max(0, hum.Health - before)
	if source and source.Stats then
		source.Stats.Heals += healed
	end
	Visuals.Highlight(target.Model, GREEN, 0.6, 0.5)
	return healed
end

-- 생존자 피해. info = { Kind, Ability?, Unblockable?, NoHaste? }
-- Kind = "Self" (오발 등 자해) 는 막기/보호막/가속/통계를 건너뜀
-- Kind = "Bleed" (출혈 지속 피해) 는 막을 수 없고, 가속/발전기 중단/명중 수를 건너뜀
function Combat.Damage(attacker, target, amount: number, info): boolean
	if not target or target.Role ~= "Survivor" or not State.IsAlive(target) then
		return false
	end
	info = info or {}
	local isSelf = info.Kind == "Self"
	local isBleed = info.Kind == "Bleed"
	local byOther = attacker ~= nil and attacker ~= target and not isSelf

	-- 막기: 피해 무효 + 공격한 살인마 기절
	if not isSelf and not info.Unblockable and Status.Has(target, "Blocking") then
		Status.Remove(target, "Blocking")
		Visuals.Burst(target.Root.Position, BLUE, 4, 0.3)
		if attacker and attacker.Role == "Killer" then
			Combat.Stun(target, attacker, 3, { Ability = "Block" })
		end
		Net.Message(target.Owner, "막기 성공!", BLUE, 1.5)
		return false
	end

	local modified = State.CallHook(target, "OnDamaged", attacker, amount, info)
	if type(modified) == "number" then
		amount = modified
	end
	if amount <= 0 then
		return false
	end

	-- 보호막: 다음 피해 1회 완전 흡수
	if not isSelf and Status.Has(target, "Shielded") then
		Status.Remove(target, "Shielded")
		Visuals.Burst(target.Root.Position, BLUE, 4, 0.3)
		Net.Message(target.Owner, "보호막이 피해를 막았다!", BLUE, 1.5)
		return false
	end

	local resist = Status.Value(target, "Resistant")
	if resist > 0 then
		amount *= math.max(0, 1 - resist)
	end

	local hum = target.Humanoid
	local before = hum.Health
	hum:TakeDamage(amount)
	local dealt = math.max(0, before - hum.Health)

	if byOther and attacker.Stats then
		attacker.Stats.Damage += dealt
		if not isBleed then
			attacker.Stats.Hits += 1
		end
	end

	-- 피격 연출
	Visuals.Highlight(target.Model, RED, 0.25, 0.3)
	Net.Send(target.Owner, "Hit")
	if byOther and not isBleed then
		Net.Send(attacker.Owner, "HitConfirm")
	end

	-- 맞은 생존자는 잠깐 가속 (도망칠 기회)
	if not isSelf and not isBleed and not info.NoHaste then
		Status.Add(target, "Hasted", Config.HIT_HASTE_TIME, Config.HIT_HASTE)
	end
	if not isBleed then
		GeneratorService.StopWork(target)
	end

	if byOther then
		State.CallHook(attacker, "OnDealtDamage", target, dealt, info)
		if hum.Health <= 0 and attacker.Stats then
			attacker.Stats.Kills += 1
			State.CallHook(attacker, "OnKill", target)
		end
	end
	return true
end

-- 기절. 대상의 OnStunned 훅이 시간을 바꾸거나(0 이하면 취소) 할 수 있음
function Combat.Stun(source, target, duration: number, info): boolean
	if not State.IsAlive(target) then
		return false
	end
	local modified = State.CallHook(target, "OnStunned", source, duration, info)
	if type(modified) == "number" then
		duration = modified
	end
	if duration <= 0 then
		return false
	end
	Status.Add(target, "Stunned", duration)
	if target.Role == "Survivor" then
		GeneratorService.StopWork(target)
	end
	Visuals.Burst(target.Root.Position, YELLOW, 5, 0.35)
	if source and source ~= target then
		if source.Stats then
			source.Stats.Stuns += 1
		end
		State.CallHook(source, "OnStunDealt", target, duration, info)
		local text = target.Role == "Killer" and "살인마를 기절시켰다!" or (target.Name .. " 님을 기절시켰다!")
		Net.Message(source.Owner, text, YELLOW, 2)
	end
	Net.Message(target.Owner, ("%.1f초간 기절!"):format(duration), YELLOW, duration)
	return true
end

-- 히트박스에 걸린 모델 처리 (등록된 대상 포함). onHit(target) 은 생존자에게 실제 피해가 들어갔을 때 호출
function Combat.HitModel(attacker, model: Model, damage: number, onHit: ((any) -> ())?, info): boolean
	local registered = targets[model]
	if registered then
		local ok, result = pcall(registered.Fn, attacker, damage, info)
		if not ok then
			warn("특수 대상 피격 오류:", result)
			return false
		end
		return result == true
	end
	local target = State.FromModel(model)
	if target and target.Role == "Survivor" then
		local ok = Combat.Damage(attacker, target, damage, info)
		if ok and onHit then
			onHit(target)
		end
		return ok
	end
	return false
end

-- 살인마 기본 공격 (M1)
function Combat.KillerAttack(data)
	if data.Role ~= "Killer" or not State.IsAlive(data) then
		return
	end
	if Status.Has(data, "Stunned") or Status.Has(data, "Silenced") or Combat.OnCooldown(data, "M1") then
		return
	end
	local def = data.Def
	Combat.SetCooldown(data, "M1", def.AttackCooldown)
	Status.Add(data, "Slowed", 0.6, 0.4)
	Visuals.Slash(data.Root.CFrame, def.Color, def.AttackRange)

	local roundId = State.RoundId
	task.delay(0.12, function()
		if State.RoundId ~= roundId or not State.IsAlive(data) or Status.Has(data, "Stunned") then
			return
		end
		for _, model in ipairs(Combat.QueryFront(data, def.AttackRange)) do
			Combat.HitModel(data, model, def.AttackDamage, nil, { Kind = "M1" })
		end
	end)
end

---------------------------------------------------------------- 출혈

local function tickBleeding()
	local killer = State.GetKiller()
	for _, data in pairs(State.All()) do
		if data.Role == "Survivor" and State.IsAlive(data) and Status.Has(data, "Bleeding") then
			Combat.Damage(killer, data, Status.Value(data, "Bleeding"), { Kind = "Bleed", Unblockable = true })
		end
	end
end

function Combat.Init()
	Remotes.Attack.OnServerEvent:Connect(function(player)
		if not Net.RateLimit(player, "Attack", ATTACK_RATE) then
			return
		end
		local data = State.Get(player)
		if data then
			Combat.KillerAttack(data)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= BLEED_INTERVAL then
			acc -= BLEED_INTERVAL
			tickBleeding()
		end
	end)
end

return Combat
