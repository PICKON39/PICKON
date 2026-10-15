-- BotService: 봇 살인마 / 봇 생존자 생성과 정리
-- 각 봇은 세션 { Active, Data, Model } 을 가지며, 두뇌 모듈의 Run(data, session, map) 이 별도 스레드에서 돈다.
-- session.Active 가 false 가 되거나 봇이 죽으면 두뇌 루프가 끝납니다.
local Players = game:GetService("Players")

local Server = script.Parent
local State = require(Server.State)
local CharacterSetup = require(Server.CharacterSetup)
local AbilityService = require(Server.Abilities)
local KillerBrain = require(script.KillerBrain)
local SurvivorBrain = require(script.SurvivorBrain)

local BotService = {}

local SKIN = Color3.fromRGB(234, 184, 146)

local sessions = {} -- [session] = true

local function makeDescription(role: string, def): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	if role == "Survivor" and typeof(def.Color) == "Color3" then
		local color: Color3 = def.Color
		local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
		desc.HeadColor = SKIN
		desc.TorsoColor = color
		desc.LeftArmColor = SKIN
		desc.RightArmColor = SKIN
		desc.LeftLegColor = dark
		desc.RightLegColor = dark
	end
	return desc
end

local function buildModel(role: string, def, cframe: CFrame, owner): Model
	local model = Players:CreateHumanoidModelFromDescription(makeDescription(role, def), Enum.HumanoidRigType.R15)
	local ok, err = pcall(function()
		model.Name = owner.DisplayName
		model:SetAttribute("Bot", true)
		model:PivotTo(cframe)
		model.Parent = workspace
		CharacterSetup.Apply(model, role, def)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
		end
	end)
	if not ok then
		model:Destroy()
		error(err, 0)
	end
	return model
end

local function spawnBot(role: string, def, cframe: CFrame, map, owner, brain)
	local model = buildModel(role, def, cframe, owner)
	local data = State.Create(owner, role, def, model)
	local session = { Active = true, Data = data, Model = model, Owner = owner }
	sessions[session] = true

	local ok, err = pcall(AbilityService.Attach, data)
	if not ok then
		warn("봇 능력 연결 실패:", owner.Name, err)
	end

	task.spawn(function()
		local runOk, runErr = pcall(brain.Run, data, session, map)
		if not runOk then
			warn("봇 AI 종료 (오류):", owner.Name, runErr)
		end
	end)
	return data
end

local function makeOwner(name: string, displayName: string)
	return { IsBot = true, Name = name, DisplayName = displayName, UserId = 0 }
end

function BotService.SpawnKiller(def, cframe: CFrame, map)
	local owner = makeOwner("BotKiller", ("%s (봇)"):format(def.DisplayName or def.Id))
	return spawnBot("Killer", def, cframe, map, owner, KillerBrain)
end

function BotService.SpawnSurvivor(def, cframe: CFrame, map, index: number)
	local owner = makeOwner(("BotSurvivor%d"):format(index), ("%s (봇 %d)"):format(def.DisplayName or def.Id, index))
	return spawnBot("Survivor", def, cframe, map, owner, SurvivorBrain)
end

-- 살아 있는 봇 세션 목록
function BotService.Sessions()
	local list = {}
	for session in pairs(sessions) do
		table.insert(list, session)
	end
	return list
end

-- 모든 봇의 두뇌를 멈추고 모델과 State 항목을 제거
function BotService.DespawnAll()
	for session in pairs(sessions) do
		session.Active = false
		if State.Get(session.Owner) == session.Data then
			State.Remove(session.Owner)
		end
		pcall(function()
			session.Model:Destroy()
		end)
	end
	table.clear(sessions)
end

return BotService
