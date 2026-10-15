-- 캐릭터 능력(Q / E) 처리
-- 핸들러가 false 를 반환하면 쿨다운이 적용되지 않습니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local State = require(script.Parent.State)
local Status = require(script.Parent.Status)
local Combat = require(script.Parent.Combat)
local Visuals = require(script.Parent.Visuals)
local Net = require(script.Parent.Net)

local AbilityService = {}
local Handlers = {}

local YELLOW = Color3.fromRGB(255, 230, 80)
local GREEN = Color3.fromRGB(90, 255, 120)

local function flatLook(data): Vector3
	local l = data.Root.CFrame.LookVector
	local v = Vector3.new(l.X, 0, l.Z)
	if v.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return v.Unit
end

local function survivorsNear(position: Vector3, radius: number, exclude)
	local list = {}
	for _, d in ipairs(State.AliveList("Survivor")) do
		if d ~= exclude and (d.Root.Position - position).Magnitude <= radius then
			table.insert(list, d)
		end
	end
	return list
end

local function groundY(data): number
	return data.Root.Position.Y - (data.Humanoid.HipHeight + data.Root.Size.Y / 2)
end

-- 벽에 막히지 않는 만큼만 앞으로 이동
local function dashForward(data, distance: number): number
	local dir = flatLook(data)
	local result = Combat.CastWalls(data.Root.Position, dir * distance)
	local d = result and math.max(0, result.Distance - 2.5) or distance
	if d > 0.5 then
		data.Model:PivotTo(data.Model:GetPivot() + dir * d)
	end
	return d
end

---------------------------------------------------------------- 생존자

Handlers.Adrenaline = function(data)
	Status.Add(data, "Hasted", 4, 0.4)
	data.Stamina = math.min(data.MaxStamina, data.Stamina + 40)
	data.Exhausted = false
	Visuals.Highlight(data.Model, YELLOW, 4, 0.75)
end

Handlers.SixthSense = function(data)
	local killer = State.GetKiller()
	if not killer or not State.IsAlive(killer) then
		return false
	end
	Net.Send(data.Owner, "Reveal", killer.Model, 5)
	Net.Message(data.Owner, "살인마의 기척이 느껴진다...", Color3.fromRGB(255, 80, 80), 2)
end

Handlers.Block = function(data)
	Status.Add(data, "Blocking", 1.2)
	Status.Add(data, "Slowed", 1.2, 0.6)
	Visuals.Highlight(data.Model, Color3.fromRGB(120, 200, 255), 1.2, 0.5)
end

Handlers.Punch = function(data)
	Visuals.Slash(data.Root.CFrame, data.Def.Color, 6)
	local killer = Combat.FindKillerIn(Combat.QueryFront(data, 6))
	if killer then
		Combat.Stun(data, killer, 1.75)
	end
end

Handlers.Medkit = function(data)
	local best, bestDist = nil, math.huge
	for _, s in ipairs(survivorsNear(data.Root.Position, 12, data)) do
		local dist = (s.Root.Position - data.Root.Position).Magnitude
		if s.Humanoid.Health < s.Humanoid.MaxHealth and dist < bestDist then
			best, bestDist = s, dist
		end
	end
	if best then
		Combat.Heal(best, 35)
		Visuals.Beam(data.Root.Position, best.Root.Position, GREEN)
		Net.Message(best.Owner, data.Owner.Name .. " 님이 치료해 주었다! (+35)", GREEN, 2)
		Net.Message(data.Owner, best.Owner.Name .. " 님을 치료했다.", GREEN, 2)
	elseif data.Humanoid.Health < data.Humanoid.MaxHealth then
		Combat.Heal(data, 25)
		Net.Message(data.Owner, "스스로 치료했다. (+25)", GREEN, 2)
	else
		Net.Message(data.Owner, "치료할 대상이 없다.", Color3.fromRGB(200, 200, 200), 1.5)
		return false
	end
end

Handlers.Rally = function(data)
	local targets = survivorsNear(data.Root.Position, 18, nil)
	for _, s in ipairs(targets) do
		Status.Add(s, "Hasted", 6, 0.25)
		Visuals.Highlight(s.Model, GREEN, 6, 0.8)
		if s ~= data then
			Net.Message(s.Owner, "격려를 받았다! 이동속도 증가", GREEN, 2)
		end
	end
	Visuals.Burst(data.Root.Position, GREEN, 18, 0.5)
