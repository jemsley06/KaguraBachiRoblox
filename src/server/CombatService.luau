-- Server-authoritative combat state for any character model (players and NPCs alike).
--
-- Replicated attributes set on each registered model, read by clients:
--   Stunned       (bool)    can't move, attack, block or dodge
--   Blocking      (bool)    F is held
--   Attacking     (bool)    in a swing's windup
--   Posture       (number)  PostureMax..0, drained by blocked hits, guard breaks at 0
--   Ragdolled     (bool)    limp from a finisher; the physics owner applies the humanoid state
--   SwingPhase    (string)  "None" | "Windup" | "Slash", drives the swing animation
--   SwingVariant  (number)  which combo hit is being swung (1..ComboLength)
--   DodgeCharges  (number)  dodges available
--   FeintReadyAt  (number)  workspace:GetServerTimeNow() when feint is off cooldown

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Knockback = require(ReplicatedStorage.Shared.Knockback)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fx = require(script.Parent.Fx)

type AttackProfile = Config.AttackProfile

export type CombatState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,

	stunUntil: number,
	iframeUntil: number,
	ragdolled: boolean,

	blocking: boolean,
	posture: number,
	lastPostureHit: number,

	parryWindowEnd: number,
	parryCooldownUntil: number,
	parryAttemptId: number,
	parryLanded: boolean,
	whiffStreak: number,

	attacking: boolean,
	attackToken: number, -- bumping this cancels a pending swing
	attackReadyAt: number,
	combo: number,
	lastAttackTime: number,
	feintReadyAt: number,

	dodgeCharges: number,
	dodgeRechargeAt: number,
}

local COMBATANT_TAG = "Combatant"
local SLASH_POSE_TIME = 0.2 -- how long the follow-through pose is held after the hit frame

local CombatService = {}

local states: { [Model]: CombatState } = {}

local function now(): number
	return os.clock()
end

local function isStunned(state: CombatState): boolean
	return now() < state.stunUntil
end

local function setBlocking(state: CombatState, value: boolean)
	if state.blocking == value then
		return
	end
	state.blocking = value
	state.model:SetAttribute("Blocking", value)
	Fx.setBlockOutline(state.model, value)
end

local function setAttacking(state: CombatState, value: boolean)
	state.attacking = value
	state.model:SetAttribute("Attacking", value)
end

-- Cancels a pending swing without stunning (used by stuns and feints).
local function cancelSwing(state: CombatState)
	state.attackToken += 1
	setAttacking(state, false)
	state.model:SetAttribute("SwingPhase", "None")
	Fx.clearWindup(state.model)
end

-- Stun interrupts everything: pending swings, blocks, and parry windows.
local function applyStun(state: CombatState, duration: number)
	state.stunUntil = math.max(state.stunUntil, now() + duration)
	state.parryWindowEnd = 0
	cancelSwing(state)
	setBlocking(state, false)
	state.model:SetAttribute("Stunned", true)
end

-- Ragdoll lasts until the stun ends (cleared in the Heartbeat upkeep below).
local function setRagdoll(state: CombatState, on: boolean)
	if state.ragdolled == on then
		return
	end
	state.ragdolled = on
	Ragdoll.setJoints(state.model, on)
	state.model:SetAttribute("Ragdolled", on)
	if not Players:GetPlayerFromCharacter(state.model) then
		Ragdoll.setState(state.humanoid, on)
	end
end

-- Is `defender` facing toward `attacker` closely enough to block/parry?
local function isFacing(defender: CombatState, attacker: CombatState): boolean
	local toAttacker = attacker.root.Position - defender.root.Position
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 1e-3 then
		return true
	end
	local look = defender.root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z).Unit
	return look:Dot(toAttacker.Unit) >= Config.Block.FacingDot
end

-- Called when a parry window ends without catching an attack.
-- `whiffStreak` counts consecutive missed parries (1 on the first miss,
-- reset to 0 whenever a parry lands).
-- Returns how many seconds before pressing F can open a new parry window.
-- Pressing F during the lockout still blocks, it just can't parry.
function CombatService.getWhiffCooldown(whiffStreak: number): number
	-- TODO(you): decide how parry spam gets punished.
	return Config.Parry.WhiffCooldown
