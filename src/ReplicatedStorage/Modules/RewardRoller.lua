--[[
	RewardRoller.lua - place this ModuleScript in ServerScriptService.

	CONFIGURATION
	- Change GACHA_COST to set the Gold price of one roll.
	- Weight is a relative drop chance. Weights 10, 55, 35 equal 10%, 55%, 35%.
	  They do not need to total 100: weights 1, 2, 7 mean 10%, 20%, 70%.
	- MinAmount/MaxAmount set the quantity range. Use the same number for a fixed amount.
	- To add a reward, copy a REWARDS entry, assign a unique Id, and add a function
	  with the same Id to REWARD_HANDLERS in GachaService.server.lua.
	- To remove a reward, delete its table entry. Do not use Weight = 0.
	- DisplayName may be changed freely; Id connects the reward to its server handler.

	POWER ORB TYPES
	- If Power Orb wins, the script performs a second roll for one of ORB_TYPES.
	- There are four entries, so each one has exactly a 25% chance.
	- Replace every placeholder Id with the real orb/item Id used by the game.
	- Keep all four Id values unique. DisplayName is only text shown to the player.
]]

local RewardRoller = {}

RewardRoller.GACHA_COST = 100

local REWARDS = {
	{Id = "PowerOrb", DisplayName = "Power Orb", Weight = 10, MinAmount = 1, MaxAmount = 1},
	{Id = "Money", DisplayName = "Money", Weight = 55, MinAmount = 100, MaxAmount = 500},
	{Id = "EXP", DisplayName = "EXP", Weight = 35, MinAmount = 25, MaxAmount = 100},
}

local ORB_TYPES = {
	{Id = "REPLACE_WITH_ORB_ID_1", DisplayName = "Orb 1"}, -- 25%
	{Id = "REPLACE_WITH_ORB_ID_2", DisplayName = "Orb 2"}, -- 25%
	{Id = "REPLACE_WITH_ORB_ID_3", DisplayName = "Orb 3"}, -- 25%
	{Id = "REPLACE_WITH_ORB_ID_4", DisplayName = "Orb 4"}, -- 25%
}

export type RolledReward = {
	Id: string,
	DisplayName: string,
	Amount: number,
	OrbId: string?,
	OrbDisplayName: string?,
}

local random = Random.new()
local totalWeight = 0

for _, reward in REWARDS do
	assert(type(reward.Id) == "string" and reward.Id ~= "", "Every reward needs an Id")
	assert(reward.Weight > 0, `{reward.Id} must have a Weight greater than 0`)
	assert(reward.MinAmount >= 0, `{reward.Id} cannot have a negative MinAmount`)
	assert(reward.MaxAmount >= reward.MinAmount, `{reward.Id} has an invalid amount range`)
	totalWeight += reward.Weight
end

function RewardRoller.Roll(): RolledReward
	local roll = random:NextNumber(0, totalWeight)
	local accumulatedWeight = 0

	for _, reward in REWARDS do
		accumulatedWeight += reward.Weight
		if roll <= accumulatedWeight then
			local result: RolledReward = {
				Id = reward.Id,
				DisplayName = reward.DisplayName,
				Amount = random:NextInteger(reward.MinAmount, reward.MaxAmount),
			}

			-- A Power Orb result triggers an equal 1-in-4 secondary roll.
			if reward.Id == "PowerOrb" then
				local selectedOrb = ORB_TYPES[random:NextInteger(1, #ORB_TYPES)]
				result.OrbId = selectedOrb.Id
				result.OrbDisplayName = selectedOrb.DisplayName
			end

			return result
		end
	end

	-- Fallback for a possible floating-point precision edge case.
	local fallback = REWARDS[#REWARDS]
	return {
		Id = fallback.Id,
		DisplayName = fallback.DisplayName,
		Amount = random:NextInteger(fallback.MinAmount, fallback.MaxAmount),
	}
end


return RewardRoller
