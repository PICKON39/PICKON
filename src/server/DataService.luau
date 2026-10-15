-- 플레이어 데이터: 돈, 악의(Malice), 승리 수, 캐릭터 보유 목록
-- 지금은 세션 동안만 유지됩니다 (DataStore 저장은 DATA 트랙에서 추가).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Util = require(Shared.Util)

local DataService = {}

local STAT_NAMES = { "Money", "Malice", "Wins" }

local profiles = {} -- [Player] = { Money, Malice, Wins, Owned = { ["S:Id"] = true } }

local function isPlayer(owner): boolean
	return typeof(owner) == "Instance" and owner:IsA("Player") and owner.Parent ~= nil
end

local function ownKey(role: string, id: string): string
	return (role == "Killer" and "K:" or "S:") .. id
end

local function setStat(player: Player, name: string, value: number)
	local ls = player:FindFirstChild("leaderstats")
	local stat = ls and ls:FindFirstChild(name)
	if stat and stat:IsA("IntValue") then
		stat.Value = value
	end
end

-- 프로필 값을 leaderstats / 플레이어 속성에 반영
local function sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, name in ipairs(STAT_NAMES) do
		setStat(player, name, profile[name])
	end
	player:SetAttribute("Money", profile.Money)
	local owned = {}
	for key in pairs(profile.Owned) do
		table.insert(owned, key)
	end
	table.sort(owned)
	player:SetAttribute("Owned", Util.JoinCsv(owned))
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	profiles[player] = {
		Money = Config.START_MONEY,
		Malice = 0,
		Wins = 0,
		Owned = {},
	}

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs(STAT_NAMES) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	player:SetAttribute("RolePreference", "Survivor")
	player:SetAttribute("SurvivorChoice", Config.DEFAULT_SURVIVOR)
	player:SetAttribute("KillerChoice", Config.DEFAULT_KILLER)
	sync(player)
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
end

-- 프로필 테이블 (없으면 nil)
function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.GetMoney(player: Player): number
	local profile = profiles[player]
	return profile and profile.Money or 0
end

function DataService.AddMoney(player: Player, n: number)
	local profile = profiles[player]
	if profile and n ~= 0 then
		profile.Money = math.max(0, math.floor(profile.Money + n))
		sync(player)
	end
end

function DataService.GetMalice(player: Player): number
	local profile = profiles[player]
	return profile and profile.Malice or 0
end

function DataService.SetMalice(player: Player, n: number)
	local profile = profiles[player]
	if profile then
		profile.Malice = math.max(0, math.floor(n))
		sync(player)
	end
end

function DataService.AddMalice(player: Player, n: number)
	DataService.SetMalice(player, DataService.GetMalice(player) + n)
end

function DataService.AddWin(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Wins += 1
		sync(player)
	end
end

-- 캐릭터 보유 여부: 무료 캐릭터, 스튜디오 전체 해금, 또는 구매한 캐릭터
function DataService.Owns(player: Player, role: string, id: string): boolean
	local def = Characters.Get(role, id)
	if not def then
		return false
	end
	if Characters.IsFree(def) then
		return true
	end
	if Config.UNLOCK_ALL_IN_STUDIO and RunService:IsStudio() then
		return true
	end
	local profile = profiles[player]
	return profile ~= nil and profile.Owned[ownKey(role, def.Id)] == true
end

-- 캐릭터 구매 → (성공 여부, 안내 문구)
function DataService.TryBuy(player: Player, role: string, id: string): (boolean, string?)
	local profile = profiles[player]
	local def = Characters.Get(role, id)
	if not profile or not def then
		return false, "존재하지 않는 캐릭터입니다."
	end
	if DataService.Owns(player, role, id) then
		return false, "이미 보유한 캐릭터입니다."
	end
	local price = def.Price or 0
	if profile.Money < price then
		return false, ("돈이 부족합니다. (%d / %d)"):format(profile.Money, price)
	end
	profile.Money -= price
	profile.Owned[ownKey(role, def.Id)] = true
	sync(player)
	return true, ("%s 구매 완료! (-%d)"):format(def.DisplayName or def.Id, price)
end

local function stat(stats, name: string): number
	return stats and tonumber(stats[name]) or 0
end

-- 결과 한 줄 → 보상 금액
local function rewardFor(row, winner: string): number
	local R = Config.Rewards or {}
	local s = row.Stats
	local money = R.Participation or 0
	if row.Role == "Killer" then
		money += (R.Kill or 0) * stat(s, "Kills")
		money += (R.DamagePer10 or 0) * math.floor(stat(s, "Damage") / 10)
		if winner == "Killer" then
			money += R.KillerWin or 0
		end
	else
		if row.Survived then
			money += R.Survive or 0
		end
		if winner == "Survivors" then
			money += R.SurvivorWin or 0
		end
		money += (R.GeneratorStep or 0) * stat(s, "Generators")
		money += (R.Stun or 0) * stat(s, "Stuns")
		money += (R.HealPer10 or 0) * math.floor(stat(s, "Heals") / 10)
	end
	return math.max(0, math.floor(money))
end

-- 라운드 결과 반영: 돈 / 승리 수 / 악의. 반환값 = { [Player] = 이번 라운드에 번 돈 }
function DataService.ApplyRoundResults(summary): { [Player]: number }
	local earned = {}
	for _, row in ipairs(summary.Rows or {}) do
		local owner = row.Owner
		if not row.IsBot and isPlayer(owner) and profiles[owner] then
			local money = rewardFor(row, summary.Winner)
			earned[owner] = money
			DataService.AddMoney(owner, money)
			if summary.Winner == "Killer" and row.Role == "Killer" then
				DataService.AddWin(owner)
			elseif summary.Winner == "Survivors" and row.Role == "Survivor" and row.Survived then
				DataService.AddWin(owner)
			end
		end
	end

	-- 악의: 이번 살인마는 0, 나머지 모두 증가
	for _, player in ipairs(Players:GetPlayers()) do
		if player == summary.KillerOwner then
			DataService.SetMalice(player, 0)
		else
			DataService.AddMalice(player, math.random(Config.MALICE_MIN, Config.MALICE_MAX))
		end
	end
	return earned
end

return DataService
