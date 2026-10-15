-- 상태 이상 관리: Stunned, Slowed, Hasted, Rooted, Blocking, Invisible
-- 활성 상태는 캐릭터 모델 Attribute 로도 복제되어 클라이언트 HUD 에 표시됩니다.
local Visuals = require(script.Parent.Visuals)

local Status = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local onAdd = {
	Invisible = function(data)
		Visuals.SetInvisible(data.Model, true)
	end,
	Stunned = function(data)
		Visuals.Label(data.Model, "기절!", Color3.fromRGB(255, 230, 80), 1)
	end,
}

local onRemove = {
	Invisible = function(data)
		if data.Model.Parent then
			Visuals.SetInvisible(data.Model, false)
		end
	end,
}

function Status.Add(data, name: string, duration: number, value: number?)
	local expires = now() + duration
	local s = data.Statuses[name]
	if s then
		s.Expires = math.max(s.Expires, expires)
		if value then
			s.Value = value
		end
	else
		data.Statuses[name] = { Expires = expires, Value = value or 0 }
		if onAdd[name] then
			onAdd[name](data)
		end
	end
	if data.Model then
		data.Model:SetAttribute(name, true)
	end
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

function Status.Remove(data, name: string)
	if data.Statuses[name] then
		data.Statuses[name] = nil
		if data.Model then
			data.Model:SetAttribute(name, nil)
		end
		if onRemove[name] then
			onRemove[name](data)
		end
	end
end

function Status.Update(data)
	local t = now()
	for name, s in pairs(data.Statuses) do
		if s.Expires <= t then
			Status.Remove(data, name)
		end
	end
end

return Status
