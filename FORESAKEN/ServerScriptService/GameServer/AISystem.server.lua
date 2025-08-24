--[[
	FORESAKEN AI System Server Script
	Manages enemy spawning, AI behavior trees, and pathfinding
	
	Features:
	- Enemy spawning with weights and limits
	- Behavior tree execution
	- Pathfinding with PathfindingService
	- State management for all AI entities
	- Combat AI integration
]]

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Enemies = require(ReplicatedStorage.Shared.Modules.Enemies)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)
local MathUtil = require(ReplicatedStorage.Shared.Modules.Util.Math)

-- AI System
local AISystem = {}

-- Active AI entities
local ActiveEnemies = {}
local EnemyCount = {}
local SpawnLocations = {}
local LastSpawnTime = {}

-- Behavior tree execution state
local BehaviorTreeState = {}

-- AI Update frequency
local AI_UPDATE_INTERVAL = 0.1 -- 10 times per second
local lastAIUpdate = 0

-- Initialize spawn locations
local function initializeSpawnLocations()
	local spawnsFolder = workspace:FindFirstChild("Spawns")
	if spawnsFolder then
		local enemySpawns = spawnsFolder:FindFirstChild("Enemies")
		if enemySpawns then
			for _, spawn in pairs(enemySpawns:GetChildren()) do
				if spawn:IsA("BasePart") then
					table.insert(SpawnLocations, spawn.Position)
				end
			end
		end
	end
	
	-- If no spawn locations found, create default ones
	if #SpawnLocations == 0 then
		SpawnLocations = {
			Vector3.new(50, 5, 50),
			Vector3.new(-50, 5, 50),
			Vector3.new(50, 5, -50),
			Vector3.new(-50, 5, -50),
			Vector3.new(0, 5, 75),
			Vector3.new(0, 5, -75)
		}
	end
	
	print("Initialized", #SpawnLocations, "enemy spawn locations")
end

-- Create enemy model
local function createEnemyModel(enemyId: string, position: Vector3): Model?
	local enemyData = Enemies.GetEnemyData(enemyId)
	if not enemyData then return nil end
	
	local model = Instance.new("Model")
	model.Name = enemyData.name
	
	-- Create humanoid root part
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Position = position
	rootPart.BrickColor = BrickColor.new("Dark stone grey")
	rootPart.TopSurface = Enum.SurfaceType.Smooth
	rootPart.BottomSurface = Enum.SurfaceType.Smooth
	rootPart.Parent = model
	
	-- Create head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Position = position + Vector3.new(0, 1.5, 0)
	head.BrickColor = BrickColor.new("Light stone grey")
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Parent = model
	
	-- Create torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = position
	torso.BrickColor = BrickColor.new("Medium stone grey")
	torso.TopSurface = Enum.SurfaceType.Smooth
	torso.BottomSurface = Enum.SurfaceType.Smooth
	torso.Parent = model
	
	-- Create humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = enemyData.health
	humanoid.Health = enemyData.health
	humanoid.WalkSpeed = enemyData.speed
	humanoid.JumpPower = 50
	humanoid.Parent = model
	
	-- Weld parts together
	local neckWeld = Instance.new("WeldConstraint")
	neckWeld.Part0 = torso
	neckWeld.Part1 = head
	neckWeld.Parent = torso
	
	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = rootPart
	rootWeld.Part1 = torso
	rootWeld.Parent = rootPart
	
	-- Add AI identifier
	local aiTag = Instance.new("StringValue")
	aiTag.Name = "AIType"
	aiTag.Value = enemyId
	aiTag.Parent = model
	
	-- Add to collection service for easy tracking
	CollectionService:AddTag(model, "AIEnemy")
	
	model.Parent = workspace
	
	-- Create health bar
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 25)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = head
	
	local healthBar = Instance.new("Frame")
	healthBar.Size = UDim2.new(1, 0, 0.4, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = billboard
	
	local healthBG = Instance.new("Frame")
	healthBG.Size = UDim2.new(1, 0, 1, 0)
	healthBG.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	healthBG.BorderSizePixel = 0
	healthBG.ZIndex = healthBar.ZIndex - 1
	healthBG.Parent = billboard
	
	return model
end

-- Initialize AI state for an enemy
local function initializeAIState(enemy: Model, enemyId: string): {[string]: any}
	local enemyData = Enemies.GetEnemyData(enemyId)
	if not enemyData then return {} end
	
	local aiState = {
		-- Basic info
		model = enemy,
		enemyId = enemyId,
		enemyData = enemyData,
		
		-- Health and status
		currentHealth = enemyData.health,
		maxHealth = enemyData.health,
		isAlive = true,
		
		-- AI state
		currentState = "Idle",
		previousState = "Idle",
		stateTime = 0,
		
		-- Targets and awareness
		target = nil,
		lastKnownTargetPosition = nil,
		alertLevel = 0,
		detectionRadius = enemyData.detectRange,
		
		-- Movement
		destination = nil,
		path = nil,
		pathIndex = 1,
		isMoving = false,
		stuck = false,
		stuckTime = 0,
		lastPosition = Vector3.new(0, 0, 0),
		
		-- Combat
		lastAttackTime = 0,
		attackCooldown = 1.0,
		damageReceivedRecently = 0,
		lastDamageTime = 0,
		
		-- Special abilities
		chargeCooldown = 0,
		reinforcementCooldown = 0,
		
		-- Behavior tree
		behaviorTree = Enemies.GetBehaviorTree(enemyId),
		blackboard = {}
	}
	
	if enemy:FindFirstChild("HumanoidRootPart") then
		aiState.lastPosition = enemy.HumanoidRootPart.Position
	end
	
	return aiState
end

-- Find nearby players
local function findNearbyPlayers(position: Vector3, radius: number): {Player}
	local nearbyPlayers = {}
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
			if distance <= radius then
				table.insert(nearbyPlayers, player)
			end
		end
	end
	
	return nearbyPlayers
end

-- Behavior tree condition checks
local function checkCondition(aiState: {[string]: any}, condition: string): boolean
	if condition == "has_target" then
		return aiState.target ~= nil
		
	elseif condition == "in_attack_range" then
		if not aiState.target then return false end
		local distance = (aiState.model.HumanoidRootPart.Position - aiState.target.Character.HumanoidRootPart.Position).Magnitude
		return distance <= aiState.enemyData.attackRange
		
	elseif condition == "low_health" then
		local fleePercent = Enemies.GetSpecialProperty(aiState.enemyId, "fleeHealthPercent") or 0.3
		return aiState.currentHealth / aiState.maxHealth <= fleePercent
		
	elseif condition == "is_staggered" then
		return aiState.currentState == "Stagger"
		
	elseif condition == "charge_ready" then
		return aiState.chargeCooldown <= 0
		
	elseif condition == "under_heavy_fire" then
		return aiState.damageReceivedRecently > 30
		
	elseif condition == "reinforcement_ready" then
		return aiState.reinforcementCooldown <= 0
	end
	
	return false
end

-- Behavior tree actions
local function executeAction(aiState: {[string]: any}, action: string): boolean
	local humanoid = aiState.model:FindFirstChild("Humanoid")
	if not humanoid then return false end
	
	if action == "patrol" then
		if not aiState.destination or aiState.isMoving == false then
			-- Choose random patrol point
			local currentPos = aiState.model.HumanoidRootPart.Position
			local patrolDistance = Enemies.GetSpecialProperty(aiState.enemyId, "patrolDistance") or 20
			
			local randomDirection = Vector3.new(
				(math.random() - 0.5) * 2,
				0,
				(math.random() - 0.5) * 2
			).Unit
			
			aiState.destination = currentPos + randomDirection * patrolDistance
			aiState.isMoving = true
		end
		return true
		
	elseif action == "move_to_target" then
		if aiState.target and aiState.target.Character then
			aiState.destination = aiState.target.Character.HumanoidRootPart.Position
			aiState.isMoving = true
			return true
		end
		return false
		
	elseif action == "attack_target" then
		if aiState.target and aiState.target.Character then
			local currentTime = tick()
			if currentTime - aiState.lastAttackTime >= aiState.attackCooldown then
				-- Perform attack
				local distance = (aiState.model.HumanoidRootPart.Position - aiState.target.Character.HumanoidRootPart.Position).Magnitude
				if distance <= aiState.enemyData.attackRange then
					-- Deal damage to player
					NetEvents.SendToServer("Damage", {
						targetId = tostring(aiState.target.UserId),
						weaponId = "Enemy" .. aiState.enemyId,
						damage = aiState.enemyData.damage
					})
					
					aiState.lastAttackTime = currentTime
					return true
				end
			end
		end
		return false
		
	elseif action == "flee_from_target" then
		if aiState.target and aiState.target.Character then
			local currentPos = aiState.model.HumanoidRootPart.Position
			local targetPos = aiState.target.Character.HumanoidRootPart.Position
			local fleeDirection = (currentPos - targetPos).Unit
			
			aiState.destination = currentPos + fleeDirection * 30
			aiState.isMoving = true
			humanoid.WalkSpeed = aiState.enemyData.speed * 1.5 -- Flee faster
			return true
		end
		return false
		
	elseif action == "roam" then
		if not aiState.isMoving then
			local currentPos = aiState.model.HumanoidRootPart.Position
			local roamDistance = 15
			
			local randomDirection = Vector3.new(
				(math.random() - 0.5) * 2,
				0,
				(math.random() - 0.5) * 2
			).Unit
			
			aiState.destination = currentPos + randomDirection * roamDistance
			aiState.isMoving = true
		end
		return true
	end
	
	return false
end

-- Execute behavior tree
local function executeBehaviorTree(aiState: {[string]: any})
	local behaviorTree = aiState.behaviorTree
	if not behaviorTree then return end
	
	-- Simple behavior tree executor
	for _, node in ipairs(behaviorTree.nodes) do
		if node.type == "sequence" then
			local allSuccess = true
			for _, child in ipairs(node.children) do
				if child.type == "condition" then
					if not checkCondition(aiState, child.check) then
						allSuccess = false
						break
					end
				elseif child.type == "action" then
					if not executeAction(aiState, child.action) then
						allSuccess = false
						break
					end
				end
			end
			if allSuccess then
				break -- Successfully executed this sequence
			end
		elseif node.type == "action" then
			executeAction(aiState, node.action)
			break
		end
	end
end

-- Update AI pathfinding
local function updatePathfinding(aiState: {[string]: any})
	if not aiState.isMoving or not aiState.destination then return end
	
	local humanoid = aiState.model:FindFirstChild("Humanoid")
	local rootPart = aiState.model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	
	local currentPosition = rootPart.Position
	
	-- Check if we've reached the destination
	if (currentPosition - aiState.destination).Magnitude < 5 then
		aiState.isMoving = false
		aiState.destination = nil
		aiState.path = nil
		humanoid:MoveTo(currentPosition)
		return
	end
	
	-- Create path if we don't have one
	if not aiState.path then
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 4
		})
		
		local success, errorMessage = pcall(function()
			path:ComputeAsync(currentPosition, aiState.destination)
		end)
		
		if success and path.Status == Enum.PathStatus.Success then
			aiState.path = path
			aiState.pathIndex = 1
			local waypoints = path:GetWaypoints()
			if #waypoints > 1 then
				humanoid:MoveTo(waypoints[2].Position) -- Skip first waypoint (current position)
				aiState.pathIndex = 2
			end
		else
			-- Fallback to direct movement
			humanoid:MoveTo(aiState.destination)
		end
	else
		-- Follow existing path
		local waypoints = aiState.path:GetWaypoints()
		if aiState.pathIndex <= #waypoints then
			local currentWaypoint = waypoints[aiState.pathIndex]
			
			if (currentPosition - currentWaypoint.Position).Magnitude < 3 then
				aiState.pathIndex = aiState.pathIndex + 1
				if aiState.pathIndex <= #waypoints then
					humanoid:MoveTo(waypoints[aiState.pathIndex].Position)
				else
					-- Reached end of path
					aiState.isMoving = false
					aiState.destination = nil
					aiState.path = nil
				end
			end
		end
	end
	
	-- Check if stuck
	if (currentPosition - aiState.lastPosition).Magnitude < 0.5 then
		aiState.stuckTime = aiState.stuckTime + AI_UPDATE_INTERVAL
		if aiState.stuckTime > 3 then
			-- Been stuck for 3 seconds, try new path
			aiState.path = nil
			aiState.stuckTime = 0
		end
	else
		aiState.stuckTime = 0
	end
	
	aiState.lastPosition = currentPosition
