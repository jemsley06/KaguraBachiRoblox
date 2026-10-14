-- Launches a character's root: a horizontal push held for a short time plus a
-- vertical pop. Must run on whichever machine owns the character's physics:
-- the victim's own client for players, the server for NPCs.

local Knockback = {}

function Knockback.apply(root: BasePart, horizontal: Vector3, upSpeed: number, duration: number)
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	local createdAttachment = false
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Parent = root
		createdAttachment = true
	end

	-- Plane mode only constrains horizontal velocity, so the pop and gravity still apply.
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Knockback"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.huge
	velocity.PlaneVelocity = Vector2.new(horizontal.X, horizontal.Z)
	velocity.Parent = root

	root.AssemblyLinearVelocity = Vector3.new(horizontal.X, upSpeed, horizontal.Z)

	task.delay(duration, function()
		velocity:Destroy()
		if createdAttachment and attachment then
			attachment:Destroy()
		end
	end)
end

return Knockback
