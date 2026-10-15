-- 교차로 마을: 집 다섯 채와 가로등, 무작위 나무 / 바위 / 상자가 흩어진 밤의 마을
local Kit = require(script.Parent.Kit)

local SIZE = 260
local HALF = SIZE / 2
local CENTER = Vector3.zero

-- 집 { 중심, 너비, 깊이 }
local HOUSES = {
	{ Vector3.new(0, 0, 0), 30, 20 },
	{ Vector3.new(-55, 0, -55), 24, 24 },
	{ Vector3.new(55, 0, 55), 24, 24 },
	{ Vector3.new(-55, 0, 60), 22, 26 },
	{ Vector3.new(60, 0, -55), 26, 22 },
}

local GENERATOR_SPOTS = {
	Vector3.new(-100, 0, -100),
	Vector3.new(100, 0, -100),
	Vector3.new(-100, 0, 100),
	Vector3.new(100, 0, 100),
	Vector3.new(-112, 0, 0),
	Vector3.new(112, 0, 0),
	Vector3.new(-35, 0, 25),
	Vector3.new(35, 0, -25),
}

local LAMPS = {
	Vector3.new(-80, 0, -20),
	Vector3.new(80, 0, 20),
	Vector3.new(-20, 0, -85),
	Vector3.new(20, 0, 85),
	Vector3.new(-90, 0, 55),
	Vector3.new(90, 0, -60),
	Vector3.new(0, 0, -40),
	Vector3.new(0, 0, 40),
}

-- 봇 순찰 지점 (장애물이 생기지 않도록 미리 예약)
local PATROL_POINTS = {
	Vector3.new(-80, 0, -100),
	Vector3.new(0, 0, -85),
	Vector3.new(80, 0, -100),
	Vector3.new(-110, 0, -30),
	Vector3.new(-35, 0, -30),
	Vector3.new(35, 0, 30),
	Vector3.new(110, 0, 30),
	Vector3.new(-80, 0, 100),
	Vector3.new(0, 0, 85),
	Vector3.new(80, 0, 100),
	Vector3.new(-25, 0, 0),
	Vector3.new(25, 0, 0),
}

local SURVIVOR_SPAWN_Z = -112
local KILLER_SPAWN = Vector3.new(0, 4, 112)
local ITEM_SPOT_COUNT = 10

local Crossroads = {
	Id = "Crossroads",
	DisplayName = "교차로 마을",
	-- 맵 조명 (MapService.ApplyLighting 형식)
	Lighting = {
		ClockTime = 0,
		Brightness = 1,
		Ambient = Color3.fromRGB(45, 40, 55),
		OutdoorAmbient = Color3.fromRGB(70, 65, 85),
		GlobalShadows = true,
		Atmosphere = {
			Density = 0.42,
			Offset = 0,
			Color = Color3.fromRGB(60, 50, 70),
			Decay = Color3.fromRGB(30, 20, 35),
			Glare = 0,
			Haze = 2,
		},
		ColorCorrection = {
			Saturation = -0.3,
			Contrast = 0.1,
			TintColor = Color3.fromRGB(225, 215, 235),
		},
	},
}

function Crossroads.Build(parent: Instance, rng: Random)
	Kit.Ground(parent, CENTER, SIZE, Color3.fromRGB(45, 52, 38), Enum.Material.Grass)
	Kit.Boundary(parent, CENTER, SIZE, 40)

	local layout = Kit.Layout(CENTER, HALF)

	-- 집 (안쪽 바닥은 아이템 자리로 사용)
	local itemSpots = {}
	for _, h in ipairs(HOUSES) do
		Kit.House(parent, h[1], h[2], h[3])
		layout.Reserve(h[1], math.max(h[2], h[3]) * 0.75)
		local offset = Vector3.new(rng:NextNumber(-h[2] / 4, h[2] / 4), 0, rng:NextNumber(-h[3] / 4, h[3] / 4))
		table.insert(itemSpots, h[1] + offset)
	end

	for _, spot in ipairs(GENERATOR_SPOTS) do
		layout.Reserve(spot, 9)
	end

	-- 스폰
	local survivorSpawns = {}
	for i = 0, 7 do
		local pos = Vector3.new(-14 + i * 4, 4, SURVIVOR_SPAWN_Z)
		table.insert(survivorSpawns, CFrame.lookAt(pos, Vector3.new(0, 4, 0)))
	end
	layout.Reserve(Vector3.new(0, 0, SURVIVOR_SPAWN_Z), 20)
	layout.Reserve(KILLER_SPAWN, 12)

	for _, pos in ipairs(LAMPS) do
		Kit.Lamp(parent, pos)
		layout.Reserve(pos, 3)
	end
	for _, pos in ipairs(PATROL_POINTS) do
		layout.Reserve(pos, 3)
	end

	-- 바깥 아이템 자리 (장애물을 놓기 전에 예약해 두면 항상 비어 있음)
	local outdoor = layout.Scatter(ITEM_SPOT_COUNT - #itemSpots, 3, rng, function() end)
	for _, pos in ipairs(outdoor) do
		table.insert(itemSpots, pos)
	end

	-- 무작위 장애물
	layout.Scatter(45, 4, rng, function(pos)
		Kit.Tree(parent, pos, rng)
	end)
	layout.Scatter(25, 3.5, rng, function(pos)
		Kit.Rock(parent, pos, rng)
	end)
	layout.Scatter(18, 3.5, rng, function(pos)
		Kit.Crate(parent, pos, rng)
	end)

	return {
		Id = Crossroads.Id,
		DisplayName = Crossroads.DisplayName,
		SurvivorSpawns = survivorSpawns,
		KillerSpawn = CFrame.lookAt(KILLER_SPAWN, Vector3.new(0, 4, 0)),
		GeneratorSpots = table.clone(GENERATOR_SPOTS),
		ItemSpots = itemSpots,
		PatrolPoints = table.clone(PATROL_POINTS),
		Center = CENTER,
		HalfSize = HALF,
	}
end

return Crossroads
