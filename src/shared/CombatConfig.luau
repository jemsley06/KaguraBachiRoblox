-- Every combat tunable lives here so balancing never requires touching logic.
-- All times are in seconds, speeds in studs/second.

local CombatConfig = {}

CombatConfig.Movement = {
	WalkSpeed = 16,
	SprintSpeed = 28,
	BlockSpeed = 7, -- walking while holding F
	AttackSpeed = 10, -- walking during a swing's windup
	DoubleTapWindow = 0.3, -- max gap between two W presses to start sprinting
	DefaultFov = 70,
	SprintFov = 80,
}

-- Q dash, Jujutsu Shenanigans style: a short burst in the direction you're moving.
CombatConfig.Dash = {
	Speed = 70,
	Duration = 0.22,
	Cooldown = 1.2,
	IFrames = 0.15, -- invulnerable window at the start of the dash (server side)
}

-- F held = block. Blocked hits deal no HP damage but fill posture.
CombatConfig.Block = {
	PostureMax = 100,
	PostureRegenDelay = 1.5, -- seconds after the last blocked hit before posture recovers
	PostureRegenRate = 25, -- posture per second
	GuardBreakStun = 1.5,
	-- Dot product threshold between defender's look vector and direction to attacker.
	-- 0 = 180 degree frontal arc. Hits from behind ignore block and parry.
	FacingDot = 0,
}

-- F pressed = the first moments of the block are a parry window (Deepwoken style).
CombatConfig.Parry = {
	Window = 0.2,
	WhiffCooldown = 0.6, -- base lockout after a parry window catches nothing
	AttackerStun = 1.0, -- how long the parried attacker is stunned
}

-- M1 combo.
CombatConfig.Attack = {
	ComboLength = 4,
	ComboResetTime = 1.0, -- idle time after which the combo restarts at hit 1
	Windup = 0.3, -- delay between clicking and the hitbox appearing (the parry tell)
	Cooldown = 0.35, -- recovery after a normal hit
	FinisherCooldown = 1.1, -- recovery after the last hit of the combo
	Range = 7,
	Width = 6,
	Damage = 8,
	FinisherDamage = 14,
	PostureDamage = 20,
	FinisherPostureDamage = 35,
	HitStun = 0.45,
}

return CombatConfig