end

Handlers.CoinFlip = function(data)
	Status.Add(data, "Rooted", 0.5)
	if math.random() < 0.5 then
		data.Charges = math.min(3, data.Charges + 1)
		Net.Message(data.Owner, ("앞면! 행운 %d/3"):format(data.Charges), YELLOW, 1.5)
	else
		Net.Message(data.Owner, ("뒷면... 행운 %d/3"):format(data.Charges), Color3.fromRGB(180, 180, 180), 1.5)
	end
	if not data.IsBot then
		data.Owner:SetAttribute("Charges", data.Charges)
	end
end

Handlers.Shoot = function(data)
	local chance = math.min(0.95, 0.35 + 0.2 * data.Charges)
	data.Charges = 0
	if not data.IsBot then
		data.Owner:SetAttribute("Charges", 0)
	end
	Status.Add(data, "Rooted", 0.4)

	local origin = data.Root.Position + Vector3.new(0, 1, 0)
	local look = flatLook(data)

	if math.random() > chance then
		-- 오발
		data.Humanoid:TakeDamage(20)
		Status.Add(data, "Slowed", 2, 0.5)
		Visuals.Burst(origin + look * 2, Color3.fromRGB(255, 120, 40), 3, 0.3)
		Net.Message(data.Owner, "오발! 총이 터졌다!", Color3.fromRGB(255, 120, 40), 2)
		return
	end

	-- 정면 20도 / 90칸 안의 살인마를 노린다
	local killer = State.GetKiller()
	local hitPos = origin + look * 90
	if killer and State.IsAlive(killer) then
		local toKiller = killer.Root.Position - data.Root.Position
		local flat = Vector3.new(toKiller.X, 0, toKiller.Z)
		if flat.Magnitude <= 90 and flat.Magnitude > 0.1 and flat.Unit:Dot(look) >= math.cos(math.rad(20)) then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { data.Model, Visuals.Folder }
			local result = workspace:Raycast(origin, killer.Root.Position - origin, params)
			if not result or result.Instance:IsDescendantOf(killer.Model) then
				hitPos = killer.Root.Position
				Combat.Stun(data, killer, 3.5)
				Visuals.Beam(origin, hitPos, YELLOW)
				return
			end
		end
	end
	Visuals.Beam(origin, hitPos, YELLOW)
	Net.Message(data.Owner, "빗나갔다!", Color3.fromRGB(200, 200, 200), 1.5)
end

Handlers.Slash = function(data)
	Visuals.Slash(data.Root.CFrame, Color3.fromRGB(220, 230, 255), 8)
	local killer = Combat.FindKillerIn(Combat.QueryFront(data, 8))
	if killer then
		Combat.Stun(data, killer, 2.25)
	end
end

Handlers.Chicken = function(data)
	if data.Humanoid.Health >= data.Humanoid.MaxHealth then
		Net.Message(data.Owner, "배가 부르다.", Color3.fromRGB(200, 200, 200), 1.5)
		return false
	end
	Status.Add(data, "Slowed", 3, 0.5)
	Visuals.Label(data.Model, "🍗", Color3.new(1, 1, 1), 3)
	for i = 1, 3 do
		task.delay(i, function()
			if State.IsAlive(data) then
				Combat.Heal(data, 10)
			end
		end)
	end
end

Handlers.Cloak = function(data)
	Status.Add(data, "Invisible", 5)
	Status.Add(data, "Hasted", 5, 0.15)
end

Handlers.Decoy = function(data)
	Visuals.Decoy(data.Model, data.Def.SprintSpeed, 6)
end

---------------------------------------------------------------- 살인마

