-- 사망 후 라운드 관전
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local Spectate = {}

local player = Players.LocalPlayer
local bar, nameLabel
local index = 1
local target: Player? = nil

local function candidates(): { Player }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local role = p:GetAttribute("Role")
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if p ~= player and (role == "Survivor" or role == "Killer") and hum and hum.Health > 0 then
			table.insert(list, p)
		end
	end
	return list
end

local function active(): boolean
	return player:GetAttribute("Role") == "Spectator" and ReplicatedStorage:GetAttribute("GameState") == "InRound"
end

local function cycle(delta: number)
	local list = candidates()
	if #list == 0 then
		target = nil
		return
	end
	index = (index - 1 + delta) % #list + 1
	target = list[index]
end

local function resetCamera()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		workspace.CurrentCamera.CameraSubject = hum
	end
end

function Spectate.Init(gui: ScreenGui)
	bar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(360, 48),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, { UI.corner(10) })
	local prev = UI.button({ Size = UDim2.fromOffset(48, 40), Position = UDim2.fromOffset(4, 4), Text = "◀", Parent = bar })
	local nextB = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(48, 40),
		Position = UDim2.new(1, -4, 0, 4),
		Text = "▶",
		Parent = bar,
	})
	nameLabel = UI.label({
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.new(1, -120, 1, -16),
		Text = "",
		Parent = bar,
	})
	prev.Activated:Connect(function()
		cycle(-1)
	end)
	nextB.Activated:Connect(function()
		cycle(1)
	end)

	local wasActive = false
	RunService.Heartbeat:Connect(function()
		local isActive = active()
		bar.Visible = isActive
		if not isActive then
			if wasActive then
				target = nil
				resetCamera()
			end
			wasActive = false
			return
		end
		wasActive = true

		local hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		local role = target and target:GetAttribute("Role")
		if not hum or hum.Health <= 0 or (role ~= "Survivor" and role ~= "Killer") then
			cycle(0)
			hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		end
		if target and hum then
			local label = target:GetAttribute("Role") == "Killer" and "살인마" or "생존자"
			nameLabel.Text = ("관전 중: %s (%s)"):format(target.DisplayName, label)
			if workspace.CurrentCamera.CameraSubject ~= hum then
				workspace.CurrentCamera.CameraSubject = hum
			end
		else
			nameLabel.Text = "관전할 대상이 없습니다"
		end
	end)
end

return Spectate
