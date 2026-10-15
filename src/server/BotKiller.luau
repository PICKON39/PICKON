-- 혼자 접속했을 때 사용하는 간단한 AI 살인마
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local State = require(script.Parent.State)
local Status = require(script.Parent.Status)
local Combat = require(script.Parent.Combat)
local AbilityService = require(script.Parent.AbilityService)
local CharacterSetup = require(script.Parent.CharacterSetup)
local Visuals = require(script.Parent.Visuals)

local BotKiller = {}

local current = nil

local function nearestSurvivor(data)
	local best, bestDist = nil, math.huge
	for _, s in ipairs(State.AliveList("Survivor")) do
		if not Status.Has(s, "Invisible") then
			local dist = (s.Root.Position - data.Root.Position).Magnitude
			if dist < bestDist then
				best, bestDist = s, dist
			end
		end
	end
	return best, bestDist
end

local function hasLineOfSight(data, target): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { data.Model, target.Model, Visuals.Folder }
	local from = data.Root.Position
	return workspace:Raycast(from, target.Root.Position - from, params) == nil
end

local function face(data, position: Vector3)
	local root = data.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function think(data, session)
	local hum: Humanoid = data.Humanoid
	local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false })
	local waypoints, wpIndex, lastPath = nil, 1, 0
	local wanderTarget, lastWander = nil, 0
	local runTrack = Visuals.LoadRunAnimation(hum)

	while current == session and State.IsAlive(data) do
		local vel = data.Root.AssemblyLinearVelocity
		local moving = Vector3.new(vel.X, 0, vel.Z).Magnitude > 1
		if runTrack then
			if moving and not runTrack.IsPlaying then
				runTrack:Play()
			elseif not moving and runTrack.IsPlaying then
				runTrack:Stop()
			end
		end

		local target, dist = nearestSurvivor(data)
		if target and not Status.Has(data, "Stunned") then
			data.Sprinting = dist < 70
			local tpos = target.Root.Position

			if dist <= data.Def.AttackRange + 1.5 then
				face(data, tpos)
				Combat.KillerAttack(data)
			elseif dist < 22 and math.random() < 0.06 then
				face(data, tpos)
				AbilityService.Use(data, "Q")
			elseif dist > 10 and dist < 35 and math.random() < 0.05 and hasLineOfSight(data, target) then
				face(data, tpos)
				AbilityService.Use(data, "E")
			end

			if hasLineOfSight(data, target) then
				waypoints = nil
				hum:MoveTo(tpos)
			else
				if not waypoints or os.clock() - lastPath > 1 then
					lastPath = os.clock()
					local ok = pcall(function()
						path:ComputeAsync(data.Root.Position, tpos)
					end)
					if ok and path.Status == Enum.PathStatus.Success then
						waypoints = path:GetWaypoints()
						wpIndex = math.min(2, #waypoints)
					else
						waypoints = nil
						hum:MoveTo(tpos)
					end
				end
				if waypoints and waypoints[wpIndex] then
					local wp = waypoints[wpIndex].Position
					if (Vector3.new(wp.X, 0, wp.Z) - Vector3.new(data.Root.Position.X, 0, data.Root.Position.Z)).Magnitude < 3 then
						wpIndex += 1
					end
					if waypoints[wpIndex] then
						hum:MoveTo(waypoints[wpIndex].Position)
					end
				end
			end
		elseif not target then
			-- 목표가 없으면 배회
			data.Sprinting = false
			if not wanderTarget or os.clock() - lastWander > 5 then
				lastWander = os.clock()
				wanderTarget = Vector3.new(math.random(-100, 100), 0, math.random(-100, 100))
				hum:MoveTo(wanderTarget)
			end
		end
		task.wait(0.15)
	end
	if runTrack then
		runTrack:Stop()
	end
end

function BotKiller.Spawn(def, cframe: CFrame)
	BotKiller.Despawn()
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = def.DisplayName .. " (봇)"
	model:PivotTo(cframe)
	model.Parent = workspace
	CharacterSetup.Apply(model, "Killer", def)

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local owner = { IsBot = true, Name = model.Name }
	local data = State.Create(owner, "Killer", def, model)
	local session = { Data = data, Model = model }
	current = session
	task.spawn(think, data, session)
	return data
end

function BotKiller.Despawn()
	if current then
		State.Remove(current.Data.Owner)
		current.Model:Destroy()
		current = nil
	end
end

return BotKiller
