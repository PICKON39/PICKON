-- 라운드에 참가 중인 엔티티(플레이어 또는 봇)의 상태 저장소
-- owner 는 Player 인스턴스이거나, 봇의 경우 { IsBot = true, Name = ... } 테이블입니다.
local State = {}

local entries = {}

function State.Create(owner, role: string, def, model: Model)
	local data = {
		Owner = owner,
		IsBot = typeof(owner) ~= "Instance",
		Role = role,
		Def = def,
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid"),
		Root = model:FindFirstChild("HumanoidRootPart"),
		Alive = true,
		Stamina = def.MaxStamina,
		MaxStamina = def.MaxStamina,
		Sprinting = false,
		Exhausted = false,
		Cooldowns = {},
		Statuses = {},
		Charges = 0,
		RepairingGen = nil,
		LastGenStep = nil,
	}
	entries[owner] = data
	return data
end

function State.Get(owner)
	return entries[owner]
end

function State.Remove(owner)
	entries[owner] = nil
end

function State.All()
	return entries
end

function State.IsAlive(data): boolean
	return data ~= nil
		and data.Alive
		and data.Humanoid ~= nil
		and data.Humanoid.Health > 0
		and data.Root ~= nil
		and data.Model.Parent ~= nil
end

function State.FromModel(model: Instance)
	for _, data in pairs(entries) do
		if data.Model == model then
			return data
		end
	end
	return nil
end

function State.GetKiller()
	for _, data in pairs(entries) do
		if data.Role == "Killer" then
			return data
		end
	end
	return nil
end

function State.AliveList(role: string)
	local list = {}
	for _, data in pairs(entries) do
		if data.Role == role and State.IsAlive(data) then
			table.insert(list, data)
		end
	end
	return list
end

function State.CountAlive(role: string): number
	return #State.AliveList(role)
end

return State
