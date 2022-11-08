local MOVE_OFFSET = 0.45
local CHASE_RANGE = 120

local UP = CFrame.new(0,0,-MOVE_OFFSET)
local LEFT = CFrame.new(-MOVE_OFFSET,0,0)
local DOWN = CFrame.new(0,0,MOVE_OFFSET)
local RIGHT = CFrame.new(MOVE_OFFSET,0,0)
local UP_RIGHT = CFrame.new(MOVE_OFFSET, 0, -MOVE_OFFSET)
local UP_LEFT = CFrame.new(-MOVE_OFFSET, 0, -MOVE_OFFSET)
local DOWN_RIGHT = CFrame.new(-MOVE_OFFSET, 0, MOVE_OFFSET)
local DOWN_LEFT = CFrame.new(-MOVE_OFFSET, 0, MOVE_OFFSET)
local MOVEMENT_OPTIONS = {UP, LEFT, DOWN, RIGHT, UP_RIGHT, UP_LEFT, DOWN_RIGHT, DOWN_LEFT}

local TRAIL_DEBUG = false -- If a trail should be left behind the bots to see where they went

local Utility = require(game.ServerScriptService.Utility)
local serverEventsFolder = game.ServerStorage:WaitForChild('ServerEvents')
local fireWeaponsServerEvent = serverEventsFolder:WaitForChild('FireWeaponsServer')
local respawnBotServerEvent = serverEventsFolder:WaitForChild('RespawnBot')

local bot = script.Parent
local blockNumber = bot:WaitForChild('BlockNum').Value

-- Have simple movement scheme of moving the ship forward a certain direction for a certain amount of time
-- moveUp/Down/Right/Left


-- This way, when the ship is (per say) chasing someone, they simply have to calculate which direction will get the closest to the player and perform that task
-- This will also make the ships seem a bit dumb (which is good) because their decisions will be delayed based on the more sporadic player movement
-- If the player is far-enough away in a certain direction, they will also attempt to boost
-- If the player is too close to them, no matter if the bot is scared or not, the bot will back up
-- BOTS MUST BE ABLE TO HANDLE BEING BOUNCED


-----------------<<|| Ship Controls ||>>-------------------------------------------------------------------------

--[[
	Turn the bot towards some direction
	@param direction: Direction to face the ship towards
]]
local function updateBotRotation(direction)
	local targetOrientation = Vector3.new(0, 0, 0) -- up by default
	if direction == RIGHT then
		targetOrientation = Vector3.new(0, -90, 0)
	elseif direction == LEFT then
		targetOrientation = Vector3.new(0, 90, 0)
	elseif direction == UP_RIGHT then
		targetOrientation = Vector3.new(0, -45, 0)
	elseif direction == UP_LEFT then
		targetOrientation = Vector3.new(0, 45, 0)
	elseif direction == DOWN_RIGHT then
		targetOrientation = Vector3.new(0, -135, 0)
	elseif direction == DOWN_LEFT then
		targetOrientation = Vector3.new(0, 135, 0)
	elseif direction == DOWN then
		if bot.Orientation.Y >= 90 then
			targetOrientation = Vector3.new(0, 180, 0)
		else
			targetOrientation = Vector3.new(0, -180, 0) 
		end
	end
	
	local rotationDiff = (targetOrientation.Y - bot.Orientation.Y)/5
	for i = 1,5,1 do
		wait()
		bot.CFrame *= CFrame.Angles(0, math.rad(rotationDiff), 0)
	end
end

--[[
	Boost the ship forward
]]
local function boostShip()
	bot:FindFirstChild(bot.Name .. "'s Hitbox").BoostSound:Play()
	
	local boostParticle1 = game.ReplicatedStorage.Effects.BoostParticle1:Clone()
	local boostParticle2 = game.ReplicatedStorage.Effects.BoostParticle2:Clone()
	boostParticle1.Parent = bot
	boostParticle2.Parent = bot
	bot:FindFirstChild(tostring(bot.Name).."'s Hitbox").BoostSound:Play()
	
	for i = 1,8 do -- Boost player's ship forward
		wait()
		bot.CFrame *= CFrame.new(0, 0, 5*UP.Z)
	end
	
	wait(.3)
	boostParticle1.Enabled = false
	boostParticle2.Enabled = false
	wait(1.5)
	boostParticle1:Destroy()
	boostParticle2:Destroy()
