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
	-- Forward dodge is a longer lunge that ends in the dash attack.
	FrontSpeed = 65,
	FrontDuration = 0.38,
	Charges = 2,
	-- Every dodge restarts this timer; when it completes, all charges refill.
	RechargeTime = 1.5,
	IFrames = 0.3, -- invulnerable window from the start of the dodge (server side)
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
	HitStun: number, -- how long a clean hit stuns the target
	Knockback: number?, -- horizontal launch speed on a clean hit (studs/s)
}

local BASE_DAMAGE = 8

-- M1 combo.
CombatConfig.Attack = {
	ComboLength = 4,
	ComboResetTime = 1.0, -- idle time after which the combo restarts at hit 1
	-- Hitstun is longer than the gap between hit frames (recovery + next windup),
	-- so a clean M1 chain can't be escaped: the combo is guaranteed until the finisher.
	KnockbackUpSpeed = 22, -- vertical pop on knockback hits
	KnockbackDuration = 0.25, -- how long the horizontal launch force is held

	Normal = {
		Windup = 0.25, -- slight windup: the parry tell
		Recovery = 0.3,
		Range = 7,
		Width = 6,
		Damage = BASE_DAMAGE,
		PostureDamage = 20,
		HitStun = 0.8,
	} :: AttackProfile,

	Finisher = { -- last hit of the combo: knocks the target away
		Windup = 0.3,
		Recovery = 1.0,
		Range = 7,
		Width = 7,
		Damage = BASE_DAMAGE * 1.2,
		PostureDamage = 35,
		HitStun = 1.0,
		Knockback = 60,
	} :: AttackProfile,

	-- Forward dodge. Counts as hit 1 of the combo. The windup equals the forward
	-- dodge's duration so the hit lands as the lunge ends.
	Dash = {
		Windup = CombatConfig.Dash.FrontDuration,
		Recovery = 0.3,
		Range = 8,
		Width = 6,
		Damage = BASE_DAMAGE,
		PostureDamage = 20,
		HitStun = 0.8,
	} :: AttackProfile,
}

return CombatConfig
