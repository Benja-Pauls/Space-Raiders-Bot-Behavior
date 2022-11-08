-- Ensure that entire worldspace has spawned
local worldSpace = workspace:WaitForChild('Worldspace')
worldSpace:WaitForChild('Plate1'); worldSpace:WaitForChild('Plate16')

local serverEventsFolder = game.ServerStorage:WaitForChild('ServerEvents')
local respawnBotServerEvent = serverEventsFolder:WaitForChild("RespawnBot")

local shipsFolder = workspace:WaitForChild('Ships')
local botsFolder = game.ReplicatedStorage:WaitForChild('BotShips')
local testBot = botsFolder:WaitForChild('TestManTheTestBot')
local botBehavior = script:WaitForChild('BotBehavior')

--[[
	Spawn in a new bot
	@param plate: The plate the bot will be correlated with
	@param plateNumber: Number of the plate
]]
local function spawnBot(plate, plateNumber)
	local newBot = testBot:Clone()
	newBot.Parent = shipsFolder
	newBot.CFrame = plate.CFrame
	newBot.Hitbox.CFrame = newBot.CFrame
	newBot.CFrame += Vector3.new(0, -newBot.Position.Y, 0) -- Move to N,0,N
	newBot.Name = "Bot" .. plateNumber
	newBot.Hitbox.Name = newBot.Name .. "'s Hitbox"

	-- Move GUI_Display into position too
	if newBot:FindFirstChild('GUI_Display') then
		newBot.GUI_Display.Position = newBot.Position + Vector3.new(0, 10, 0) -- up a bit
		newBot.GUI_Display.CFrame *= CFrame.new(0, 0, newBot.GUI_Display.Distance.Value) -- Offset downward by set amount for that ship
	end

	local blockNumReference = Instance.new("StringValue", newBot)
	blockNumReference.Name = "BlockNum"
	blockNumReference.Value = plateNumber

	local botBehavior = script:WaitForChild('BotBehavior'):Clone()
	botBehavior.Parent = newBot
	botBehavior.Enabled = true
end

-- Spawn fresh bots in each area
for _,plate in pairs (worldSpace:GetChildren()) do
	if string.match(plate.Name, "Plate") ~= nil then
		if plate.Name ~= "Plate10" and plate.Name ~= "Plate11" and plate.Name ~= "Plate7" and plate.Name ~= "Plate6" then
			wait(7) -- Some delay between spawning all the bots
			spawnBot(plate, string.gsub(plate.Name, "Plate", ""))
		end
	end
end

--[[
	Respawn a bot that has just died
	@param botName: Name of the bot that just died (Example: Bot16)
]]
respawnBotServerEvent.Event:Connect(function(botName)
	wait(20) -- Wait some time until immediately respawning the bot again (spawn cooldown)
	local plateNumber = string.gsub(botName, "Bot", "")
	local plate = worldSpace:FindFirstChild("Plate"..plateNumber)
	spawnBot(plate, plateNumber)
end)










