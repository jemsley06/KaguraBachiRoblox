-- Client-side movement: sprint, dash, and WalkSpeed derived from server combat state.
-- The client owns its character's physics, so movement runs here for zero input lag;
-- the server only grants dash i-frames and enforces the dash cooldown.

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
local dashReadyAt = 0
local jumpEnabled = true

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
	if dashing or os.clock() < dashReadyAt or character:GetAttribute("Stunned") then
		return
	end

	-- Dash where you're moving; with no input, dash forward (JJS behaviour).
	local direction = humanoid.MoveDirection
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then
		local look = root.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	direction = direction.Unit

	dashing = true
	dashReadyAt = os.clock() + Config.Dash.Cooldown
	Remotes.Combat:FireServer("Dash")

	-- Plane mode only constrains horizontal velocity, so gravity still works mid-dash.
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
			return
		end
		-- Ease out from full dash speed down to sprint speed so the dash flows into movement.
		local speed = cfg.Speed + (Config.Movement.SprintSpeed - cfg.Speed) * alpha * alpha
		velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
	end)
end

-- Runs every frame: WalkSpeed is a pure function of combat state, so the server
-- never has to write movement properties the client also writes.
local function update(dt: number)
	local character, humanoid = getCharacterParts()
	local camera = Workspace.CurrentCamera
	if not character or not humanoid then
		sprinting = false
		return
	end

	local stunned = character:GetAttribute("Stunned") == true
	local blocking = character:GetAttribute("Blocking") == true
	local attacking = character:GetAttribute("Attacking") == true

	if stunned or blocking or humanoid.MoveDirection.Magnitude < 0.1 then
		sprinting = false
	end

	local m = Config.Movement
	if stunned then
		humanoid.WalkSpeed = 0
	elseif blocking then
		humanoid.WalkSpeed = m.BlockSpeed
	elseif attacking then
		humanoid.WalkSpeed = m.AttackSpeed
	elseif sprinting then
		humanoid.WalkSpeed = m.SprintSpeed
	else
		humanoid.WalkSpeed = m.WalkSpeed
	end

	if jumpEnabled == stunned then
		jumpEnabled = not stunned
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpEnabled)
	end

	if camera then
		local targetFov = if sprinting then m.SprintFov else m.DefaultFov
		camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 10)
	end
end

player.CharacterAdded:Connect(function()
	sprinting = false
	dashing = false
	jumpEnabled = true
end)

RunService.RenderStepped:Connect(update)

return Movement
