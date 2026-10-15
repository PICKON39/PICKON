-- 접속 처리, 리더보드(Malice / Wins), 캐릭터 선택
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)

local LobbyService = {}

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local malice = Instance.new("IntValue")
	malice.Name = "Malice"
	malice.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	stats.Parent = player

	player:SetAttribute("Role", "Lobby")
	player:SetAttribute("SurvivorChoice", Config.DEFAULT_SURVIVOR)
	player:SetAttribute("KillerChoice", Config.DEFAULT_KILLER)
end

function LobbyService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		State.Remove(player)
	end)

	Remotes.SelectCharacter.OnServerEvent:Connect(function(player, kind, id)
		if kind ~= "Survivor" and kind ~= "Killer" then
			return
		end
		if not Characters.Get(kind, id) then
			return
		end
		player:SetAttribute(kind == "Killer" and "KillerChoice" or "SurvivorChoice", id)
	end)
end

return LobbyService
