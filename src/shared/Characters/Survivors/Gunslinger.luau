-- 총잡이: 동전으로 운을 모아 한 발에 건다
return {
	Id = "Gunslinger",
	Order = 4,
	Price = 500,
	DisplayName = "총잡이",
	Description = "동전으로 운을 모아 한 발에 거는 도박사.",
	Color = Color3.fromRGB(230, 120, 60),
	MaxHealth = 85,
	WalkSpeed = 12,
	SprintSpeed = 25,
	MaxStamina = 100,
	Abilities = {
		Q = {
			Id = "CoinFlip",
			Name = "동전 던지기",
			Cooldown = 4,
			Description = "앞면이면 행운 충전 +1 (최대 3)",
			MaxCharges = 3,
		},
		E = {
			Id = "Shoot",
			Name = "사격",
			Cooldown = 40,
			Description = "충전이 많을수록 명중률↑. 명중 시 살인마 3.5초 기절, 실패하면 오발",
		},
	},
}
