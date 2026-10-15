-- 봇 이동 도우미: 경로 탐색(PathfindingService) 추적, 끼임 감지, 달리기 애니메이션
local PathfindingService = game:GetService("PathfindingService")

local Server = script.Parent.Parent
local Combat = require(Server.Combat)
local Visuals = require(Server.Visuals)

local Nav = {}
Nav.__index = Nav

local REPATH_INTERVAL = 1 -- 경로 재계산 간격(초)
local GOAL_MOVED = 4 -- 목표가 이만큼 움직이면 경로 재계산
local WAYPOINT_REACHED = 3
local STUCK_TIME = 1.5 -- 이 시간 동안 거의 못 움직이면 끼인 것으로 판단
local FORCE_PATH_TIME = 2.5 -- 끼였을 때 직선 이동 대신 경로 탐색을 강제하는 시간

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
Nav.FlatDistance = flatDist

function Nav.new(data)
	local self = setmetatable({}, Nav)
	self.Data = data
	self.Path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false })
	self.Waypoints = nil
	self.Index = 1
	self.PathGoal = nil
	self.LastPath = 0
	self.LastProgress = os.clock()
	self.LastPos = data.Root.Position
	self.ForcePathUntil = 0
	self.RunTrack = Visuals.LoadRunAnimation(data.Humanoid)
	return self
end

-- 수평으로 position 을 바라보게 회전
function Nav.Face(data, position: Vector3)
	local root = data.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- 벽에 가리지 않고 직선으로 볼 수 있는지 (캐릭터 / 이펙트는 무시)
function Nav.ClearLine(from: Vector3, to: Vector3): boolean
	local dir = to - from
	if dir.Magnitude < 0.1 then
		return true
	end
	return Combat.CastWalls(from, dir) == nil
end

function Nav:UpdateStuck(moving: boolean)
	local pos = self.Data.Root.Position
	local t = os.clock()
	if not moving or flatDist(pos, self.LastPos) > 1 then
		self.LastPos = pos
		self.LastProgress = t
	elseif t - self.LastProgress > STUCK_TIME then
		-- 끼였음: 잠시 경로 탐색을 강제하고 경로를 새로 계산
		self.LastPos = pos
		self.LastProgress = t
		self.ForcePathUntil = t + FORCE_PATH_TIME
		self.Waypoints = nil
	end
end

local function computePath(self, goal: Vector3)
	self.LastPath = os.clock()
	self.PathGoal = goal
	local ok = pcall(function()
		self.Path:ComputeAsync(self.Data.Root.Position, goal)
	end)
	if ok and self.Path.Status == Enum.PathStatus.Success then
		self.Waypoints = self.Path:GetWaypoints()
		self.Index = math.min(2, #self.Waypoints)
	else
		self.Waypoints = nil
	end
end

-- goal 로 이동. 직선 시야가 있으면 바로 걷고, 없으면 경로를 따라갑니다.
function Nav:MoveTo(goal: Vector3)
	local data = self.Data
	local hum: Humanoid = data.Humanoid
	local pos = data.Root.Position
	local t = os.clock()
	self:UpdateStuck(true)

	local direct = t >= self.ForcePathUntil and Nav.ClearLine(pos, Vector3.new(goal.X, pos.Y, goal.Z))
	if direct then
		self.Waypoints = nil
		hum:MoveTo(goal)
		return
	end

	local goalMoved = not self.PathGoal or flatDist(self.PathGoal, goal) > GOAL_MOVED
	if not self.Waypoints or (goalMoved and t - self.LastPath > REPATH_INTERVAL) then
		computePath(self, goal)
	end
	local waypoints = self.Waypoints
	if not waypoints then
		hum:MoveTo(goal)
		return
	end
	local wp = waypoints[self.Index]
	if wp and flatDist(wp.Position, pos) < WAYPOINT_REACHED then
		self.Index += 1
		wp = waypoints[self.Index]
	end
	if wp then
		hum:MoveTo(wp.Position)
	else
		self.Waypoints = nil
		hum:MoveTo(goal)
	end
end

function Nav:Stop()
	self.Waypoints = nil
	local root = self.Data.Root
	self.Data.Humanoid:MoveTo(root.Position)
	self:UpdateStuck(false)
end

-- 이동 중이면 달리기 애니메이션 재생
function Nav:Animate()
	local track = self.RunTrack
	if not track then
		return
	end
	local vel = self.Data.Root.AssemblyLinearVelocity
	local moving = Vector3.new(vel.X, 0, vel.Z).Magnitude > 1
	if moving and not track.IsPlaying then
		track:Play()
	elseif not moving and track.IsPlaying then
		track:Stop()
	end
end

function Nav:Destroy()
	if self.RunTrack then
		pcall(function()
			self.RunTrack:Stop()
		end)
	end
end

return Nav
