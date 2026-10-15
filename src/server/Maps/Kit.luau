-- 맵 제작용 공용 파트 헬퍼 (로비 / 경기장 모듈이 함께 사용)
-- 모든 좌표의 Y = 0 이 지면 높이입니다. 무작위가 필요한 함수는 rng(Random) 를 받습니다.
local Kit = {}

Kit.DOOR_W = 8
Kit.DOOR_H = 9
Kit.WALL_T = 1.2

-- 고정(Anchored) 파트 생성. props 의 키/값을 그대로 속성에 대입합니다.
function Kit.Part(parent: Instance, props: { [string]: any }): Part
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

local part = Kit.Part

-- 파트에 점광원 추가
function Kit.Light(bulb: BasePart, range: number, brightness: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = bulb.Color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = bulb
	return light
end

-- 가로등
function Kit.Lamp(parent: Instance, position: Vector3, color: Color3?)
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
	Kit.Light(bulb, 38, 1.6, true)
end

-- 벽 (door = true 면 가운데에 문 구멍)
function Kit.Wall(
	parent: Instance,
	center: Vector3,
	length: number,
	height: number,
	alongX: boolean,
	door: boolean,
	color: Color3?,
	material: Enum.Material?
)
	local axis = alongX and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	local function seg(offset: number, len: number, h: number, yBase: number)
		part(parent, {
			Name = "Wall",
			Size = alongX and Vector3.new(len, h, Kit.WALL_T) or Vector3.new(Kit.WALL_T, h, len),
			Position = center + axis * offset + Vector3.new(0, yBase + h / 2, 0),
			Color = color or Color3.fromRGB(85, 70, 60),
			Material = material or Enum.Material.Brick,
		})
	end
	if not door then
		seg(0, length, height, 0)
		return
	end
	local side = (length - Kit.DOOR_W) / 2
	seg(-(Kit.DOOR_W / 2 + side / 2), side, height, 0)
	seg(Kit.DOOR_W / 2 + side / 2, side, height, 0)
	seg(0, Kit.DOOR_W, height - Kit.DOOR_H, Kit.DOOR_H)
end

-- 문이 세 개 달린 단층 집 (서쪽 벽만 막혀 있음)
function Kit.House(parent: Instance, center: Vector3, w: number, d: number): Model
	local model = Instance.new("Model")
	model.Name = "House"
	local h = 13
	Kit.Wall(model, center + Vector3.new(0, 0, -d / 2), w + Kit.WALL_T, h, true, true)
	Kit.Wall(model, center + Vector3.new(0, 0, d / 2), w + Kit.WALL_T, h, true, true)
	Kit.Wall(model, center + Vector3.new(-w / 2, 0, 0), d, h, false, false)
	Kit.Wall(model, center + Vector3.new(w / 2, 0, 0), d, h, false, true)
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
	Kit.Light(bulb, 20, 1.2)
	model.Parent = parent
	return model
end

function Kit.Tree(parent: Instance, position: Vector3, rng: Random)
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

function Kit.Rock(parent: Instance, position: Vector3, rng: Random)
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

function Kit.Crate(parent: Instance, position: Vector3, rng: Random)
	part(parent, {
		Name = "Crate",
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = Color3.fromRGB(110, 80, 45),
		Material = Enum.Material.WoodPlanks,
	})
end

-- 정사각형 바닥 (윗면이 Y = center.Y)
function Kit.Ground(parent: Instance, center: Vector3, size: number, color: Color3, material: Enum.Material): Part
	return part(parent, {
		Name = "Ground",
		Size = Vector3.new(size, 4, size),
		Position = center - Vector3.new(0, 2, 0),
		Color = color,
		Material = material,
	})
end

-- 정사각형 경기장의 바깥 경계벽
function Kit.Boundary(parent: Instance, center: Vector3, size: number, height: number, color: Color3?)
	local half = size / 2
	for _, info in ipairs({
		{ Vector3.new(0, height / 2, -half), Vector3.new(size + 2, height, 2) },
		{ Vector3.new(0, height / 2, half), Vector3.new(size + 2, height, 2) },
		{ Vector3.new(-half, height / 2, 0), Vector3.new(2, height, size + 2) },
		{ Vector3.new(half, height / 2, 0), Vector3.new(2, height, size + 2) },
	}) do
		part(parent, {
			Name = "Boundary",
			Size = info[2],
			Position = center + info[1],
			Color = color or Color3.fromRGB(28, 24, 30),
			Material = Enum.Material.WoodPlanks,
		})
	end
end

-- 배치 예약표: 장애물끼리 / 중요 지점과 겹치지 않도록 XZ 평면의 원으로 자리를 예약합니다.
export type Layout = {
	Reserve: (pos: Vector3, radius: number) -> (),
	IsFree: (pos: Vector3, radius: number) -> boolean,
	-- center 기준 반경 half 정사각형 안에서 빈 자리를 찾아 builder(pos) 를 count 번 호출
	Scatter: (count: number, radius: number, rng: Random, builder: (Vector3) -> ()) -> { Vector3 },
}

function Kit.Layout(center: Vector3, half: number, margin: number?): Layout
	local reserved = {}
	local pad = margin or 8
	local layout = {} :: Layout

	function layout.Reserve(pos: Vector3, radius: number)
		table.insert(reserved, { X = pos.X, Z = pos.Z, Radius = radius })
	end

	function layout.IsFree(pos: Vector3, radius: number): boolean
		for _, r in ipairs(reserved) do
			local dx, dz = pos.X - r.X, pos.Z - r.Z
			if dx * dx + dz * dz < (r.Radius + radius) ^ 2 then
				return false
			end
		end
		return true
	end

	function layout.Scatter(count: number, radius: number, rng: Random, builder: (Vector3) -> ()): { Vector3 }
		local placed = {}
		local tries = 0
		while #placed < count and tries < count * 30 do
			tries += 1
			local pos = center
				+ Vector3.new(rng:NextNumber(-half + pad, half - pad), 0, rng:NextNumber(-half + pad, half - pad))
			if layout.IsFree(pos, radius) then
				builder(pos)
				layout.Reserve(pos, radius)
				table.insert(placed, pos)
			end
		end
		return placed
	end

	return layout
end

return Kit
