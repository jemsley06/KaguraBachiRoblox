-- Keybinds:
--   M1          attack (4-hit combo)
--   M2          feint (during a swing's windup)
--   F (tap)     parry, F (hold) block
--   Q           dodge (forward = dash attack)
--   W W         double tap to sprint
--   Left Shift  toggle shift lock

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Movement = require(script.Parent.Movement)
local ShiftLock = require(script.Parent.ShiftLock)
require(script.Parent.SwordAnimator)
require(script.Parent.Hud)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- typing in chat, clicking UI, etc.
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.Combat:FireServer("Attack")
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
