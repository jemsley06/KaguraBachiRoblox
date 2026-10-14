-- R6 ragdoll. Split in two because of physics ownership:
--   setJoints  runs on the server (joint changes replicate to everyone)
--   setState   runs on whoever owns the character's physics: the player's own
--              client for players, the server for NPCs

local Ragdoll = {}

local JOINTS = { "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local LIMBS = { "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local TAG = "RagdollPart" -- name of every instance this module creates

local function makeAttachment(parent: BasePart, cframe: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = TAG
	attachment.CFrame = cframe
	attachment.Parent = parent
	return attachment
end

-- Swaps the limb/neck motors for ball sockets. RootJoint stays, so the root follows the torso.
function Ragdoll.setJoints(model: Model, on: boolean)
	local torso = model:FindFirstChild("Torso")
	if not torso then
		return
	end

	for _, name in JOINTS do
		local motor = torso:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then
			motor.Enabled = not on
			if on and motor.Part0 and motor.Part1 then
				local socket = Instance.new("BallSocketConstraint")
				socket.Name = TAG
				socket.Attachment0 = makeAttachment(motor.Part0, motor.C0)
				socket.Attachment1 = makeAttachment(motor.Part1, motor.C1)
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true
				socket.UpperAngle = 60
				socket.Parent = torso
			end
		end
	end

	-- Limbs don't collide on R6 by default; ragdolled they'd sink into the floor.
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limb.CanCollide = on
		end
	end

	if not on then
		for _, descendant in model:GetDescendants() do
			if descendant.Name == TAG then
				descendant:Destroy()
			end
		end
	end
end

-- Physics state lets the joints flop instead of the humanoid standing itself up.
function Ragdoll.setState(humanoid: Humanoid, on: boolean)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, not on)
	humanoid:ChangeState(if on then Enum.HumanoidStateType.Physics else Enum.HumanoidStateType.GettingUp)
end

return Ragdoll
