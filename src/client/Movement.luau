-- Client-side movement: momentum, sprint, and dodges.
-- The client owns its character's physics, so movement runs here for zero input lag;
-- the server only grants dodge i-frames, enforces charges, and starts dash attacks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Movement = {}

local sprinting = false
local lastForwardTap = 0
local dashing = false
local jumpEnabled = true
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

local function classifyDirection(direction: Vector3, root: BasePart): string
	local look = flatten(root.CFrame.LookVector).Unit
	local right = flatten(root.CFrame.RightVector).Unit
	local forwardDot = direction:Dot(look)
	if forwardDot >= Config.Dash.ForwardDot then
		return "Front"
	elseif forwardDot <= -Config.Dash.ForwardDot then
		return "Back"
	end
	return if direction:Dot(right) > 0 then "Right" else "Left"
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

	-- Dodge where you're moving; with no input, dodge forward.
	local direction = flatten(humanoid.MoveDirection)
	if direction.Magnitude < 0.1 then
		direction = flatten(root.CFrame.LookVector)
	end
	direction = direction.Unit

	dodgeCharges -= 1
	dodgeRechargeAt = os.clock() + Config.Dash.RechargeTime
	dashing = true
	-- Forward dodges become dash attacks on the server.
	Remotes.Combat:FireServer("Dash", classifyDirection(direction, root))

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
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - start) / cfg.Duration
		if alpha >= 1 or not velocity.Parent then
			connection:Disconnect()
			velocity:Destroy()
			if createdAttachment and attachment then
				attachment:Destroy()
			end
			dashing = false
			-- Momentum: leave the dodge at max ground speed. If the player keeps
			-- holding a direction they stay sprinting; otherwise update() resets.
			currentSpeed = Config.Movement.SprintSpeed
			sprinting = true
			return
		end
		-- Ease out from full dodge speed down to sprint speed so it flows into movement.
		local speed = cfg.Speed + (Config.Movement.SprintSpeed - cfg.Speed) * alpha * alpha
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
	currentSpeed = Config.Movement.WalkSpeed
	dodgeCharges = Config.Dash.Charges
end)

RunService.RenderStepped:Connect(update)

return Movement
