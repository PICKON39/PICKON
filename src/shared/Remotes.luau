-- 서버에서는 RemoteEvent 를 생성하고, 클라이언트에서는 기다렸다가 가져옵니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"SetSprint", -- C→S (bool)
	"UseAbility", -- C→S ("Q" | "E")
	"Attack", -- C→S (살인마 기본 공격)
	"SelectCharacter", -- C→S ("Survivor" | "Killer", id)
	"GeneratorStep", -- C→S (generatorId)
	"GeneratorCancel", -- C→S
	"Notify", -- S→C (kind, ...)
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in ipairs(NAMES) do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
