-- 의무병: 치료와 격려
return {
	Id = "Medic",
	Order = 3,
	Price = 0,
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
}