end

--[[
	Move the bot is a particular direction for some amount of distance
	@param direction: Direction to move in   (Up:0,0,-1 | Left:-1,0,0 | Down:0,0,1 | Right:1,0,0)
	@param distance: Number of studs to move
	@param noUpdate: True if there is no need to check the rotation of the ship
	@param boost: True if the ship is boosting away
]]
local function moveBot(direction, distance, noUpdate, boost)
	-- Rotate the ship to face the direction is should move
	if not noUpdate then
		updateBotRotation(direction)
	end
	
	-- Update the location of the bot smoothly
	for i = 1,distance*10,1 do
		wait()
		
		-- The ship has already rotated so that it just needs to move forward 
		if boost then
			boostShip()
		else
			bot.CFrame *= UP
		end
		
		bot.GUI_Display.Position = bot.Position + Vector3.new(0, 10, 0) -- up a bit
		bot.GUI_Display.CFrame *= CFrame.new(0, 0, bot.GUI_Display.Distance.Value) -- Offset downward by set amount for that ship
		
		-- Leave trail markers
		if TRAIL_DEBUG then
			local marker = Instance.new("Part", workspace)
			marker.Anchored = true
			marker.Name = "Marker"
			marker.Size = Vector3.new(1, 1, 1)
			marker.Material = Enum.Material.Neon
			marker.Color = Color3.fromRGB(209, 0, 0)
			marker.Position = bot.Position
		end
	end
end

--[[
	Fire the weapons on the bot
]]
local function fireWeapons()
	local firstBlasterReached = false
	
	for _,blaster in pairs (bot:GetChildren()) do
		if blaster.Name == "Blaster" then
			if firstBlasterReached then
				fireWeaponsServerEvent:Fire(bot, blaster.Position, blaster.Rotation)
			else
				firstBlasterReached = true
				fireWeaponsServerEvent:Fire(bot, blaster.Position, blaster.Rotation, true)
			end
		end
	end
end

--[[
	The bot has been destroyed
]]
local function destroyBot()
	local deathExplosion = game.ReplicatedStorage.Effects.DeathExplosion:Clone()
	local botPostiion = bot.Position; local botName = bot.Name
	bot:Destroy()
	
	deathExplosion.Skull:Destroy()
	deathExplosion.Parent = workspace
	deathExplosion.Position = botPostiion
	deathExplosion.ExplosionSound:Play()
	wait(.2)
	deathExplosion.Explosion.Enabled = false
	deathExplosion.Smoke.Enabled = false
	wait(2)
	deathExplosion:Destroy()
	respawnBotServerEvent:Fire(botName)
end


------------------<<|| Ship Utility ||>>----------------------------------------------------------------------

--[[
	Check if the ship is within the expected bounds of the plate it first spawned at
]]
local function withinBlockBounds()
	local plate = workspace.Worldspace:FindFirstChild("Plate" .. blockNumber)
	local platePosition = plate.Position
	local botPosition = bot.Position
	
	-- Plate size is: 479.5,1,479.5
	local maxX = platePosition.X + plate.Size.X/1.5; local minX = platePosition.X - plate.Size.X/1.5
	local maxZ = platePosition.Z + plate.Size.Z/1.5; local minZ = platePosition.Z - plate.Size.Z/1.5
	if botPosition.X > minX and botPosition.X < maxX and botPosition.Z > minZ and botPosition.Z < maxZ then
		return true
	else
		return false
	end
end

--[[
	Check that the bot and a hitbox are within range for the bot to notice the hitbox
	@param hitbox: Hitbox that the bot could possible see
]]
local function checkDistance(hitbox)
	if hitbox then
		local dist = (bot.Position - hitbox.Position).Magnitude
		if dist <= CHASE_RANGE then
			return dist
		else
			return false
		end
	else
		return false
	end
end

