-- Keybinds:
--   M1          attack (4-hit combo)
--   F (tap)     parry, F (hold) block
--   Q           dash
--   W W         double tap to sprint

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Movement = require(script.Parent.Movement)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- typing in chat, clicking UI, etc.
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.Combat:FireServer("Attack")
	elseif input.KeyCode == Enum.KeyCode.F then
		Remotes.Combat:FireServer("BlockStart")
	elseif input.KeyCode == Enum.KeyCode.Q then
		Movement.dash()
	elseif input.KeyCode == Enum.KeyCode.W then
		Movement.onForwardPressed()
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
