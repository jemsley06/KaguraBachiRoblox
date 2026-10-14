-- Welds a placeholder katana to an R6 character's right arm.
-- Swap the parts for a MeshPart once you have a proper model of Chihiro's blade.

local Sword = {}

local BLADE_LENGTH = 4

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

local function weld(arm: BasePart, part: BasePart, offset: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = arm
	w.Part1 = part
	w.C0 = offset
	w.Parent = part
end

function Sword.attach(character: Model)
	local arm = character:FindFirstChild("Right Arm") :: BasePart?
	if not arm or character:FindFirstChild("Katana") then
		return
	end
	-- The grip's +Y axis points forward out of the fist when the arm hangs down,
	-- so the blade follows the swing as the shoulder rotates.
	local grip = arm:FindFirstChild("RightGripAttachment") :: Attachment?
	local gripCFrame = if grip then grip.CFrame else CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)

	local model = Instance.new("Model")
	model.Name = "Katana"

	local handle = makePart("Handle", Vector3.new(0.22, 1, 0.22), Color3.fromRGB(40, 20, 20), Enum.Material.Fabric)
	local guard = makePart("Guard", Vector3.new(0.55, 0.1, 0.55), Color3.fromRGB(140, 110, 50), Enum.Material.Metal)
	local blade = makePart("Blade", Vector3.new(0.12, BLADE_LENGTH, 0.3), Color3.fromRGB(25, 25, 30), Enum.Material.Metal)

	weld(arm, handle, gripCFrame * CFrame.new(0, 0, 0))
	weld(arm, guard, gripCFrame * CFrame.new(0, 0.55, 0))
	weld(arm, blade, gripCFrame * CFrame.new(0, 0.6 + BLADE_LENGTH / 2, 0))

	handle.Parent = model
	guard.Parent = model
	blade.Parent = model
	model.Parent = character
end

return Sword
