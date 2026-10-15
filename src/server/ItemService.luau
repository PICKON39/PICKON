-- 아이템 서비스 (임시 껍데기)
-- 맵의 ItemSpots 에 아이템을 배치하고 줍기 / 사용을 처리하는 실제 구현은 ITEMS 트랙에서 작성합니다.
local ItemService = {}

function ItemService.Init() end

-- 라운드 시작 시 map.ItemSpots 에 아이템 배치 (미구현)
function ItemService.Spawn(_map) end

-- 라운드 종료 시 아이템 정리 (미구현)
function ItemService.Clear() end

return ItemService
