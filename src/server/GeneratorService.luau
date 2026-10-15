-- 발전기: ProximityPrompt 로 퍼즐을 열고, 퍼즐 단계를 완료할 때마다 진행도가 오릅니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local Status = require(script.Parent.Status)
local Net = require(script.Parent.Net)

local GeneratorService = {}
GeneratorService.OnCompleted = nil :: ((any) -> ())?

local RED = Color3.fromRGB(255, 60, 60)
local GREEN = Color3.fromRGB(80, 255, 120)

local folder: Folder
local spots: { Vector3 } = {}
local gens = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function updateVisual(gen)
	local ratio = gen.Progress / Config.GENERATOR_STEPS
	gen.Label.Text = gen.Completed and "완료" or ("%d%%"):format(math.floor(ratio * 100))
	local color = RED:Lerp(GREEN, ratio)
	gen.Light.Color = color
	gen.PointLight.Color = color
end

local function build(id: number, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Generator" .. id
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)

	local body = part(model, "Body", Vector3.new(5, 3.5, 3.5), base * CFrame.new(0, 1.75, 0), Color3.fromRGB(70, 75, 80))
	part(model, "Top", Vector3.new(4.4, 0.5, 3), base * CFrame.new(0, 3.75, 0), Color3.fromRGB(110, 90, 40))
	part(model, "Pipe", Vector3.new(0.6, 2.5, 0.6), base * CFrame.new(1.6, 5, 0.8), Color3.fromRGB(50, 50, 55))
	local light = part(model, "Light", Vector3.new(0.8, 0.8, 0.8), base * CFrame.new(-1.6, 4.4, 0), RED, Enum.Material.Neon)
	light.Shape = Enum.PartType.Ball

	local pointLight = Instance.new("PointLight")
	pointLight.Color = RED
	pointLight.Range = 14
	pointLight.Brightness = 2
	pointLight.Parent = light

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "수리하기"
	prompt.ObjectText = "발전기"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = body

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(80, 30)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = bb
	bb.Parent = body

	model.PrimaryPart = body
	model.Parent = folder

	local gen = {
		Id = id,
		Model = model,
		Position = body.Position,
		Prompt = prompt,
		Light = light,
		PointLight = pointLight,
		Label = label,
		Progress = 0,
		Completed = false,
	}
	updateVisual(gen)

	prompt.Triggered:Connect(function(player)
		local data = State.Get(player)
		if not data or data.Role ~= "Survivor" or not State.IsAlive(data) then
			return
		end
		if gen.Completed or Status.Has(data, "Stunned") then
			return
		end
		data.RepairingGen = id
		Net.Send(player, "OpenGenerator", id, model, gen.Progress, Config.GENERATOR_STEPS)
	end)

	return gen
end

local function complete(gen)
	gen.Completed = true
	gen.Prompt.Enabled = false
	updateVisual(gen)
	for _, data in pairs(State.All()) do
		if data.RepairingGen == gen.Id then
			data.RepairingGen = nil
			Net.Send(data.Owner, "CloseGenerator")
		end
	end
	if GeneratorService.OnCompleted then
		GeneratorService.OnCompleted(gen)
	end
end

local function onStep(player: Player, id)
	local data = State.Get(player)
	if not data or data.Role ~= "Survivor" or not State.IsAlive(data) then
		return
	end
	local gen = gens[id]
	if not gen or gen.Completed or data.RepairingGen ~= id then
		return
	end
	if (data.Root.Position - gen.Position).Magnitude > Config.GENERATOR_REPAIR_RANGE then
		return
	end
	local t = os.clock()
	if data.LastGenStep and t - data.LastGenStep < Config.GENERATOR_STEP_COOLDOWN then
		return
	end
	data.LastGenStep = t

	gen.Progress += 1
	updateVisual(gen)
	if gen.Progress >= Config.GENERATOR_STEPS then
		complete(gen)
	else
		for _, other in pairs(State.All()) do
			if other.RepairingGen == id then
				Net.Send(other.Owner, "GeneratorProgress", id, gen.Progress, Config.GENERATOR_STEPS)
			end
		end
	end
end

function GeneratorService.Init(map)
	spots = map.GeneratorSpots
	folder = Instance.new("Folder")
	folder.Name = "Generators"
	folder.Parent = workspace

	Remotes.GeneratorStep.OnServerEvent:Connect(onStep)
	Remotes.GeneratorCancel.OnServerEvent:Connect(function(player)
		local data = State.Get(player)
		if data then
			data.RepairingGen = nil
		end
	end)
end

function GeneratorService.Clear()
	folder:ClearAllChildren()
	table.clear(gens)
end

function GeneratorService.Reset(count: number)
	GeneratorService.Clear()
	local shuffled = table.clone(spots)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for i = 1, math.min(count, #shuffled) do
		gens[i] = build(i, shuffled[i])
	end
end

function GeneratorService.Remaining(): number
	local n = 0
	for _, gen in pairs(gens) do
		if not gen.Completed then
			n += 1
		end
	end
	return n
end

function GeneratorService.Total(): number
	local n = 0
	for _ in pairs(gens) do
		n += 1
	end
	return n
end

return GeneratorService
