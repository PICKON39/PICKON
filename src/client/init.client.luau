-- 클라이언트 진입점
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UI = require(script.UI)
local HUD = require(script.HUD)
local CharacterSelect = require(script.CharacterSelect)
local GeneratorPuzzle = require(script.GeneratorPuzzle)
local Controls = require(script.Controls)
local Spectate = require(script.Spectate)
local Effects = require(script.Effects)

local player = Players.LocalPlayer

local gui = UI.new("ScreenGui", {
	Name = "GameHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

Effects.Init(gui)
HUD.Init(gui, Controls.Use)
CharacterSelect.Init(gui)
GeneratorPuzzle.Init(gui)
Controls.Init(gui)
Spectate.Init(gui)

-- 살인마에게는 발전기 프롬프트를 숨긴다
local function updatePrompts()
	ProximityPromptService.Enabled = player:GetAttribute("Role") ~= "Killer"
end
player:GetAttributeChangedSignal("Role"):Connect(updatePrompts)
updatePrompts()

Remotes.Notify.OnClientEvent:Connect(function(kind: string, a, b, c, d)
	if kind == "Message" then
		HUD.Announce(a, b, c)
	elseif kind == "Reveal" then
		Effects.Reveal(a, b)
	elseif kind == "OpenGenerator" then
		GeneratorPuzzle.Open(a, b, c, d)
	elseif kind == "GeneratorProgress" then
		GeneratorPuzzle.Progress(a, b, c)
	elseif kind == "CloseGenerator" then
		GeneratorPuzzle.Close()
	elseif kind == "Hit" then
		Effects.HitFlash()
	elseif kind == "HitConfirm" then
		Effects.HitConfirm()
	elseif kind == "LMS" then
		Effects.LastManStanding()
	end
end)
