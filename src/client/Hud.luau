-- Minimal combat HUD: posture, dodge charges, feint cooldown, and shift lock state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Movement = require(script.Parent.Movement)
local ShiftLock = require(script.Parent.ShiftLock)

local player = Players.LocalPlayer

local READY_COLOR = Color3.fromRGB(235, 235, 240)
local SPENT_COLOR = Color3.fromRGB(70, 70, 80)
local POSTURE_FULL_COLOR = Color3.fromRGB(120, 170, 255)
local POSTURE_LOW_COLOR = Color3.fromRGB(255, 70, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "CombatHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -24)
bar.Size = UDim2.fromOffset(260, 28)
bar.BackgroundTransparency = 1
bar.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = bar

local function makeLabel(text: string, width: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(width, 22)
	label.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	label.BackgroundTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Text = text
	label.TextColor3 = READY_COLOR
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
	label.Parent = bar
	return label
end

-- Posture: drains as your block takes hits, guard breaks when empty.
local postureBack = Instance.new("Frame")
postureBack.AnchorPoint = Vector2.new(0.5, 1)
postureBack.Position = UDim2.new(0.5, 0, 1, -60)
postureBack.Size = UDim2.fromOffset(220, 8)
postureBack.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
postureBack.BackgroundTransparency = 0.3
postureBack.BorderSizePixel = 0
postureBack.Parent = gui

local postureFill = Instance.new("Frame")
postureFill.Size = UDim2.fromScale(1, 1)
postureFill.BackgroundColor3 = POSTURE_FULL_COLOR
postureFill.BorderSizePixel = 0
postureFill.Parent = postureBack

local pips: { Frame } = {}
for i = 1, Config.Dash.Charges do
	local pip = Instance.new("Frame")
	pip.Name = "Dodge" .. i
	pip.Size = UDim2.fromOffset(18, 18)
	pip.BackgroundColor3 = READY_COLOR
	pip.Rotation = 45
	pip.LayoutOrder = i
	pip.Parent = bar
	pips[i] = pip
end

local feintLabel = makeLabel("FEINT", 64)
feintLabel.LayoutOrder = 10
local lockLabel = makeLabel("SHIFT LOCK", 84)
lockLabel.LayoutOrder = 11

RunService.RenderStepped:Connect(function()
	local charges = Movement.getDodgeCharges()
	for i, pip in pips do
		pip.BackgroundColor3 = if i <= charges then READY_COLOR else SPENT_COLOR
	end

	local character = player.Character
	local posture = character and character:GetAttribute("Posture")
	local postureMax = Config.Block.PostureMax
	local ratio = math.clamp(if typeof(posture) == "number" then posture / postureMax else 1, 0, 1)
	postureFill.Size = UDim2.fromScale(ratio, 1)
	postureFill.BackgroundColor3 = POSTURE_LOW_COLOR:Lerp(POSTURE_FULL_COLOR, ratio)

	local feintReadyAt = character and character:GetAttribute("FeintReadyAt")
	local remaining = if typeof(feintReadyAt) == "number" then feintReadyAt - Workspace:GetServerTimeNow() else 0
	if remaining > 0 then
		feintLabel.Text = string.format("FEINT %.1f", remaining)
		feintLabel.TextColor3 = SPENT_COLOR
	else
		feintLabel.Text = "FEINT"
		feintLabel.TextColor3 = READY_COLOR
	end

	lockLabel.TextColor3 = if ShiftLock.isEnabled() then READY_COLOR else SPENT_COLOR
end)

return {}
