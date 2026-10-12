-- Entry point: registers characters for combat and routes client input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(script.Parent.CombatService)
local Dummies = require(script.Parent.Dummies)
local Sword = require(script.Parent.Sword)

local function onCharacterAdded(character: Model)
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	CombatService.register(character)
	Sword.attach(character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Clients only send intent. Every rule (cooldowns, stuns, timing) is checked in CombatService.
local handlers: { [string]: (Model) -> () } = {
	BlockStart = function(character)
		CombatService.startBlock(character)
	end,
	BlockEnd = CombatService.stopBlock,
	Attack = CombatService.attack,
	Dash = function(character)
		CombatService.dash(character)
	end,
}

Remotes.Combat.OnServerEvent:Connect(function(player, action)
	local character = player.Character
	local handler = typeof(action) == "string" and handlers[action]
	if character and handler and CombatService.get(character) then
		handler(character)
	end
end)

Dummies.spawnAll()
