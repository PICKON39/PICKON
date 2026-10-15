-- 게임 전체 밸런스 / 진행 설정값
local Config = {
	-- 진행
	MIN_PLAYERS = 1, -- 1명이면 봇 살인마와 대결 (테스트용)
	BOT_KILLER_WHEN_SOLO = true,
	INTERMISSION_TIME = 20,
	ROUND_TIME = 240,
	ROUND_END_TIME = 8,
	LAST_MAN_STANDING_TIME = 60,

	-- 발전기
	GENERATOR_COUNT = 5,
	GENERATOR_STEPS = 4, -- 발전기 하나당 퍼즐 단계 수
	GENERATOR_STEP_COOLDOWN = 1.2,
	GENERATOR_TIME_REDUCTION = 25, -- 발전기 하나 완료 시 줄어드는 라운드 시간(초)
	GENERATOR_REPAIR_RANGE = 10,

	-- 스태미나
	STAMINA_DRAIN = 12, -- 초당 소모량
	STAMINA_REGEN = 18, -- 초당 회복량
	EXHAUST_RECOVER_RATIO = 0.35, -- 탈진 후 이 비율만큼 회복되어야 다시 달릴 수 있음

	-- 살인마 선정
	MALICE_MIN = 1,
	MALICE_MAX = 3,

	-- 기본 캐릭터
	DEFAULT_SURVIVOR = "Runner",
	DEFAULT_KILLER = "Hollow",

	-- 맵
	ARENA_SIZE = 260,
	LOBBY_POSITION = Vector3.new(0, 0, 500),
}

return Config
