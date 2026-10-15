-- 감시자: 감염과 칼날 투척
return {
	Id = "Watcher",
	Order = 3,
	Price = 1000,
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
		Q = {
			Id = "MassInfection",
			Name = "대량 감염",
			Cooldown = 40,
			Description = "잠시 후 주변 22칸에 피해 15 + 3초 둔화",
		},
		E = {
			Id = "HurledBlade",
			Name = "칼날 투척",
			Cooldown = 18,
			Description = "칼날을 던져 처음 맞은 생존자에게 피해 25 + 둔화",
		},
	},
}
