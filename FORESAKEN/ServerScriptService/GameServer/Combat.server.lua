--[[
	FORESAKEN Combat Server Script
	Handles all combat mechanics on the server side
	
	Features:
	- Weapon firing validation
	- Damage calculation and application
	- Hit detection and validation
	- Rate of fire enforcement
	- Anti-exploit protection
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Items = require(ReplicatedStorage.Shared.Modules.Items)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)
local MathUtil = require(ReplicatedStorage.Shared.Modules.Util.Math)

-- Combat state tracking
local PlayerCombatState = {}
local LastFireTimes = {}
local DamageQueue = {}

-- Weapon configurations (from Config module)
local WeaponData = Config.Weapons

-- Initialize networking
NetEvents.Initialize()

-- Player combat state structure
local function createPlayerCombatState(player: Player)
	return {
		health = 100,
		maxHealth = 100,
		armor = 0,
		maxArmor = 100,
		currentWeapon = nil,
		currentAmmo = 0,
		maxAmmo = 0,
		isAlive = true,
		lastDamageTime = 0,
		damageImmunity = 0,
		weaponEquipped = false
	}
end

-- Validate weapon fire rate
local function validateFireRate(player: Player, weaponId: string): boolean
	local weaponConfig = WeaponData[weaponId]
	if not weaponConfig then return false end
	
	local currentTime = tick()
	local playerId = tostring(player.UserId)
	local lastFireTime = LastFireTimes[playerId] or 0
	
	-- Calculate minimum time between shots
	local rpm = weaponConfig.rpm
	local minInterval = 60 / rpm -- Convert RPM to seconds between shots
	
	if currentTime - lastFireTime >= minInterval then
		LastFireTimes[playerId] = currentTime
		return true
	end
	
	return false
end

-- Perform raycast for hit detection
local function performWeaponRaycast(origin: Vector3, direction: Vector3, range: number, shooter: Player): RaycastResult?
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {shooter.Character}
	
	local ray = workspace:Raycast(origin, direction * range, raycastParams)
	return ray
end

-- Calculate damage with armor reduction
local function calculateDamage(baseDamage: number, armor: number): number
	local armorReduction = armor / (armor + 100) -- Diminishing returns formula
	local finalDamage = baseDamage * (1 - armorReduction)
	return math.max(finalDamage, baseDamage * 0.1) -- Minimum 10% damage gets through
end

-- Apply damage to player
local function applyDamage(victim: Player, damage: number, attacker: Player?, weaponId: string?)
	local victimState = PlayerCombatState[victim.UserId]
	if not victimState or not victimState.isAlive then return end
	
	local currentTime = tick()
	
	-- Check damage immunity (prevent spam)
	if currentTime - victimState.damageImmunity < 0.1 then return end
	
	-- Calculate actual damage with armor
	local actualDamage = calculateDamage(damage, victimState.armor)
	
	-- Apply damage to armor first
	if victimState.armor > 0 then
		local armorDamage = math.min(actualDamage * 0.5, victimState.armor)
		victimState.armor = math.max(0, victimState.armor - armorDamage)
		actualDamage = actualDamage - armorDamage
	end
	
	-- Apply remaining damage to health
	victimState.health = math.max(0, victimState.health - actualDamage)
	victimState.lastDamageTime = currentTime
	victimState.damageImmunity = currentTime
	
	-- Send damage update to client
	NetEvents.SendToClient(victim, "PlayerDamaged", {
		health = victimState.health,
		maxHealth = victimState.maxHealth,
		armor = victimState.armor,
		maxArmor = victimState.maxArmor,
		damage = actualDamage,
		attacker = attacker and attacker.Name,
		weapon = weaponId
	})
	
	-- Update HUD
	NetEvents.SendToClient(victim, "HudUpdate", {
		health = victimState.health,
		maxHealth = victimState.maxHealth,
		armor = victimState.armor,
		maxArmor = victimState.maxArmor
	})
	
	-- Check for death
	if victimState.health <= 0 then
		handlePlayerDeath(victim, attacker, weaponId)
	end
	
	-- Fire combat signal for analytics
	Signals.Get("Combat"):Fire(attacker, victim, weaponId, actualDamage)
	
	print(string.format("%s took %.1f damage from %s (Health: %.1f/%.1f)", 
		victim.Name, actualDamage, attacker and attacker.Name or "Unknown", 
		victimState.health, victimState.maxHealth))
end

-- Handle player death
function handlePlayerDeath(victim: Player, killer: Player?, weaponId: string?)
	local victimState = PlayerCombatState[victim.UserId]
	if not victimState then return end
	
	victimState.isAlive = false
	
	-- Ragdoll the character
	local character = victim.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
			humanoid.Health = 0
		end
		
		-- Create ragdoll effect
		for _, joint in pairs(character:GetDescendants()) do
			if joint:IsA("Motor6D") then
				local attachment0 = Instance.new("Attachment")
				local attachment1 = Instance.new("Attachment")
				attachment0.Parent = joint.Part0
				attachment1.Parent = joint.Part1
				attachment0.CFrame = joint.C0
				attachment1.CFrame = joint.C1
				
				local ballSocket = Instance.new("BallSocketConstraint")
				ballSocket.Attachment0 = attachment0
				ballSocket.Attachment1 = attachment1
				ballSocket.Parent = joint.Part0
				
				joint:Destroy()
			end
		end
	end
	
	-- Update stats
	if killer and killer ~= victim then
		-- Update killer stats
		local SaveSystem = require(script.Parent.Save)
		SaveSystem.UpdatePlayerProfile(killer, function(profile)
			profile.stats.pvpkills = profile.stats.pvpkills + 1
			return profile
		end)
		
		-- Add kill XP
		SaveSystem.AddXP(killer, Config.Economy.KillXP)
	end
	
	-- Update victim stats
	local SaveSystem = require(script.Parent.Save)
	SaveSystem.UpdatePlayerProfile(victim, function(profile)
		profile.stats.deaths = profile.stats.deaths + 1
		return profile
	end)
	
	-- Send death notifications
	NetEvents.SendToAllClients("PlayerDamaged", {
		type = "death",
		victim = victim.Name,
		killer = killer and killer.Name,
		weapon = weaponId
	})
	
	-- Fire death signal
	Signals.Get("PlayerKilled"):Fire(victim, killer, weaponId)
	
	print(string.format("%s was killed by %s with %s", 
		victim.Name, killer and killer.Name or "Unknown", weaponId or "Unknown"))
	
	-- Respawn after delay (for spectating)
	task.wait(Config.Match.SpectateTimeSeconds)
	victim:LoadCharacter()
end

-- Handle weapon fire events
NetEvents.OnServerEvent("WeaponFire", function(player: Player, data)
	local playerState = PlayerCombatState[player.UserId]
	if not playerState or not playerState.isAlive then return end
	
	local weaponId = data.weaponId
	local direction = data.direction
	local origin = data.origin
	
	-- Validate weapon
	local weaponConfig = WeaponData[weaponId]
	if not weaponConfig then
		warn("Invalid weapon:", weaponId)
		return
	end
	
	-- Validate fire rate
	if not validateFireRate(player, weaponId) then
		warn("Fire rate exceeded for player:", player.Name)
		return
	end
	
	-- Check ammo
	if playerState.currentAmmo <= 0 then
		return -- No ammo
	end
	
	-- Consume ammo
	playerState.currentAmmo = math.max(0, playerState.currentAmmo - 1)
	
	-- Perform hit detection
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	-- Use character position as origin if not provided
	local fireOrigin = origin or humanoidRootPart.Position + Vector3.new(0, 1.5, 0)
	local fireDirection = direction.Unit
	
	-- Perform raycast
	local hitResult = performWeaponRaycast(fireOrigin, fireDirection, weaponConfig.range, player)
	
	if hitResult then
		local hitPart = hitResult.Instance
		local hitCharacter = hitPart.Parent
		
		-- Check if we hit a player
		local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
		if hitPlayer and hitPlayer ~= player then
			-- Calculate damage based on hit location
			local baseDamage = weaponConfig.dmg
			local hitLocation = hitPart.Name
			
			-- Headshot multiplier
			if hitLocation == "Head" then
				baseDamage = baseDamage * 1.5
			end
			
			-- Apply damage
			applyDamage(hitPlayer, baseDamage, player, weaponId)
		end
		
		-- Create hit effect at impact point
		local hitEffect = Instance.new("Explosion")
		hitEffect.Size = 1
		hitEffect.BlastRadius = 0
		hitEffect.BlastPressure = 0
		hitEffect.Position = hitResult.Position
		hitEffect.Parent = workspace
		
		Debris:AddItem(hitEffect, 2)
	end
	
	-- Send weapon fire event to all clients for visual effects
	NetEvents.SendToAllClients("WeaponFired", {
		player = player.Name,
		weapon = weaponId,
		origin = fireOrigin,
		direction = fireDirection,
		hit = hitResult and hitResult.Position
	})
	
	-- Update ammo display
	NetEvents.SendToClient(player, "HudUpdate", {
		currentAmmo = playerState.currentAmmo,
		maxAmmo = playerState.maxAmmo
	})
end)

-- Handle damage events (for melee, explosives, etc.)
NetEvents.OnServerEvent("Damage", function(player: Player, data)
	local targetId = data.targetId
	local weaponId = data.weaponId
	local damage = data.damage
	
	-- Find target player
	local targetPlayer = nil
	for _, p in pairs(Players:GetPlayers()) do
		if tostring(p.UserId) == targetId then
			targetPlayer = p
			break
		end
	end
	
	if not targetPlayer then return end
	
	-- Validate damage amount
	local maxDamage = 100 -- Maximum damage per hit
	if damage > maxDamage then
		warn("Excessive damage amount from player:", player.Name)
		return
	end
	
	-- Apply damage
	applyDamage(targetPlayer, damage, player, weaponId)
end)

-- Player management
local function onPlayerAdded(player: Player)
	PlayerCombatState[player.UserId] = createPlayerCombatState(player)
	print("Combat state created for player:", player.Name)
end

local function onPlayerRemoving(player: Player)
	PlayerCombatState[player.UserId] = nil
	LastFireTimes[tostring(player.UserId)] = nil
	print("Combat state cleaned up for player:", player.Name)
end

-- Character spawning
local function onCharacterAdded(player: Player, character: Model)
	local playerState = PlayerCombatState[player.UserId]
	if playerState then
		-- Reset health and state
		playerState.health = playerState.maxHealth
		playerState.isAlive = true
		playerState.currentWeapon = nil
		playerState.currentAmmo = 0
		playerState.maxAmmo = 0
		
		-- Send initial HUD update
		NetEvents.SendToClient(player, "HudUpdate", {
			health = playerState.health,
			maxHealth = playerState.maxHealth,
			armor = playerState.armor,
			maxArmor = playerState.maxArmor,
			weapon = playerState.currentWeapon,
			currentAmmo = playerState.currentAmmo,
			maxAmmo = playerState.maxAmmo
		})
	end
end

-- Equipment functions
local function equipWeapon(player: Player, weaponId: string)
	local playerState = PlayerCombatState[player.UserId]
	if not playerState then return end
	
	local weaponConfig = WeaponData[weaponId]
	if not weaponConfig then return end
	
	playerState.currentWeapon = weaponId
	playerState.maxAmmo = 30 -- Default mag size, should come from weapon config
	playerState.currentAmmo = playerState.maxAmmo
	playerState.weaponEquipped = true
	
	-- Send weapon update to client
	NetEvents.SendToClient(player, "HudUpdate", {
		weapon = weaponId,
		currentAmmo = playerState.currentAmmo,
		maxAmmo = playerState.maxAmmo
	})
	
	print(string.format("%s equipped %s", player.Name, weaponId))
end

-- Public API for other systems
local CombatSystem = {}

function CombatSystem.GetPlayerHealth(player: Player): number?
	local state = PlayerCombatState[player.UserId]
	return state and state.health
end

function CombatSystem.SetPlayerHealth(player: Player, health: number)
	local state = PlayerCombatState[player.UserId]
	if state then
		state.health = math.max(0, math.min(health, state.maxHealth))
		
		NetEvents.SendToClient(player, "HudUpdate", {
			health = state.health,
			maxHealth = state.maxHealth
		})
	end
end

function CombatSystem.AddArmor(player: Player, armor: number)
	local state = PlayerCombatState[player.UserId]
	if state then
		state.armor = math.min(state.armor + armor, state.maxArmor)
		
		NetEvents.SendToClient(player, "HudUpdate", {
			armor = state.armor,
			maxArmor = state.maxArmor
		})
	end
end

function CombatSystem.EquipWeapon(player: Player, weaponId: string)
	equipWeapon(player, weaponId)
end

function CombatSystem.IsPlayerAlive(player: Player): boolean
	local state = PlayerCombatState[player.UserId]
	return state and state.isAlive or false
end

-- Initialize system
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
	
	-- Connect character events
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

-- Connect new players' character events
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)

print("Combat System initialized")

return CombatSystem