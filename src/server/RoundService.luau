-- 게임 루프: 대기 → 인터미션 → 라운드 → 결과
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local State = require(script.Parent.State)
local Net = require(script.Parent.Net)
local Visuals = require(script.Parent.Visuals)
local GeneratorService = require(script.Parent.GeneratorService)
local CharacterSetup = require(script.Parent.CharacterSetup)
local BotKiller = require(script.Parent.BotKiller)

local RoundService = {}

local RED = Color3.fromRGB(255, 70, 70)
local GREEN = Color3.fromRGB(90, 255, 120)
local WHITE = Color3.new(1, 1, 1)

local timer = 0

local function setGame(state: string, t: number)
	ReplicatedStorage:SetAttribute("GameState", state)
	ReplicatedStorage:SetAttribute("Timer", t)
end

local function stat(player: Player, name: string): IntValue?
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(name) :: IntValue?
end

local function pickKiller(players: { Player }): Player
	local shuffled = table.clone(players)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local best, bestMalice = shuffled[1], -1
	for _, p in ipairs(shuffled) do
		local m = stat(p, "Malice")
		local value = m and m.Value or 0
		if value > bestMalice then
			best, bestMalice = p, value
		end
	end
	return best
end

local function chosenDef(player: Player, role: string)
	local attr = role == "Killer" and "KillerChoice" or "SurvivorChoice"
	return Characters.Get(role, player:GetAttribute(attr))
		or Characters.Get(role, role == "Killer" and Config.DEFAULT_KILLER or Config.DEFAULT_SURVIVOR)
end

local function onDeath(data)
	if not data.Alive then
		return
	end
	data.Alive = false
	if data.RepairingGen then
		data.RepairingGen = nil
		Net.Send(data.Owner, "CloseGenerator")
	end
	if not data.IsBot then
		data.Owner:SetAttribute("Role", "Spectator")
	end
	if data.Role == "Survivor" then
		Net.MessageAll(data.Owner.Name .. " 님이 쓰러졌습니다.", RED, 3)
	end
end

local function waitForAppearance(player: Player)
	if player:HasAppearanceLoaded() then
		return
	end
	local loaded = false
	local conn = player.CharacterAppearanceLoaded:Connect(function()
		loaded = true
	end)
	local t0 = os.clock()
	while not loaded and os.clock() - t0 < 3 do
		task.wait(0.1)
	end
	conn:Disconnect()
end

local function spawnPlayer(player: Player, role: string, def, cframe: CFrame)
	player:LoadCharacter()
	local model = player.Character
	if not model then
		return nil
	end
	local hum = model:WaitForChild("Humanoid", 5) :: Humanoid?
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not hum or not root then
		return nil
	end
	waitForAppearance(player)
	model:PivotTo(cframe)
	CharacterSetup.Apply(model, role, def)

	local data = State.Create(player, role, def, model)
	player:SetAttribute("Role", role)
	player:SetAttribute("CharacterId", def.Id)
	player:SetAttribute("MaxStamina", def.MaxStamina)
	player:SetAttribute("Stamina", def.MaxStamina)
	player:SetAttribute("Charges", 0)
	for _, key in ipairs({ "M1", "Q", "E" }) do
		player:SetAttribute("CD_" .. key, 0)
	end
	hum.Died:Connect(function()
		onDeath(data)
	end)
	return data
end

local function cleanup()
	BotKiller.Despawn()
	for owner in pairs(State.All()) do
		State.Remove(owner)
	end
	GeneratorService.Clear()
	Visuals.Clear()
	ReplicatedStorage:SetAttribute("KillerName", nil)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("Role", "Lobby")
		player:SetAttribute("CharacterId", nil)
		task.spawn(function()
			pcall(function()
				player:LoadCharacter()
			end)
		end)
	end
end

local function killerGone(killer): boolean
	if not killer or not State.IsAlive(killer) then
		return true
	end
	if not killer.IsBot and killer.Owner.Parent == nil then
		return true
	end
	return false
end

