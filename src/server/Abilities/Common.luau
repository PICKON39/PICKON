-- 캐릭터 서버 모듈용 도구 모음 (투사체 / 설치물 / 자주 쓰는 계산)
-- 캐릭터 모듈은 서버 모듈 대신 Common 하나만 require 합니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent

local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local State = require(Server.State)
local Status = require(Server.Status)
local Combat = require(Server.Combat)
local Visuals = require(Server.Visuals)
local Net = require(Server.Net)
local GeneratorService = require(Server.GeneratorService)

local Common = {
	Config = Config,
	Characters = Characters,
	State = State,
	Status = Status,
	Combat = Combat,
	Visuals = Visuals,
	Net = Net,
	GeneratorService = GeneratorService,
}

local DEPLOYABLE_HIT_COLOR = Color3.fromRGB(255, 60, 60)
local DEPLOYABLE_WATCH_INTERVAL = 0.5 -- TickInterval 이 없을 때 라운드 변경 감시 주기

---------------------------------------------------------------- 기본 헬퍼

-- 살아 있고 현재 라운드의 엔트리인지
function Common.Alive(data): boolean
	return State.IsAlive(data) and data.RoundId == State.RoundId
end

-- 바라보는 방향 (수평 단위 벡터)
function Common.FlatLook(data): Vector3
	local l = data.Root.CFrame.LookVector
	local v = Vector3.new(l.X, 0, l.Z)
	if v.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return v.Unit
end

-- 발밑 지면 높이
function Common.GroundY(data): number
	local root = data.Root
	if data.Humanoid.RigType == Enum.HumanoidRigType.R6 then
		return root.Position.Y - root.Size.Y / 2 - 2
	end
	return root.Position.Y - (data.Humanoid.HipHeight + root.Size.Y / 2)
end

-- 벽에 막히지 않는 만큼만 앞으로 이동. 실제 이동 거리 반환
function Common.DashForward(data, distance: number): number
	local dir = Common.FlatLook(data)
	local result = Combat.CastWalls(data.Root.Position, dir * distance)
	local d = if result then math.max(0, result.Distance - 2.5) else distance
	if d <= 0.5 then
		return 0
	end
	data.Model:PivotTo(data.Model:GetPivot() + dir * d)
	return d
end

function Common.SurvivorsNear(position: Vector3, radius: number, exclude)
	local list = {}
	for _, d in ipairs(State.AliveList("Survivor")) do
		if d ~= exclude and (d.Root.Position - position).Magnitude <= radius then
			table.insert(list, d)
		end
	end
	return list
end

-- 살아 있는 살인마 (없으면 nil)
function Common.GetKiller()
	local killer = State.GetKiller()
	if killer and State.IsAlive(killer) then
		return killer
	end
	return nil
end

-- 목록에서 position 에 가장 가까운 엔트리와 거리
function Common.Nearest(list, position: Vector3)
	local best, bestDist = nil, math.huge
	for _, d in ipairs(list) do
		local dist = (d.Root.Position - position).Magnitude
		if dist < bestDist then
			best, bestDist = d, dist
		end
	end
	return best, bestDist
end

-- position 이 data 의 정면 maxAngleDeg 안에 있는지 (수평 기준)
function Common.IsInFront(data, position: Vector3, maxAngleDeg: number): boolean
	local to = position - data.Root.Position
	local flat = Vector3.new(to.X, 0, to.Z)
	if flat.Magnitude < 0.01 then
		return true
	end
	return flat.Unit:Dot(Common.FlatLook(data)) >= math.cos(math.rad(maxAngleDeg))
end

-- attacker 가 target 의 등 뒤 maxAngleDeg 안에 있는지
function Common.IsBehind(attacker, target, maxAngleDeg: number): boolean
	local to = attacker.Root.Position - target.Root.Position
	local flat = Vector3.new(to.X, 0, to.Z)
	if flat.Magnitude < 0.01 then
		return false
	end
	return flat.Unit:Dot(-Common.FlatLook(target)) >= math.cos(math.rad(maxAngleDeg))
end

-- seconds 후 data 가 아직 살아 있고 같은 라운드면 fn 실행
function Common.Delay(data, seconds: number, fn: () -> ())
	task.delay(seconds, function()
		if Common.Alive(data) then
			fn()
		end
	end)
end

