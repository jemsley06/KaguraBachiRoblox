-- Training dummies so the combat loop can be tested solo:
--   Training Dummy   stands still, takes hits
--   Blocker Dummy    always holds block, for testing posture / guard breaks
--   Swordsman Dummy  swings at the nearest player and sometimes feints, for practising parries

local Players = game:GetService("Players")

local CombatService = require(script.Parent.CombatService)
local Sword = require(script.Parent.Sword)

local Dummies = {}

local RESPAWN_DELAY = 3
local SWORDSMAN_AGGRO_RANGE = 14
local SWORDSMAN_SWING_INTERVAL = 2
local SWORDSMAN_FEINT_CHANCE = 0.35
local SWORDSMAN_FEINT_AFTER = 0.12 -- seconds into the windup before feinting
local SWORDSMAN_RESWING_DELAY = 0.35 -- pause after a feint before the real swing

type Behavior = "Idle" | "Blocker" | "Swordsman"

local DEFINITIONS: { { name: string, position: Vector3, behavior: Behavior } } = {
	{ name = "Training Dummy", position = Vector3.new(-12, 4, -20), behavior = "Idle" },
	{ name = "Blocker Dummy", position = Vector3.new(0, 4, -20), behavior = "Blocker" },
	{ name = "Swordsman Dummy", position = Vector3.new(12, 4, -20), behavior = "Swordsman" },
}

local function nearestPlayerRoot(origin: Vector3, maxDistance: number): BasePart?
	local best: BasePart? = nil
	local bestDistance = maxDistance
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - origin).Magnitude
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best
end

local function runBehavior(model: Model, behavior: Behavior)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local home = root.CFrame

	while model.Parent do
		local state = CombatService.get(model)
		if not state then
			break
		end

		if behavior == "Blocker" then
			-- Re-raise the guard whenever a stun (e.g. guard break) dropped it.
			CombatService.startBlock(model, false)
			task.wait(0.25)
		elseif behavior == "Swordsman" then
			local target = nearestPlayerRoot(root.Position, SWORDSMAN_AGGRO_RANGE)
			if target then
				local flatTarget = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z)
				root.CFrame = CFrame.lookAt(root.Position, flatTarget)
				if CombatService.attack(model) and math.random() < SWORDSMAN_FEINT_CHANCE then
					task.wait(SWORDSMAN_FEINT_AFTER)
					if CombatService.feint(model) then
						task.wait(SWORDSMAN_RESWING_DELAY)
						CombatService.attack(model)
					end
				end
			else
				root.CFrame = home
			end
			task.wait(SWORDSMAN_SWING_INTERVAL)
		else
			task.wait(1)
		end
	end
end

local function spawnDummy(definition)
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	model.Name = definition.name
	model:PivotTo(CFrame.new(definition.position))
	model.Parent = workspace

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil)

	CombatService.register(model)
	Sword.attach(model)
	task.spawn(runBehavior, model, definition.behavior)

	humanoid.Died:Connect(function()
		task.wait(RESPAWN_DELAY)
		model:Destroy()
		spawnDummy(definition)
	end)
end

function Dummies.spawnAll()
	for _, definition in DEFINITIONS do
		spawnDummy(definition)
	end
end

return Dummies