function RoundService.PlayRound(map)
	local players = Players:GetPlayers()
	local useBot = #players == 1 and Config.BOT_KILLER_WHEN_SOLO
	if #players == 0 or (#players < 2 and not useBot) then
		return
	end

	local killerPlayer = if useBot then nil else pickKiller(players)

	GeneratorService.Reset(Config.GENERATOR_COUNT)
	ReplicatedStorage:SetAttribute("GeneratorsTotal", GeneratorService.Total())
	ReplicatedStorage:SetAttribute("GeneratorsLeft", GeneratorService.Remaining())
	setGame("Starting", 0)

	-- 스폰
	local spawnIndex = 0
	for _, player in ipairs(players) do
		if player.Parent then
			local role = player == killerPlayer and "Killer" or "Survivor"
			local cframe
			if role == "Killer" then
				cframe = map.KillerSpawn
			else
				spawnIndex += 1
				cframe = map.SurvivorSpawns[(spawnIndex - 1) % #map.SurvivorSpawns + 1]
			end
			local ok, err = pcall(spawnPlayer, player, role, chosenDef(player, role), cframe)
			if not ok then
				warn("스폰 실패", player.Name, err)
			end
		end
	end
	if useBot then
		local id = Characters.KillerOrder[math.random(1, #Characters.KillerOrder)]
		BotKiller.Spawn(Characters.Killers[id], map.KillerSpawn)
	end

	local killer = State.GetKiller()
	local survivorsStart = State.CountAlive("Survivor")
	if not killer or survivorsStart == 0 then
		cleanup()
		return
	end

	ReplicatedStorage:SetAttribute("KillerName", killer.Def.DisplayName)
	for _, data in pairs(State.All()) do
		if data.Role == "Killer" then
			Net.Message(data.Owner, "당신은 살인마입니다. 모든 생존자를 처치하세요!", RED, 4)
		else
			Net.Message(
				data.Owner,
				("살인마 [%s] 에게서 살아남으세요! 발전기를 고치면 시간이 줄어듭니다."):format(killer.Def.DisplayName),
				WHITE,
				4
			)
		end
	end

	-- 라운드 진행
	timer = Config.ROUND_TIME
	local lastManStanding = false
	GeneratorService.OnCompleted = function()
		timer = math.max(5, timer - Config.GENERATOR_TIME_REDUCTION)
		local left = GeneratorService.Remaining()
		ReplicatedStorage:SetAttribute("GeneratorsLeft", left)
		ReplicatedStorage:SetAttribute("Timer", timer)
		Net.MessageAll(
			("발전기 수리 완료! (-%d초) 남은 발전기: %d"):format(Config.GENERATOR_TIME_REDUCTION, left),
			GREEN,
			3
		)
	end

	local result
	while true do
		local alive = State.CountAlive("Survivor")
		ReplicatedStorage:SetAttribute("SurvivorsAlive", alive)
		setGame("InRound", timer)

		if alive == 0 then
			result = "Killer"
			break
		end
		if killerGone(killer) then
			result = "Survivors"
			break
		end
		if alive == 1 and survivorsStart >= 2 and not lastManStanding then
			lastManStanding = true
			timer = math.min(timer, Config.LAST_MAN_STANDING_TIME)
			Net.All("LMS")
			Net.MessageAll("최후의 생존자! 끝까지 버텨라!", RED, 4)
			for _, s in ipairs(State.AliveList("Survivor")) do
				s.Stamina = s.MaxStamina
				s.Exhausted = false
			end
		end
		if timer <= 0 then
			result = "Survivors"
			break
		end
		task.wait(1)
		timer -= 1
	end
	GeneratorService.OnCompleted = nil

	-- 결과 / 보상
	local aliveSurvivors = State.AliveList("Survivor")
	if result == "Killer" then
		Net.MessageAll("살인마의 승리!", RED, Config.ROUND_END_TIME)
		if not killer.IsBot and killer.Owner.Parent then
			local wins = stat(killer.Owner, "Wins")
			if wins then
				wins.Value += 1
			end
		end
	else
		Net.MessageAll(("생존자의 승리! (%d명 생존)"):format(#aliveSurvivors), GREEN, Config.ROUND_END_TIME)
		for _, s in ipairs(aliveSurvivors) do
			local wins = stat(s.Owner, "Wins")
			if wins then
				wins.Value += 1
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local malice = stat(player, "Malice")
		if malice then
			if player == killerPlayer then
				malice.Value = 0
			else
				malice.Value += math.random(Config.MALICE_MIN, Config.MALICE_MAX)
			end
		end
	end

	-- 결과 화면 동안 모두 멈춤
	for _, data in pairs(State.All()) do
		data.Alive = false
		if data.Humanoid then
			data.Humanoid.WalkSpeed = 0
		end
	end
	for t = Config.ROUND_END_TIME, 1, -1 do
		setGame("RoundEnd", t)
		task.wait(1)
	end
	cleanup()
end

function RoundService.Run(map)
	while true do
		while #Players:GetPlayers() < Config.MIN_PLAYERS do
			setGame("Waiting", 0)
			task.wait(1)
		end
		for t = Config.INTERMISSION_TIME, 1, -1 do
			setGame("Intermission", t)
			task.wait(1)
		end
		if #Players:GetPlayers() >= Config.MIN_PLAYERS then
			local ok, err = pcall(RoundService.PlayRound, map)
			if not ok then
				warn("라운드 오류:", err)
				cleanup()
			end
		end
	end
end

return RoundService
