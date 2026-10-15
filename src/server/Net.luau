-- 서버 → 클라이언트 알림 헬퍼 + 리모트 요청 빈도 제한
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local State = require(script.Parent.State)

local Net = {}

-- [Player] = { [key] = 마지막 허용 시각(os.clock) }
local lastCalls: { [Player]: { [string]: number } } = {}

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

-- 살인마가 플레이어면 그에게만
function Net.Killer(kind: string, ...)
	local killer = State.GetKiller()
	if killer then
		Net.Send(killer.Owner, kind, ...)
	end
end

-- 라운드에 참가한 모든 생존자 플레이어 (생사 무관)
function Net.Survivors(kind: string, ...)
	for _, data in pairs(State.All()) do
		if data.Role == "Survivor" then
			Net.Send(data.Owner, kind, ...)
		end
	end
end

-- true = 허용 (시각 기록), false = 너무 잦은 요청
function Net.RateLimit(player: Player, key: string, interval: number): boolean
	local calls = lastCalls[player]
	if not calls then
		calls = {}
		lastCalls[player] = calls
	end
	local t = os.clock()
	local last = calls[key]
	if last and t - last < interval then
		return false
	end
	calls[key] = t
	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastCalls[player] = nil
end)

return Net
