-- Welds a simple placeholder katana to a character's right hand.
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

function Sword.attach(character: Model)
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not hand or character:FindFirstChild("Katana") then
		return
	end
	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local gripCFrame = if grip then grip.CFrame else CFrame.new(0, -1, 0)

	local model = Instance.new("Model")
	model.Name = "Katana"

	local blade = makePart("Blade", Vector3.new(0.12, BLADE_LENGTH, 0.3), Color3.fromRGB(25, 25, 30), Enum.Material.Metal)
	local guard = makePart("Guard", Vector3.new(0.5, 0.1, 0.5), Color3.fromRGB(140, 110, 50), Enum.Material.Metal)
	blade.Parent = model
	guard.Parent = model

	-- Point the blade forward out of the fist, with its base at the grip.
	local bladeWeld = Instance.new("Weld")
	bladeWeld.Part0 = hand
	bladeWeld.Part1 = blade
	bladeWeld.C0 = gripCFrame * CFrame.Angles(math.rad(-90), 0, 0)
	bladeWeld.C1 = CFrame.new(0, -BLADE_LENGTH / 2 - 0.2, 0)
	bladeWeld.Parent = blade

	local guardWeld = Instance.new("Weld")
	guardWeld.Part0 = hand
	guardWeld.Part1 = guard
	guardWeld.C0 = bladeWeld.C0 * CFrame.new(0, 0.2, 0)
	guardWeld.Parent = guard

	model.Parent = character
end

return Sword
