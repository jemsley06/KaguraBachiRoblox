-- Custom shift lock: locks the mouse to the screen centre and turns the
-- character to face the camera, so aiming swings and dodges follows the mouse.
-- Roblox's built-in shift lock is disabled in default.project.json so the two don't fight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer

local ShiftLock = {}

local enabled = false
local applied = false -- whether the locked state is currently applied to the character

function ShiftLock.toggle()
	enabled = not enabled
end

function ShiftLock.isEnabled(): boolean
	return enabled
end

-- Runs right after the camera updates each frame. The camera scripts reset
-- MouseBehavior every frame, so the lock has to be re-applied every frame too.
RunService:BindToRenderStep("KaguraShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	if not humanoid or not root or not camera then
		return
	end

	if enabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		humanoid.AutoRotate = false
		humanoid.CameraOffset = Config.ShiftLock.CameraOffset
		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 1e-3 and humanoid.Health > 0 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
		end
		applied = true
	elseif applied then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
		applied = false
	end
end)

player.CharacterAdded:Connect(function()
	applied = false
end)

return ShiftLock
