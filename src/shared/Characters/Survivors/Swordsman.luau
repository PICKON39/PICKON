-- 검객: 검으로 살인마에게 맞선다
return {
	Id = "Swordsman",
	Order = 5,
	Price = 400,
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
}