--[[
	See if the bot should be scared of the nearest player it sees
	@param hitbox: Hitbox of nearest player it sees
	
	@return True if the bot should chase that player
]]
local function checkIfShouldChase(hitbox)
	if hitbox then
		local playerUserId = string.gsub(hitbox.Name, "'s Hitbox", "")
		local playerData = game.ServerStorage.PlayerData:FindFirstChild(playerUserId)
		if playerData then
			local playerLevel = playerData.SessionData.Level.Value
			if playerLevel > 6 then
				return false
			else
				return true
			end
		end
	end
end

--[[
	Determine the hit direction for two colliding objects
	@param hit1: First hitbox being hit
	@param hit2: Second hitbox being hit
]]
local function getBounceDirections(hit1, hit2, constant)
	-- Determine positive or negative direction for each of the bounced players
	local x_diff, z_diff = hit1.CFrame.X - hit2.CFrame.X, hit1.CFrame.Z - hit2.CFrame.Z
	local other_x_dir, other_z_dir, player_x_dir, player_z_dir
	if x_diff < 0 then
		player_x_dir = 1; other_x_dir = -1
	else
		player_x_dir = -1; other_x_dir = 1
	end
	if z_diff < 0 then
		player_z_dir = 1; other_z_dir = -1
	else
		player_z_dir = -1; other_z_dir = 1
	end

	-- Move the ship proportional to the half lengths of the other ship
	local other_x_dim, other_z_dim = hit1.Size.X/3, hit1.Size.Z/3
	local player_x_dim, player_z_dim = hit2.Size.Z/3, hit2.Size.Z/3
	if constant then
		other_x_dim = constant; other_z_dim = constant
		player_x_dim = constant; player_z_dim = constant
	end
	local player_push = Vector3.new(other_x_dim*player_x_dir, 0, other_z_dim*player_z_dir)
	local other_push = Vector3.new(player_x_dim*other_x_dir, 0, player_z_dim*other_z_dir)
	return player_push,other_push
end

--[[
	Go back the way each of the players came (make a unit vector from current and prev CFrame)
	@param hitbox  The hitbox that will be moved (and used as movement reference)
	@param pushDirection Vector3 representing direction player will be bounced towards
	@param filter: True if the player bouncing should be filtered out from updates to clients
]]
local function pushBackShip()
	for m = 1,7 do
		wait()
		bot.CFrame *= CFrame.new(0, 0, 5*MOVE_OFFSET)
	end
end

-------------------<<|| Ship AI ||>>------------------------------------------------------------------------------


function lookForPlayers()
	-- Find all ships within range of bot
	local availableHitboxes = {}
	for _,hitbox in pairs (game.Workspace:WaitForChild('Ships'):GetChildren()) do
		if string.match(hitbox.Name, 'Hitbox') then
			local dist = checkDistance(hitbox)
			if dist then
				table.insert(availableHitboxes, {hitbox, dist})
			end
		end
	end

	-- Select target which is seeable and closest
	if #availableHitboxes >= 1 then
		local closestHitbox = {availableHitboxes[1], 42} -- default value
		for _,hitboxInfo in pairs (availableHitboxes) do
			if hitboxInfo[2] < closestHitbox[2] then
				closestHitbox = hitboxInfo
			end
		end
		return closestHitbox[1]
	else
		return nil
	end
end

--[[
	Drive the ship directly back to the center of their spawn block. Like an ESO enemy returning to their spawn point
]]
function returnToBlockNumber()
	-- print("RETURNING TO THE PLATE")
	local plate = workspace.Worldspace:FindFirstChild("Plate" .. blockNumber)
	bot.CFrame = CFrame.new(bot.Position, plate.Position)
	-- print("DIFF: ", (bot.Position - plate.Position).Magnitude)
	moveBot(nil, (bot.Position - plate.Position).Magnitude/14, true)
	wander() -- Returned to their appropraite block, start wandering again
end


--[[
	Wander the ship around randomly
	Move back to block number if exceed certain range from spawn point
]]
function wander()
	while withinBlockBounds() do
		-- Determine random direction to move in 
		local direction = MOVEMENT_OPTIONS[math.random(1, 8)]
		moveBot(direction, 4)
		
		-- Check if there is anyone nearby
		local foundHitbox = lookForPlayers()
		if foundHitbox then
			if type(foundHitbox) == "table" then
				foundHitbox = foundHitbox[1]
			end
			if checkIfShouldChase(foundHitbox) then
				chase(foundHitbox)
			else
				runAway(foundHitbox.Position)
			end
		end
	end

	-- Leaving the bounds of their block number. Return to an inner portion of the block
	returnToBlockNumber()