end

function CombatService.register(model: Model): CombatState?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return nil
	end

	local state: CombatState = {
		model = model,
		humanoid = humanoid,
		root = root,
		stunUntil = 0,
		iframeUntil = 0,
		ragdolled = false,
		blocking = false,
		posture = Config.Block.PostureMax,
		lastPostureHit = 0,
		parryWindowEnd = 0,
		parryCooldownUntil = 0,
		parryAttemptId = 0,
		parryLanded = false,
		whiffStreak = 0,
		attacking = false,
		attackToken = 0,
		attackReadyAt = 0,
		combo = 0,
		lastAttackTime = 0,
		feintReadyAt = 0,
		dodgeCharges = Config.Dash.Charges,
		dodgeRechargeAt = 0,
	}
	states[model] = state

	model:SetAttribute("Stunned", false)
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Attacking", false)
	model:SetAttribute("Posture", state.posture)
	model:SetAttribute("Ragdolled", false)
	model:SetAttribute("SwingPhase", "None")
	model:SetAttribute("SwingVariant", 1)
	model:SetAttribute("DodgeCharges", state.dodgeCharges)
	model:SetAttribute("FeintReadyAt", 0)
	CollectionService:AddTag(model, COMBATANT_TAG)

	humanoid.Died:Connect(function()
		states[model] = nil
	end)
	model.Destroying:Connect(function()
		states[model] = nil
	end)

	return state
end

function CombatService.get(model: Model): CombatState?
	return states[model]
end

-- F pressed. `allowParry` = false lets NPCs hold a plain block.
function CombatService.startBlock(model: Model, allowParry: boolean?)
	local state = states[model]
	if not state or state.blocking or state.attacking or isStunned(state) then
		return
	end
	setBlocking(state, true)

	local t = now()
	if allowParry == false or t < state.parryCooldownUntil or t < state.parryWindowEnd then
		return
	end

	state.parryWindowEnd = t + Config.Parry.Window
	state.parryLanded = false
	state.parryAttemptId += 1
	local attemptId = state.parryAttemptId

	task.delay(Config.Parry.Window, function()
		if states[model] ~= state or state.parryAttemptId ~= attemptId then
			return
		end
		if state.parryLanded then
			state.whiffStreak = 0
		else
			state.whiffStreak += 1
			state.parryCooldownUntil = now() + CombatService.getWhiffCooldown(state.whiffStreak)
		end
	end)
end

-- F released. The parry window deliberately survives the release:
-- a quick tap of F is the intended way to parry.
function CombatService.stopBlock(model: Model)
	local state = states[model]
	if state then
		setBlocking(state, false)
	end
end

-- Players own their character's physics, so their own client applies the launch;
-- the server applies it directly to NPCs.
local function launch(attacker: CombatState, defender: CombatState, speed: number, upSpeed: number)
	local away = defender.root.Position - attacker.root.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 1e-3 then
		away = attacker.root.CFrame.LookVector
		away = Vector3.new(away.X, 0, away.Z)
	end
	local horizontal = if speed > 0 then away.Unit * speed else Vector3.zero
	local cfg = Config.Attack

	local player = Players:GetPlayerFromCharacter(defender.model)
	if player then
		Remotes.Knockback:FireClient(player, horizontal, upSpeed, cfg.KnockbackDuration)
	else
		Knockback.apply(defender.root, horizontal, upSpeed, cfg.KnockbackDuration)
	end
end

type HitResult = "Dodged" | "Parried" | "Blocked" | "GuardBroken" | "Hit"

