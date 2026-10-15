-- 러너: 빠른 발과 넉넉한 스태미나
return {
	Id = "Runner",
	Order = 1,
	Price = 0,
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
}
