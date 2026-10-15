-- 피해 / 기절 / 히트박스 / 살인마 기본 공격
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local State = require(script.Parent.State)
local Status = require(script.Parent.Status)
local Visuals = require(script.Parent.Visuals)
local Net = require(script.Parent.Net)

local Combat = {}

function Combat.Now(): number
	return workspace:GetServerTimeNow()
end

function Combat.SetCooldown(data, key: string, duration: number)
	local expires = Combat.Now() + duration
	data.Cooldowns[key] = expires
	if not data.IsBot then
		data.Owner:SetAttribute("CD_" .. key, expires)
	end
end

function Combat.OnCooldown(data, key: string): boolean
	return (data.Cooldowns[key] or 0) > Combat.Now()
end

-- 반경 안에 있는 (Humanoid 를 가진) 모델 목록
function Combat.QueryRadius(center: Vector3, radius: number, ignore: { Instance }): { Model }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local found = {}
	local list = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not found[model] then
			found[model] = true
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(list, model)
			end
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

function Combat.Heal(data, amount: number)
	if not State.IsAlive(data) then
		return
	end
	local hum = data.Humanoid
	hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	Visuals.Highlight(data.Model, Color3.fromRGB(90, 255, 120), 0.6, 0.5)
end

-- 살인마 → 생존자 피해. 막기 상태면 반격 기절.
function Combat.Damage(attacker, target, amount: number): boolean
	if target.Role ~= "Survivor" or not State.IsAlive(target) then
		return false
	end

	if Status.Has(target, "Blocking") then
		Status.Remove(target, "Blocking")
		Visuals.Burst(target.Root.Position, Color3.fromRGB(120, 200, 255), 4, 0.3)
		if attacker and attacker.Role == "Killer" then
			Combat.Stun(target, attacker, 3)
		end
		Net.Message(target.Owner, "막기 성공!", Color3.fromRGB(120, 200, 255), 1.5)
		return false
	end

	target.Humanoid:TakeDamage(amount)
	Visuals.Highlight(target.Model, Color3.fromRGB(255, 40, 40), 0.25, 0.3)
	Net.Send(target.Owner, "Hit")

	-- 맞은 생존자는 잠깐 가속 (도망칠 기회)
	Status.Add(target, "Hasted", 1.5, 0.3)

	if target.RepairingGen then
		target.RepairingGen = nil
		Net.Send(target.Owner, "CloseGenerator")
	end
	if attacker then
		Net.Send(attacker.Owner, "HitConfirm")
	end
	return true
end

-- 생존자 → 살인마 기절
function Combat.Stun(source, target, duration: number)
	if not State.IsAlive(target) then
		return
	end
	Status.Add(target, "Stunned", duration)
	Visuals.Burst(target.Root.Position, Color3.fromRGB(255, 230, 80), 5, 0.35)
	if source and not source.IsBot then
		Net.Message(source.Owner, "살인마를 기절시켰다!", Color3.fromRGB(255, 230, 80), 2)
	end
	Net.Message(target.Owner, ("%.1f초간 기절!"):format(duration), Color3.fromRGB(255, 230, 80), duration)
end

-- 히트박스에 걸린 모델 처리 (분신 포함). onHit(target) 은 실제 피해가 들어갔을 때 호출.
function Combat.HitModel(attacker, model: Model, damage: number, onHit: ((any) -> ())?): boolean
	if model:GetAttribute("Decoy") then
		Visuals.Burst(model:GetPivot().Position, Color3.fromRGB(170, 120, 255), 5, 0.4)
		model:Destroy()
		if attacker then
			Status.Add(attacker, "Slowed", 2, 0.5)
			Net.Message(attacker.Owner, "분신이었다!", Color3.fromRGB(170, 120, 255), 2)
		end
		return true
	end
	local target = State.FromModel(model)
	if target and target.Role == "Survivor" then
		local ok = Combat.Damage(attacker, target, damage)
		if ok and onHit then
			onHit(target)
		end
		return ok
	end
	return false
end

function Combat.KillerAttack(data)
	if data.Role ~= "Killer" or not State.IsAlive(data) then
		return
	end
	if Status.Has(data, "Stunned") or Combat.OnCooldown(data, "M1") then
		return
	end
	local def = data.Def
	Combat.SetCooldown(data, "M1", def.AttackCooldown)
	Status.Add(data, "Slowed", 0.6, 0.4)
	Visuals.Slash(data.Root.CFrame, def.Color, def.AttackRange)

	task.delay(0.12, function()
		if not State.IsAlive(data) or Status.Has(data, "Stunned") then
			return
		end
		for _, model in ipairs(Combat.QueryFront(data, def.AttackRange)) do
			Combat.HitModel(data, model, def.AttackDamage)
		end
	end)
end

-- 캐릭터들과 이펙트를 무시하는 벽 감지용 레이캐스트
function Combat.CastWalls(origin: Vector3, direction: Vector3): RaycastResult?
	local ignore: { Instance } = { Visuals.Folder }
	for _, data in pairs(State.All()) do
		table.insert(ignore, data.Model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(origin, direction, params)
end

function Combat.Init()
	Remotes.Attack.OnServerEvent:Connect(function(player)
		local data = State.Get(player)
		if data then
			Combat.KillerAttack(data)
		end
	end)
end

return Combat
