-- Client-side movement: momentum, sprint, and dodges.
-- The client owns its character's physics, so movement runs here for zero input lag;
-- the server only grants dodge i-frames, enforces charges, and starts dash attacks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Knockback = require(ReplicatedStorage.Shared.Knockback)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)

local player = Players.LocalPlayer

local Movement = {}

local sprinting = false
local lastForwardTap = 0
local dashing = false
local jumpEnabled = true
local ragdolled = false
local currentSpeed = Config.Movement.WalkSpeed

-- Predicted locally (same rule as the server) so the HUD and input feel instant.
local dodgeCharges = Config.Dash.Charges
local dodgeRechargeAt = 0

local function getCharacterParts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function flatten(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Snap the input to one of the character's four directions (JJS style, no diagonals).
-- Whichever axis the input leans toward more wins; exact diagonals count as forward/back.
local function snapDirection(input: Vector3, root: BasePart): (string, Vector3)
	local look = flatten(root.CFrame.LookVector).Unit
	local right = flatten(root.CFrame.RightVector).Unit
	local forwardDot = input:Dot(look)
	local rightDot = input:Dot(right)
	if math.abs(forwardDot) >= math.abs(rightDot) then
		if forwardDot >= 0 then
			return "Front", look
		end
		return "Back", -look
	end
	if rightDot > 0 then
		return "Right", right
	end
	return "Left", -right
end

-- Rotates `from` toward `to` around the vertical axis by at most `maxAngle` radians.
local function turnToward(from: Vector3, to: Vector3, maxAngle: number): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= maxAngle then
		return to
	end
	local sign = if from:Cross(to).Y >= 0 then 1 else -1
	return CFrame.fromAxisAngle(Vector3.yAxis, sign * maxAngle):VectorToWorldSpace(from)
end

function Movement.getDodgeCharges(): number
	return dodgeCharges
end

-- Double-tap W: the second press within DoubleTapWindow starts the sprint.
function Movement.onForwardPressed()
	local t = os.clock()
	if t - lastForwardTap <= Config.Movement.DoubleTapWindow then
		sprinting = true
		lastForwardTap = 0 -- a third quick tap shouldn't count as another double tap
	else
		lastForwardTap = t
	end
end

function Movement.onForwardReleased()
	sprinting = false
end

function Movement.dash()
	local character, humanoid, root = getCharacterParts()
	if not character or not humanoid or not root then
		return
	end
	if dashing or dodgeCharges <= 0 or character:GetAttribute("Stunned") then
		return
	end

	-- Dodge toward the movement input, snapped to 4 directions; with no input, dodge forward.
	local input = flatten(humanoid.MoveDirection)
	if input.Magnitude < 0.1 then
		input = flatten(root.CFrame.LookVector)
	end
	local directionName, direction = snapDirection(input, root)
	local isFront = directionName == "Front"

	-- The forward lunge spends every charge (same rule as the server).
	dodgeCharges = if isFront then 0 else dodgeCharges - 1
	dodgeRechargeAt = os.clock() + Config.Dash.RechargeTime
	dashing = true
	-- Forward dodges become dash attacks on the server, hitting on contact.
	Remotes.Combat:FireServer("Dash", directionName)

	-- Plane mode only constrains horizontal velocity, so gravity still works mid-dodge.
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	local createdAttachment = false
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Parent = root
		createdAttachment = true
	end

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.huge
	velocity.Parent = root

	local cfg = Config.Dash
	local dashSpeed = if isFront then cfg.FrontSpeed else cfg.Speed
	local duration = if isFront then cfg.FrontDuration else cfg.Duration
	local start = os.clock()
	-- The lunge faces its own direction while steering, so the server's hitbox follows it.
	local previousAutoRotate = humanoid.AutoRotate
	if isFront then
		humanoid.AutoRotate = false
	end
	local sawWindup = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local alpha = (os.clock() - start) / duration
		-- The server flips the swing to Slash on contact: stop at the target, not through it.
		local phase = character:GetAttribute("SwingPhase")
		sawWindup = sawWindup or phase == "Windup"
		local connected = isFront and sawWindup and phase == "Slash"
		if alpha >= 1 or connected or not velocity.Parent then
			connection:Disconnect()
			velocity:Destroy()
			if createdAttachment and attachment then
				attachment:Destroy()
			end
			dashing = false
			if isFront then
				humanoid.AutoRotate = previousAutoRotate
			end
			-- Momentum: leave the dodge at max ground speed. If the player keeps
			-- holding a direction they stay sprinting; otherwise update() resets.
			currentSpeed = Config.Movement.SprintSpeed
			sprinting = true
			return
		end
		-- Steer the forward lunge toward the camera, with a capped turn rate.
		local camera = Workspace.CurrentCamera
		if isFront and camera then
			local look = flatten(camera.CFrame.LookVector)
			if look.Magnitude > 1e-3 then
				direction = turnToward(direction, look.Unit, cfg.FrontSteerRate * dt)
				root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
			end
		end
		-- Ease out from full dodge speed down to sprint speed so it flows into movement.
		local speed = dashSpeed + (Config.Movement.SprintSpeed - dashSpeed) * alpha * alpha
		velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
	end)