local function resolveHit(attacker: CombatState, defender: CombatState, profile: AttackProfile): HitResult
	local t = now()

	if t < defender.iframeUntil then
		return "Dodged"
	end

	local facing = isFacing(defender, attacker)

	if facing and t < defender.parryWindowEnd then
		defender.parryLanded = true
		defender.whiffStreak = 0
		defender.parryCooldownUntil = 0 -- successful parries can be chained
		applyStun(attacker, Config.Parry.AttackerStun)
		Fx.flash(defender.model, Color3.new(1, 1, 1), 0.25)
		Fx.flash(attacker.model, Color3.fromRGB(255, 220, 120), 0.4)
		return "Parried"
	end

	if facing and defender.blocking then
		defender.posture -= profile.PostureDamage
		defender.lastPostureHit = t
		if defender.posture <= 0 then
			defender.posture = Config.Block.PostureMax
			defender.model:SetAttribute("Posture", defender.posture)
			applyStun(defender, Config.Block.GuardBreakStun)
			Fx.flash(defender.model, Color3.fromRGB(255, 140, 0), 0.5)
			return "GuardBroken"
		end
		defender.model:SetAttribute("Posture", defender.posture)
		Fx.flash(defender.model, Color3.fromRGB(120, 170, 255), 0.15)
		return "Blocked"
	end

	defender.humanoid:TakeDamage(profile.Damage)
	-- Hitstun outlasts the gap to the attacker's next hit, so M1 chains are true combos.
	applyStun(defender, profile.HitStun)
	if profile.Ragdoll then
		setRagdoll(defender, true)
	end
	if profile.Knockback or profile.LaunchUp then
		launch(attacker, defender, profile.Knockback or 0, profile.LaunchUp or 0)
	end
	Fx.flash(defender.model, Color3.fromRGB(255, 40, 40), 0.2)
	return "Hit"
end

-- A box in front of the attacker, optionally stretched downward (downslam).
local function getHitBox(state: CombatState, profile: AttackProfile): (CFrame, Vector3)
	local reachDown = profile.ReachDown or 0
	local offset = CFrame.new(0, -reachDown / 2, -profile.Range / 2)
	return state.root.CFrame * offset, Vector3.new(profile.Width, 5 + reachDown, profile.Range)
end

-- Living combatants (other than the attacker) inside the attack's hitbox.
local function findTargets(state: CombatState, profile: AttackProfile): { CombatState }
	local boxCFrame, boxSize = getHitBox(state, profile)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.model }

	local targets: { CombatState } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(boxCFrame, boxSize, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] then
			seen[model] = true
			local defender = states[model]
			if defender and defender.humanoid.Health > 0 then
				table.insert(targets, defender)
			end
		end
	end
	return targets
end

-- The hit frame: show the slash pose, then resolve everything in the hitbox.
local function strike(state: CombatState, token: number, profile: AttackProfile, isHeavy: boolean)
	local model = state.model
	setAttacking(state, false)
	Fx.clearWindup(model)
	model:SetAttribute("SwingPhase", "Slash")
	local boxCFrame, boxSize = getHitBox(state, profile)
	Fx.slash(boxCFrame, boxSize, isHeavy)
	for _, defender in findTargets(state, profile) do
		resolveHit(state, defender, profile)
	end

	task.delay(SLASH_POSE_TIME, function()
		if states[model] == state and state.attackToken == token then
			model:SetAttribute("SwingPhase", "None")
		end
	end)
end

local function isAirborne(humanoid: Humanoid): boolean
	local humanoidState = humanoid:GetState()
	return humanoidState == Enum.HumanoidStateType.Freefall or humanoidState == Enum.HumanoidStateType.Jumping
end

-- M1. `modifier` only matters on the finisher: "Up" (Space held) uppercuts,
-- "Down" (airborne, checked here too) downslams.
-- Returns whether a swing started.
function CombatService.attack(model: Model, modifier: string?): boolean
	local state = states[model]
	if not state or state.blocking or state.attacking or isStunned(state) then
		return false
	end
	local t = now()
	if t < state.attackReadyAt then
		return false
	end

	local cfg = Config.Attack
	if t - state.lastAttackTime > cfg.ComboResetTime then
		state.combo = 0
	end
	state.combo = state.combo % cfg.ComboLength + 1
	state.lastAttackTime = t

	local isFinisher = state.combo == cfg.ComboLength
	local profile: AttackProfile = cfg.Combo[state.combo]
	if isFinisher then
		profile = if modifier == "Up"
			then cfg.Uppercut
			elseif modifier == "Down" and isAirborne(state.humanoid) then cfg.Downslam
			else cfg.Finisher
	end

	state.attackReadyAt = t + profile.Windup + profile.Recovery
	state.attackToken += 1
	local token = state.attackToken
	setAttacking(state, true)
	model:SetAttribute("SwingVariant", state.combo)
	model:SetAttribute("SwingPhase", "Windup")
	Fx.windup(model, profile.Windup, isFinisher)

	task.delay(profile.Windup, function()
		-- A stun or feint during windup bumps the token and cancels the swing.
		if states[model] == state and state.attackToken == token then
			strike(state, token, profile, isFinisher)
		end
	end)
	return true
