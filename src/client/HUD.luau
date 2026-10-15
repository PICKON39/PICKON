-- 상단 타이머, 체력/스태미나, 능력 슬롯, 알림 메시지
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local UI = require(script.Parent.UI)

local HUD = {}

local player = Players.LocalPlayer
local C = UI.Colors

local stateLabel, subLabel
local statusFrame, nameLabel, setHealth, setStamina, effectLabel
local slotFrame
local slots = {}
local announce
local announceToken = 0
local onSlotPressed: (string) -> () = function() end

local STATUS_TEXT = {
	{ "Stunned", "기절", Color3.fromRGB(255, 230, 80) },
	{ "Rooted", "고정", Color3.fromRGB(200, 200, 200) },
	{ "Slowed", "둔화", Color3.fromRGB(120, 170, 255) },
	{ "Hasted", "가속", Color3.fromRGB(120, 255, 150) },
	{ "Invisible", "투명", Color3.fromRGB(190, 150, 255) },
	{ "Blocking", "방어", Color3.fromRGB(120, 200, 255) },
}

local function formatTime(t: number): string
	t = math.max(0, math.floor(t))
	return ("%d:%02d"):format(t // 60, t % 60)
end

local function currentDef()
	local role = player:GetAttribute("Role")
	if role ~= "Survivor" and role ~= "Killer" then
		return nil, role
	end
	return Characters.Get(role, player:GetAttribute("CharacterId")), role
end

local function makeSlot(key: string, keyText: string, name: string, color: Color3)
	local button = UI.button({
		Name = key,
		Size = UDim2.fromOffset(86, 86),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Text = "",
		AutoButtonColor = true,
		Parent = slotFrame,
	})
	UI.stroke(color, 2).Parent = button
	UI.label({
		Size = UDim2.new(0, 30, 0, 22),
		Position = UDim2.fromOffset(6, 4),
		Text = keyText,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})
	local nameText = UI.label({
		Size = UDim2.new(1, -8, 0, 34),
		Position = UDim2.new(0, 4, 1, -38),
		Text = name,
		TextWrapped = true,
		Parent = button,
	})
	local overlay = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { UI.corner(8) })
	local cdText = UI.label({
		Size = UDim2.fromScale(1, 0.6),
		Position = UDim2.fromScale(0, 0.2),
		ZIndex = 4,
		Text = "",
		Parent = overlay,
	})
	button.Activated:Connect(function()
		onSlotPressed(key)
	end)
	slots[key] = { Button = button, Overlay = overlay, CdText = cdText, NameText = nameText, BaseName = name }
end

local function rebuildSlots()
	for _, s in pairs(slots) do
		s.Button:Destroy()
	end
	table.clear(slots)
	local def, role = currentDef()
	if not def then
		slotFrame.Visible = false
		return
	end
	slotFrame.Visible = true
	if role == "Killer" then
		makeSlot("M1", "클릭", "공격", def.Color)
	end
	for _, key in ipairs({ "Q", "E" }) do
		local ability = def.Abilities[key]
		if ability then
			makeSlot(key, key, ability.Name, def.Color)
			slots[key].ShowCharges = ability.ShowCharges
		end
	end
end

