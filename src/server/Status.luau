-- 상태 이상 관리
-- Stunned, Rooted, Repairing, Silenced, Slowed(v), Hasted(v), Invisible, Blocking, Shielded,
-- Resistant(v), Bleeding(v = 초당 피해), Undetectable, Blinded
-- 활성 상태는 캐릭터 모델 Attribute(값 = 만료 서버 시각)로 복제되어 클라이언트 HUD 에 표시됩니다.
local Visuals = require(script.Parent.Visuals)
local Net = require(script.Parent.Net)

local Status = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- 새로 걸렸을 때
local onAdd = {
	Invisible = function(data)
		Visuals.SetInvisible(data.Model, true)
	end,
	Stunned = function(data)
		Visuals.Label(data.Model, "기절!", Color3.fromRGB(255, 230, 80), 1)
	end,
	Blinded = function(data)
		Net.Send(data.Owner, "Blind", Status.Remaining(data, "Blinded"))
	end,
}

-- 이미 걸린 상태가 연장되었을 때
local onExtend = {
	Blinded = onAdd.Blinded,
}

-- 해제되었을 때
local onRemove = {
	Invisible = function(data)
		if data.Model.Parent then
			Visuals.SetInvisible(data.Model, false)
		end
	end,
}

local function replicate(data, name: string, expires: number?)
	if data.Model then
		data.Model:SetAttribute(name, expires)
	end
end

local function run(handlers, data, name: string)
	local fn = handlers[name]
	if fn then
		local ok, err = pcall(fn, data)
		if not ok then
			warn("상태 처리 오류", name, err)
		end
	end
end

-- 이미 활성 상태면 만료 시각/값은 더 큰 쪽으로 갱신
function Status.Add(data, name: string, duration: number, value: number?)
	local expires = now() + duration
	local s = data.Statuses[name]
	if s and s.Expires > now() then
		local oldExpires = s.Expires
		s.Expires = math.max(s.Expires, expires)
		if value then
			s.Value = math.max(s.Value, value)
		end
		replicate(data, name, s.Expires)
		if s.Expires > oldExpires then
			run(onExtend, data, name)
		end
		return
	end
	data.Statuses[name] = { Expires = expires, Value = value or 0 }
	replicate(data, name, expires)
	run(onAdd, data, name)
end

function Status.Has(data, name: string): boolean
	local s = data.Statuses[name]
	return s ~= nil and s.Expires > now()
end

function Status.Value(data, name: string): number
	local s = data.Statuses[name]
	if s and s.Expires > now() then
		return s.Value
	end
	return 0
end

-- 남은 시간(초), 없으면 0
function Status.Remaining(data, name: string): number
	local s = data.Statuses[name]
	if s then
		return math.max(0, s.Expires - now())
	end
	return 0
end

function Status.Remove(data, name: string)
	if data.Statuses[name] then
		data.Statuses[name] = nil
		replicate(data, name, nil)
		run(onRemove, data, name)
	end
end

-- 만료된 상태 제거
function Status.Update(data)
	local t = now()
	for name, s in pairs(data.Statuses) do
		if s.Expires <= t then
			Status.Remove(data, name)
		end
	end
end

-- 모든 상태 제거
function Status.Clear(data)
	for name in pairs(data.Statuses) do
		Status.Remove(data, name)
	end
end

return Status
