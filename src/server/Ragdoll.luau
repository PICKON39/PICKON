-- 사망 시 래그돌: Motor6D 를 BallSocketConstraint 로 바꿔 몸이 축 늘어지게 합니다.
-- (CharacterSetup 에서 Humanoid.BreakJointsOnDeath = false 로 설정되어 있어야 관절이 남아 있음)
local Ragdoll = {}

local ROOT_JOINTS = { Root = true, RootJoint = true }

local function convert(motor: Motor6D)
	local part0, part1 = motor.Part0, motor.Part1
	if not part0 or not part1 then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "RagdollAttachment0"
	a0.CFrame = motor.C0
	a0.Parent = part0
	local a1 = Instance.new("Attachment")
	a1.Name = "RagdollAttachment1"
	a1.CFrame = motor.C1
	a1.Parent = part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "RagdollSocket"
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	socket.LimitsEnabled = true
	socket.UpperAngle = 60
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -45
	socket.TwistUpperAngle = 45
	socket.Parent = part0

	motor.Enabled = false
end

function Ragdoll.Apply(model: Model?)
	if not model or not model.Parent then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.RequiresNeck = false
			hum.BreakJointsOnDeath = false
		end)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and not ROOT_JOINTS[d.Name] then
			local ok, err = pcall(convert, d)
			if not ok then
				warn("래그돌 관절 변환 실패:", d:GetFullName(), err)
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			pcall(function()
				if d.Name == "HumanoidRootPart" then
					d.CanCollide = false
				elseif d.Parent == model and not d.Massless then
					-- 팔다리 / 몸통만 충돌 (장식 파트는 그대로)
					d.CanCollide = true
				end
			end)
		end
	end
end

return Ragdoll
