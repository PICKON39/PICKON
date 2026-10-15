-- 이동속도 / 달리기 / 스태미나 (서버 권위, 봇 포함)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local Status = require(script.Parent.Status)

local Movement = {}

-- 움직일 수 없게 만드는 상태
local IMMOBILE = { "Stunned", "Rooted", "Repairing" }

local function immobile(data): boolean
	for _, name in ipairs(IMMOBILE) do
		if Status.Has(data, name) then
			return true
		end
	end
	return false
end

local function step(data, dt: number)
	Status.Update(data)

	local def = data.Def
	local vel = data.Root.AssemblyLinearVelocity
	local moving = Vector3.new(vel.X, 0, vel.Z).Magnitude > 2
	local sprinting = data.Sprinting and moving and not data.Exhausted and data.Stamina > 0

	if sprinting then
		data.Stamina = math.max(0, data.Stamina - Config.STAMINA_DRAIN * dt)
		if data.Stamina <= 0 then
			data.Exhausted = true
		end
	else
		data.Stamina = math.min(data.MaxStamina, data.Stamina + Config.STAMINA_REGEN * dt)
		if data.Exhausted and data.Stamina >= data.MaxStamina * Config.EXHAUST_RECOVER_RATIO then
			data.Exhausted = false
		end
	end

	local speed = sprinting and def.SprintSpeed or def.WalkSpeed
	if immobile(data) then
		speed = 0
	else
		speed *= (1 - Status.Value(data, "Slowed")) * (1 + Status.Value(data, "Hasted"))
	end
	if math.abs(data.Humanoid.WalkSpeed - speed) > 0.05 then
		data.Humanoid.WalkSpeed = speed
	end

	if not data.IsBot then
		local rounded = math.floor(data.Stamina + 0.5)
		if data.Vars._sentStamina ~= rounded then
			data.Vars._sentStamina = rounded
			data.Owner:SetAttribute("Stamina", rounded)
		end
	end
end

function Movement.Init()
	Remotes.SetSprint.OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" then
			return
		end
		local data = State.Get(player)
		if data then
			data.Sprinting = on
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, data in pairs(State.All()) do
			if State.IsAlive(data) then
				step(data, dt)
			end
		end
	end)
end

return Movement