function HUD.Announce(text: string, color: Color3?, duration: number?)
	announceToken += 1
	local token = announceToken
	announce.Text = text
	announce.TextColor3 = color or C.Text
	announce.TextTransparency = 0
	announce.TextStrokeTransparency = 0.3
	task.delay(duration or 3, function()
		if token == announceToken then
			TweenService:Create(announce, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function update()
	-- 상단
	local state = ReplicatedStorage:GetAttribute("GameState")
	local t = ReplicatedStorage:GetAttribute("Timer") or 0
	if state == "Intermission" then
		stateLabel.Text = ("다음 라운드까지 %d초"):format(t)
		subLabel.Text = "로비에서 캐릭터를 선택하세요"
	elseif state == "Starting" then
		stateLabel.Text = "라운드 시작!"
		subLabel.Text = ""
	elseif state == "InRound" then
		stateLabel.Text = formatTime(t)
		subLabel.Text = ("생존자 %d명 · 발전기 %d/%d 남음 · 살인마: %s"):format(
			ReplicatedStorage:GetAttribute("SurvivorsAlive") or 0,
			ReplicatedStorage:GetAttribute("GeneratorsLeft") or 0,
			ReplicatedStorage:GetAttribute("GeneratorsTotal") or 0,
			ReplicatedStorage:GetAttribute("KillerName") or "?"
		)
	elseif state == "RoundEnd" then
		stateLabel.Text = "라운드 종료"
		subLabel.Text = ("%d초 후 로비로 이동"):format(t)
	else
		stateLabel.Text = "플레이어를 기다리는 중..."
		subLabel.Text = ""
	end

	-- 상태 패널
	local def, role = currentDef()
	statusFrame.Visible = def ~= nil
	if not def then
		return
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	nameLabel.Text = (role == "Killer" and "살인마 · " or "생존자 · ") .. def.DisplayName
	nameLabel.TextColor3 = def.Color
	if role == "Killer" then
		setHealth(1, "∞")
	elseif hum then
		setHealth(hum.Health / hum.MaxHealth, ("%d / %d"):format(math.ceil(hum.Health), hum.MaxHealth))
	end
	local stamina = player:GetAttribute("Stamina") or 0
	local maxStamina = player:GetAttribute("MaxStamina") or 100
	setStamina(stamina / maxStamina, ("스태미나 %d"):format(stamina))

	local effects = {}
	if character then
		for _, info in ipairs(STATUS_TEXT) do
			if character:GetAttribute(info[1]) then
				table.insert(effects, info[2])
			end
		end
	end
	effectLabel.Text = table.concat(effects, " · ")

	-- 쿨다운
	local nowT = workspace:GetServerTimeNow()
	for key, s in pairs(slots) do
		local remaining = (player:GetAttribute("CD_" .. key) or 0) - nowT
		if remaining > 0 then
			s.Overlay.Visible = true
			s.CdText.Text = remaining >= 10 and ("%d"):format(math.ceil(remaining)) or ("%.1f"):format(remaining)
		else
			s.Overlay.Visible = false
		end
		if s.ShowCharges then
			s.NameText.Text = ("%s (%d/3)"):format(s.BaseName, player:GetAttribute("Charges") or 0)
		end
	end
end

function HUD.Init(gui: ScreenGui, slotCallback: (string) -> ())
	onSlotPressed = slotCallback

	-- 상단 타이머
	local top = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(440, 66),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, { UI.corner(10), UI.stroke(C.Accent, 1.5) })
	stateLabel = UI.label({
		Size = UDim2.new(1, -16, 0.6, 0),
		Position = UDim2.fromOffset(8, 4),
		Font = Enum.Font.GothamBlack,
		Text = "",
		Parent = top,
	})
	subLabel = UI.label({
		Size = UDim2.new(1, -16, 0.3, 0),
		Position = UDim2.new(0, 8, 0.62, 0),
		TextColor3 = C.SubText,
		Font = Enum.Font.Gotham,
		Text = "",
		Parent = top,
	})

	-- 좌하단 상태
	statusFrame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(300, 112),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, { UI.corner(10), UI.padding(10) })
	nameLabel = UI.label({
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		Parent = statusFrame,
	})
	local _, sh = UI.bar(statusFrame, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 20), C.Health)
	local _, ss = UI.bar(statusFrame, UDim2.fromOffset(0, 56), UDim2.new(1, 0, 0, 16), C.Stamina)
	setHealth, setStamina = sh, ss
	effectLabel = UI.label({
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 76),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 230, 120),
		Text = "",
		Parent = statusFrame,
	})

	-- 우하단 능력 슬롯
	slotFrame = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(290, 86),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- 중앙 알림
	announce = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.new(0.8, 0, 0, 44),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 1,
		TextTransparency = 1,
		Text = "",
		ZIndex = 20,
		Parent = gui,
	})

	player:GetAttributeChangedSignal("Role"):Connect(rebuildSlots)
	player:GetAttributeChangedSignal("CharacterId"):Connect(rebuildSlots)
	rebuildSlots()

	RunService.RenderStepped:Connect(update)
end

return HUD
