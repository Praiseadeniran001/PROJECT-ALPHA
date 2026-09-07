--[[
	GachaService.server.lua - place this Script in ServerScriptService.

	EXPECTED PLAYER VALUES (example IntValue setup)
	- player.leaderstats.Gold: currency used to buy a roll
	- player.leaderstats.Money: possible reward
	- player.EXP: possible reward
	- player.PowerOrbs: possible reward

	This script creates ReplicatedStorage.RollGacha automatically. A LocalScript calls
	RollGacha:InvokeServer(). The server checks Gold, charges the player, rolls, and
	grants the result. Never accept price, reward Id, amount, or chances from a client.

	If the game uses ProfileService, DataStore2, or custom player data, replace the
	IntValue code below with that system's server-side read/write functions.

	ADDING A REWARD
	1. Add it to REWARDS in RewardRoller.lua.
	2. Add a function to REWARD_HANDLERS below. Its key must exactly match its Id.
	3. Return true after successfully granting it, or false to refund the Gold cost.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RewardRoller = require(ServerScriptService:WaitForChild("RewardRoller"))

local rollGacha = ReplicatedStorage:FindFirstChild("RollGacha")
if not rollGacha then
	rollGacha = Instance.new("RemoteFunction")
	rollGacha.Name = "RollGacha"
	rollGacha.Parent = ReplicatedStorage
end
assert(rollGacha:IsA("RemoteFunction"), "RollGacha must be a RemoteFunction")

local function getIntValue(parent: Instance?, name: string): IntValue?
	local value = parent and parent:FindFirstChild(name)
	return if value and value:IsA("IntValue") then value else nil
end

local REWARD_HANDLERS = {
	PowerOrb = function(player: Player, amount: number): boolean
		local value = getIntValue(player, "PowerOrbs")
		if not value then return false end
		value.Value += amount
		return true
	end,
	Money = function(player: Player, amount: number): boolean
		local value = getIntValue(player:FindFirstChild("leaderstats"), "Money")
		if not value then return false end
		value.Value += amount
		return true
	end,
	EXP = function(player: Player, amount: number): boolean
		local value = getIntValue(player, "EXP")
		if not value then return false end
		value.Value += amount
		return true
	end,
}

local ROLL_COOLDOWN = 0.5 -- Increase this if the roll animation is longer.
local lastRollTime: {[Player]: number} = {}

rollGacha.OnServerInvoke = function(player: Player)
	local now = os.clock()
	if lastRollTime[player] and now - lastRollTime[player] < ROLL_COOLDOWN then
		return {Success = false, Error = "Please wait before rolling again."}
	end
	lastRollTime[player] = now

	local gold = getIntValue(player:FindFirstChild("leaderstats"), "Gold")
	if not gold then return {Success = false, Error = "Gold value was not found."} end
	if gold.Value < RewardRoller.GACHA_COST then
		return {Success = false, Error = "Not enough Gold."}
	end

	local reward = RewardRoller.Roll()
	local handler = REWARD_HANDLERS[reward.Id]
	if not handler then
		warn(`No reward handler exists for Id: {reward.Id}`)
		return {Success = false, Error = "This reward is not configured."}
	end

	gold.Value -= RewardRoller.GACHA_COST
	if not handler(player, reward.Amount) then
		gold.Value += RewardRoller.GACHA_COST -- Refund if granting fails.
		warn(`Could not grant {reward.Id} to {player.Name}; Gold was refunded.`)
		return {Success = false, Error = "Reward failed. Gold was refunded."}
	end

	return {
		Success = true,
		RewardId = reward.Id,
		RewardName = reward.DisplayName,
		Amount = reward.Amount,
		GoldSpent = RewardRoller.GACHA_COST,
		GoldRemaining = gold.Value,
	}
end

Players.PlayerRemoving:Connect(function(player)
	lastRollTime[player] = nil
end)