-- 충전 수 (HUD 의 Charges 표시)
function Common.SetCharges(data, n: number)
	data.Charges = n
	if not data.IsBot then
		data.Owner:SetAttribute("Charges", n)
	end
end

function Common.Message(data, text: string, color: Color3?, duration: number?)
	Net.Message(data.Owner, text, color, duration)
end

local function undetectable(model: Model): boolean
	local target = State.FromModel(model)
	return target ~= nil and Status.Has(target, "Undetectable")
end

-- viewer 에게 대상 모델을 벽 너머로 보여줌 (대상이 Undetectable 이면 false)
function Common.Reveal(viewer, targetModel: Model?, duration: number, color: Color3?): boolean
	if not viewer or not targetModel or undetectable(targetModel) then
		return false
	end
	Net.Send(viewer.Owner, "Reveal", targetModel, duration, color)
	return true
end

-- 모든 생존자 플레이어에게 대상 모델을 보여줌
function Common.RevealToSurvivors(targetModel: Model?, duration: number, color: Color3?): boolean
	if not targetModel or undetectable(targetModel) then
		return false
	end
	Net.Survivors("Reveal", targetModel, duration, color)
	return true
end

function Common.Sfx(name: string, position: Vector3?)
	Net.All("Sfx", name, position)
end

---------------------------------------------------------------- 투사체

-- opts = { Owner, Origin, Direction, Speed, MaxDistance, Size?, Color?, Shape?, Radius?, Hits?, OnHit?, OnExpire? }
-- OnHit(targetData?, model, position) 가 true 를 반환하면 계속 날아감. 모델마다 한 번만 맞음
function Common.Projectile(opts)
	local owner = opts.Owner
	local roundId = State.RoundId
	local dir: Vector3 = opts.Direction
	dir = if dir.Magnitude < 1e-3 then Vector3.new(0, 0, -1) else dir.Unit
	local pos: Vector3 = opts.Origin
	local speed: number = opts.Speed or 100
	local maxDist: number = opts.MaxDistance or 100
	local radius: number = opts.Radius or 1.5
	local hits: string = opts.Hits or (if owner and owner.Role == "Killer" then "Survivor" else "Killer")
	local ignore: { Instance } = { Visuals.Folder }
	if owner and owner.Model then
		table.insert(ignore, owner.Model)
	end

	local part = Visuals.Part(
		opts.Size or Vector3.new(0.6, 0.6, 2),
		CFrame.lookAt(pos, pos + dir),
		opts.Color or Color3.new(1, 1, 1),
		0,
		opts.Shape
	)
	local traveled = 0
	local hitModels = {}
	local stopped = false
	local conn: RBXScriptConnection? = nil

	local function stop()
		if stopped then
			return
		end
		stopped = true
		if conn then
			conn:Disconnect()
		end
		Visuals.Fade(part, 0.15)
	end

	-- 맞힐 수 있는 모델인지, 그리고 그 엔트리
	local function match(model: Model): (boolean, any)
		local role = Combat.TargetRole(model)
		if role then
			return hits == "Any" or role == hits, nil
		end
		local data = State.FromModel(model)
		if data and data ~= owner and State.IsAlive(data) and (hits == "Any" or data.Role == hits) then
			return true, data
		end
		return false, nil
	end

	-- 멈춰야 하면 true
	local function checkHits(at: Vector3): boolean
		for _, model in ipairs(Combat.QueryRadius(at, radius, ignore)) do
			if not hitModels[model] then
				local ok, data = match(model)
				if ok then
					hitModels[model] = true
					local keep = false
					if opts.OnHit then
						local success, result = pcall(opts.OnHit, data, model, at)
						if not success then
							warn("투사체 OnHit 오류:", result)
						end
						keep = success and result == true
					end
					if not keep or stopped then
						return true
					end
				end
			end
		end
		return false
	end

	local function expire(at: Vector3)
		if opts.OnExpire then
			local ok, err = pcall(opts.OnExpire, at)
			if not ok then
				warn("투사체 OnExpire 오류:", err)
			end
		end
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		if stopped then
			return
		end
		if State.RoundId ~= roundId then
			stop()
			return
		end
		local stepDist = math.min(speed * dt, maxDist - traveled)
		local wall = Combat.CastWalls(pos, dir * stepDist)
		local travel = if wall then wall.Distance else stepDist
		-- 한 프레임 이동 구간을 반경 간격으로 나눠 검사 (빠른 투사체가 대상을 건너뛰지 않도록)
		local samples = math.max(1, math.ceil(travel / radius))
		for i = 1, samples do
			local at = pos + dir * (travel * i / samples)
			if checkHits(at) then
				part.CFrame = CFrame.lookAt(at, at + dir)
				stop()
				return
			end
		end
		pos += dir * travel
		traveled += travel
		part.CFrame = CFrame.lookAt(pos, pos + dir)
		if wall or traveled >= maxDist - 1e-3 then
			stop()
			expire(if wall then wall.Position else pos)
		end
	end)

	return { Stop = stop }
