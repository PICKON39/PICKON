-- 클라이언트 전용 연출
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local Effects = {}

local flash: Frame

function Effects.Init(gui: ScreenGui)
	flash = UI.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Active = false,
		Parent = gui,
	})
end

local function pulse(color: Color3, strength: number, duration: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

function Effects.HitFlash()
	pulse(Color3.fromRGB(255, 0, 0), 0.45, 0.5)
end

function Effects.HitConfirm()
	pulse(Color3.fromRGB(255, 255, 255), 0.12, 0.15)
end

function Effects.LastManStanding()
	pulse(Color3.fromRGB(180, 0, 0), 0.7, 2)
end

-- 벽 너머로 모델을 보여준다
function Effects.Reveal(model: Model?, duration: number?)
	if not model or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 40, 40)
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.FillTransparency = 0.4
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = model
	h.Parent = workspace.CurrentCamera
	Debris:AddItem(h, duration or 5)
end

return Effects
