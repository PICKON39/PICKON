-- 로비 캐릭터 선택 패널
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local CharacterSelect = {}

local player = Players.LocalPlayer
local C = UI.Colors

local panel, toggle, list, maliceLabel, detailLabel
local tab = "Survivor"
local userHidden = false
local entries = {}

local function abilityText(def): string
	local lines = { def.Description, "" }
	for _, key in ipairs({ "Q", "E" }) do
		local a = def.Abilities[key]
		if a then
			table.insert(lines, ("[%s] %s (%ds) - %s"):format(key, a.Name, a.Cooldown, a.Description))
		end
	end
	if def.MaxHealth then
		table.insert(lines, ("체력 %d · 스태미나 %d · 달리기 %d"):format(def.MaxHealth, def.MaxStamina, def.SprintSpeed))
	else
		table.insert(lines, ("공격력 %d · 스태미나 %d · 달리기 %d"):format(def.AttackDamage, def.MaxStamina, def.SprintSpeed))
	end
	return table.concat(lines, "\n")
end

local function chosenId(): string?
	return player:GetAttribute(tab == "Killer" and "KillerChoice" or "SurvivorChoice")
end

local function refresh()
	local selected = chosenId()
	for id, button in pairs(entries) do
		local def = Characters.Get(tab, id)
		local isSelected = id == selected
		button.BackgroundColor3 = isSelected and def.Color:Lerp(Color3.new(0, 0, 0), 0.55) or C.PanelLight
		button.Text = (isSelected and "✔ " or "") .. def.DisplayName
	end
	local def = Characters.Get(tab, selected)
	detailLabel.Text = def and abilityText(def) or ""
	local ls = player:FindFirstChild("leaderstats")
	local malice = ls and ls:FindFirstChild("Malice")
	maliceLabel.Text = ("악의(Malice): %d  — 가장 높은 사람이 다음 살인마"):format(malice and malice.Value or 0)
end

local function buildList()
	for _, b in pairs(entries) do
		b:Destroy()
	end
	table.clear(entries)
	local order = tab == "Killer" and Characters.KillerOrder or Characters.SurvivorOrder
	for i, id in ipairs(order) do
		local def = Characters.Get(tab, id)
		local b = UI.button({
			Name = id,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 34),
			TextScaled = false,
			TextSize = 16,
			Parent = list,
		})
		UI.stroke(def.Color, 1.5).Parent = b
		b.Activated:Connect(function()
			Remotes.SelectCharacter:FireServer(tab, id)
		end)
		entries[id] = b
	end
	refresh()
end

local function shouldShow(): boolean
	local role = player:GetAttribute("Role")
	return role == "Lobby" or role == nil
end

function CharacterSelect.Init(gui: ScreenGui)
	panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(320, 470),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { UI.corner(12), UI.stroke(C.Accent, 1.5), UI.padding(12) })

	UI.label({
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBlack,
		Text = "캐릭터 선택",
		Parent = panel,
	})

	local tabs = {}
	for i, info in ipairs({ { "Survivor", "생존자" }, { "Killer", "살인마" } }) do
		local b = UI.button({
			Size = UDim2.new(0.5, -4, 0, 30),
			Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 34),
			Text = info[2],
			Parent = panel,
		})
		tabs[info[1]] = b
		b.Activated:Connect(function()
			tab = info[1]
			for key, tb in pairs(tabs) do
				tb.BackgroundColor3 = key == tab and C.Accent or C.PanelLight
			end
			buildList()
		end)
	end
	tabs.Survivor.BackgroundColor3 = C.Accent

	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	detailLabel = UI.label({
		Position = UDim2.fromOffset(0, 250),
		Size = UDim2.new(1, 0, 0, 150),
		TextScaled = false,
		TextSize = 13,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.SubText,
		Text = "",
		Parent = panel,
	})

	maliceLabel = UI.label({
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 20),
		TextScaled = false,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 120, 120),
		Text = "",
		Parent = panel,
	})

	toggle = UI.button({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, -260),
		Size = UDim2.fromOffset(120, 30),
		Text = "캐릭터 ▲",
		TextScaled = false,
		TextSize = 15,
		Parent = gui,
	})
	toggle.Activated:Connect(function()
		userHidden = not userHidden
	end)

	player:GetAttributeChangedSignal("SurvivorChoice"):Connect(refresh)
	player:GetAttributeChangedSignal("KillerChoice"):Connect(refresh)
	buildList()

	local lastMaliceRefresh = 0
	RunService.Heartbeat:Connect(function()
		local show = shouldShow()
		toggle.Visible = show
		panel.Visible = show and not userHidden
		toggle.Text = userHidden and "캐릭터 ▼" or "캐릭터 ▲"
		if show and os.clock() - lastMaliceRefresh > 1 then
			lastMaliceRefresh = os.clock()
			refresh()
		end
	end)
end

return CharacterSelect
