-- 생존자 / 살인마 캐릭터 정의 모음
-- 각 캐릭터는 Survivors / Killers 폴더 안의 ModuleScript 하나 (모듈 이름 = Id).
-- Abilities 의 Id 는 서버 Abilities/<역할>/<Id> 모듈의 핸들러 이름과 일치해야 합니다.
local Characters = {}

Characters.Survivors = {}
Characters.Killers = {}
Characters.SurvivorOrder = {} :: { string }
Characters.KillerOrder = {} :: { string }

local function load(folder: Instance?, into, order: { string })
	if not folder then
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, def = pcall(require, child)
			if not ok then
				warn("캐릭터 정의 로드 실패:", child.Name, def)
			elseif type(def) ~= "table" or def.Id ~= child.Name then
				warn("캐릭터 정의의 Id 가 모듈 이름과 다름:", child.Name)
			else
				into[def.Id] = def
				table.insert(order, def.Id)
			end
		end
	end
	-- Order 순, 같으면 Id 순
	table.sort(order, function(a, b)
		local oa, ob = into[a].Order or math.huge, into[b].Order or math.huge
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
end

load(script:FindFirstChild("Survivors"), Characters.Survivors, Characters.SurvivorOrder)
load(script:FindFirstChild("Killers"), Characters.Killers, Characters.KillerOrder)

function Characters.Get(role: string, id: any)
	if typeof(id) ~= "string" then
		return nil
	end
	if role == "Killer" then
		return Characters.Killers[id]
	end
	return Characters.Survivors[id]
end

-- 가격이 0(또는 없음)이면 무료 캐릭터
function Characters.IsFree(def): boolean
	return def ~= nil and (def.Price or 0) <= 0
end

return Characters
