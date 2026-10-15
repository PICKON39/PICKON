-- 의무병: 구급상자 / 격려
local Common = require(script.Parent.Parent.Common)
local Status, Combat, Visuals = Common.Status, Common.Combat, Common.Visuals

local GREEN = Color3.fromRGB(90, 255, 120)
local GRAY = Color3.fromRGB(200, 200, 200)

local M = { Abilities = {} }

function M.Abilities.Medkit(data)
	-- 12칸 안에서 다친 동료 중 가장 가까운 사람
	local best, bestDist = nil, math.huge
	for _, s in ipairs(Common.SurvivorsNear(data.Root.Position, 12, data)) do
		local dist = (s.Root.Position - data.Root.Position).Magnitude
		if s.Humanoid.Health < s.Humanoid.MaxHealth and dist < bestDist then
			best, bestDist = s, dist
		end
	end
	if best then
		Combat.Heal(data, best, 35)
		Visuals.Beam(data.Root.Position, best.Root.Position, GREEN)
		Common.Message(best, data.Name .. " 님이 치료해 주었다! (+35)", GREEN, 2)
		Common.Message(data, best.Name .. " 님을 치료했다.", GREEN, 2)
	elseif data.Humanoid.Health < data.Humanoid.MaxHealth then
		Combat.Heal(data, data, 25)
		Common.Message(data, "스스로 치료했다. (+25)", GREEN, 2)
	else
		Common.Message(data, "치료할 대상이 없다.", GRAY, 1.5)
		return false
	end
	return true
end

function M.Abilities.Rally(data)
	for _, s in ipairs(Common.SurvivorsNear(data.Root.Position, 18)) do
		Status.Add(s, "Hasted", 6, 0.25)
		Visuals.Highlight(s.Model, GREEN, 6, 0.8)
		if s ~= data then
			Common.Message(s, "격려를 받았다! 이동속도 증가", GREEN, 2)
		end
	end
	Visuals.Burst(data.Root.Position, GREEN, 18, 0.5)
	return true
end

return M
