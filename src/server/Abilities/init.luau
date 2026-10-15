-- AbilityService: 캐릭터 능력(Q / E / R) 처리 + 캐릭터 서버 모듈(훅) 관리
-- 캐릭터 모듈은 Survivors / Killers 폴더 안에 Id 이름으로 둡니다. (반환: { Abilities = { [abilityId] = fn }, 훅... })
-- 능력 핸들러가 false 를 반환하면 쿨다운이 적용되지 않습니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Server = script.Parent
local State = require(Server.State)
local Status = require(Server.Status)
local Combat = require(Server.Combat)
local Net = require(Server.Net)

local AbilityService = {}

local KEYS = { Q = true, E = true, R = true }
local USE_RATE = 0.15 -- 같은 키 연타 최소 간격(초)

local modules: { Survivor: { [string]: any }, Killer: { [string]: any } }? = nil

local function loadFolder(folder: Instance?, into: { [string]: any })
	if not folder then
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, mod = pcall(require, child)
			if ok and type(mod) == "table" then
				into[child.Name] = mod
			else
				warn("캐릭터 서버 모듈 로드 실패:", child.Name, mod)
			end
		end
	end
end

-- 캐릭터 모듈은 처음 필요할 때 한 번만 로드
local function getModules()
	if not modules then
		local loaded = { Survivor = {}, Killer = {} }
		loadFolder(script:FindFirstChild("Survivors"), loaded.Survivor)
		loadFolder(script:FindFirstChild("Killers"), loaded.Killer)
		modules = loaded
		return loaded
	end
	return modules
end

function AbilityService.GetModule(role: string, id: any)
	if typeof(id) ~= "string" then
		return nil
	end
	local m = getModules()
	return (if role == "Killer" then m.Killer else m.Survivor)[id]
end

-- 라운드 시작 시 엔트리에 캐릭터 모듈 연결 + 시작 쿨다운 + OnSpawn
function AbilityService.Attach(data)
	data.Hooks = AbilityService.GetModule(data.Role, data.Def.Id) or {}
	for key, ability in pairs(data.Def.Abilities or {}) do
		if type(ability.StartCooldown) == "number" and ability.StartCooldown > 0 then
			Combat.SetCooldown(data, key, ability.StartCooldown)
		end
	end
	State.CallHook(data, "OnSpawn")
end

function AbilityService.Use(data, key: string): boolean
	if not data or not KEYS[key] then
		return false
	end
	local ability = data.Def.Abilities and data.Def.Abilities[key]
	if not ability then
		return false
	end
	if not State.IsAlive(data) or Status.Has(data, "Stunned") or Status.Has(data, "Silenced") then
		return false
	end
	if Combat.OnCooldown(data, key) then
		return false
	end
	local hooks = data.Hooks or AbilityService.GetModule(data.Role, data.Def.Id)
	local handler = hooks and hooks.Abilities and hooks.Abilities[ability.Id]
	if type(handler) ~= "function" then
		warn("능력 핸들러 없음:", data.Def.Id, ability.Id)
		return false
	end
	if State.CallHook(data, "CanUse", key, ability) == false then
		return false
	end
	local ok, result = pcall(handler, data, ability)
	if not ok then
		warn("능력 오류", ability.Id, result)
		return false
	end
	if result == false then
		return false
	end
	Combat.SetCooldown(data, key, ability.Cooldown)
	return true
end

-- 라운드 종료 시 모든 엔트리의 OnCleanup
function AbilityService.CleanupAll()
	for _, data in pairs(State.All()) do
		State.CallHook(data, "OnCleanup")
	end
end

function AbilityService.Init()
	getModules()

	Remotes.UseAbility.OnServerEvent:Connect(function(player, key)
		if typeof(key) ~= "string" or not KEYS[key] then
			return
		end
		if not Net.RateLimit(player, "UseAbility" .. key, USE_RATE) then
			return
		end
		local data = State.Get(player)
		if data then
			AbilityService.Use(data, key)
		end
	end)

	-- 살아 있는 엔트리의 OnTick (CallHook 이 pcall 로 보호)
	RunService.Heartbeat:Connect(function(dt)
		for _, data in pairs(State.All()) do
			local hooks = data.Hooks
			if hooks and type(hooks.OnTick) == "function" and State.IsAlive(data) then
				State.CallHook(data, "OnTick", dt)
			end
		end
	end)
end

return AbilityService