end

--[[
	Start chasing and attacking a particular hitbox
	@param hitbox: Hitbox that the bot will be chasing
]]
function chase(hitbox)
	local distance = true
	local hitboxParent = hitbox.Parent
	local hitboxName = hitbox.Name
	while distance do
		hitbox = hitboxParent:FindFirstChild(hitboxName) -- update hitbox each time
		if hitbox then
			distance = checkDistance(hitbox)
			bot.CFrame = CFrame.new(bot.Position, hitbox.Position)

			if distance and distance > 35 then
				moveBot(nil, 1, true)
				if distance < 60 then
					fireWeapons()
					wait(1)
				end
			else
				fireWeapons()
				wait(1)
			end
		else
			distance = false
		end
	end
	wander() -- Done with chase, start wandering again
end



--[[
	Run away from a particular location
	@param location: Location the bot should try running away from
]]
function runAway(location)
	bot.CFrame = CFrame.new(bot.Position, location)
	bot.CFrame *= CFrame.Angles(0, math.rad(180), 0) -- Turn completely around
	boostShip()
end


---------------------<<|| Ship-Like Behavior ||>>--------------------------------------------------------------------------------------
local hitbox = bot:WaitForChild(bot.Name .. "'s Hitbox")
bot:WaitForChild(bot.Name .. "'s Hitbox").Touched:Connect(function(hit)
	if hit:IsDescendantOf(workspace.Ships) then
		pushBackShip()
	elseif hit.Name == "Material" then
		local worth = hit:FindFirstChild("Worth")
		if worth then
			hitbox.MatGain:Play()
			bot.Health.Value += worth.Value
			hit:Destroy()
		end
	elseif hit.Name == "Bounce" or hit.Name == "AsteroidBounce" or hit.Name == "CrackedBounce" then -- Asteroid, wall
		local player_push,other_push = getBounceDirections(hit, bot, 2.5)
		
		-- Bounce back
		hitbox.Bounce:Play()
		for m = 1,5 do
			wait()
			bot.CFrame += player_push/2
			bot.CFrame += Vector3.new(0, -bot.Position.Y, 0) -- Ensure staying on y-plane
		end
	elseif hit.Name == "BarrierMain" then
		local barrier = hit.Parent
		local pushDirection = barrier.Push.Value
		local hitbox = bot:FindFirstChild(bot.Name .. "'s Hitbox")
		
		if math.abs(pushDirection.Z) == 1 then
			local change = hitbox.Position.Z - (barrier.Wall.Position.Z + pushDirection.Z)
			pushDirection = Vector3.new(0, 0, change+1)
		else -- Change in X Direction
			local change = hitbox.Position.X - (barrier.Wall.Position.X + pushDirection.X)
			pushDirection = Vector3.new(change+1, 0, 0)
		end
		
		-- Bounce back
		hitbox.Bounce:Play()
		for m = 1,8 do
			wait()
			bot.CFrame += pushDirection
			bot.CFrame += Vector3.new(0, -bot.Position.Y, 0) -- Ensure staying on y-plane
		end
	end
end)

local guiDisplay = bot:WaitForChild('GUI_Display')
guiDisplay.SurfaceGui.PlayerInfo.PlayerName.Text = bot.Name
bot:WaitForChild('Health'):GetPropertyChangedSignal("Value"):Connect(function()
	local newHealth = bot.Health.Value
	if newHealth <= 0 then
		guiDisplay.SurfaceGui.PlayerInfo.MaterialCount.Text = "0"
		destroyBot()
	else
		guiDisplay.SurfaceGui.PlayerInfo.MaterialCount.Text = tostring(newHealth)
		guiDisplay.SurfaceGui.HealthBar.Background.Health.Size = UDim2.new(1,0,newHealth/3000,0)
	end
end)

wander() -- Upon instantiation, start wandering
