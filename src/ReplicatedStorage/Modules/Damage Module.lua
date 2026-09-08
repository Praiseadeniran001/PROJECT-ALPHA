local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StatusEffectModule = require(script.Parent.StatusEffectModule)
local RagdollModule = require(script.Parent.RagdollModule)

local DamageModule = {}

--=========================================================
-- COMBAT FOUNDATION -- CENTRAL DAMAGE CALCULATION
--
-- This is the ONE authoritative point where Class modifiers
-- are applied to a base damage number. It is a PURE function
-- (no TakeDamage call, no side effects) so it can be dropped
-- into any existing damage call site -- including ones that
-- must NOT gain DamageModule.Damage's side effects (stun,
-- camera shake, damage indicator) -- without changing that
-- site's existing hit behavior, only the final number.
--
-- metadata (optional) = {
--     DamageType = "Melee" | "Ability" | "Projectile" | "Environmental" | "NPC",
--     Source = "SwordM1" (free-form, for logging/debugging),
--     IsPlayerAttack = true/false,
-- }
--
-- If metadata is omitted entirely, this function is not
-- consulted by DamageModule.Damage (see below) -- existing
-- callers that don't pass metadata are byte-for-byte
-- unaffected by this addition.
--=========================================================

function DamageModule.CalculateFinalDamage(attacker, victim, baseDamage, metadata)
	if type(baseDamage) ~= "number" then
		return baseDamage
	end

	local finalDamage = baseDamage
	metadata = metadata or {}

	--=====================================================
	-- ATTACKER-SIDE MODIFIERS
	-- Only meaningful if the attacker is an actual Player
	-- (NPCs / environmental hazards have no Class and are
	-- safely skipped -- see COMBAT FOUNDATION Test F).
	--=====================================================

	if attacker and typeof(attacker) == "Instance" and attacker:IsA("Player") then
		if metadata.DamageType == "Melee" then
			finalDamage = finalDamage * (attacker:GetAttribute("MeleeDamageMultiplier") or 1)
		elseif metadata.DamageType == "Ability" then
			finalDamage = finalDamage * (attacker:GetAttribute("AbilityDamageMultiplier") or 1)
		end
		-- "Projectile" / "Environmental" / "NPC" / unset: no attacker-side
		-- Class modifier is defined for these yet -- base damage passes
		-- through unchanged, same as before centralization.
	end

	--=====================================================
	-- DEFENDER-SIDE MODIFIERS
	-- Only meaningful if the victim is a player's character.
	--=====================================================

	local defenderPlayer = Players:GetPlayerFromCharacter(victim)
	if defenderPlayer then
		finalDamage = finalDamage * (defenderPlayer:GetAttribute("DamageTakenMultiplier") or 1)

		-- Defense: NOT ACTIVATED. No established Defense formula exists
		-- yet in this project (per Combat Foundation task instructions).
		-- Intentionally left as a documented no-op rather than guessing
		-- a formula. Future formula slots in here, e.g.:
		--   finalDamage = finalDamage * DefenseReductionFormula(defenderPlayer)

		-- KnockbackResistance: out of scope for the damage pipeline --
		-- knockback is applied by each call site independently and is
		-- not touched by this task.
	end

	return finalDamage
end

function DamageModule.Damage(attacker,victim,damage,ragdoll,metadata)

	local hum = victim:FindFirstChild("Humanoid")

	if not hum then

		return

	end

	-- Only run the centralized calculation when a caller explicitly
	-- opts in by passing metadata. Existing callers (Ice moveset,
	-- Meteor shii) never pass a 5th argument, so `damage` reaches
	-- TakeDamage completely unchanged for them -- zero behavior change.
	local finalDamage = damage
	if metadata then
		finalDamage = DamageModule.CalculateFinalDamage(attacker, victim, damage, metadata)
	end

	hum:TakeDamage(finalDamage)

	StatusEffectModule.Stun(victim, 0.2)

	local root = victim:FindFirstChild("HumanoidRootPart")

	if root then

		ReplicatedStorage.RemoteEvents.DamageIndicator:FireAllClients(

			root.Position,

			finalDamage

		)

		-- Guard against a nil/non-Player attacker (e.g. a future
		-- environmental source routed through the full bundle).
		-- Every existing caller always passes a valid Player, so this
		-- guard changes nothing for them.
		if attacker and typeof(attacker) == "Instance" and attacker:IsA("Player") then
			ReplicatedStorage.RemoteEvents.CameraShake:FireClient(

				attacker,

				.12

			)
		end

	end

	if ragdoll then

		RagdollModule.Enable(victim,2)

	end

end

return DamageModule