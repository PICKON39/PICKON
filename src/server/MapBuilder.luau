-- 코드로 로비와 경기장(맵)을 생성합니다. 별도 .rbxl 에셋 없이 동작합니다.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local rng = Random.new(1337)

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(45, 40, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 65, 85)
	Lighting.GlobalShadows = true
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("ColorCorrectionEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(60, 50, 70)
	atmosphere.Decay = Color3.fromRGB(30, 20, 35)
	atmosphere.Glare = 0
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.3
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromRGB(225, 215, 235)
	cc.Parent = Lighting
end

local function lamp(parent: Instance, position: Vector3, color: Color3?)
	part(parent, {
		Name = "LampPost",
		Size = Vector3.new(0.6, 12, 0.6),
		Position = position + Vector3.new(0, 6, 0),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Metal,
	})
	local bulb = part(parent, {
		Name = "Bulb",
		Size = Vector3.new(1.4, 1, 1.4),
		Position = position + Vector3.new(0, 12.3, 0),
		Color = color or Color3.fromRGB(255, 190, 110),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = bulb.Color
	light.Range = 38
	light.Brightness = 1.6
	light.Shadows = true
	light.Parent = bulb
end

local function buildLobby(parent: Instance)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = parent
	local c = Config.LOBBY_POSITION

	part(lobby, {
		Name = "Floor",
		Size = Vector3.new(90, 2, 90),
		Position = c - Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(55, 50, 60),
		Material = Enum.Material.Cobblestone,
	})
	for _, info in ipairs({
		{ Vector3.new(0, 4, -45), Vector3.new(90, 8, 1) },
		{ Vector3.new(0, 4, 45), Vector3.new(90, 8, 1) },
		{ Vector3.new(-45, 4, 0), Vector3.new(1, 8, 90) },
		{ Vector3.new(45, 4, 0), Vector3.new(1, 8, 90) },
	}) do
		part(lobby, {
			Name = "Fence",
			Size = info[2],
			Position = c + info[1],
			Color = Color3.fromRGB(40, 30, 30),
			Material = Enum.Material.WoodPlanks,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = c + Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(120, 20, 20)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Parent = lobby

	-- 타이틀 간판
	local sign = part(lobby, {
		Name = "Sign",
		Size = Vector3.new(40, 12, 1),
		Position = c + Vector3.new(0, 14, -44),
		Color = Color3.fromRGB(15, 10, 15),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Creepster
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(220, 30, 30)
	title.Text = "ABANDONED"
	title.Parent = gui

	for _, offset in ipairs({
		Vector3.new(-30, 0, -30),
		Vector3.new(30, 0, -30),
		Vector3.new(-30, 0, 30),
		Vector3.new(30, 0, 30),
	}) do
		lamp(lobby, c + offset)
	end
end

local DOOR_W, DOOR_H, WALL_T = 8, 9, 1.2

local function wall(model: Instance, center: Vector3, length: number, height: number, alongX: boolean, door: boolean)
	local axis = alongX and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	local function seg(offset: number, len: number, h: number, yBase: number)
		part(model, {
			Name = "Wall",
			Size = alongX and Vector3.new(len, h, WALL_T) or Vector3.new(WALL_T, h, len),
			Position = center + axis * offset + Vector3.new(0, yBase + h / 2, 0),
			Color = Color3.fromRGB(85, 70, 60),
			Material = Enum.Material.Brick,
		})
	end
	if not door then
		seg(0, length, height, 0)
		return
	end
	local side = (length - DOOR_W) / 2
	seg(-(DOOR_W / 2 + side / 2), side, height, 0)
	seg(DOOR_W / 2 + side / 2, side, height, 0)
	seg(0, DOOR_W, height - DOOR_H, DOOR_H)
end

local function house(parent: Instance, center: Vector3, w: number, d: number)
	local model = Instance.new("Model")
	model.Name = "House"
	local h = 13
	wall(model, center + Vector3.new(0, 0, -d / 2), w + WALL_T, h, true, true)
	wall(model, center + Vector3.new(0, 0, d / 2), w + WALL_T, h, true, true)
	wall(model, center + Vector3.new(-w / 2, 0, 0), d, h, false, false)
	wall(model, center + Vector3.new(w / 2, 0, 0), d, h, false, true)
	part(model, {
		Name = "Roof",
		Size = Vector3.new(w + 3, 1, d + 3),
		Position = center + Vector3.new(0, h + 0.5, 0),
		Color = Color3.fromRGB(50, 35, 35),
		Material = Enum.Material.Slate,
	})
	part(model, {
		Name = "Floor",
		Size = Vector3.new(w, 0.2, d),
		Position = center + Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(70, 50, 35),
		Material = Enum.Material.WoodPlanks,
	})
	local bulb = part(model, {
		Name = "CeilingLight",
		Size = Vector3.new(1, 0.4, 1),
		Position = center + Vector3.new(0, h - 0.3, 0),
		Color = Color3.fromRGB(255, 200, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = bulb.Color
	light.Range = 20
	light.Brightness = 1.2
	light.Parent = bulb
	model.Parent = parent
end

local function tree(parent: Instance, position: Vector3)
	local height = rng:NextNumber(12, 18)
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2.4, 2.4),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 45, 35),
		Material = Enum.Material.Wood,
	})
	local size = rng:NextNumber(9, 14)
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Position = position + Vector3.new(0, height + size * 0.25, 0),
		Color = Color3.fromRGB(30, 50, 32),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

local function rock(parent: Instance, position: Vector3)
	local s = rng:NextNumber(3, 7)
	part(parent, {
		Name = "Rock",
		Size = Vector3.new(s * 1.3, s, s),
		CFrame = CFrame.new(position + Vector3.new(0, s / 2 - 0.5, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(80, 80, 85),
		Material = Enum.Material.Slate,
	})
end

local function crate(parent: Instance, position: Vector3)
	part(parent, {
		Name = "Crate",
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = Color3.fromRGB(110, 80, 45),
		Material = Enum.Material.WoodPlanks,
	})
end

local function buildArena(parent: Instance)
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = parent
	local size = Config.ARENA_SIZE
	local half = size / 2

	part(arena, {
		Name = "Ground",
		Size = Vector3.new(size, 4, size),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(45, 52, 38),
		Material = Enum.Material.Grass,
	})
	for _, info in ipairs({
		{ Vector3.new(0, 20, -half), Vector3.new(size + 2, 40, 2) },
		{ Vector3.new(0, 20, half), Vector3.new(size + 2, 40, 2) },
		{ Vector3.new(-half, 20, 0), Vector3.new(2, 40, size + 2) },
		{ Vector3.new(half, 20, 0), Vector3.new(2, 40, size + 2) },
	}) do
		part(arena, {
			Name = "Boundary",
			Size = info[2],
			Position = info[1],
			Color = Color3.fromRGB(28, 24, 30),
			Material = Enum.Material.WoodPlanks,
		})
	end

	local reserved = {}
	local function reserve(pos: Vector3, radius: number)
		table.insert(reserved, { Pos = pos, Radius = radius })
	end
	local function isFree(pos: Vector3, radius: number): boolean
		for _, r in ipairs(reserved) do
			if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(r.Pos.X, 0, r.Pos.Z)).Magnitude < r.Radius + radius then
				return false
			end
		end
		return true
	end

	-- 집
	local houses = {
		{ Vector3.new(0, 0, 0), 30, 20 },
		{ Vector3.new(-55, 0, -55), 24, 24 },
		{ Vector3.new(55, 0, 55), 24, 24 },
		{ Vector3.new(-55, 0, 60), 22, 26 },
		{ Vector3.new(60, 0, -55), 26, 22 },
	}
	for _, h in ipairs(houses) do
		house(arena, h[1], h[2], h[3])
		reserve(h[1], math.max(h[2], h[3]) * 0.75)
	end

	-- 발전기 위치
	local generatorSpots = {
		Vector3.new(-100, 0, -100),
		Vector3.new(100, 0, -100),
		Vector3.new(-100, 0, 100),
		Vector3.new(100, 0, 100),
		Vector3.new(-112, 0, 0),
		Vector3.new(112, 0, 0),
		Vector3.new(-35, 0, 25),
		Vector3.new(35, 0, -25),
	}
	for _, spot in ipairs(generatorSpots) do
		reserve(spot, 9)
	end

	-- 스폰
	local survivorSpawns = {}
	for i = 0, 7 do
		local pos = Vector3.new(-14 + i * 4, 4, -112)
		table.insert(survivorSpawns, CFrame.lookAt(pos, Vector3.new(0, 4, 0)))
	end
	local killerSpawnPos = Vector3.new(0, 4, 112)
	reserve(Vector3.new(0, 0, -112), 20)
	reserve(killerSpawnPos, 12)

	-- 가로등
	for _, pos in ipairs({
		Vector3.new(-80, 0, -20),
		Vector3.new(80, 0, 20),
		Vector3.new(-20, 0, -85),
		Vector3.new(20, 0, 85),
		Vector3.new(-90, 0, 55),
		Vector3.new(90, 0, -60),
		Vector3.new(0, 0, -40),
		Vector3.new(0, 0, 40),
	}) do
		lamp(arena, pos)
		reserve(pos, 3)
	end

	-- 무작위 장애물
	local function scatter(count: number, radius: number, builder)
		local placed, tries = 0, 0
		while placed < count and tries < count * 30 do
			tries += 1
			local pos = Vector3.new(rng:NextNumber(-half + 8, half - 8), 0, rng:NextNumber(-half + 8, half - 8))
			if isFree(pos, radius) then
				builder(arena, pos)
				reserve(pos, radius)
				placed += 1
			end
		end
	end
	scatter(45, 4, tree)
	scatter(25, 3.5, rock)
	scatter(18, 3.5, crate)

	return {
		SurvivorSpawns = survivorSpawns,
		KillerSpawn = CFrame.lookAt(killerSpawnPos, Vector3.new(0, 4, 0)),
		GeneratorSpots = generatorSpots,
	}
end

function MapBuilder.Build()
	-- 기본 템플릿의 Baseplate / SpawnLocation 제거 (경기장과 겹치지 않도록)
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") or child.Name == "Baseplate" then
			child:Destroy()
		end
	end

	setupLighting()

	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace

	buildLobby(mapFolder)
	return buildArena(mapFolder)
end

return MapBuilder
