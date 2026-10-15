-- 간단한 UI 생성 헬퍼
local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(18, 16, 24),
	PanelLight = Color3.fromRGB(38, 34, 48),
	Text = Color3.fromRGB(235, 230, 240),
	SubText = Color3.fromRGB(160, 155, 170),
	Accent = Color3.fromRGB(220, 40, 50),
	Health = Color3.fromRGB(220, 60, 60),
	Stamina = Color3.fromRGB(240, 200, 70),
	Good = Color3.fromRGB(90, 230, 120),
}

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UI.stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or Color3.fromRGB(70, 60, 80),
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	return UI.new("TextLabel", defaults)
end

function UI.button(props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = UI.Colors.PanelLight,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	local b = UI.new("TextButton", defaults)
	UI.corner(8).Parent = b
	return b
end

-- 배경 + 채움 바. 반환값: (frame, setRatio(ratio, text))
function UI.bar(parent: Instance, position: UDim2, size: UDim2, color: Color3)
	local bg = UI.new("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(30, 28, 36),
		Parent = parent,
	}, { UI.corner(6) })
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		Parent = bg,
	}, { UI.corner(6) })
	local text = UI.label({
		Size = UDim2.fromScale(1, 1),
		TextScaled = false,
		TextSize = 14,
		ZIndex = 2,
		Parent = bg,
	})
	local function set(ratio: number, label: string?)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		text.Text = label or ""
	end
	return bg, set, fill
end

return UI