end

-- Forward dodge: the lunge is the windup, and the hit lands on first contact.
-- A lunge that touches nobody whiffs quietly and doesn't open the combo.
local function startDashAttack(state: CombatState)
	local model = state.model
	if state.attacking or now() < state.attackReadyAt then
		return
	end
	local profile = Config.Attack.Dash
	local window = Config.Dash.FrontDuration + Config.Dash.ContactGrace
	local deadline = now() + window

	state.attackReadyAt = deadline
	state.attackToken += 1
	local token = state.attackToken
	setAttacking(state, true)
	model:SetAttribute("SwingVariant", 1)
	model:SetAttribute("SwingPhase", "Windup")
	Fx.windup(model, window, false)

	task.spawn(function()
		while now() < deadline do
			RunService.Heartbeat:Wait()
			if states[model] ~= state or state.attackToken ~= token then
				return
			end
			if #findTargets(state, profile) > 0 then
				local t = now()
				state.combo = 1 -- the next M1 is hit 2
				state.lastAttackTime = t
				state.attackReadyAt = t + profile.Recovery
				strike(state, token, profile, false)
				return
			end
		end
		if states[model] == state and state.attackToken == token then
			setAttacking(state, false)
			model:SetAttribute("SwingPhase", "None")
		end
	end)
end

-- M2 during windup: cancel the swing to bait a parry. The feinted swing doesn't
-- advance the combo, and a new swing can start almost immediately.
function CombatService.feint(model: Model): boolean
	local state = states[model]
	if not state or not state.attacking or isStunned(state) then
		return false
	end
	local t = now()
	if t < state.feintReadyAt then
		return false
	end

	cancelSwing(state)
	state.combo = math.max(0, state.combo - 1)
	state.attackReadyAt = t + Config.Feint.ReswingDelay
	state.feintReadyAt = t + Config.Feint.Cooldown
	model:SetAttribute("FeintReadyAt", workspace:GetServerTimeNow() + Config.Feint.Cooldown)
	return true
end

-- Q. `direction` is the client's classification of the dodge ("Front", "Back", "Left", "Right").
-- Charges: every dodge restarts the recharge timer; when it completes, all charges refill.
function CombatService.dash(model: Model, direction: string): boolean
	local state = states[model]
	if not state or isStunned(state) or state.dodgeCharges <= 0 then
		return false
	end
	local t = now()

	local isFront = direction == "Front"
	-- The forward lunge is a commitment: it spends every charge.
	state.dodgeCharges = if isFront then 0 else state.dodgeCharges - 1
	state.dodgeRechargeAt = t + Config.Dash.RechargeTime
	state.iframeUntil = t + Config.Dash.IFrames
	model:SetAttribute("DodgeCharges", state.dodgeCharges)
	setBlocking(state, false) -- dodging drops your guard

	if isFront then
		startDashAttack(state)
	end
	return true
end

-- Per-frame upkeep: clear expired stuns and ragdolls, regenerate posture, refill dodges.
RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for model, state in states do
		if model:GetAttribute("Stunned") and t >= state.stunUntil then
			model:SetAttribute("Stunned", false)
			setRagdoll(state, false)
		end

		local postureMax = Config.Block.PostureMax
		if state.posture < postureMax and t - state.lastPostureHit >= Config.Block.PostureRegenDelay then
			state.posture = math.min(postureMax, state.posture + Config.Block.PostureRegenRate * dt)
			model:SetAttribute("Posture", math.ceil(state.posture))
		end

		if state.dodgeCharges < Config.Dash.Charges and t >= state.dodgeRechargeAt then
			state.dodgeCharges = Config.Dash.Charges
			model:SetAttribute("DodgeCharges", state.dodgeCharges)
		end
	end
end)

return CombatService
