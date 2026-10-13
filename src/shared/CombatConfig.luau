-- Every combat tunable lives here so balancing never requires touching logic.
-- All times are in seconds, speeds in studs/second. Keep DESIGN.md in sync.

local CombatConfig = {}

CombatConfig.Movement = {
	WalkSpeed = 16,
	SprintSpeed = 28, -- max ground speed; dodges exit at this speed
	Acceleration = 40, -- studs/s^2 ramp toward a faster target speed (momentum)
	Deceleration = 35, -- studs/s^2 bleed toward a slower target speed
	BlockSpeed = 7, -- walking while holding F
	AttackSpeed = 10, -- walking during a swing's windup
	DoubleTapWindow = 0.3, -- max gap between two W presses to start sprinting
	DefaultFov = 70,
	SprintFov = 80,
}

-- Q dodge: a short burst in the direction you're moving.
CombatConfig.Dash = {
	Speed = 70,
	Duration = 0.22,
	Charges = 2,
	-- Every dodge restarts this timer; when it completes, all charges refill.
	RechargeTime = 1.5,
	IFrames = 0.3, -- invulnerable window from the start of the dodge (server side)
	-- Dot product between dodge direction and facing above which a dodge counts
	-- as "forward" and triggers a dash attack.
	ForwardDot = 0.7,
}

CombatConfig.ShiftLock = {
	CameraOffset = Vector3.new(1.75, 0.25, 0),
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

-- M2 during a swing's windup cancels it to bait parries.
CombatConfig.Feint = {
	Cooldown = 2,
	ReswingDelay = 0.1, -- how soon after feinting a new swing can start
}

export type AttackProfile = {
	Windup: number,
	Recovery: number, -- time after the hit frame before the next swing
	Range: number,
	Width: number,
	Damage: number,
	PostureDamage: number,
}

-- M1 combo.
CombatConfig.Attack = {
	ComboLength = 4,
	ComboResetTime = 1.0, -- idle time after which the combo restarts at hit 1
	HitStun = 0.45,

	Normal = {
		Windup = 0.25, -- slight windup: the parry tell
		Recovery = 0.3,
		Range = 7,
		Width = 6,
		Damage = 8,
		PostureDamage = 20,
	} :: AttackProfile,

	Finisher = { -- last hit of the combo
		Windup = 0.3,
		Recovery = 1.0,
		Range = 7,
		Width = 7,
		Damage = 14,
		PostureDamage = 35,
	} :: AttackProfile,

	-- Forward dodge. Counts as hit 1 of the combo. The windup roughly matches
	-- the dodge duration so the hit lands as the dodge ends.
	Dash = {
		Windup = 0.2,
		Recovery = 0.3,
		Range = 8,
		Width = 6,
		Damage = 8,
		PostureDamage = 20,
	} :: AttackProfile,
}

return CombatConfig
