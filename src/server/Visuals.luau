-- 서버측 시각 효과 (모든 플레이어에게 보임)
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Visuals = {}

local function getFolder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end

-- 순수 이펙트 파츠 (CanQuery = false)
local folder = getFolder("Effects")
Visuals.Folder = folder

-- 라운드 동안 존재하는 오브젝트 (설치물 / 분신 / 소환수). 라운드 종료 시 정리
local roundFolder = getFolder("RoundObjects")
Visuals.RoundFolder = roundFolder

function Visuals.Part(size: Vector3, cframe: CFrame, color: Color3, transparency: number?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

function Visuals.Fade(part: BasePart, duration: number, goal: { [string]: any }?)
	local props = goal or {}
	props.Transparency = 1
	TweenService:Create(part, TweenInfo.new(duration), props):Play()
	Debris:AddItem(part, duration + 0.05)
end

function Visuals.Slash(rootCF: CFrame, color: Color3, range: number?)
	local r = range or 6
	local p = Visuals.Part(Vector3.new(r * 1.2, 0.3, r * 0.8), rootCF * CFrame.new(0, 0, -r * 0.55), color, 0.2)
	Visuals.Fade(p, 0.25, { Size = Vector3.new(r * 1.5, 0.1, r) })
end

function Visuals.Burst(position: Vector3, color: Color3, radius: number, duration: number?)
	local p = Visuals.Part(Vector3.one, CFrame.new(position), color, 0.3, Enum.PartType.Ball)
	Visuals.Fade(p, duration or 0.4, { Size = Vector3.one * radius * 2 })
end

-- 바닥에 납작하게 퍼지는 원형 파동
function Visuals.Ring(position: Vector3, color: Color3, radius: number, duration: number?)
	local cf = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local p = Visuals.Part(Vector3.new(0.2, 1, 1), cf, color, 0.35, Enum.PartType.Cylinder)
	Visuals.Fade(p, duration or 0.5, { Size = Vector3.new(0.2, radius * 2, radius * 2) })
end

function Visuals.Spike(groundPosition: Vector3, color: Color3)
	local p = Visuals.Part(Vector3.new(1.5, 0.5, 1.5), CFrame.new(groundPosition), color, 0)
	TweenService:Create(p, TweenInfo.new(0.12), {
		Size = Vector3.new(1.5, 7, 1.5),
		CFrame = CFrame.new(groundPosition + Vector3.new(0, 3.5, 0)),
	}):Play()
	task.delay(0.6, function()
		if p.Parent then
			Visuals.Fade(p, 0.3)
		end
	end)
end

function Visuals.Beam(from: Vector3, to: Vector3, color: Color3)
	local dist = (to - from).Magnitude
	if dist < 0.1 then
		return
	end
	local p = Visuals.Part(Vector3.new(0.3, 0.3, dist), CFrame.lookAt((from + to) / 2, to), color, 0)
	Visuals.Fade(p, 0.3)
end

function Visuals.Highlight(model: Model, color: Color3, duration: number, fillTransparency: number?)
	local h = Instance.new("Highlight")
	h.Name = "EffectHighlight"
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = fillTransparency or 0.6
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	Debris:AddItem(h, duration)
	return h
end

-- 머리 위에 잠깐 떠오르는 글자
function Visuals.Label(model: Model, text: string, color: Color3, duration: number)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "EffectLabel"
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = color
	tl.TextStrokeTransparency = 0
	tl.Text = text
	tl.Parent = bb
	bb.Parent = head
	Debris:AddItem(bb, duration)
end

function Visuals.SetInvisible(model: Model, on: boolean)
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			if on then
				if d:GetAttribute("OrigT") == nil then
					d:SetAttribute("OrigT", d.Transparency)
				end
				d.Transparency = 0.92
			else
				local orig = d:GetAttribute("OrigT")
				if orig ~= nil then
					d.Transparency = orig
					d:SetAttribute("OrigT", nil)
				end
			end
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = on and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
	end
end

-- 기본 달리기 애니메이션 (서버가 소유한 NPC/분신용)
local RUN_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://913376220",
	[Enum.HumanoidRigType.R6] = "rbxassetid://180426354",
}

function Visuals.LoadRunAnimation(humanoid: Humanoid): AnimationTrack?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = RUN_ANIM[humanoid.RigType] or RUN_ANIM[Enum.HumanoidRigType.R15]
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		return track
	end
	return nil
end

-- 캐릭터를 복제해 앞으로 달려가는 분신을 만든다 (RoundFolder 에 생성, 피격 처리는 호출자가 등록)
function Visuals.Decoy(model: Model, speed: number, duration: number): Model?
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local wasArchivable = model.Archivable
	model.Archivable = true
	local clone = model:Clone()
	model.Archivable = wasArchivable
	if not clone then
		return nil
	end

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Highlight") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	for name in pairs(clone:GetAttributes()) do
		clone:SetAttribute(name, nil)
	end
	for _, tag in ipairs(CollectionService:GetTags(clone)) do
		CollectionService:RemoveTag(clone, tag)
	end
	Visuals.SetInvisible(clone, false)
	clone:SetAttribute("Decoy", true)
	clone.Parent = roundFolder

	local hum = clone:FindFirstChildOfClass("Humanoid")
	local cRoot = clone:FindFirstChild("HumanoidRootPart")
	if hum and cRoot and cRoot:IsA("BasePart") then
		hum.WalkSpeed = speed
		pcall(function()
			cRoot:SetNetworkOwner(nil)
		end)
		local track = Visuals.LoadRunAnimation(hum)
		if track then
			track:Play()
		end
		local look = root.CFrame.LookVector
		hum:MoveTo(cRoot.Position + Vector3.new(look.X, 0, look.Z) * speed * duration)
	end
	Debris:AddItem(clone, duration)
	return clone
end

function Visuals.Clear()
	folder:ClearAllChildren()
	roundFolder:ClearAllChildren()
end

return Visuals
