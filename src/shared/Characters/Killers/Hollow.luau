-- 할로우: 부패의 가시와 순간이동
return {
	Id = "Hollow",
	Order = 1,
	Price = 0,
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
		Q = {
			Id = "CorruptSpikes",
			Name = "부패의 가시",
			Cooldown = 20,
			Description = "전방 일직선으로 가시를 솟게 해 피해 20 + 둔화",
		},
		E = { Id = "GlitchStep", Name = "글리치 스텝", Cooldown = 25, Description = "전방으로 최대 20칸 순간이동" },
	},
}