end

-- Update AI awareness and targeting
local function updateAwareness(aiState: {[string]: any})
	local rootPart = aiState.model:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	local currentPosition = rootPart.Position
	local nearbyPlayers = findNearbyPlayers(currentPosition, aiState.detectionRadius)
	
	-- Find closest player
	local closestPlayer = nil
	local closestDistance = math.huge
	
	for _, player in ipairs(nearbyPlayers) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - currentPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestPlayer = player
			end
		end
	end
	
	-- Update target
	if closestPlayer and closestDistance <= aiState.detectionRadius then
		aiState.target = closestPlayer
		aiState.lastKnownTargetPosition = closestPlayer.Character.HumanoidRootPart.Position
		aiState.alertLevel = math.min(aiState.alertLevel + AI_UPDATE_INTERVAL, 1.0)
	else
		-- Lose target if too far away
		if aiState.target then
			local targetDistance = math.huge
			if aiState.target.Character and aiState.target.Character:FindFirstChild("HumanoidRootPart") then
				targetDistance = (aiState.target.Character.HumanoidRootPart.Position - currentPosition).Magnitude
			end
			
			if targetDistance > aiState.detectionRadius * 1.5 then
				aiState.target = nil
				aiState.alertLevel = math.max(aiState.alertLevel - AI_UPDATE_INTERVAL, 0)
			end
		end
	end
