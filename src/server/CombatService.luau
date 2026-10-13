-- Server-authoritative combat state for any character model (players and NPCs alike).
--
-- Replicated attributes set on each registered model, read by clients:
--   Stunned       (bool)    can't move, attack, block or dodge
--   Blocking      (bool)    F is held
--   Attacking     (bool)    in a swing's windup
--   Posture       (number)  0..PostureMax, guard breaks when full
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
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fx = require(script.Parent.Fx)

type AttackProfile = Config.AttackProfile

export type CombatState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,

	stunUntil: number,
	iframeUntil: number,

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
		blocking = false,
		posture = 0,
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
	model:SetAttribute("Posture", 0)
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
local function launch(attacker: CombatState, defender: CombatState, speed: number)
	local away = defender.root.Position - attacker.root.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 1e-3 then
		away = attacker.root.CFrame.LookVector
		away = Vector3.new(away.X, 0, away.Z)
	end
	local horizontal = away.Unit * speed
	local cfg = Config.Attack

	local player = Players:GetPlayerFromCharacter(defender.model)
	if player then
		Remotes.Knockback:FireClient(player, horizontal, cfg.KnockbackUpSpeed, cfg.KnockbackDuration)
	else
		Knockback.apply(defender.root, horizontal, cfg.KnockbackUpSpeed, cfg.KnockbackDuration)
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
		defender.posture += profile.PostureDamage
		defender.lastPostureHit = t
		if defender.posture >= Config.Block.PostureMax then
			defender.posture = 0
			defender.model:SetAttribute("Posture", 0)
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
	if profile.Knockback then
		launch(attacker, defender, profile.Knockback)
	end
	Fx.flash(defender.model, Color3.fromRGB(255, 40, 40), 0.2)
	return "Hit"
end

local function performHit(state: CombatState, profile: AttackProfile, isHeavy: boolean)
	local boxCFrame = state.root.CFrame * CFrame.new(0, 0, -profile.Range / 2)
	local boxSize = Vector3.new(profile.Width, 5, profile.Range)

	Fx.slash(boxCFrame, boxSize, isHeavy)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.model }

	local alreadyHit: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(boxCFrame, boxSize, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not alreadyHit[model] then
			alreadyHit[model] = true
			local defender = states[model]
			if defender and defender.humanoid.Health > 0 then
				resolveHit(state, defender, profile)
			end
		end
	end
end

-- Starts a swing. `isDashAttack` = triggered by a forward dodge: it always
-- opens the combo, so the next M1 continues from hit 2.
-- Returns whether a swing started.
function CombatService.attack(model: Model, isDashAttack: boolean?): boolean
	local state = states[model]
	if not state or state.blocking or state.attacking or isStunned(state) then
		return false
	end
	local t = now()
	if t < state.attackReadyAt then
		return false
	end

	local cfg = Config.Attack
	if isDashAttack then
		state.combo = 1
	else
		if t - state.lastAttackTime > cfg.ComboResetTime then
			state.combo = 0
		end
		state.combo = state.combo % cfg.ComboLength + 1
	end
	state.lastAttackTime = t

	local isFinisher = state.combo == cfg.ComboLength
	local profile: AttackProfile = if isDashAttack then cfg.Dash elseif isFinisher then cfg.Finisher else cfg.Normal

	state.attackReadyAt = t + profile.Windup + profile.Recovery
	state.attackToken += 1
	local token = state.attackToken
	setAttacking(state, true)
	model:SetAttribute("SwingVariant", state.combo)
	model:SetAttribute("SwingPhase", "Windup")
	Fx.windup(model, profile.Windup, isFinisher)

	task.delay(profile.Windup, function()
		-- A stun or feint during windup bumps the token and cancels the swing.
		if states[model] ~= state or state.attackToken ~= token then
			return
		end
		setAttacking(state, false)
		model:SetAttribute("SwingPhase", "Slash")
		performHit(state, profile, isFinisher)

		task.delay(SLASH_POSE_TIME, function()
			if states[model] == state and state.attackToken == token then
				model:SetAttribute("SwingPhase", "None")
			end
		end)
	end)
	return true
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

	state.dodgeCharges -= 1
	state.dodgeRechargeAt = t + Config.Dash.RechargeTime
	state.iframeUntil = t + Config.Dash.IFrames
	model:SetAttribute("DodgeCharges", state.dodgeCharges)
	setBlocking(state, false) -- dodging drops your guard

	if direction == "Front" then
		CombatService.attack(model, true)
	end
	return true
end

-- Per-frame upkeep: clear expired stuns, regenerate posture, refill dodges.
RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for model, state in states do
		if model:GetAttribute("Stunned") and t >= state.stunUntil then
			model:SetAttribute("Stunned", false)
		end

		if state.posture > 0 and t - state.lastPostureHit >= Config.Block.PostureRegenDelay then
			state.posture = math.max(0, state.posture - Config.Block.PostureRegenRate * dt)
			model:SetAttribute("Posture", math.floor(state.posture))
		end

		if state.dodgeCharges < Config.Dash.Charges and t >= state.dodgeRechargeAt then
			state.dodgeCharges = Config.Dash.Charges
			model:SetAttribute("DodgeCharges", state.dodgeCharges)
		end
	end
end)

return CombatService
