-- 서버 → 클라이언트 알림 헬퍼
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Net = {}

local function isPlayer(owner): boolean
	return typeof(owner) == "Instance" and owner:IsA("Player") and owner.Parent ~= nil
end

function Net.Send(owner, kind: string, ...)
	if isPlayer(owner) then
		Remotes.Notify:FireClient(owner, kind, ...)
	end
end

function Net.All(kind: string, ...)
	Remotes.Notify:FireAllClients(kind, ...)
end

function Net.Message(owner, text: string, color: Color3?, duration: number?)
	Net.Send(owner, "Message", text, color, duration)
end

function Net.MessageAll(text: string, color: Color3?, duration: number?)
	Net.All("Message", text, color, duration)
end

return Net
