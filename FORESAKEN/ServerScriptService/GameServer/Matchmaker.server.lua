--[[
	FORESAKEN Matchmaker Server Script
	Handles player spawning, match state, and respawn mechanics
	
	Features:
	- Match lifecycle management
	- Player spawning at designated points
	- Spectator mode after death
	- Match timer and session limits
	- Player count management
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)

-- Matchmaker System
local Matchmaker = {}

-- Match state
local MatchState = {
	isActive = false,
	startTime = 0,
	endTime = 0,
	maxDuration = Config.Match.SessionMinutes * 60, -- Convert to seconds
	playerCount = 0,
	maxPlayers = Config.Match.MaxPlayers,
	extractZonesOpen = false,
	extractOpenTime = 0
}

-- Player states
local PlayerStates = {}
local SpawnLocations = {}
local SpectatorCameras = {}

-- Player state structure
local function createPlayerState(player: Player)
	return {
		isAlive = true,
		isSpectating = false,
		spawnTime = 0,
		deathTime = 0,
		canRespawn = false,
		spectatorTarget = nil,
		matchJoinTime = tick(),
		extractAttempts = 0
	}
end

-- Initialize spawn locations
local function initializeSpawnLocations()
	local spawnsFolder = workspace:FindFirstChild("Spawns")
	if spawnsFolder then
		local playerSpawns = spawnsFolder:FindFirstChild("Players")
		if playerSpawns then
			for _, spawn in pairs(playerSpawns:GetChildren()) do
				if spawn:IsA("BasePart") then
					table.insert(SpawnLocations, {
						position = spawn.Position,
						occupied = false,
						lastUsed = 0
					})
				end
			end
		end
	end
	
	-- Create default spawn locations if none found
	if #SpawnLocations == 0 then
		local defaultSpawns = {
			Vector3.new(0, 10, 0),
			Vector3.new(10, 10, 10),
			Vector3.new(-10, 10, 10),
			Vector3.new(10, 10, -10),
			Vector3.new(-10, 10, -10),
			Vector3.new(20, 10, 0),
			Vector3.new(-20, 10, 0),
			Vector3.new(0, 10, 20),
			Vector3.new(0, 10, -20),
			Vector3.new(15, 10, 15),
			Vector3.new(-15, 10, 15),
			Vector3.new(15, 10, -15)
		}
		
		for _, pos in ipairs(defaultSpawns) do
			table.insert(SpawnLocations, {
				position = pos,
				occupied = false,
				lastUsed = 0
			})
		end
	end
	
	print("Initialized", #SpawnLocations, "player spawn locations")
end

-- Find best spawn location
local function findBestSpawnLocation(): Vector3?
	if #SpawnLocations == 0 then return nil end
	
	-- Find unoccupied spawn that hasn't been used recently
	local bestSpawn = nil
	local bestScore = -1
	local currentTime = tick()
	
	for i, spawn in ipairs(SpawnLocations) do
		if not spawn.occupied then
			local timeSinceUsed = currentTime - spawn.lastUsed
			local score = timeSinceUsed
			
			-- Check distance from other players
			for _, player in pairs(Players:GetPlayers()) do
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local distance = (player.Character.HumanoidRootPart.Position - spawn.position).Magnitude
					if distance < 20 then
						score = score - (20 - distance) -- Penalty for being too close
					end
				end
			end
			
			if score > bestScore then
				bestScore = score
				bestSpawn = spawn
			end
		end
	end
	
	if bestSpawn then
		bestSpawn.occupied = true
		bestSpawn.lastUsed = currentTime
		
		-- Free up spawn after a delay
		task.spawn(function()
			task.wait(5)
			bestSpawn.occupied = false
		end)
		
		return bestSpawn.position
	end
	
	-- Fallback to any spawn if all are occupied
	local randomSpawn = SpawnLocations[math.random(1, #SpawnLocations)]
	return randomSpawn.position
end

-- Create spectator camera system
local function createSpectatorCamera(player: Player)
	local camera = Instance.new("Camera")
	camera.Name = "SpectatorCamera"
	camera.CameraType = Enum.CameraType.Scriptable
	
	-- Position camera above map
	camera.CFrame = CFrame.new(Vector3.new(0, 100, 0), Vector3.new(0, 0, 0))
	camera.Parent = workspace
	
	SpectatorCameras[player] = camera
	
	-- Send camera info to client
	NetEvents.SendToClient(player, "SpectatorModeEnabled", {
		cameraPosition = camera.CFrame.Position,
		availableTargets = getAlivePlayerNames()
	})
end

-- Get list of alive player names for spectating
local function getAlivePlayerNames(): {string}
	local aliveNames = {}
	for _, player in pairs(Players:GetPlayers()) do
		local playerState = PlayerStates[player.UserId]
		if playerState and playerState.isAlive then
			table.insert(aliveNames, player.Name)
		end
	end
	return aliveNames
end

-- Spawn player at location
local function spawnPlayerAtLocation(player: Player, position: Vector3)
	-- Create spawn location with slight offset to prevent overlap
	local spawnCFrame = CFrame.new(position + Vector3.new(0, 5, 0))
	
	-- Load character
	player:LoadCharacter()
	
	-- Wait for character to load
	local character = player.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	
	-- Set spawn position
	humanoidRootPart.CFrame = spawnCFrame
	
	-- Update player state
	local playerState = PlayerStates[player.UserId]
	if playerState then
		playerState.isAlive = true
		playerState.isSpectating = false
		playerState.spawnTime = tick()
		playerState.canRespawn = false
	end
	
	-- Clean up spectator camera
	if SpectatorCameras[player] then
		SpectatorCameras[player]:Destroy()
		SpectatorCameras[player] = nil
	end
	
	-- Send spawn notification to client
	NetEvents.SendToClient(player, "PlayerSpawned", {
		position = position,
		matchTime = MatchState.isActive and (tick() - MatchState.startTime) or 0
	})
	
	print("Spawned", player.Name, "at", position)
end

-- Handle player death
local function handlePlayerDeath(player: Player, killer: Player?, cause: string?)
	local playerState = PlayerStates[player.UserId]
	if not playerState then return end
	
	playerState.isAlive = false
	playerState.deathTime = tick()
	playerState.isSpectating = true
	
	-- Update match statistics
	local SaveSystem = require(script.Parent.Save)
	SaveSystem.UpdatePlayerProfile(player, function(profile)
		profile.stats.deaths = profile.stats.deaths + 1
		return profile
	end)
	
	-- Award XP to killer
	if killer and killer ~= player then
		SaveSystem.AddXP(killer, Config.Economy.KillXP)
		SaveSystem.UpdatePlayerProfile(killer, function(profile)
			profile.stats.pvpkills = profile.stats.pvpkills + 1
			return profile
		end)
	end
	
	-- Create spectator camera
	createSpectatorCamera(player)
	
	-- Send death notification
	NetEvents.SendToAllClients("PlayerDeath", {
		victim = player.Name,
		killer = killer and killer.Name,
		cause = cause,
		spectateTime = Config.Match.SpectateTimeSeconds
	})
	
	-- Schedule respawn after spectate time (in survival-extraction, usually no respawn)
	if not Config.GameRules.RespawnEnabled then
		-- In extraction mode, players stay dead until next match
		playerState.canRespawn = false
	else
		task.spawn(function()
			task.wait(Config.Match.SpectateTimeSeconds)
			if playerState.isSpectating then
				playerState.canRespawn = true
				NetEvents.SendToClient(player, "RespawnAvailable", {})
			end
		end)
	end
	
	print(player.Name, "died", killer and ("killed by " .. killer.Name) or "")
end

-- Handle player respawn request
local function handleRespawnRequest(player: Player)
	local playerState = PlayerStates[player.UserId]
	if not playerState or not playerState.canRespawn then return end
	
	local spawnPosition = findBestSpawnLocation()
	if spawnPosition then
		spawnPlayerAtLocation(player, spawnPosition)
	end
end

-- Start new match
local function startMatch()
	if MatchState.isActive then return end
	
	MatchState.isActive = true
	MatchState.startTime = tick()
	MatchState.endTime = MatchState.startTime + MatchState.maxDuration
	MatchState.extractOpenTime = MatchState.startTime + (Config.Match.ExtractOpenAt.t * 60)
	MatchState.extractZonesOpen = false
	
	-- Spawn all connected players
	for _, player in pairs(Players:GetPlayers()) do
		local spawnPosition = findBestSpawnLocation()
		if spawnPosition then
			spawnPlayerAtLocation(player, spawnPosition)
		end
	end
	
	-- Send match start notification
	NetEvents.SendToAllClients("MatchStarted", {
		duration = MatchState.maxDuration,
		extractOpenTime = Config.Match.ExtractOpenAt.t * 60,
		playerCount = #Players:GetPlayers()
	})
	
	-- Fire analytics event
	Signals.Get("MatchStarted"):Fire(#Players:GetPlayers())
	
	print("Match started with", #Players:GetPlayers(), "players")
end

-- End current match
local function endMatch(reason: string?)
	if not MatchState.isActive then return end
	
	MatchState.isActive = false
	
	-- Calculate match results
	local survivors = {}
	local totalExtracts = 0
	
	for _, player in pairs(Players:GetPlayers()) do
		local playerState = PlayerStates[player.UserId]
		if playerState and playerState.isAlive then
			table.insert(survivors, player.Name)
		end
		if playerState then
			totalExtracts = totalExtracts + playerState.extractAttempts
		end
	end
	
	-- Send match end notification
	NetEvents.SendToAllClients("MatchEnded", {
		reason = reason or "TimeLimit",
		duration = tick() - MatchState.startTime,
		survivors = survivors,
		totalExtracts = totalExtracts
	})
	
	-- Fire analytics event
	Signals.Get("MatchEnded"):Fire(survivors, totalExtracts, tick() - MatchState.startTime)
	
	print("Match ended:", reason or "Time limit reached")
	
	-- Start new match after delay
	task.spawn(function()
		task.wait(10) -- 10 second break between matches
		if #Players:GetPlayers() > 0 then
			startMatch()
		end
	end)
end

-- Update match state
local function updateMatchState()
	if not MatchState.isActive then return end
	
	local currentTime = tick()
	
	-- Check if extract zones should open
	if not MatchState.extractZonesOpen and currentTime >= MatchState.extractOpenTime then
		MatchState.extractZonesOpen = true
		
		NetEvents.SendToAllClients("ExtractZonesOpened", {
			zones = Config.Match.ExtractOpenAt.zones
		})
		
		Signals.Get("ExtractOpened"):Fire(Config.Match.ExtractOpenAt.zones)
		print("Extract zones opened")
	end
	
	-- Check if match should end
	if currentTime >= MatchState.endTime then
		endMatch("TimeLimit")
	end
	
	-- Check if all players are dead
	local alivePlayers = 0
	for _, player in pairs(Players:GetPlayers()) do
		local playerState = PlayerStates[player.UserId]
		if playerState and playerState.isAlive then
			alivePlayers = alivePlayers + 1
		end
	end
	
	if alivePlayers == 0 and #Players:GetPlayers() > 0 then
		endMatch("AllPlayersDead")
	end
end

-- Player management
local function onPlayerAdded(player: Player)
	PlayerStates[player.UserId] = createPlayerState(player)
	MatchState.playerCount = #Players:GetPlayers()
	
	-- Connect player death events
	player.CharacterRemoving:Connect(function(character)
		-- This is called when character is about to be removed
		-- The actual death handling is done in Combat.server.lua
	end)
	
	-- Auto-start match if enough players
	if not MatchState.isActive and MatchState.playerCount >= 2 then
		task.spawn(function()
			task.wait(5) -- Give time for players to load
			startMatch()
		end)
	elseif MatchState.isActive then
		-- Join ongoing match
		local spawnPosition = findBestSpawnLocation()
		if spawnPosition then
			spawnPlayerAtLocation(player, spawnPosition)
		end
	end
	
	print("Player joined:", player.Name, "- Total players:", MatchState.playerCount)
end

local function onPlayerRemoving(player: Player)
	PlayerStates[player.UserId] = nil
	MatchState.playerCount = #Players:GetPlayers() - 1
	
	-- Clean up spectator camera
	if SpectatorCameras[player] then
		SpectatorCameras[player]:Destroy()
		SpectatorCameras[player] = nil
	end
	
	print("Player left:", player.Name, "- Total players:", MatchState.playerCount)
end

-- Network event handlers
NetEvents.OnServerEvent("RequestRespawn", handleRespawnRequest)

-- Public API
function Matchmaker.StartMatch()
	startMatch()
end

function Matchmaker.EndMatch(reason: string?)
	endMatch(reason)
end

function Matchmaker.GetMatchState()
	return MatchState
end

function Matchmaker.GetPlayerState(player: Player)
	return PlayerStates[player.UserId]
end

function Matchmaker.HandlePlayerDeath(player: Player, killer: Player?, cause: string?)
	handlePlayerDeath(player, killer, cause)
end

function Matchmaker.IsMatchActive(): boolean
	return MatchState.isActive
end

function Matchmaker.GetAlivePlayerCount(): number
	local count = 0
	for _, player in pairs(Players:GetPlayers()) do
		local playerState = PlayerStates[player.UserId]
		if playerState and playerState.isAlive then
			count = count + 1
		end
	end
	return count
end

-- Initialize system
function Matchmaker.Initialize()
	initializeSpawnLocations()
	
	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	
	-- Handle players already in game
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	
	-- Start match state update loop
	RunService.Heartbeat:Connect(updateMatchState)
	
	print("Matchmaker initialized")
end

-- Initialize on script load
Matchmaker.Initialize()

return Matchmaker