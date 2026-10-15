-- 게임 전체 밸런스 / 진행 설정값
local Config = {
	-- 진행
	MIN_PLAYERS = 1, -- 이 인원 이상이면 라운드 시작 (1명이면 봇과 대결)
	SOLO_BOTS = true, -- 혼자일 때 봇으로 상대/동료를 채움
	SOLO_BOT_SURVIVORS = 4, -- 혼자 살인마를 할 때 생성할 봇 생존자 수
	FILL_SURVIVOR_BOTS_TO = 0, -- 2명 이상일 때 생존자가 이 수가 되도록 봇 추가 (0 = 사용 안 함)
	INTERMISSION_TIME = 20,
	KILLER_RELEASE_DELAY = 6, -- 라운드 시작 후 살인마가 묶여 있는 시간
	ROUND_TIME_BASE = 150,
	ROUND_TIME_PER_SURVIVOR = 20,
	ROUND_TIME_MAX = 300,
	ROUND_END_TIME = 12,
	LAST_MAN_STANDING_TIME = 60,
	KILL_TIME_BONUS = 15, -- 생존자가 쓰러질 때 늘어나는 라운드 시간(초)

	-- 발전기
	GENERATOR_COUNT_BASE = 2, -- 발전기 수 = 기본값 + 생존자 수
	GENERATOR_COUNT_MAX = 6,
	GENERATOR_STEPS = 4, -- 발전기 하나당 퍼즐 단계 수
	GENERATOR_TIME_REDUCTION = 20, -- 발전기 하나 완료 시 줄어드는 라운드 시간(초)
	GENERATOR_REPAIR_RANGE = 10,
	GENERATOR_MIN_SOLVE_TIME = 1.2, -- 퍼즐 한 단계를 푸는 데 필요한 최소 시간(초)
	GENERATOR_NOTIFY_KILLER = true, -- 단계 완료 시 살인마에게 위치 알림
	FLOW_GRID_SIZE = 5,
	FLOW_PAIRS = 4,
	BOT_REPAIR_STEP_TIME = 8, -- 봇이 한 단계를 수리하는 데 걸리는 시간(초)

	-- 스태미나 / 이동
	STAMINA_DRAIN = 12, -- 초당 소모량
	STAMINA_REGEN = 18, -- 초당 회복량
	EXHAUST_RECOVER_RATIO = 0.35, -- 탈진 후 이 비율만큼 회복되어야 다시 달릴 수 있음
	HIT_HASTE = 0.3, -- 맞은 생존자의 일시 가속 비율
	HIT_HASTE_TIME = 1.5,

	-- 살인마 선정
	MALICE_MIN = 1,
	MALICE_MAX = 3,

	-- 아이템
	ITEM_COUNT = 6,
	MAX_ITEMS_HELD = 2,

	-- 경제 / 저장
	START_MONEY = 0,
	UNLOCK_ALL_IN_STUDIO = true, -- 스튜디오에서는 모든 캐릭터 해금
	DATASTORE_NAME = "AbandonedData_v1",
	AUTOSAVE_INTERVAL = 120,
	Rewards = {
		Participation = 10,
		Survive = 60,
		SurvivorWin = 30,
		GeneratorStep = 6,
		Stun = 15,
		HealPer10 = 4,
		Kill = 30,
		KillerWin = 80,
		DamagePer10 = 2,
	},

	-- 기본 캐릭터
	DEFAULT_SURVIVOR = "Runner",
	DEFAULT_KILLER = "Hollow",

	-- 위치
	LOBBY_POSITION = Vector3.new(0, 0, 1200),

	-- 공포 반경 (클라이언트 연출)
	TERROR_RADIUS = 70,
	CHASE_RADIUS = 28,

	-- 디버그
	DEBUG = false,
}

return Config
