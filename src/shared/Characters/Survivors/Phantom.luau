-- 유령: 은신과 분신으로 살인마를 속인다
return {
	Id = "Phantom",
	Order = 6,
	Price = 600,
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
}
