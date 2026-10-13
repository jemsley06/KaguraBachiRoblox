-- Minimal combat HUD: dodge charges, feint cooldown, and shift lock state.

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