end

-- Update single AI entity
local function updateAI(aiState: {[string]: any})
	if not aiState.isAlive or not aiState.model.Parent then return end
	
	-- Update timers
	aiState.stateTime = aiState.stateTime + AI_UPDATE_INTERVAL
	aiState.chargeCooldown = math.max(0, aiState.chargeCooldown - AI_UPDATE_INTERVAL)
	aiState.reinforcementCooldown = math.max(0, aiState.reinforcementCooldown - AI_UPDATE_INTERVAL)
	
	-- Reduce recent damage over time
	if tick() - aiState.lastDamageTime > 5 then
		aiState.damageReceivedRecently = 0
	end
	
	-- Update awareness and targeting
	updateAwareness(aiState)
	
	-- Execute behavior tree
	executeBehaviorTree(aiState)
	
	-- Update pathfinding
	updatePathfinding(aiState)
	
	-- Update health bar
	local humanoid = aiState.model:FindFirstChild("Humanoid")
	if humanoid then
		local head = aiState.model:FindFirstChild("Head")
		if head and head:FindFirstChild("BillboardGui") then
			local healthBar = head.BillboardGui:FindFirstChild("Frame")
			if healthBar then
				local healthPercent = aiState.currentHealth / aiState.maxHealth
				healthBar.Size = UDim2.new(healthPercent, 0, 0.4, 0)
			end
		end
	end