Handlers.CorruptSpikes = function(data)
	local dir = flatLook(data)
	local origin = data.Root.Position
	local y = groundY(data)
	local color = data.Def.Color
	local alreadyHit = {}
	Status.Add(data, "Rooted", 0.4)

	for i = 1, 7 do
		task.delay(i * 0.07, function()
			local p = origin + dir * (i * 4.5)
			local ground = Vector3.new(p.X, y, p.Z)
			Visuals.Spike(ground, color)
			local center = ground + Vector3.new(0, 2.5, 0)
			for _, model in ipairs(Combat.QueryRadius(center, 4, { data.Model, Visuals.Folder })) do
				if not alreadyHit[model] then
					alreadyHit[model] = true
					Combat.HitModel(data, model, 20, function(target)
						Status.Add(target, "Slowed", 2, 0.35)
					end)
				end
			end
		end)
	end
end

Handlers.GlitchStep = function(data)
	local from = data.Root.Position
	local moved = dashForward(data, 20)
	if moved < 3 then
		return false
	end
	Visuals.Burst(from, data.Def.Color, 4, 0.3)
	Visuals.Burst(data.Root.Position, data.Def.Color, 4, 0.3)
end

Handlers.Rage = function(data)
	Status.Add(data, "Hasted", 5, 0.3)
	Visuals.Highlight(data.Model, data.Def.Color, 5, 0.7)
	Visuals.Label(data.Model, "분노!", data.Def.Color, 1.5)
end

Handlers.Lunge = function(data)
	task.spawn(function()
		local hit = false
		for _ = 1, 8 do
			if not State.IsAlive(data) or Status.Has(data, "Stunned") then
				return
			end
			if dashForward(data, 3) < 2 then
				break
			end
			for _, model in ipairs(Combat.QueryFront(data, 4, 3.5)) do
				if Combat.HitModel(data, model, 30) then
					hit = true
				end
			end
			if hit then
				break
			end
			task.wait(0.025)
		end
		if not hit then
			Status.Add(data, "Slowed", 1.2, 0.5)
		end
	end)
end

Handlers.MassInfection = function(data)
	Status.Add(data, "Rooted", 0.9)
	Visuals.Label(data.Model, "!!", data.Def.Color, 0.9)
	task.delay(0.9, function()
		if not State.IsAlive(data) or Status.Has(data, "Stunned") then
			return
		end
		local center = data.Root.Position
		Visuals.Burst(center, data.Def.Color, 22, 0.6)
		for _, s in ipairs(survivorsNear(center, 22, nil)) do
			if Combat.Damage(data, s, 15) then
				Status.Add(s, "Slowed", 3, 0.4)
			end
		end
	end)
end

Handlers.HurledBlade = function(data)
	local dir = flatLook(data)
	local pos = data.Root.Position + dir * 2.5
	local blade = Visuals.Part(Vector3.new(0.6, 0.6, 4), CFrame.lookAt(pos, pos + dir), data.Def.Color, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { data.Model, Visuals.Folder }

	local speed, maxDist, traveled = 120, 90, 0
	local conn
	local function finish()
		conn:Disconnect()
		Visuals.Fade(blade, 0.15)
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		local stepDist = speed * dt
		local result = workspace:Raycast(pos, dir * stepDist, params)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				Combat.HitModel(data, model, 25, function(target)
					Status.Add(target, "Slowed", 2.5, 0.35)
				end)
			end
			finish()
			return
		end
		pos += dir * stepDist
		traveled += stepDist
		blade.CFrame = CFrame.lookAt(pos, pos + dir)
		if traveled >= maxDist then
			finish()
		end
	end)
end

----------------------------------------------------------------

function AbilityService.Use(data, key: string)
	local ability = data.Def.Abilities and data.Def.Abilities[key]
	if not ability then
		return
	end
	if not State.IsAlive(data) or Status.Has(data, "Stunned") or Combat.OnCooldown(data, key) then
		return
	end
	local handler = Handlers[ability.Id]
	if not handler then
		warn("능력 핸들러 없음:", ability.Id)
		return
	end
	local ok, result = pcall(handler, data, ability)
	if not ok then
		warn("능력 오류", ability.Id, result)
		return
	end
	if result ~= false then
		Combat.SetCooldown(data, key, ability.Cooldown)
	end
end

function AbilityService.Init()
	Remotes.UseAbility.OnServerEvent:Connect(function(player, key)
		if key ~= "Q" and key ~= "E" then
			return
		end
		local data = State.Get(player)
		if data then
			AbilityService.Use(data, key)
		end
	end)
end

return AbilityService
