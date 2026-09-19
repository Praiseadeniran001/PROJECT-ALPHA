--[[
	Place this LocalScript inside a TextButton or ImageButton in StarterGui.
	Replace print/warn with the game's result animation and notification UI.
	Do not grant rewards or remove Gold here; all economy logic belongs on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local button = script.Parent
local rollGacha = ReplicatedStorage:WaitForChild("RollGacha")

assert(button:IsA("GuiButton"), "This LocalScript must be inside a GUI button")

local waitingForServer = false

button.Activated:Connect(function()
	if waitingForServer then return end
	waitingForServer = true
	button.Active = false

	local requestWorked, result = pcall(function()
		return rollGacha:InvokeServer()
	end)

	waitingForServer = false
	button.Active = true

	if not requestWorked then
		warn("The gacha request failed. Please try again.")
	elseif not result.Success then
		warn(result.Error)
	else
		print(`You received {result.Amount}x {result.RewardName}!`)
		print(`Gold remaining: {result.GoldRemaining}`)
	end
end)

