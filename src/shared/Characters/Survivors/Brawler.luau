-- 싸움꾼: 공격을 막아내고 반격
return {
	Id = "Brawler",
	Order = 2,
	Price = 0,
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
}
