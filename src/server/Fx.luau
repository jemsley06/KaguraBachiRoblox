-- Placeholder visual feedback until real animations/VFX exist.
-- Everything is created on the server so all clients see it.

local Debris = game:GetService("Debris")

local Fx = {}

function Fx.flash(model: Model, color: Color3, duration: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, duration)
end

function Fx.setBlockOutline(model: Model, enabled: boolean)
	local existing = model:FindFirstChild("BlockOutline")
	if enabled and not existing then
		local highlight = Instance.new("Highlight")
		highlight.Name = "BlockOutline"
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(120, 170, 255)
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	elseif not enabled and existing then
		existing:Destroy()
	end
end

-- The parry tell: the blade glints during a swing's windup.
-- Without real animations this is the only cue for when to press F.
function Fx.windup(model: Model, duration: number, isFinisher: boolean)
	local katana = model:FindFirstChild("Katana")
	if not katana then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "WindupGlint"
	highlight.FillColor = if isFinisher then Color3.fromRGB(255, 60, 30) else Color3.new(1, 1, 1)
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = katana
	Debris:AddItem(highlight, duration)
end

function Fx.clearWindup(model: Model)
	local katana = model:FindFirstChild("Katana")
	local glint = katana and katana:FindFirstChild("WindupGlint")
	if glint then
		glint:Destroy()
	end
end

function Fx.slash(cframe: CFrame, size: Vector3, isFinisher: boolean)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = if isFinisher then Color3.fromRGB(255, 60, 30) else Color3.fromRGB(230, 230, 240)
	part.Transparency = 0.6
	part.Size = Vector3.new(size.X, 0.15, size.Z)
	part.CFrame = cframe
	part.Parent = workspace
	Debris:AddItem(part, 0.12)
end

return Fx
