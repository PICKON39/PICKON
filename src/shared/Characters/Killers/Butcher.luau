-- 도살자: 분노와 돌진
return {
	Id = "Butcher",
	Order = 2,
	Price = 0,
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
		E = {
			Id = "Lunge",
			Name = "돌진",
			Cooldown = 15,
			Description = "앞으로 돌진해 부딪힌 생존자에게 피해 30. 빗나가면 잠시 둔화",
		},
	},
}
