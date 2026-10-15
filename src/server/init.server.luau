-- 서버 진입점
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) -- RemoteEvent 생성 (가장 먼저)

local DataService = require(script.DataService)
local MapService = require(script.MapService)
local LobbyService = require(script.LobbyService)
local Movement = require(script.Movement)
local Combat = require(script.Combat)
local AbilityService = require(script.Abilities)
local GeneratorService = require(script.GeneratorService)
local ItemService = require(script.ItemService)
local RoundService = require(script.RoundService)

ReplicatedStorage:SetAttribute("GameState", "Waiting")
ReplicatedStorage:SetAttribute("Timer", 0)

DataService.Init()
MapService.Init()
LobbyService.Init()
Movement.Init()
Combat.Init()
AbilityService.Init()
GeneratorService.Init()
ItemService.Init()

RoundService.Run()
