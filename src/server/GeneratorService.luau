-- 발전기: ProximityPrompt 로 퍼즐을 열고, 퍼즐 단계를 완료할 때마다 진행도가 오릅니다.
-- 퍼즐이 열려 있는 동안 생존자는 Repairing 상태(이동 불가). 봇은 BotWork 로 시간을 채워 수리합니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local State = require(script.Parent.State)
local Status = require(script.Parent.Status)
local Net = require(script.Parent.Net)

local GeneratorService = {}
GeneratorService.OnCompleted = nil :: ((any) -> ())?

local RED = Color3.fromRGB(255, 60, 60)
local GREEN = Color3.fromRGB(80, 255, 120)

-- 퍼즐이 열려 있는 동안 유지되는 Repairing 상태 시간 (StopWork 에서 해제)
local REPAIRING_DURATION = 3600

local folder: Folder? = nil
local gens = {}

local function getFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Generators"
		f.Parent = workspace
		folder = f
		return f
	end
	return folder
end

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

local function inRange(data, gen): boolean
	return (data.Root.Position - gen.Position).Magnitude <= Config.GENERATOR_REPAIR_RANGE
end

local function canWork(data): boolean
	return data ~= nil and data.Role == "Survivor" and State.IsAlive(data) and not Status.Has(data, "Stunned")
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
	model:SetAttribute("GeneratorId", id)
	model.Parent = getFolder()

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
		GeneratorService.StartWork(State.Get(player), id)
	end)

	return gen
end

-- 이 발전기를 작업 중인 엔트리 목록
local function workers(genId: number)
	local list = {}
	for _, data in pairs(State.All()) do
		if data.RepairingGen == genId then
			table.insert(list, data)
		end
	end
	return list
end

local function complete(gen)
	gen.Completed = true
	gen.Prompt.Enabled = false
	updateVisual(gen)
	for _, data in ipairs(workers(gen.Id)) do
		GeneratorService.StopWork(data)
	end
	State.Broadcast("OnAnyGeneratorCompleted", gen)
	if GeneratorService.OnCompleted then
		local ok, err = pcall(GeneratorService.OnCompleted, gen)
		if not ok then
			warn("발전기 완료 처리 오류:", err)
		end
	end
end

-- 퍼즐 한 단계 완료 처리 (플레이어/봇 공통)
local function step(data, gen)
	gen.Progress += 1
	data.Stats.Generators += 1
	updateVisual(gen)
	State.CallHook(data, "OnGeneratorStep", gen)
	if Config.GENERATOR_NOTIFY_KILLER then
		Net.Killer("GenPing", gen.Position)
	end
	if gen.Progress >= Config.GENERATOR_STEPS then
		complete(gen)
		return
	end
	for _, other in ipairs(workers(gen.Id)) do
		Net.Send(other.Owner, "GeneratorProgress", gen.Id, gen.Progress, Config.GENERATOR_STEPS)
	end
end

-- 숫자 퍼즐 단계 완료 요청 (클라이언트 → 서버)
local function onStep(player: Player, id)
	if typeof(id) ~= "number" then
		return
	end
	local data = State.Get(player)
	if not canWork(data) or data.RepairingGen ~= id then
		return
	end
	local gen = gens[id]
	if not gen or gen.Completed or not inRange(data, gen) then
		return
	end
	local t = os.clock()
	local last = data.Vars._genLastStep
	if last and t - last < Config.GENERATOR_MIN_SOLVE_TIME then
		return
	end
	data.Vars._genLastStep = t
	step(data, gen)
end

function GeneratorService.Init()
	getFolder()
	Remotes.GeneratorStep.OnServerEvent:Connect(onStep)
	Remotes.GeneratorCancel.OnServerEvent:Connect(function(player)
		local data = State.Get(player)
		if data then
			GeneratorService.StopWork(data)
		end
	end)
end

function GeneratorService.Clear()
	for _, data in pairs(State.All()) do
		if data.RepairingGen then
			GeneratorService.StopWork(data)
		end
	end
	getFolder():ClearAllChildren()
	table.clear(gens)
end

-- 맵의 GeneratorSpots 중 무작위 count 곳에 발전기 생성
function GeneratorService.Reset(map, count: number)
	GeneratorService.Clear()
	local spots = Util.Shuffle(table.clone(map.GeneratorSpots or {}))
	for i = 1, math.min(count, #spots) do
		gens[i] = build(i, spots[i])
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
	return #gens
end

function GeneratorService.GetAll()
	return table.clone(gens)
end

-- 가장 가까운 미완료 발전기와 거리
function GeneratorService.NearestIncomplete(position: Vector3)
	local best, bestDist = nil, math.huge
	for _, gen in ipairs(gens) do
		if not gen.Completed then
			local dist = (gen.Position - position).Magnitude
			if dist < bestDist then
				best, bestDist = gen, dist
			end
		end
	end
	return best, bestDist
end

-- 수리 시작. 플레이어는 퍼즐 창을 열고 Repairing 상태가 됨, 봇은 작업 표시만
function GeneratorService.StartWork(data, genId: number): boolean
	if not canWork(data) then
		return false
	end
	local gen = gens[genId]
	if not gen or gen.Completed or not inRange(data, gen) then
		return false
	end
	if data.RepairingGen and data.RepairingGen ~= genId then
		GeneratorService.StopWork(data)
	end
	data.RepairingGen = genId
	if data.IsBot then
		return true
	end
	data.Vars._genLastStep = os.clock()
	Status.Add(data, "Repairing", REPAIRING_DURATION)
	Net.Send(data.Owner, "OpenGenerator", genId, gen.Model, gen.Progress, Config.GENERATOR_STEPS)
	return true
end

-- 수리 중단 (퍼즐 창 닫기 + Repairing 해제)
function GeneratorService.StopWork(data)
	if not data then
		return
	end
	local wasWorking = data.RepairingGen ~= nil
	data.RepairingGen = nil
	data.Vars._genWork = nil
	if data.Statuses.Repairing then
		Status.Remove(data, "Repairing")
	end
	if wasWorking and not data.IsBot then
		Net.Send(data.Owner, "CloseGenerator")
	end
end

-- 봇 수리 틱: 범위 안이면 시간을 쌓고 BOT_REPAIR_STEP_TIME 마다 한 단계 완료
function GeneratorService.BotWork(data, gen, dt: number): boolean
	if not gen or gen.Completed or gens[gen.Id] ~= gen or not canWork(data) or not inRange(data, gen) then
		return false
	end
	if data.RepairingGen ~= gen.Id and not GeneratorService.StartWork(data, gen.Id) then
		return false
	end
	local work = (data.Vars._genWork or 0) + dt
	if work >= Config.BOT_REPAIR_STEP_TIME then
		work -= Config.BOT_REPAIR_STEP_TIME
		data.Vars._genWork = work
		step(data, gen)
	else
		data.Vars._genWork = work
	end
	return true
end

return GeneratorService
