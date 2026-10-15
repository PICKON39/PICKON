-- 생존자 / 살인마 캐릭터 정의
-- Abilities 의 Id 는 서버 AbilityService 의 핸들러 이름과 일치해야 합니다.
local Characters = {}

Characters.Survivors = {
	Runner = {
		Id = "Runner",
		DisplayName = "러너",
		Description = "빠른 발과 넉넉한 스태미나. 도망치는 데 특화된 생존자.",
		Color = Color3.fromRGB(255, 205, 60),
		MaxHealth = 100,
		WalkSpeed = 12,
		SprintSpeed = 26,
		MaxStamina = 130,
		Abilities = {
			Q = { Id = "Adrenaline", Name = "아드레날린", Cooldown = 30, Description = "4초간 이동속도 +40%, 스태미나 40 회복" },
			E = { Id = "SixthSense", Name = "육감", Cooldown = 40, Description = "5초간 벽 너머의 살인마 위치를 본다" },
		},
	},
	Brawler = {
		Id = "Brawler",
		DisplayName = "싸움꾼",
		Description = "단단한 몸으로 공격을 막아내고 반격하는 생존자.",
		Color = Color3.fromRGB(90, 170, 255),
		MaxHealth = 120,
		WalkSpeed = 11,
		SprintSpeed = 24,
		MaxStamina = 100,
		Abilities = {
			Q = { Id = "Block", Name = "막기", Cooldown = 25, Description = "1.2초간 방어. 그 사이 맞으면 피해 무효 + 살인마 3초 기절" },
			E = { Id = "Punch", Name = "주먹", Cooldown = 30, Description = "전방을 강타해 살인마를 1.75초 기절" },
		},
	},
	Medic = {
		Id = "Medic",
		DisplayName = "의무병",
		Description = "동료를 치료하고 사기를 북돋는 지원형 생존자.",
		Color = Color3.fromRGB(110, 230, 120),
		MaxHealth = 90,
		WalkSpeed = 12,
		SprintSpeed = 25,
		MaxStamina = 110,
		Abilities = {
			Q = { Id = "Medkit", Name = "구급상자", Cooldown = 35, Description = "가까운 동료를 35 치료 (없으면 자신 25)" },
			E = { Id = "Rally", Name = "격려", Cooldown = 40, Description = "주변 생존자 모두 6초간 이동속도 +25%" },
		},
	},
	Gunslinger = {
		Id = "Gunslinger",
		DisplayName = "총잡이",
		Description = "동전으로 운을 모아 한 발에 거는 도박사.",
		Color = Color3.fromRGB(230, 120, 60),
		MaxHealth = 85,
		WalkSpeed = 12,
		SprintSpeed = 25,
		MaxStamina = 100,
		Abilities = {
			Q = { Id = "CoinFlip", Name = "동전 던지기", Cooldown = 4, Description = "앞면이면 행운 충전 +1 (최대 3)", ShowCharges = true },
			E = { Id = "Shoot", Name = "사격", Cooldown = 40, Description = "충전이 많을수록 명중률↑. 명중 시 살인마 3.5초 기절, 실패하면 오발" },
		},
	},
	Swordsman = {
		Id = "Swordsman",
		DisplayName = "검객",
		Description = "검 한 자루로 살인마에게 맞서는 용감한 생존자.",
		Color = Color3.fromRGB(200, 200, 220),
		MaxHealth = 100,
		WalkSpeed = 12,
		SprintSpeed = 25,
		MaxStamina = 100,
		Abilities = {
			Q = { Id = "Slash", Name = "베기", Cooldown = 30, Description = "전방을 베어 살인마를 2.25초 기절" },
			E = { Id = "Chicken", Name = "치킨", Cooldown = 50, Description = "3초 동안 먹으며 체력 30 회복 (먹는 동안 느려짐)" },
		},
	},
	Phantom = {
		Id = "Phantom",
		DisplayName = "유령",
		Description = "모습을 감추고 분신으로 살인마를 속이는 생존자.",
		Color = Color3.fromRGB(170, 120, 255),
		MaxHealth = 90,
		WalkSpeed = 12,
		SprintSpeed = 25,
		MaxStamina = 110,
		Abilities = {
			Q = { Id = "Cloak", Name = "은신", Cooldown = 35, Description = "5초간 투명해지고 이동속도 +15%" },
			E = { Id = "Decoy", Name = "분신", Cooldown = 40, Description = "앞으로 달려가는 분신을 만든다. 살인마가 때리면 둔화" },
		},
	},
}

Characters.Killers = {
	Hollow = {
		Id = "Hollow",
		DisplayName = "할로우",
		Description = "오류로 뒤틀린 존재. 부패의 가시와 순간이동으로 생존자를 몰아붙인다.",
		Color = Color3.fromRGB(255, 40, 40),
		BodyColor = Color3.fromRGB(18, 18, 22),
		WalkSpeed = 12,
		SprintSpeed = 27,
		MaxStamina = 110,
		AttackDamage = 30,
		AttackRange = 6,
		AttackCooldown = 1.1,
		Abilities = {
			Q = { Id = "CorruptSpikes", Name = "부패의 가시", Cooldown = 20, Description = "전방 일직선으로 가시를 솟게 해 피해 20 + 둔화" },
			E = { Id = "GlitchStep", Name = "글리치 스텝", Cooldown = 25, Description = "전방으로 최대 20칸 순간이동" },
		},
	},
	Butcher = {
		Id = "Butcher",
		DisplayName = "도살자",
		Description = "멈추지 않는 추격자. 분노로 속도를 올리고 돌진해 내려찍는다.",
		Color = Color3.fromRGB(255, 140, 40),
		BodyColor = Color3.fromRGB(60, 40, 30),
		WalkSpeed = 12,
		SprintSpeed = 27,
		MaxStamina = 120,
		AttackDamage = 25,
		AttackRange = 6,
		AttackCooldown = 0.9,
		Abilities = {
			Q = { Id = "Rage", Name = "분노", Cooldown = 35, Description = "5초간 이동속도 +30%" },
			E = { Id = "Lunge", Name = "돌진", Cooldown = 15, Description = "앞으로 돌진해 부딪힌 생존자에게 피해 30. 빗나가면 잠시 둔화" },
		},
	},
	Watcher = {
		Id = "Watcher",
		DisplayName = "감시자",
		Description = "모든 것을 지켜보는 자. 감염을 퍼뜨리고 칼날을 던진다.",
		Color = Color3.fromRGB(80, 255, 120),
		BodyColor = Color3.fromRGB(25, 30, 25),
		WalkSpeed = 11,
		SprintSpeed = 26,
		MaxStamina = 110,
		AttackDamage = 25,
		AttackRange = 6.5,
		AttackCooldown = 1.0,
		Abilities = {
			Q = { Id = "MassInfection", Name = "대량 감염", Cooldown = 40, Description = "잠시 후 주변 22칸에 피해 15 + 3초 둔화" },
			E = { Id = "HurledBlade", Name = "칼날 투척", Cooldown = 18, Description = "칼날을 던져 처음 맞은 생존자에게 피해 25 + 둔화" },
		},
	},
}

Characters.SurvivorOrder = { "Runner", "Brawler", "Medic", "Gunslinger", "Swordsman", "Phantom" }
Characters.KillerOrder = { "Hollow", "Butcher", "Watcher" }

function Characters.Get(role: string, id: string?)
	if typeof(id) ~= "string" then
		return nil
	end
	if role == "Killer" then
		return Characters.Killers[id]
	end
	return Characters.Survivors[id]
end

return Characters
