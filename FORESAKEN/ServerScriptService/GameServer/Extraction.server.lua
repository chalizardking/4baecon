--[[
	FORESAKEN Extraction Server Script
	Handles extraction zones, player extraction mechanics, and rewards
	
	Features:
	- Extract zone creation and management
	- Timed extraction mechanics (8-second channel)
	- Extract zone opening at specific match times
	- Combat interruption of extraction
	- Reward calculation and distribution
	- Anti-griefing protection
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Items = require(ReplicatedStorage.Shared.Modules.Items)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)
local MathUtil = require(ReplicatedStorage.Shared.Modules.Util.Math)

-- Extraction System
local ExtractionSystem = {}

-- Extract zone data
local ExtractZones = {}
local PlayerExtractions = {}
local ZoneLocations = {
	["ZoneA"] = Vector3.new(75, 5, 75),
	["ZoneB"] = Vector3.new(-75, 5, -75)
}

-- Extraction state tracking
local ExtractionStates = {}

-- Extract zone configuration
local EXTRACT_CHANNEL_TIME = Config.GameRules.RequiredExtractTime
local EXTRACT_RADIUS = 15
local EXTRACT_HEIGHT = 20

-- Initialize networking
NetEvents.Initialize()

-- Create extract zone model
local function createExtractZone(zoneId: string, position: Vector3): Model
	local zoneModel = Instance.new("Model")
	zoneModel.Name = "ExtractZone_" .. zoneId
	
	-- Main extraction area
	local extractArea = Instance.new("Part")
	extractArea.Name = "ExtractArea"
	extractArea.Size = Vector3.new(EXTRACT_RADIUS * 2, 1, EXTRACT_RADIUS * 2)
	extractArea.Position = position
	extractArea.BrickColor = BrickColor.new("Bright green")
	extractArea.Material = Enum.Material.ForceField
	extractArea.Transparency = 0.5
	extractArea.CanCollide = false
	extractArea.Anchored = true
	extractArea.Shape = Enum.PartType.Cylinder
	extractArea.Parent = zoneModel
	
	-- Extract zone boundary (invisible collision detector)
	local boundary = Instance.new("Part")
	boundary.Name = "Boundary"
	boundary.Size = Vector3.new(EXTRACT_RADIUS * 2, EXTRACT_HEIGHT, EXTRACT_RADIUS * 2)
	boundary.Position = position + Vector3.new(0, EXTRACT_HEIGHT / 2, 0)
	boundary.Transparency = 1
	boundary.CanCollide = false
	boundary.Anchored = true
	boundary.Parent = zoneModel
	
	-- Add zone identifier
	local zoneInfo = Instance.new("StringValue")
	zoneInfo.Name = "ZoneID"
	zoneInfo.Value = zoneId
	zoneInfo.Parent = zoneModel
	
	-- Add active state
	local activeState = Instance.new("BoolValue")
	activeState.Name = "Active"
	activeState.Value = false
	activeState.Parent = zoneModel
	
	-- Visual effects
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(0, 255, 0)
	pointLight.Brightness = 2
	pointLight.Range = 25
	pointLight.Parent = extractArea
	
	-- Beacon effect
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(2, 10, 2)
	beacon.Position = position + Vector3.new(0, 5, 0)
	beacon.BrickColor = BrickColor.new("Bright green")
	beacon.Material = Enum.Material.Neon
	beacon.CanCollide = false
	beacon.Anchored = true
	beacon.Parent = zoneModel
	
	-- Beacon animation
	local beaconTween = TweenService:Create(beacon,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Transparency = 0.8}
	)
	beaconTween:Play()
	
	-- Add to workspace
	zoneModel.Parent = workspace
	CollectionService:AddTag(zoneModel, "ExtractZone")
	
	return zoneModel
end

