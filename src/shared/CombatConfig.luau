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

-- Q dodge, Jujutsu Shenanigans style: snaps to one of four directions relative to
-- the character (forward, back, left, right), never diagonal.
CombatConfig.Dash = {
	Speed = 70,
	Duration = 0.22, -- back and side dodges
	-- Forward dodge is a longer lunge, steered by the camera, that hits whatever it touches.
	-- It drains every charge, so it's a commitment.
	FrontSpeed = 65,
	FrontDuration = 0.38,
	FrontSteerRate = 6, -- radians/s the lunge can turn toward the camera
	FrontHitRange = 4, -- depth of the contact box in front of the lunge
	ContactGrace = 0.1, -- extra server-side contact time to cover replication lag
	Charges = 2,
	-- Every dodge restarts this timer; when it completes, all charges refill.
	RechargeTime = 1.5,
	IFrames = 0.3, -- invulnerable window from the start of the dodge (server side)
}

CombatConfig.ShiftLock = {
	CameraOffset = Vector3.new(1.75, 0.25, 0),
}

-- F held = block. Blocked hits deal no HP damage but drain posture.
CombatConfig.Block = {
	PostureMax = 100, -- posture starts full; reaching 0 breaks the guard
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
	HitStun: number, -- how long a clean hit stuns the target (and ragdolls it, if Ragdoll)
	Knockback: number?, -- horizontal launch speed on a clean hit (studs/s)
	LaunchUp: number?, -- vertical launch speed on a clean hit; negative slams down
	Ragdoll: boolean?,
}

local BASE_DAMAGE = 8

-- Builds one combo hit. Each hit has its own fixed windup/recovery so the
-- string has a rhythm instead of a metronome.
local function comboHit(windup: number, recovery: number): AttackProfile
	return {
		Windup = windup, -- the parry tell
		Recovery = recovery,
		Range = 7,
		Width = 6,
		Damage = BASE_DAMAGE,
		PostureDamage = 20,
		HitStun = 0.8,
	}
end

-- Finisher variants share everything except how the target is launched.
local function finisher(knockback: number, launchUp: number, hitStun: number): AttackProfile
	return {
		Windup = 0.3,
		Recovery = 1.0,
		Range = 7,
		Width = 7,
		Damage = BASE_DAMAGE * 1.2,
		PostureDamage = 35,
		HitStun = hitStun,
		Knockback = knockback,
		LaunchUp = launchUp,
		Ragdoll = true,
	}
end

-- M1 combo.
CombatConfig.Attack = {
	ComboLength = 4,
	ComboResetTime = 1.0, -- idle time after which the combo restarts at hit 1
	KnockbackDuration = 0.25, -- how long the horizontal launch force is held

	-- Hits 1..ComboLength-1. Hitstun (0.8) must stay longer than each hit's
	-- recovery + the next hit's windup, so a clean chain can't be escaped.
	Combo = {
		comboHit(0.25, 0.30),
		comboHit(0.22, 0.25),
		comboHit(0.28, 0.35),
	},

	Finisher = finisher(60, 22, 1.0), -- M1: knocks the target away
	Uppercut = finisher(8, 75, 1.4), -- Space held + M1: launches the target up
	Downslam = finisher(0, -80, 1.2), -- M1 while airborne: slams the target down

	-- Forward dodge. Hits on contact, then counts as hit 1 of the combo.
	Dash = {
		Windup = 0, -- unused: the hit lands on contact during the lunge
		Recovery = 0.3,
		Range = CombatConfig.Dash.FrontHitRange,
		Width = 6,
		Damage = BASE_DAMAGE,
		PostureDamage = 20,
		HitStun = 0.8,
	} :: AttackProfile,
}

return CombatConfig
