-- Keybinds:
--   M1          attack (4-hit combo)
--   Space + M1  finisher uppercut (hold Space)
--   air M1      finisher downslam (jump first)
--   M2          feint (during a swing's windup)
--   F (tap)     parry, F (hold) block
--   Q           dodge (forward = dash attack)
--   W W         double tap to sprint
--   Left Shift  toggle shift lock

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Movement = require(script.Parent.Movement)
local ShiftLock = require(script.Parent.ShiftLock)
require(script.Parent.SwordAnimator)
require(script.Parent.Hud)

-- Finisher modifier sent with every M1; the server only uses it on the last hit.
-- Holding Space wins over being airborne, since holding Space also jumps.
local function getAttackModifier(): string?
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		return "Up"
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
		return "Down"
	end
	return nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- typing in chat, clicking UI, etc.
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.Combat:FireServer("Attack", getAttackModifier())
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		Remotes.Combat:FireServer("Feint")
	elseif input.KeyCode == Enum.KeyCode.F then
		Remotes.Combat:FireServer("BlockStart")
	elseif input.KeyCode == Enum.KeyCode.Q then
		Movement.dash()
	elseif input.KeyCode == Enum.KeyCode.W then
		Movement.onForwardPressed()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		ShiftLock.toggle()
	end
end)

-- Releases ignore gameProcessed so focusing chat mid-hold can't leave you stuck blocking.
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		Remotes.Combat:FireServer("BlockEnd")
	elseif input.KeyCode == Enum.KeyCode.W then
		Movement.onForwardReleased()
	end
end)
