-- 작은 순수 헬퍼 함수 모음 (서버/클라이언트 공용)
local Util = {}

-- 리스트를 제자리에서 섞고 그대로 반환 (rng: Random 객체, 없으면 math.random)
function Util.Shuffle<T>(list: { T }, rng: Random?): { T }
	for i = #list, 2, -1 do
		local j = if rng then rng:NextInteger(1, i) else math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- 초 → "m:ss"
function Util.FormatTime(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(total // 60, total % 60)
end

-- Y 성분을 0으로 만든 벡터
function Util.Flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- "a,b,c" → { "a", "b", "c" } (빈 항목과 앞뒤 공백은 제거)
function Util.SplitCsv(s: string?): { string }
	local list = {}
	if type(s) ~= "string" then
		return list
	end
	for item in s:gmatch("[^,]+") do
		local trimmed = item:match("^%s*(.-)%s*$")
		if trimmed and trimmed ~= "" then
			table.insert(list, trimmed)
		end
	end
	return list
end

-- { "a", "b" } → "a,b"
function Util.JoinCsv(list: { string }): string
	return table.concat(list, ",")
end

-- 가장 가까운 정수로 반올림
function Util.Round(n: number): number
	return math.floor(n + 0.5)
end

return Util