end

local function getTargetSpeed(character: Model): number
	local m = Config.Movement
	if character:GetAttribute("Stunned") then
		return 0
	elseif character:GetAttribute("Blocking") then
		return m.BlockSpeed
	elseif character:GetAttribute("Attacking") then
		return m.AttackSpeed
	elseif sprinting then
		return m.SprintSpeed
	end
	return m.WalkSpeed
end

-- Runs every frame. WalkSpeed is derived from combat state, so the server
-- never has to write movement properties the client also writes.
local function update(dt: number)
	if dodgeCharges < Config.Dash.Charges and os.clock() >= dodgeRechargeAt then
		dodgeCharges = Config.Dash.Charges
	end

	local character, humanoid = getCharacterParts()
	local camera = Workspace.CurrentCamera
	if not character or not humanoid then
		sprinting = false
		return
	end

	local stunned = character:GetAttribute("Stunned") == true
	local moving = humanoid.MoveDirection.Magnitude >= 0.1
	if stunned or character:GetAttribute("Blocking") or not moving then
		sprinting = false
	end

	-- Momentum: ease toward the target speed instead of snapping to it.
	-- Starting from a standstill begins at walk speed so movement never feels sluggish.
	local m = Config.Movement
	local target = getTargetSpeed(character)
	if stunned then
		currentSpeed = 0
	elseif not moving then
		currentSpeed = math.min(m.WalkSpeed, target)
	elseif currentSpeed < target then
		currentSpeed = math.min(target, math.max(currentSpeed, math.min(m.WalkSpeed, target)) + m.Acceleration * dt)
	else
		currentSpeed = math.max(target, currentSpeed - m.Deceleration * dt)
	end
	humanoid.WalkSpeed = currentSpeed

	-- The server sets Ragdolled; this client owns the physics, so it applies the state.
	local shouldRagdoll = character:GetAttribute("Ragdolled") == true
	if ragdolled ~= shouldRagdoll then
		ragdolled = shouldRagdoll
		Ragdoll.setState(humanoid, ragdolled)
	end

	if jumpEnabled == stunned then
		jumpEnabled = not stunned
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpEnabled)
	end

	if camera then
		local targetFov = if currentSpeed > m.WalkSpeed + 2 then m.SprintFov else m.DefaultFov
		camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 10)
	end
end

player.CharacterAdded:Connect(function()
	sprinting = false
	dashing = false
	jumpEnabled = true
	ragdolled = false
	currentSpeed = Config.Movement.WalkSpeed
	dodgeCharges = Config.Dash.Charges
end)

RunService.RenderStepped:Connect(update)

-- The server can't reliably move a player's character (the client owns its physics),
-- so knockback from finishers is applied here when the server asks.
Remotes.Knockback.OnClientEvent:Connect(function(horizontal: Vector3, upSpeed: number, duration: number)
	local _, _, root = getCharacterParts()
	if root then
		sprinting = false
		currentSpeed = 0
		Knockback.apply(root, horizontal, upSpeed, duration)
	end
end)

return Movement
