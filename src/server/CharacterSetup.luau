-- 라운드 시작 시 캐릭터 모델에 역할별 외형/스탯 적용
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CharacterSetup = {}

local KILLER_HEALTH = 100000

local function weld(part0: BasePart, part1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

local function decorPart(model: Model, size: Vector3, cframe: CFrame, color: Color3, attachTo: BasePart): Part
	local p = Instance.new("Part")
	p.Name = "KillerDecor"
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.Neon
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = model
	weld(attachTo, p)
	return p
end

local function applyKillerLook(model: Model, def)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = def.BodyColor
			d.Material = Enum.Material.SmoothPlastic
		end
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local face = head:FindFirstChild("face")
		if face then
			face:Destroy()
		end
		for _, x in ipairs({ -0.22, 0.22 }) do
			decorPart(model, Vector3.new(0.2, 0.12, 0.05), head.CFrame * CFrame.new(x, 0.12, -head.Size.Z / 2), def.Color, head)
		end
	end

	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		local blade = decorPart(
			model,
			Vector3.new(0.25, 0.6, 4),
			hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -1.8),
			def.Color,
			hand
		)
		blade.Name = "Weapon"
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "KillerHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = def.Color
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

function CharacterSetup.Apply(model: Model, role: string, def)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	-- Forsaken 처럼 점프 불가
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.WalkSpeed = def.WalkSpeed
	-- 죽으면 관절을 끊지 않고 Ragdoll 로 처리
	hum.BreakJointsOnDeath = false

	model:SetAttribute("Role", role)
	model:SetAttribute("CharacterId", def.Id)
	CollectionService:AddTag(model, role == "Killer" and "Killer" or "Survivor")

	if role == "Killer" then
		hum.MaxHealth = KILLER_HEALTH
		hum.Health = KILLER_HEALTH
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		model:SetAttribute("TerrorRadius", def.TerrorRadius or Config.TERROR_RADIUS)
		applyKillerLook(model, def)
	else
		hum.MaxHealth = def.MaxHealth
		hum.Health = def.MaxHealth
	end
end

return CharacterSetup