-- Initialize extract zones
local function initializeExtractZones()
	-- Look for existing extract zone locations
	local extractFolder = workspace:FindFirstChild("ExtractZones")
	if extractFolder then
		for _, zone in pairs(extractFolder:GetChildren()) do
			if zone:IsA("BasePart") then
				local zoneId = zone.Name
				ZoneLocations[zoneId] = zone.Position
			end
		end
	end
	
	-- Create extract zone models
	for zoneId, position in pairs(ZoneLocations) do
		local zoneModel = createExtractZone(zoneId, position)
		ExtractZones[zoneId] = {
			model = zoneModel,
			position = position,
			active = false,
			playersInZone = {},
			lastActivation = 0
		}
	end
	
	print("Initialized", #ZoneLocations, "extract zones")
end

-- Check if player is in extract zone
local function isPlayerInZone(player: Player, zoneId: string): boolean
	local zoneData = ExtractZones[zoneId]
	if not zoneData or not zoneData.active then return false end
	
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	local playerPosition = player.Character.HumanoidRootPart.Position
	local zonePosition = zoneData.position
	
	-- Check if within radius and height
	local horizontalDistance = Vector2.new(
		playerPosition.X - zonePosition.X,
		playerPosition.Z - zonePosition.Z
	).Magnitude
	
	local verticalDistance = math.abs(playerPosition.Y - zonePosition.Y)
	
	return horizontalDistance <= EXTRACT_RADIUS and verticalDistance <= EXTRACT_HEIGHT
end

-- Update player zone presence
local function updatePlayerZonePresence()
	for _, player in pairs(Players:GetPlayers()) do
		for zoneId, zoneData in pairs(ExtractZones) do
			local inZone = isPlayerInZone(player, zoneId)
			local wasInZone = zoneData.playersInZone[player.UserId] ~= nil
			
			if inZone and not wasInZone then
				-- Player entered zone
				zoneData.playersInZone[player.UserId] = tick()
				
				NetEvents.SendToClient(player, "ExtractZoneEntered", {
					zoneId = zoneId,
					extractTime = EXTRACT_CHANNEL_TIME
				})
				
				print(player.Name, "entered extract zone", zoneId)
				
			elseif not inZone and wasInZone then
				-- Player left zone
				zoneData.playersInZone[player.UserId] = nil
				
				-- Cancel any ongoing extraction
				if ExtractionStates[player.UserId] then
					cancelExtraction(player, "LeftZone")
				end
				
				NetEvents.SendToClient(player, "ExtractZoneExited", {
					zoneId = zoneId
				})
				
				print(player.Name, "left extract zone", zoneId)
			end
		end
	end
end

-- Start extraction process
local function startExtraction(player: Player, zoneId: string)
	local zoneData = ExtractZones[zoneId]
	if not zoneData or not zoneData.active then return end
	
	if not isPlayerInZone(player, zoneId) then return end
	
	-- Check if player is already extracting
	if ExtractionStates[player.UserId] then return end
	
	-- Check if player is alive
	local CombatSystem = require(script.Parent.Combat)
	if not CombatSystem.IsPlayerAlive(player) then return end
	
	-- Initialize extraction state
	ExtractionStates[player.UserId] = {
		player = player,
		zoneId = zoneId,
		startTime = tick(),
		progress = 0,
		interrupted = false
	}
	
	-- Send extraction started event
	NetEvents.SendToClient(player, "ExtractionStarted", {
		zoneId = zoneId,
		duration = EXTRACT_CHANNEL_TIME
	})
	
	-- Notify other players in the area
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local distance = (otherPlayer.Character.HumanoidRootPart.Position - zoneData.position).Magnitude
			if distance <= 50 then
				NetEvents.SendToClient(otherPlayer, "PlayerExtracting", {
					playerName = player.Name,
					zoneId = zoneId
				})
			end
		end
	end
	
	print(player.Name, "started extraction in", zoneId)
end

-- Cancel extraction
function cancelExtraction(player: Player, reason: string)
	local extractionState = ExtractionStates[player.UserId]
	if not extractionState then return end
	
	extractionState.interrupted = true
	ExtractionStates[player.UserId] = nil
	
	-- Send cancellation event
	NetEvents.SendToClient(player, "ExtractionCancelled", {
		reason = reason,
		progress = extractionState.progress
	})
	
	print(player.Name, "extraction cancelled:", reason)
end

-- Complete extraction
local function completeExtraction(player: Player)
	local extractionState = ExtractionStates[player.UserId]
	if not extractionState then return end
	
	ExtractionStates[player.UserId] = nil
	
	-- Calculate rewards based on items carried (would integrate with inventory system)
	local SaveSystem = require(script.Parent.Save)
	local profile = SaveSystem.GetPlayerProfile(player)
	
	if profile then
		-- Award extraction XP
		SaveSystem.AddXP(player, Config.Economy.ExtractXP)
		
		-- Increment extraction count
		SaveSystem.UpdatePlayerProfile(player, function(p)
			p.stats.extracts = p.stats.extracts + 1
			return p
		end)
		
		-- Award currency based on items extracted (simplified)
		local rewardAmount = 100 -- Base extraction reward
		SaveSystem.AddCurrency(player, rewardAmount)
	end
	
	-- Send completion event
	NetEvents.SendToClient(player, "ExtractionComplete", {
		success = true,
		rewards = {
			xp = Config.Economy.ExtractXP,
			currency = 100
		}
	})
	
	-- Remove player from game (successful extraction)
	NetEvents.SendToAllClients("PlayerExtracted", {
		playerName = player.Name,
		zoneId = extractionState.zoneId
	})
	
	-- Fire analytics event
	Signals.Get("ExtractCompleted"):Fire(player, extractionState.zoneId)
	
	print(player.Name, "successfully extracted from", extractionState.zoneId)
	
	-- Optional: Remove player character or teleport to hideout
	task.spawn(function()
		task.wait(2)
		if player.Character then
			player.Character:Destroy()
		end
	end)
end

-- Update extraction progress
local function updateExtractions()
	for playerId, extractionState in pairs(ExtractionStates) do
		if extractionState.interrupted then
			continue
		end
		
		local player = extractionState.player
		local zoneId = extractionState.zoneId
		local currentTime = tick()
		
		-- Check if player is still in zone
		if not isPlayerInZone(player, zoneId) then
			cancelExtraction(player, "LeftZone")
			continue
		end
		
		-- Check if player is still alive
		local CombatSystem = require(script.Parent.Combat)
		if not CombatSystem.IsPlayerAlive(player) then
			cancelExtraction(player, "Died")
			continue
		end
		
		-- Update progress
		local elapsed = currentTime - extractionState.startTime
		extractionState.progress = elapsed / EXTRACT_CHANNEL_TIME
		
		-- Send progress update
		NetEvents.SendToClient(player, "ExtractionProgress", {
			progress = extractionState.progress,
			timeRemaining = EXTRACT_CHANNEL_TIME - elapsed
		})
		
		-- Check for completion
		if elapsed >= EXTRACT_CHANNEL_TIME then
			completeExtraction(player)
		end
	end
end

-- Activate extract zones
local function activateExtractZones(zoneIds: {string})
	for _, zoneId in ipairs(zoneIds) do
		local zoneData = ExtractZones[zoneId]
		if zoneData then
			zoneData.active = true
			zoneData.model.Active.Value = true
			zoneData.lastActivation = tick()
			
			-- Visual activation effect
			local extractArea = zoneData.model:FindFirstChild("ExtractArea")
			if extractArea then
				extractArea.BrickColor = BrickColor.new("Lime green")
				extractArea.Transparency = 0.3
			end
			
			print("Activated extract zone:", zoneId)
		end
	end
	
	-- Notify all players
	NetEvents.SendToAllClients("ExtractZonesActivated", {
		zones = zoneIds
	})
end

-- Handle network events
NetEvents.OnServerEvent("ExtractEnter", function(player: Player, data)
	local zoneId = data.zoneId
	startExtraction(player, zoneId)
end)

NetEvents.OnServerEvent("ExtractExit", function(player: Player, data)
	if ExtractionStates[player.UserId] then
		cancelExtraction(player, "PlayerCancelled")
	end
end)

-- Handle combat interruption
Signals.Get("PlayerDamaged"):Connect(function(victim, attacker, weapon, damage)
	if ExtractionStates[victim.UserId] then
		cancelExtraction(victim, "TookDamage")
	end
end)

-- Handle extract zone opening
Signals.Get("ExtractOpened"):Connect(function(zoneIds)
	activateExtractZones(zoneIds)
end)

-- Player cleanup
local function onPlayerRemoving(player: Player)
	ExtractionStates[player.UserId] = nil
	
	-- Remove from zone tracking
	for _, zoneData in pairs(ExtractZones) do
		zoneData.playersInZone[player.UserId] = nil
	end
end

-- Public API
function ExtractionSystem.ActivateZone(zoneId: string)
	activateExtractZones({zoneId})
end

function ExtractionSystem.ActivateAllZones()
	local allZoneIds = {}
	for zoneId in pairs(ExtractZones) do
		table.insert(allZoneIds, zoneId)
	end
	activateExtractZones(allZoneIds)
end

function ExtractionSystem.DeactivateZone(zoneId: string)
	local zoneData = ExtractZones[zoneId]
	if zoneData then
		zoneData.active = false
		zoneData.model.Active.Value = false
		
		-- Cancel any ongoing extractions in this zone
		for playerId, extractionState in pairs(ExtractionStates) do
			if extractionState.zoneId == zoneId then
				cancelExtraction(extractionState.player, "ZoneDeactivated")
			end
		end
		
		print("Deactivated extract zone:", zoneId)
	end
end

function ExtractionSystem.GetActiveZones(): {string}
	local activeZones = {}
	for zoneId, zoneData in pairs(ExtractZones) do
		if zoneData.active then
			table.insert(activeZones, zoneId)
		end
	end
	return activeZones
end

function ExtractionSystem.GetPlayersInZone(zoneId: string): {Player}
	local players = {}
	local zoneData = ExtractZones[zoneId]
	if zoneData then
		for playerId in pairs(zoneData.playersInZone) do
			local player = Players:GetPlayerByUserId(playerId)
			if player then
				table.insert(players, player)
			end
		end
	end
	return players
end

function ExtractionSystem.IsPlayerExtracting(player: Player): boolean
	return ExtractionStates[player.UserId] ~= nil
end

function ExtractionSystem.GetExtractionProgress(player: Player): number?
	local extractionState = ExtractionStates[player.UserId]
	if extractionState then
		return extractionState.progress
	end
	return nil
end

-- Initialize system
function ExtractionSystem.Initialize()
	initializeExtractZones()
	
	-- Start update loops
	RunService.Heartbeat:Connect(updatePlayerZonePresence)
	RunService.Heartbeat:Connect(updateExtractions)
	
	-- Connect player events
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	
	print("Extraction System initialized")
end

-- Initialize on script load
ExtractionSystem.Initialize()

return ExtractionSystem