end

---------------------------------------------------------------- 설치물

-- opts = { Owner, Name, CFrame, Build(model), Duration?, Health?, TickInterval?, OnTick(model)?,
--          OnDestroyed(model, byKiller)? }
-- Build 는 원점(0, 0, 0) = 지면 피벗 기준의 로컬 좌표로 파츠를 만들고, 이후 모델 전체가 CFrame 으로 옮겨집니다.
-- 상대편(생존자 설치물이면 살인마)의 공격 한 번마다 Health 1 감소, 0 이 되면 파괴됩니다.
function Common.Deployable(opts): Model
	local owner = opts.Owner
	local ownerRole: string = if owner and owner.Role then owner.Role else "Survivor"
	local roundId = State.RoundId
	local target: CFrame = opts.CFrame or CFrame.identity

	local model = Instance.new("Model")
	model.Name = opts.Name or "Deployable"
	if opts.Build then
		local ok, err = pcall(opts.Build, model)
		if not ok then
			warn("설치물 생성 오류:", model.Name, err)
		end
	end

	local primary: BasePart? = nil
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			primary = child
			break
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if not primary then
				primary = d
			end
		end
	end

	if primary then
		model.PrimaryPart = primary
		-- 이미 목표 위치 근처(월드 좌표)에 만들어졌다면 그대로 둔다
		local center = primary.Position
		local builtLocal = center.Magnitude <= (center - target.Position).Magnitude
		if builtLocal then
			primary.PivotOffset = primary.CFrame:Inverse() -- 피벗 = 원점
			model:PivotTo(target)
		end
	end
	model:SetAttribute("Deployable", model.Name)
	if owner and owner.Name then
		model:SetAttribute("Owner", owner.Name)
	end
	model.Parent = Visuals.RoundFolder

	local health: number = opts.Health or 1
	local destroyed = false

	local function finish(byKiller: boolean)
		if destroyed then
			return
		end
		destroyed = true
		Combat.UnregisterTarget(model)
		if opts.OnDestroyed and State.RoundId == roundId then
			local ok, err = pcall(opts.OnDestroyed, model, byKiller)
			if not ok then
				warn("설치물 OnDestroyed 오류:", model.Name, err)
			end
		end
	end

	local function destroy(byKiller: boolean)
		if destroyed then
			return
		end
		if byKiller and model.Parent then
			Visuals.Burst(model:GetPivot().Position, DEPLOYABLE_HIT_COLOR, 4, 0.35)
		end
		finish(byKiller)
		model:Destroy()
	end

	Combat.RegisterTarget(model, function(attacker)
		if destroyed or not attacker or attacker.Role == ownerRole then
			return false
		end
		health -= 1
		Visuals.Highlight(model, DEPLOYABLE_HIT_COLOR, 0.25, 0.3)
		if health <= 0 then
			destroy(true)
		end
		return true
	end, ownerRole)

	-- 외부에서 지워진 경우 (라운드 정리 등)
	model.Destroying:Once(function()
		finish(false)
	end)

	if opts.Duration then
		task.delay(opts.Duration, destroy, false)
	end

	-- 주기 실행 + 라운드가 바뀌면 정리
	task.spawn(function()
		local interval = opts.TickInterval or DEPLOYABLE_WATCH_INTERVAL
		while not destroyed do
			task.wait(interval)
			if destroyed then
				break
			end
			if State.RoundId ~= roundId then
				destroy(false)
				break
			end
			if opts.OnTick and opts.TickInterval then
				local ok, err = pcall(opts.OnTick, model)
				if not ok then
					warn("설치물 OnTick 오류:", model.Name, err)
				end
			end
		end
	end)

	return model
end

return Common