end

-- Spawn enemy at random location
local function spawnEnemy(enemyId: string): Model?
	if #SpawnLocations == 0 then return nil end
	
	-- Check spawn limits
	local currentCount = EnemyCount[enemyId] or 0
	local maxCount = Enemies.GetMaxSpawnCount(enemyId)
	if currentCount >= maxCount then return nil end
	
	-- Choose random spawn location
	local spawnPosition = SpawnLocations[math.random(1, #SpawnLocations)]
	
	-- Create enemy model
	local enemy = createEnemyModel(enemyId, spawnPosition)
	if not enemy then return nil end
	
	-- Initialize AI state
	local aiState = initializeAIState(enemy, enemyId)
	ActiveEnemies[enemy] = aiState
	EnemyCount[enemyId] = currentCount + 1
	
	-- Handle enemy death
	local humanoid = enemy:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			aiState.isAlive = false
			EnemyCount[enemyId] = math.max(0, EnemyCount[enemyId] - 1)
			
			-- Drop loot
			local lootTable = Enemies.GetLootTable(enemyId)
			if lootTable then
				local lootItem = lootTable[math.random(1, #lootTable)]
				Signals.Get("LootSpawned"):Fire(lootItem, enemy.HumanoidRootPart.Position)
			end
			
			-- Clean up after delay
			task.wait(5)
			ActiveEnemies[enemy] = nil
			enemy:Destroy()
		end)
	end
	
	print("Spawned", enemyId, "at", spawnPosition)
	return enemy
end

-- Spawn enemies based on weights and limits
local function manageEnemySpawning()
	local totalEnemies = 0
	for _, count in pairs(EnemyCount) do
		totalEnemies = totalEnemies + count
	end
	
	-- Don't spawn if we have too many enemies
	if totalEnemies >= 20 then return end
	
	-- Try to spawn each enemy type
	for enemyId, _ in pairs(Enemies.GetAllEnemies()) do
		local currentCount = EnemyCount[enemyId] or 0
		local maxCount = Enemies.GetMaxSpawnCount(enemyId)
		local weight = Enemies.GetSpawnWeight(enemyId)
		
		if currentCount < maxCount then
			local lastSpawn = LastSpawnTime[enemyId] or 0
			local spawnCooldown = 30 / weight -- Higher weight = faster spawning
			
			if tick() - lastSpawn >= spawnCooldown then
				if math.random(1, 100) <= weight then
					spawnEnemy(enemyId)
					LastSpawnTime[enemyId] = tick()
				end
			end
		end
	end
end

-- Main AI update loop
local function updateAllAI()
	local currentTime = tick()
	if currentTime - lastAIUpdate < AI_UPDATE_INTERVAL then return end
	lastAIUpdate = currentTime
	
	-- Update all active AI
	for enemy, aiState in pairs(ActiveEnemies) do
		if enemy.Parent then
			updateAI(aiState)
		else
			-- Clean up destroyed enemies
			ActiveEnemies[enemy] = nil
		end
	end
	
	-- Manage spawning
	manageEnemySpawning()
end

-- Public API
function AISystem.SpawnEnemy(enemyId: string, position: Vector3?): Model?
	local spawnPos = position or SpawnLocations[math.random(1, #SpawnLocations)]
	if not spawnPos then return nil end
	
	local enemy = createEnemyModel(enemyId, spawnPos)
	if enemy then
		local aiState = initializeAIState(enemy, enemyId)
		ActiveEnemies[enemy] = aiState
		EnemyCount[enemyId] = (EnemyCount[enemyId] or 0) + 1
	end
	
	return enemy
end

function AISystem.GetActiveEnemyCount(): number
	local count = 0
	for _ in pairs(ActiveEnemies) do
		count = count + 1
	end
	return count
end

function AISystem.ClearAllEnemies()
	for enemy, aiState in pairs(ActiveEnemies) do
		if enemy.Parent then
			enemy:Destroy()
		end
	end
	ActiveEnemies = {}
	EnemyCount = {}
end

-- Initialize AI System
function AISystem.Initialize()
	initializeSpawnLocations()
	
	-- Start AI update loop
	RunService.Heartbeat:Connect(updateAllAI)
	
	print("AI System initialized with", #SpawnLocations, "spawn locations")
end

-- Initialize on script load
AISystem.Initialize()

return AISystem