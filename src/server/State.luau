-- 라운드에 참가 중인 엔티티(플레이어 또는 봇)의 상태 저장소
-- owner 는 Player 인스턴스이거나, 봇의 경우 { IsBot = true, Name, DisplayName, UserId = 0 } 테이블입니다.
local State = {}

-- 라운드가 바뀔 때마다 증가 (지연 실행된 효과가 이전 라운드의 것인지 판별용)
State.RoundId = 0

local entries = {}

local function displayName(owner): string
	if typeof(owner) == "Instance" and owner:IsA("Player") then
		return owner.DisplayName
	end
	if type(owner) == "table" then
		return owner.DisplayName or owner.Name or "?"
	end
	return "?"
end

function State.Create(owner, role: string, def, model: Model)
	local data = {
		Owner = owner,
		IsBot = typeof(owner) ~= "Instance",
		Role = role,
		Def = def,
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid"),
		Root = model:FindFirstChild("HumanoidRootPart"),
		Name = displayName(owner),
		RoundId = State.RoundId,
		Alive = true,
		Stamina = def.MaxStamina,
		MaxStamina = def.MaxStamina,
		Sprinting = false,
		Exhausted = false,
		Cooldowns = {},
		Statuses = {},
		Charges = 0,
		RepairingGen = nil,
		Stats = { Damage = 0, Hits = 0, Stuns = 0, Heals = 0, Generators = 0, Kills = 0 },
		Hooks = nil,
		Vars = {},
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

function State.Clear()
	table.clear(entries)
end

-- 새 라운드: RoundId 를 올리고 모든 엔트리 제거
function State.NewRound()
	State.RoundId += 1
	State.Clear()
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

-- 살인마 엔트리 (살아 있든 아니든)
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

-- 캐릭터 서버 모듈의 훅 호출. 오류는 경고만 하고 nil 반환
function State.CallHook(data, hookName: string, ...): ...any
	local hooks = data and data.Hooks
	local fn = hooks and hooks[hookName]
	if type(fn) ~= "function" then
		return nil
	end
	local result = table.pack(pcall(fn, data, ...))
	if not result[1] then
		warn(("훅 오류 [%s.%s]: %s"):format(tostring(data.Def and data.Def.Id), hookName, tostring(result[2])))
		return nil
	end
	return table.unpack(result, 2, result.n)
end

-- 살아 있는 모든 엔트리에 훅 호출
function State.Broadcast(hookName: string, ...)
	local list = {}
	for _, data in pairs(entries) do
		if State.IsAlive(data) then
			table.insert(list, data)
		end
	end
	for _, data in ipairs(list) do
		State.CallHook(data, hookName, ...)
	end
end

return State
