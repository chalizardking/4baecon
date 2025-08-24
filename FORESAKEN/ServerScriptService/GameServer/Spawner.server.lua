--[[
	FORESAKEN Spawner Server Script
	Handles loot container spawning, item generation, and loot management
	
	Features:
	- Loot container spawning with tier-based drops
	- Item rarity system with weighted probabilities
	- Dynamic loot refresh throughout match
	- Container interaction validation
	- Loot pickup anti-exploit protection
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Items = require(ReplicatedStorage.Shared.Modules.Items)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)
local MathUtil = require(ReplicatedStorage.Shared.Modules.Util.Math)

-- Spawner System
local SpawnerSystem = {}

-- Loot state management
local LootContainers = {}
local ActiveLoot = {}
local ContainerLocations = {}
local LootRNG = Random.new()

-- Container types and their loot tables
local ContainerTypes = {
	["CommonCrate"] = {
		lootTable = {
			{tier = 1, weight = 70}, -- Common items
			{tier = 2, weight = 25}, -- Uncommon items
			{tier = 3, weight = 5}   -- Rare items
		},
		itemCount = {min = 1, max = 3},
		respawnTime = 120, -- 2 minutes
		model = "CommonCrate"
	},
	
	["WeaponCache"] = {
		lootTable = {
			{tier = 2, weight = 40}, -- Uncommon weapons
			{tier = 3, weight = 35}, -- Rare weapons
			{tier = 4, weight = 20}, -- Epic weapons
			{tier = 5, weight = 5}   -- Legendary weapons
		},
		itemCount = {min = 1, max = 2},
		respawnTime = 300, -- 5 minutes
		model = "WeaponCache",
		tags = {"weapon"}
	},
	
	["MedicalSupplies"] = {
		lootTable = {
			{tier = 1, weight = 50}, -- Common medical
			{tier = 2, weight = 35}, -- Uncommon medical
			{tier = 3, weight = 15}  -- Rare medical
		},
		itemCount = {min = 2, max = 4},
		respawnTime = 90, -- 1.5 minutes
		model = "MedicalBox",
		tags = {"medical"}
	},
	
	["HighValueTarget"] = {
		lootTable = {
			{tier = 3, weight = 30}, -- Rare items
			{tier = 4, weight = 50}, -- Epic items
			{tier = 5, weight = 20}  -- Legendary items
		},
		itemCount = {min = 2, max = 5},
		respawnTime = 600, -- 10 minutes
		model = "HighValueCrate"
	}
}

-- Initialize container spawn locations
local function initializeContainerLocations()
	-- Look for existing container spawn points in workspace
	local mapFolder = workspace:FindFirstChild("Map_Greyfall")
	if mapFolder then
		local lootSpawns = mapFolder:FindFirstChild("LootSpawns")
		if lootSpawns then
			for _, spawn in pairs(lootSpawns:GetChildren()) do
				if spawn:IsA("BasePart") then
					local containerType = spawn:GetAttribute("ContainerType") or "CommonCrate"
					table.insert(ContainerLocations, {
						position = spawn.Position,
						containerType = containerType,
						occupied = false,
						lastSpawn = 0
					})
				end
			end
		end
	end
	
	-- Create default locations if none found
	if #ContainerLocations == 0 then
		local defaultLocations = {
			{pos = Vector3.new(25, 5, 25), type = "CommonCrate"},
			{pos = Vector3.new(-25, 5, 25), type = "CommonCrate"},
			{pos = Vector3.new(25, 5, -25), type = "CommonCrate"},
			{pos = Vector3.new(-25, 5, -25), type = "CommonCrate"},
			{pos = Vector3.new(0, 5, 40), type = "WeaponCache"},
			{pos = Vector3.new(0, 5, -40), type = "WeaponCache"},
			{pos = Vector3.new(40, 5, 0), type = "MedicalSupplies"},
			{pos = Vector3.new(-40, 5, 0), type = "MedicalSupplies"},
			{pos = Vector3.new(0, 5, 0), type = "HighValueTarget"}
		}
		
		for _, loc in ipairs(defaultLocations) do
			table.insert(ContainerLocations, {
				position = loc.pos,
				containerType = loc.type,
				occupied = false,
				lastSpawn = 0
			})
		end
	end
	
	print("Initialized", #ContainerLocations, "container spawn locations")
end

-- Generate random loot based on tier weights
local function generateLootForTier(tier: number, tags: {string}?): string?
	local validItems = {}
	
	-- Get all items of the specified tier
	local tierItems = Items.GetItemsByTier(tier)
	
	for _, item in ipairs(tierItems) do
		local isValid = true
		
		-- Check if item matches required tags
		if tags then
			local hasRequiredTag = false
			for _, requiredTag in ipairs(tags) do
				if Items.HasTag(item.id, requiredTag) then
					hasRequiredTag = true
					break
				end
			end
			if not hasRequiredTag then
				isValid = false
			end
		end
		
		if isValid then
			table.insert(validItems, item.id)
		end
	end
	
	if #validItems > 0 then
		return validItems[LootRNG:NextInteger(1, #validItems)]
	end
	
	return nil
end

-- Generate loot contents for a container
local function generateContainerLoot(containerType: string): {{itemId: string, quantity: number}}
	local containerConfig = ContainerTypes[containerType]
	if not containerConfig then return {} end
	
	local loot = {}
	local itemCount = LootRNG:NextInteger(containerConfig.itemCount.min, containerConfig.itemCount.max)
	
	for i = 1, itemCount do
		-- Select tier based on weighted probabilities
		local totalWeight = 0
		for _, tierData in ipairs(containerConfig.lootTable) do
			totalWeight = totalWeight + tierData.weight
		end
		
		local random = LootRNG:NextNumber(0, totalWeight)
		local currentWeight = 0
		local selectedTier = 1
		
		for _, tierData in ipairs(containerConfig.lootTable) do
			currentWeight = currentWeight + tierData.weight
			if random <= currentWeight then
				selectedTier = tierData.tier
				break
			end
		end
		
		-- Generate item for selected tier
		local itemId = generateLootForTier(selectedTier, containerConfig.tags)
		if itemId then
			-- Determine quantity based on item type
			local quantity = 1
			if Items.IsStackable(itemId) then
				local maxStack = Items.GetMaxStack(itemId)
				quantity = LootRNG:NextInteger(1, math.min(maxStack, 10))
			end
			
			table.insert(loot, {
				itemId = itemId,
				quantity = quantity
			})
		end
	end
	
	return loot
end

-- Create physical loot container model
local function createContainerModel(containerType: string, position: Vector3): Model
	local containerConfig = ContainerTypes[containerType]
	
	local model = Instance.new("Model")
	model.Name = containerConfig.model
	
	-- Main container part
	local container = Instance.new("Part")
	container.Name = "Container"
	container.Size = Vector3.new(4, 3, 4)
	container.Position = position
	container.BrickColor = BrickColor.new("Brown")
	container.Material = Enum.Material.Wood
	container.TopSurface = Enum.SurfaceType.Smooth
	container.BottomSurface = Enum.SurfaceType.Smooth
	container.Parent = model
	
	-- Add color coding based on container type
	if containerType == "WeaponCache" then
		container.BrickColor = BrickColor.new("Dark stone grey")
		container.Material = Enum.Material.Metal
	elseif containerType == "MedicalSupplies" then
		container.BrickColor = BrickColor.new("Institutional white")
		container.Material = Enum.Material.Plastic
	elseif containerType == "HighValueTarget" then
		container.BrickColor = BrickColor.new("Bright yellow")
		container.Material = Enum.Material.Neon
	end
	
	-- Add lid
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(4, 0.5, 4)
	lid.Position = position + Vector3.new(0, 1.75, 0)
	lid.BrickColor = container.BrickColor
	lid.Material = container.Material
	lid.TopSurface = Enum.SurfaceType.Smooth
	lid.BottomSurface = Enum.SurfaceType.Smooth
	lid.Parent = model
	
	-- Add interaction prompt
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = container
	
	-- Add glow effect for high-value containers
	if containerType == "HighValueTarget" then
		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(255, 255, 0)
		pointLight.Brightness = 2
		pointLight.Range = 15
		pointLight.Parent = container
	end
	
	-- Add container info
	local containerInfo = Instance.new("StringValue")
	containerInfo.Name = "ContainerType"
	containerInfo.Value = containerType
	containerInfo.Parent = model
	
	-- Add opened state
	local openedState = Instance.new("BoolValue")
	openedState.Name = "Opened"
	openedState.Value = false
	openedState.Parent = model
	
	-- Add container ID for tracking
	local containerId = Instance.new("StringValue")
	containerId.Name = "ContainerID"
	containerId.Value = HttpService:GenerateGUID(false)
	containerId.Parent = model
	
	model.Parent = workspace
	CollectionService:AddTag(model, "LootContainer")
	
	return model
end

-- Spawn loot container at location
local function spawnContainer(location: {position: Vector3, containerType: string, occupied: boolean, lastSpawn: number})
	if location.occupied then return end
	
	local containerType = location.containerType
	local containerConfig = ContainerTypes[containerType]
	if not containerConfig then return end
	
	-- Check respawn cooldown
	local currentTime = tick()
	if currentTime - location.lastSpawn < containerConfig.respawnTime then return end
	
	-- Create container model
	local containerModel = createContainerModel(containerType, location.position)
	local containerId = containerModel.ContainerID.Value
	
	-- Generate loot contents
	local loot = generateContainerLoot(containerType)
	
	-- Store container data
	LootContainers[containerId] = {
		model = containerModel,
		containerType = containerType,
		contents = loot,
		opened = false,
		location = location,
		spawnTime = currentTime
	}
	
	location.occupied = true
	location.lastSpawn = currentTime
	
	-- Set up click interaction
	local clickDetector = containerModel.Container.ClickDetector
	clickDetector.MouseClick:Connect(function(player)
		handleContainerInteraction(player, containerId)
	end)
	
	print("Spawned", containerType, "at", location.position, "with", #loot, "items")
end

-- Handle container interaction
function handleContainerInteraction(player: Player, containerId: string)
	local containerData = LootContainers[containerId]
	if not containerData or containerData.opened then return end
	
	-- Check distance validation
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local distance = (player.Character.HumanoidRootPart.Position - containerData.model.Container.Position).Magnitude
		if distance > 15 then
			warn("Player too far from container:", player.Name)
			return
		end
	end
	
	-- Mark container as opened
	containerData.opened = true
	containerData.model.Opened.Value = true
	
	-- Open container animation (lid opens)
	local lid = containerData.model:FindFirstChild("Lid")
	if lid then
		local openTween = game:GetService("TweenService"):Create(lid,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = lid.CFrame * CFrame.Angles(math.rad(-90), 0, 0)}
		)
		openTween:Play()
	end
	
	-- Send loot contents to client
	NetEvents.SendToClient(player, "ContainerOpened", {
		containerId = containerId,
		contents = containerData.contents,
		containerType = containerData.containerType
	})
	
	-- Schedule container cleanup
	task.spawn(function()
		task.wait(300) -- Container stays open for 5 minutes
		if LootContainers[containerId] then
			containerData.model:Destroy()
			LootContainers[containerId] = nil
			containerData.location.occupied = false
		end
	end)
	
	print(player.Name, "opened", containerData.containerType, "container")
end

-- Handle loot pickup requests
NetEvents.OnServerEvent("LootPickup", function(player: Player, data)
	local lootId = data.lootId
	
	-- Find the loot item
	local lootItem = ActiveLoot[lootId]
	if not lootItem then return end
	
	-- Validate distance
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local distance = (player.Character.HumanoidRootPart.Position - lootItem.position).Magnitude
		if distance > 10 then
			warn("Player too far from loot:", player.Name)
			return
		end
	end
	
	-- Add item to player inventory (this would integrate with inventory system)
	local SaveSystem = require(script.Parent.Save)
	SaveSystem.AddItemToStash(player, lootItem.itemId, lootItem.quantity)
	
	-- Remove loot from world
	if lootItem.model and lootItem.model.Parent then
		lootItem.model:Destroy()
	end
	ActiveLoot[lootId] = nil
	
	-- Send pickup confirmation
	NetEvents.SendToClient(player, "LootPickedUp", {
		itemId = lootItem.itemId,
		quantity = lootItem.quantity,
		lootId = lootId
	})
	
	-- Fire loot pickup signal for analytics
	Signals.Get("LootPickedUp"):Fire(player, lootItem.itemId, lootItem.quantity)
	
	print(player.Name, "picked up", lootItem.quantity, "x", lootItem.itemId)
end)

-- Handle loot roll requests
NetEvents.OnServerInvoke("RequestLootRoll", function(player: Player, data)
	local containerId = data.containerId
	local containerData = LootContainers[containerId]
	
	if not containerData or containerData.opened then
		return {success = false, error = "Container not found or already opened"}
	end
	
	return {
		success = true,
		items = containerData.contents
	}
end)

-- Spawn loot item in world
function SpawnerSystem.SpawnLootItem(itemId: string, position: Vector3, quantity: number?): string?
	local item = Items.GetItem(itemId)
	if not item then return nil end
	
	local lootId = HttpService:GenerateGUID(false)
	local qty = quantity or 1
	
	-- Create loot model
	local lootModel = Instance.new("Model")
	lootModel.Name = item.name
	
	local lootPart = Instance.new("Part")
	lootPart.Name = "LootItem"
	lootPart.Size = Vector3.new(1, 1, 1)
	lootPart.Position = position + Vector3.new(0, 1, 0)
	lootPart.BrickColor = BrickColor.new("Bright blue")
	lootPart.Material = Enum.Material.Neon
	lootPart.CanCollide = false
	lootPart.Anchored = true
	lootPart.Parent = lootModel
	
	-- Color based on tier
	lootPart.BrickColor = BrickColor.new(Items.GetTierColor(item.tier))
	
	-- Add click detector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 8
	clickDetector.Parent = lootPart
	
	-- Add floating animation
	local floatTween = game:GetService("TweenService"):Create(lootPart,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Position = position + Vector3.new(0, 2, 0)}
	)
	floatTween:Play()
	
	lootModel.Parent = workspace
	
	-- Store loot data
	ActiveLoot[lootId] = {
		itemId = itemId,
		quantity = qty,
		position = position,
		model = lootModel,
		spawnTime = tick()
	}
	
	-- Set up pickup interaction
	clickDetector.MouseClick:Connect(function(player)
		NetEvents.SendToServer("LootPickup", {lootId = lootId})
	end)
	
	-- Auto-cleanup after 10 minutes
	task.spawn(function()
		task.wait(600)
		if ActiveLoot[lootId] then
			if ActiveLoot[lootId].model and ActiveLoot[lootId].model.Parent then
				ActiveLoot[lootId].model:Destroy()
			end
			ActiveLoot[lootId] = nil
		end
	end)
	
	-- Send spawn notification to nearby players
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
			if distance <= 50 then
				NetEvents.SendToClient(player, "LootSpawned", {
					lootId = lootId,
					itemId = itemId,
					quantity = qty,
					position = position
				})
			end
		end
	end
	
	return lootId
end

-- Manage container spawning
local function manageContainerSpawning()
	for _, location in ipairs(ContainerLocations) do
		if not location.occupied then
			spawnContainer(location)
		end
	end
end

-- Public API
function SpawnerSystem.GetActiveContainerCount(): number
	local count = 0
	for _ in pairs(LootContainers) do
		count = count + 1
	end
	return count
end

function SpawnerSystem.GetActiveLootCount(): number
	local count = 0
	for _ in pairs(ActiveLoot) do
		count = count + 1
	end
	return count
end

function SpawnerSystem.ClearAllLoot()
	for _, lootData in pairs(ActiveLoot) do
		if lootData.model and lootData.model.Parent then
			lootData.model:Destroy()
		end
	end
	ActiveLoot = {}
	
	for _, containerData in pairs(LootContainers) do
		if containerData.model and containerData.model.Parent then
			containerData.model:Destroy()
		end
		containerData.location.occupied = false
	end
	LootContainers = {}
end

-- Initialize system
function SpawnerSystem.Initialize()
	initializeContainerLocations()
	
	-- Initial container spawn
	manageContainerSpawning()
	
	-- Periodic container management
	task.spawn(function()
		while true do
			task.wait(30) -- Check every 30 seconds
			manageContainerSpawning()
		end
	end)
	
	print("Spawner System initialized")
end

-- Initialize on script load
SpawnerSystem.Initialize()

return SpawnerSystem