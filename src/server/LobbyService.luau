-- 로비 요청 처리: 캐릭터 선택 / 구매, 혼자일 때 역할 선호
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)

local LobbyService = {}

local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(90, 255, 120)

local function validKind(kind): boolean
	return kind == "Survivor" or kind == "Killer"
end

local function choiceAttr(kind: string): string
	return kind == "Killer" and "KillerChoice" or "SurvivorChoice"
end

local function onSelect(player: Player, kind, id)
	if not validKind(kind) or typeof(id) ~= "string" or not Net.RateLimit(player, "SelectCharacter", 0.2) then
		return
	end
	if not Characters.Get(kind, id) then
		return
	end
	if not DataService.Owns(player, kind, id) then
		Net.Message(player, "아직 보유하지 않은 캐릭터입니다.", RED, 2)
		return
	end
	player:SetAttribute(choiceAttr(kind), id)
end

local function onBuy(player: Player, kind, id)
	if not validKind(kind) or typeof(id) ~= "string" or not Net.RateLimit(player, "BuyCharacter", 0.5) then
		return
	end
	local ok, message = DataService.TryBuy(player, kind, id)
	if ok then
		-- 구매한 캐릭터를 바로 선택
		player:SetAttribute(choiceAttr(kind), id)
	end
	Net.Message(player, message or (ok and "구매 완료!" or "구매할 수 없습니다."), ok and GREEN or RED, 3)
end

local function onRolePreference(player: Player, pref)
	if not validKind(pref) or not Net.RateLimit(player, "SetRolePreference", 0.2) then
		return
	end
	player:SetAttribute("RolePreference", pref)
end

local function onPlayerAdded(player: Player)
	if player:GetAttribute("Role") == nil then
		player:SetAttribute("Role", "Lobby")
	end
end

function LobbyService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		State.Remove(player)
	end)

	Remotes.SelectCharacter.OnServerEvent:Connect(onSelect)
	Remotes.BuyCharacter.OnServerEvent:Connect(onBuy)
	Remotes.SetRolePreference.OnServerEvent:Connect(onRolePreference)
end

return LobbyService
