-- 입력: Shift 달리기, Q/E 능력, 클릭 공격 (+ 모바일 버튼)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UI = require(script.Parent.UI)

local Controls = {}

local player = Players.LocalPlayer
local sprinting = false
local sprintButton: TextButton? = nil

local function inRound(): boolean
	local role = player:GetAttribute("Role")
	return role == "Survivor" or role == "Killer"
end

local function setSprint(on: boolean)
	if sprinting == on then
		return
	end
	sprinting = on
	Remotes.SetSprint:FireServer(on)
	if sprintButton then
		sprintButton.BackgroundColor3 = on and UI.Colors.Stamina or UI.Colors.PanelLight
	end
end

-- HUD 슬롯 클릭/터치에서도 사용
function Controls.Use(key: string)
	if not inRound() then
		return
	end
	if key == "M1" then
		if player:GetAttribute("Role") == "Killer" then
			Remotes.Attack:FireServer()
		end
	else
		Remotes.UseAbility:FireServer(key)
	end
end

function Controls.Init(gui: ScreenGui)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			if not processed then
				setSprint(true)
			end
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonX then
			Controls.Use("Q")
		elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonY then
			Controls.Use("E")
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			Controls.Use("M1")
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			setSprint(false)
		end
	end)

	-- 모바일: 달리기 토글 버튼 (능력은 HUD 슬롯을 터치)
	if UserInputService.TouchEnabled then
		sprintButton = UI.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -112),
			Size = UDim2.fromOffset(86, 40),
			Text = "달리기",
			Parent = gui,
		})
		sprintButton.Activated:Connect(function()
			setSprint(not sprinting)
		end)
	end

	player:GetAttributeChangedSignal("Role"):Connect(function()
		sprinting = false
		if sprintButton then
			sprintButton.BackgroundColor3 = UI.Colors.PanelLight
			sprintButton.Visible = inRound()
		end
		if inRound() and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			setSprint(true)
		end
	end)
	if sprintButton then
		sprintButton.Visible = inRound()
	end
end

return Controls
