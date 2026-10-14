-- Entry point: forces R6, registers characters for combat, and routes client input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(script.Parent.CombatService)
local Dummies = require(script.Parent.Dummies)
local Sword = require(script.Parent.Sword)

-- A model named StarterCharacter in StarterPlayer replaces the default character,
-- which forces R6 without relying on the place's Game Settings. Each player's
-- own avatar is applied onto it after spawning.
if not StarterPlayer:FindFirstChild("StarterCharacter") then
	local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	rig.Name = "StarterCharacter"
	rig.Parent = StarterPlayer
end

local function applyAvatar(player: Player, humanoid: Humanoid)
	local ok, description = pcall(Players.GetHumanoidDescriptionFromUserId, Players, math.max(player.UserId, 1))
	if ok and description then
		pcall(humanoid.ApplyDescription, humanoid, description)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	CombatService.register(character)
	applyAvatar(player, humanoid)
	if character.Parent then
		Sword.attach(character)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		-- Spawned before the R6 StarterCharacter existed: respawn as R6.
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R6 then
			player:LoadCharacter()
		else
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Clients only send intent. Every rule (cooldowns, stuns, timing) is checked in CombatService.
local handlers: { [string]: (Model, any) -> () } = {
	BlockStart = function(character)
		CombatService.startBlock(character)
	end,
	BlockEnd = function(character)
		CombatService.stopBlock(character)
	end,
	Attack = function(character, modifier)
		CombatService.attack(character, if modifier == "Up" or modifier == "Down" then modifier else nil)
	end,
	Feint = function(character)
		CombatService.feint(character)
	end,
	Dash = function(character, direction)
		if typeof(direction) == "string" then
			CombatService.dash(character, direction)
		end
	end,
}

Remotes.Combat.OnServerEvent:Connect(function(player, action, arg)
	local character = player.Character
	local handler = typeof(action) == "string" and handlers[action]
	if character and handler and CombatService.get(character) then
		handler(character, arg)
	end
end)

Dummies.spawnAll()
