-- 로비: 라운드 사이에 플레이어가 머무는 공간 (Config.LOBBY_POSITION)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)

local Lobby = {}

-- 로비 조명 (MapService.ApplyLighting 형식)
Lobby.Lighting = {
	ClockTime = 0,
	Brightness = 1,
	Ambient = Color3.fromRGB(50, 44, 58),
	OutdoorAmbient = Color3.fromRGB(80, 72, 92),
	GlobalShadows = true,
	Atmosphere = {
		Density = 0.35,
		Offset = 0,
		Color = Color3.fromRGB(64, 52, 72),
		Decay = Color3.fromRGB(30, 20, 35),
		Glare = 0,
		Haze = 1.5,
	},
	ColorCorrection = {
		Saturation = -0.2,
		Contrast = 0.1,
		TintColor = Color3.fromRGB(235, 220, 235),
	},
}

local function titleSign(parent: Instance, c: Vector3)
	local sign = Kit.Part(parent, {
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
end

-- parent 아래에 로비를 만들고 { SpawnCFrame } 을 반환
function Lobby.Build(parent: Instance)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = parent
	local c = Config.LOBBY_POSITION

	Kit.Part(lobby, {
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
		Kit.Part(lobby, {
			Name = "Fence",
			Size = info[2],
			Position = c + info[1],
			Color = Color3.fromRGB(40, 30, 30),
			Material = Enum.Material.WoodPlanks,
		})
	end

	-- 게임 전체에서 유일한 SpawnLocation (LoadCharacterAsync 는 항상 로비에서 스폰)
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

	titleSign(lobby, c)

	for _, offset in ipairs({
		Vector3.new(-30, 0, -30),
		Vector3.new(30, 0, -30),
		Vector3.new(-30, 0, 30),
		Vector3.new(30, 0, 30),
	}) do
		Kit.Lamp(lobby, c + offset)
	end

	return {
		SpawnCFrame = CFrame.new(c + Vector3.new(0, 4, 0)),
	}
end

return Lobby
