-- 서버 진입점
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) -- RemoteEvent 생성

local MapBuilder = require(script.MapBuilder)
local LobbyService = require(script.LobbyService)
local Movement = require(script.Movement)
local Combat = require(script.Combat)
local AbilityService = require(script.AbilityService)
local GeneratorService = require(script.GeneratorService)
local RoundService = require(script.RoundService)

ReplicatedStorage:SetAttribute("GameState", "Waiting")
ReplicatedStorage:SetAttribute("Timer", 0)

local map = MapBuilder.Build()

LobbyService.Init()
Movement.Init()
Combat.Init()
AbilityService.Init()
GeneratorService.Init(map)

RoundService.Run(map)
