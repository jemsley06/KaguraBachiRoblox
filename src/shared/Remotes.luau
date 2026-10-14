-- Single access point for networking objects. The server creates them,
-- clients wait for them, so there is no Studio setup required.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "CombatRemotes"

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function getEvent(name: string): RemoteEvent
	if RunService:IsServer() then
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	-- Client -> server: ("BlockStart" | "BlockEnd" | "Feint"), ("Attack", "Up" | "Down" | nil), ("Dash", direction)
	Combat = getEvent("Combat"),
	-- Server -> victim's client: (horizontalVelocity: Vector3, upSpeed: number, duration: number)
	Knockback = getEvent("Knockback"),
}
