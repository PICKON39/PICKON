-- 맵 관리: 로비 생성, 맵 투표, 경기장 불러오기 / 정리, 조명
-- 맵 모듈은 Maps 폴더의 ModuleScript (Kit / Lobby 제외) 이며, shared/Maps 에도 등록되어야 투표 후보가 됩니다.
-- 맵 모듈 형식: { Id, DisplayName, Lighting = {...}, Build = function(parent, rng) -> MapInfo }
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SharedMaps = require(Shared.Maps)
local Util = require(Shared.Util)
local Net = require(script.Parent.Net)
local Lobby = require(script.Parent.Maps.Lobby)

local MapService = {}

local VOTE_OPTION_COUNT = 3
local SKIP_MODULES = { Kit = true, Lobby = true }
local EFFECT_CLASSES = { "Atmosphere", "ColorCorrectionEffect", "Sky" }

local modules = {} -- [id] = 맵 모듈
local mapFolder: Folder? = nil
local arena: Instance? = nil
local current = nil -- 현재 MapInfo
local voting = false
local options: { string } = {}

local function loadModules()
	for _, child in ipairs(script.Parent.Maps:GetChildren()) do
		if child:IsA("ModuleScript") and not SKIP_MODULES[child.Name] then
			local ok, mod = pcall(require, child)
			if not ok then
				warn("맵 모듈 로드 실패:", child.Name, mod)
			elseif type(mod) ~= "table" or type(mod.Build) ~= "function" then
				warn("맵 모듈 형식이 잘못됨:", child.Name)
			else
				modules[mod.Id or child.Name] = mod
			end
		end
	end
end

-- 조명 적용. settings 의 일반 키는 Lighting 속성에 그대로 대입하고,
-- Atmosphere / ColorCorrection / Sky 는 해당 효과 인스턴스의 속성 테이블입니다.
function MapService.ApplyLighting(settings)
	if type(settings) ~= "table" then
		return
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		for _, className in ipairs(EFFECT_CLASSES) do
			if child:IsA(className) then
				child:Destroy()
				break
			end
		end
	end
	local function create(className: string, props)
		if type(props) ~= "table" then
			return
		end
		local inst = Instance.new(className)
		for k, v in pairs(props) do
			local ok, err = pcall(function()
				(inst :: any)[k] = v
			end)
			if not ok then
				warn("조명 효과 속성 설정 실패:", className, k, err)
			end
		end
		inst.Parent = Lighting
	end
	for k, v in pairs(settings) do
		if k ~= "Atmosphere" and k ~= "ColorCorrection" and k ~= "Sky" then
			local ok, err = pcall(function()
				(Lighting :: any)[k] = v
			end)
			if not ok then
				warn("조명 속성 설정 실패:", k, err)
			end
		end
	end
	create("Atmosphere", settings.Atmosphere)
	create("ColorCorrectionEffect", settings.ColorCorrection)
	create("Sky", settings.Sky)
end

-- 투표 가능한 맵 id 목록 (shared/Maps 의 Order 순)
function MapService.List(): { string }
	local ids = {}
	for id in pairs(modules) do
		if SharedMaps[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local oa, ob = SharedMaps[a].Order or math.huge, SharedMaps[b].Order or math.huge
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	return ids
end

function MapService.Current()
	return current
end

local function isOption(id): boolean
	return table.find(options, id) ~= nil
end

local function recount()
	local counts = {}
	for _, id in ipairs(options) do
		counts[id] = 0
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local vote = player:GetAttribute("MapVote")
		if counts[vote] then
			counts[vote] += 1
		end
	end
	for id, n in pairs(counts) do
		ReplicatedStorage:SetAttribute("VoteCount_" .. id, n)
	end
	return counts
end

local function clearVoteAttributes()
	for _, id in ipairs(options) do
		ReplicatedStorage:SetAttribute("VoteCount_" .. id, nil)
	end
	ReplicatedStorage:SetAttribute("VoteOptions", nil)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("MapVote", nil)
	end
end

local function onVote(player: Player, mapId)
	if not voting or typeof(mapId) ~= "string" or not isOption(mapId) then
		return
	end
	if not Net.RateLimit(player, "VoteMap", 0.3) then
		return
	end
	if player:GetAttribute("MapVote") == mapId then
		return
	end
	player:SetAttribute("MapVote", mapId)
	recount()
end

function MapService.StartVote()
	if voting then
		clearVoteAttributes()
	end
	options = Util.Shuffle(MapService.List())
	for i = #options, VOTE_OPTION_COUNT + 1, -1 do
		table.remove(options, i)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("MapVote", nil)
	end
	ReplicatedStorage:SetAttribute("VoteOptions", Util.JoinCsv(options))
	recount()
	voting = true
end

-- 투표 종료 → 최다 득표 맵 id (동점이면 무작위, 표가 없으면 후보 중 무작위)
function MapService.EndVote(): string?
	local counts = recount()
	voting = false
	local best, bestCount = {}, 0
	for _, id in ipairs(options) do
		local n = counts[id] or 0
		if n > bestCount then
			best, bestCount = { id }, n
		elseif n == bestCount then
			table.insert(best, id)
		end
	end
	clearVoteAttributes()
	options = {}
	if #best > 0 then
		return best[math.random(1, #best)]
	end
	return MapService.List()[1]
end

-- 경기장 생성 → MapInfo
function MapService.Load(mapId: string?)
	local mod = mapId and modules[mapId]
	if not mod then
		local fallback = MapService.List()[1]
		mod = fallback and modules[fallback]
		if not mod then
			error("불러올 수 있는 맵이 없습니다")
		end
		warn("알 수 없는 맵, 기본 맵으로 대체:", mapId, fallback)
	end
	MapService.Unload()

	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = mapFolder
	arena = folder

	local info = mod.Build(folder, Random.new())
	local meta = SharedMaps[mod.Id] or {}
	info.Id = info.Id or mod.Id
	info.DisplayName = info.DisplayName or mod.DisplayName or meta.DisplayName or info.Id
	current = info

	MapService.ApplyLighting(mod.Lighting)
	ReplicatedStorage:SetAttribute("MapId", info.Id)
	ReplicatedStorage:SetAttribute("MapName", info.DisplayName)
	return info
end

-- 경기장 제거 + 로비 조명 복구
function MapService.Unload()
	if arena then
		arena:Destroy()
		arena = nil
	end
	if current then
		current = nil
		MapService.ApplyLighting(Lobby.Lighting)
	end
	ReplicatedStorage:SetAttribute("MapId", nil)
	ReplicatedStorage:SetAttribute("MapName", nil)
end

function MapService.Init()
	-- 기본 템플릿의 Baseplate / SpawnLocation 제거 (로비 스폰만 남도록)
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") or child.Name == "Baseplate" then
			child:Destroy()
		end
	end
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace
	mapFolder = folder

	Lobby.Build(folder)
	MapService.ApplyLighting(Lobby.Lighting)
	loadModules()
	if #MapService.List() == 0 then
		warn("투표 가능한 맵이 없습니다. shared/Maps 와 server/Maps 를 확인하세요.")
	end

	Remotes.VoteMap.OnServerEvent:Connect(onVote)
	Players.PlayerRemoving:Connect(function()
		if voting then
			task.defer(recount)
		end
	end)
end

return MapService
