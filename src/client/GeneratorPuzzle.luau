-- 발전기 수리 미니게임: 흩어진 번호를 1부터 순서대로 누르면 한 단계 완료
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local GeneratorPuzzle = {}

local player = Players.LocalPlayer
local C = UI.Colors

local COUNT = 5
local AREA_W, AREA_H, BTN = 360, 200, 48

local frame, area, title
local currentId: number? = nil
local currentModel: Model? = nil
local nextNumber = 1
local waiting = false

local function newRound(progress: number, total: number)
	area:ClearAllChildren()
	nextNumber = 1
	waiting = false
	title.Text = ("발전기 수리  %d / %d"):format(progress, total)

	local placed = {}
	for i = 1, COUNT do
		local pos
		for _ = 1, 40 do
			pos = Vector2.new(math.random(0, AREA_W - BTN), math.random(0, AREA_H - BTN))
			local ok = true
			for _, p in ipairs(placed) do
				if (p - pos).Magnitude < BTN + 8 then
					ok = false
					break
				end
			end
			if ok then
				break
			end
		end
		table.insert(placed, pos)

		local b = UI.button({
			Size = UDim2.fromOffset(BTN, BTN),
			Position = UDim2.fromOffset(pos.X, pos.Y),
			Text = tostring(i),
			Font = Enum.Font.GothamBlack,
			BackgroundColor3 = Color3.fromRGB(60, 55, 70),
			Parent = area,
		})
		b.Activated:Connect(function()
			if waiting or not currentId then
				return
			end
			if i == nextNumber then
				b.BackgroundColor3 = C.Good
				b.Active = false
				b.AutoButtonColor = false
				nextNumber += 1
				if nextNumber > COUNT then
					waiting = true
					title.Text = "연결 중..."
					Remotes.GeneratorStep:FireServer(currentId)
					-- 서버 응답이 없으면(쿨다운 등) 다시 시도할 수 있도록
					local id = currentId
					task.delay(2, function()
						if waiting and currentId == id then
							newRound(progress, total)
						end
					end)
				end
			else
				b.BackgroundColor3 = C.Accent
				task.delay(0.25, function()
					if currentId then
						newRound(progress, total)
					end
				end)
			end
		end)
	end
end

function GeneratorPuzzle.Open(id: number, model: Model, progress: number, total: number)
	currentId = id
	currentModel = model
	frame.Visible = true
	newRound(progress, total)
end

function GeneratorPuzzle.Progress(id: number, progress: number, total: number)
	if id == currentId then
		newRound(progress, total)
	end
end

function GeneratorPuzzle.Close()
	currentId = nil
	currentModel = nil
	waiting = false
	frame.Visible = false
	area:ClearAllChildren()
end

function GeneratorPuzzle.IsOpen(): boolean
	return currentId ~= nil
end

local function cancel()
	if currentId then
		Remotes.GeneratorCancel:FireServer()
	end
	GeneratorPuzzle.Close()
end

function GeneratorPuzzle.Init(gui: ScreenGui)
	frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(AREA_W + 24, AREA_H + 70),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { UI.corner(12), UI.stroke(Color3.fromRGB(255, 200, 80), 2) })

	title = UI.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -60, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		Text = "",
		Parent = frame,
	})
	UI.label({
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 16),
		TextScaled = false,
		TextSize = 13,
		TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "1부터 순서대로 누르세요",
		Parent = frame,
	})

	local close = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(32, 32),
		Text = "X",
		BackgroundColor3 = C.Accent,
		Parent = frame,
	})
	close.Activated:Connect(cancel)

	area = UI.new("Frame", {
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.fromOffset(AREA_W, AREA_H),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	-- 멀어지거나 죽으면 자동 취소
	RunService.Heartbeat:Connect(function()
		if not currentId then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 or not currentModel or not currentModel.Parent then
			cancel()
			return
		end
		if (root.Position - currentModel:GetPivot().Position).Magnitude > Config.GENERATOR_REPAIR_RANGE then
			cancel()
		end
	end)

	player:GetAttributeChangedSignal("Role"):Connect(function()
		GeneratorPuzzle.Close()
	end)
end

return GeneratorPuzzle
