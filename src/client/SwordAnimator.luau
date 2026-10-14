-- Placeholder swing animation, done procedurally so no animation assets are needed.
-- Every client animates every combatant (players and dummies) by rotating the R6
-- "Right Shoulder" joint, driven by the server's SwingPhase / SwingVariant attributes.
-- Replace with real uploaded animations later; this module is the only thing to swap.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local COMBATANT_TAG = "Combatant"

-- yaw: sweep around the torso's vertical axis (+ = toward the character's left)
-- pitch: raise the arm (0 = hanging, ~1.57 = pointing forward, ~3 = overhead)
type Pose = { yaw: number, pitch: number }

local REST: Pose = { yaw = 0, pitch = 0 }

-- One windup/slash pair per combo hit, so consecutive swings alternate direction.
local SWINGS: { { windup: Pose, slash: Pose } } = {
	{ windup = { yaw = -1.3, pitch = 1.7 }, slash = { yaw = 1.0, pitch = 1.3 } }, -- right to left
	{ windup = { yaw = 1.1, pitch = 1.8 }, slash = { yaw = -1.2, pitch = 1.3 } }, -- left to right
	{ windup = { yaw = -0.2, pitch = 3.0 }, slash = { yaw = 0.2, pitch = 0.7 } }, -- overhead
	{ windup = { yaw = -0.8, pitch = 3.1 }, slash = { yaw = 0.9, pitch = 0.5 } }, -- heavy diagonal finisher
}

-- Exponential blend rates (higher = snappier). The windup is deliberately slower
-- than the slash so the tell reads clearly before the hit snaps through.
local BLEND_RATE = {
	Windup = 14,
	Slash = 45,
	None = 10,
}

type Tracked = {
	motor: Motor6D,
	baseC0: CFrame,
	current: Pose,
}

local tracked: { [Model]: Tracked } = {}

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local torso = model:WaitForChild("Torso", 5)
	local motor = torso and torso:WaitForChild("Right Shoulder", 5)
	if not motor or not motor:IsA("Motor6D") then
		return -- not an R6 rig
	end
	tracked[model] = {
		motor = motor,
		baseC0 = motor.C0,
		current = { yaw = 0, pitch = 0 },
	}
end

local function untrack(model: Instance)
	local entry = tracked[model :: Model]
	if entry and entry.motor.Parent then
		entry.motor.C0 = entry.baseC0
	end
	tracked[model :: Model] = nil
end

local function getTargetPose(model: Model): (Pose, string)
	local phase = model:GetAttribute("SwingPhase")
	local variant = model:GetAttribute("SwingVariant")
	local swing = SWINGS[if typeof(variant) == "number" then variant else 1] or SWINGS[1]
	if phase == "Windup" then
		return swing.windup, "Windup"
	elseif phase == "Slash" then
		return swing.slash, "Slash"
	end
	return REST, "None"
end

RunService.RenderStepped:Connect(function(dt)
	for model, entry in tracked do
		if not model.Parent or not entry.motor.Parent then
			tracked[model] = nil
			continue
		end
		local target, phase = getTargetPose(model)
		local alpha = 1 - math.exp(-BLEND_RATE[phase] * dt)
		local pose = entry.current
		pose.yaw += (target.yaw - pose.yaw) * alpha
		pose.pitch += (target.pitch - pose.pitch) * alpha

		-- Rotate about the shoulder: sweep around the torso's up axis, then raise
		-- the arm about the joint's own axis. With both at 0 this equals baseC0.
		local base = entry.baseC0
		entry.motor.C0 = CFrame.new(base.Position)
			* CFrame.Angles(0, pose.yaw, 0)
			* base.Rotation
			* CFrame.Angles(0, 0, pose.pitch)
	end
end)

CollectionService:GetInstanceAddedSignal(COMBATANT_TAG):Connect(function(model)
	task.spawn(track, model)
end)
CollectionService:GetInstanceRemovedSignal(COMBATANT_TAG):Connect(untrack)
for _, model in CollectionService:GetTagged(COMBATANT_TAG) do
	task.spawn(track, model)
end

return {}
