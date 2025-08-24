--[[
	FORESAKEN Save Server Script
	Handles player data loading, saving, and management using DataStoreService
	
	Features:
	- Profile-based data management
	- Automatic periodic saves
	- Retry logic with exponential backoff
	- Data validation and corruption protection
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Require shared modules
local Config = require(game.ReplicatedStorage.Shared.Modules.Config)
local Items = require(game.ReplicatedStorage.Shared.Modules.Items)
local Signals = require(game.ReplicatedStorage.Shared.Modules.Signals)

-- Data Store setup
local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local GlobalDataStore = DataStoreService:GetDataStore("GlobalData_v1")

-- Profile management
local PlayerProfiles = {}
local SaveQueue = {}
local LastSaveTimes = {}

-- Data Store Configuration
local SAVE_INTERVAL = 60 -- Save every 60 seconds
local MAX_RETRIES = 3
local RETRY_DELAY = 2 -- Base delay for exponential backoff

-- Type definitions
export type Profile = {
	uid: string,
	xp: number,
	level: number,
	currency: number,
	hideout: {
		tier: number,
		benches: {
			craft: number
		}
	},
	stash: {[string]: number},
	stats: {
		extracts: number,
		deaths: number,
		pvpkills: number,
		pveKills: number,
		timePlayedMinutes: number,
		lastLogin: number
	},
	settings: {
		masterVolume: number,
		sfxVolume: number,
		musicVolume: number,
		graphics: string
	},
	version: number
}

-- Default profile template
local function createDefaultProfile(userId: number): Profile
	return {
		uid = tostring(userId),
		xp = 0,
		level = 1,
		currency = Config.Economy.StartingCredits,
		hideout = {
			tier = 1,
			benches = {
				craft = 1
			}
		},
		stash = {
			-- Starting items
			["Scrap"] = 10,
			["Cloth"] = 5,
			["PistolAmmo"] = 20
		},
		stats = {
			extracts = 0,
			deaths = 0,
			pvpkills = 0,
			pveKills = 0,
			timePlayedMinutes = 0,
			lastLogin = os.time()
		},
		settings = {
			masterVolume = 0.8,
			sfxVolume = 0.7,
			musicVolume = 0.5,
			graphics = "Medium"
		},
		version = 1
	}
end

-- Data validation
local function validateProfile(profile: any): boolean
	if type(profile) ~= "table" then return false end
	
	-- Check required fields
	local requiredFields = {
		"uid", "xp", "level", "currency", "hideout", "stash", "stats", "settings"
	}
	
	for _, field in ipairs(requiredFields) do
		if profile[field] == nil then
			warn("Missing required field:", field)
			return false
		end
	end
	
	-- Validate data types
	if type(profile.uid) ~= "string" then return false end
	if type(profile.xp) ~= "number" then return false end
	if type(profile.level) ~= "number" then return false end
	if type(profile.currency) ~= "number" then return false end
	if type(profile.hideout) ~= "table" then return false end
	if type(profile.stash) ~= "table" then return false end
	if type(profile.stats) ~= "table" then return false end
	if type(profile.settings) ~= "table" then return false end
	
	-- Validate ranges
	if profile.level < 1 or profile.level > 100 then return false end
	if profile.currency < 0 then return false end
	if profile.hideout.tier < 1 or profile.hideout.tier > Config.Hideout.MaxTier then return false end
	
	return true
end

-- Migrate old profile versions
local function migrateProfile(profile: any): Profile
	if not profile.version then
		profile.version = 1
		
		-- Add any missing fields from newer versions
		if not profile.settings then
			profile.settings = {
				masterVolume = 0.8,
				sfxVolume = 0.7,
				musicVolume = 0.5,
				graphics = "Medium"
			}
		end
		
		if not profile.stats.pveKills then
			profile.stats.pveKills = 0
		end
		
		if not profile.stats.timePlayedMinutes then
			profile.stats.timePlayedMinutes = 0
		end
		
		if not profile.stats.lastLogin then
			profile.stats.lastLogin = os.time()
		end
	end
	
	return profile
end

-- Save profile with retry logic
local function saveProfileWithRetry(userId: number, profile: Profile, retryCount: number?)
	local retries = retryCount or 0
	local key = "Player_" .. tostring(userId)
	
	local success, errorMsg = pcall(function()
		PlayerDataStore:SetAsync(key, profile)
	end)
	
	if success then
		LastSaveTimes[userId] = tick()
		SaveQueue[userId] = nil
		print("Saved profile for user:", userId)
		
		-- Fire save completion signal
		Signals.Get("DataSaved"):Fire(userId, profile)
	else
		warn("Failed to save profile for user:", userId, "Error:", errorMsg)
		
		if retries < MAX_RETRIES then
			local delay = RETRY_DELAY * (2 ^ retries) -- Exponential backoff
			print("Retrying save in", delay, "seconds...")
			
			task.wait(delay)
			saveProfileWithRetry(userId, profile, retries + 1)
		else
			warn("Max retries exceeded for user:", userId, "Data may be lost!")
			Signals.Get("ErrorOccurred"):Fire("SaveFailed", {userId = userId, retries = retries})
		end
	end
end

-- Load profile with retry logic
local function loadProfileWithRetry(userId: number, retryCount: number?): Profile?
	local retries = retryCount or 0
	local key = "Player_" .. tostring(userId)
	
	local success, result = pcall(function()
		return PlayerDataStore:GetAsync(key)
	end)
	
	if success then
		if result then
			-- Validate and migrate loaded data
			if validateProfile(result) then
				local migratedProfile = migrateProfile(result)
				print("Loaded profile for user:", userId)
				return migratedProfile
			else
				warn("Invalid profile data for user:", userId, "Creating new profile")
				return createDefaultProfile(userId)
			end
		else
			-- New player, create default profile
			print("New player detected:", userId)
			return createDefaultProfile(userId)
		end
	else
		warn("Failed to load profile for user:", userId, "Error:", result)
		
		if retries < MAX_RETRIES then
			local delay = RETRY_DELAY * (2 ^ retries)
			print("Retrying load in", delay, "seconds...")
			
			task.wait(delay)
			return loadProfileWithRetry(userId, retries + 1)
		else
			warn("Max retries exceeded for user:", userId, "Using default profile")
			return createDefaultProfile(userId)
		end
	end
end

-- Public API
local SaveSystem = {}

function SaveSystem.LoadPlayerData(player: Player): Profile?
	local userId = player.UserId
	
	if PlayerProfiles[userId] then
		return PlayerProfiles[userId]
	end
	
	local profile = loadProfileWithRetry(userId)
	if profile then
		PlayerProfiles[userId] = profile
		LastSaveTimes[userId] = tick()
		
		-- Update last login time
		profile.stats.lastLogin = os.time()
		
		-- Fire data loaded signal
		Signals.Get("DataLoaded"):Fire(userId, profile)
		
		return profile
	end
	
	return nil
end

function SaveSystem.SavePlayerData(player: Player, immediate: boolean?)
	local userId = player.UserId
	local profile = PlayerProfiles[userId]
	
	if not profile then
		warn("No profile found for user:", userId)
		return
	end
	
	if immediate then
		saveProfileWithRetry(userId, profile)
	else
		-- Queue for batch save
		SaveQueue[userId] = profile
	end
end

function SaveSystem.GetPlayerProfile(player: Player): Profile?
	return PlayerProfiles[player.UserId]
end

function SaveSystem.UpdatePlayerProfile(player: Player, updateFunc: (Profile) -> Profile)
	local userId = player.UserId
	local profile = PlayerProfiles[userId]
	
	if profile then
		local updatedProfile = updateFunc(profile)
		if validateProfile(updatedProfile) then
			PlayerProfiles[userId] = updatedProfile
			SaveQueue[userId] = updatedProfile
		else
			warn("Invalid profile update for user:", userId)
		end
	end
end

-- Player management
local function onPlayerAdded(player: Player)
	print("Player joined:", player.Name)
	SaveSystem.LoadPlayerData(player)
end

local function onPlayerRemoving(player: Player)
	print("Player leaving:", player.Name)
	SaveSystem.SavePlayerData(player, true) -- Immediate save on leave
	
	-- Clean up
	local userId = player.UserId
	PlayerProfiles[userId] = nil
	SaveQueue[userId] = nil
	LastSaveTimes[userId] = nil
end

-- Periodic save system
local function periodicSave()
	local currentTime = tick()
	
	for userId, profile in pairs(SaveQueue) do
		local lastSave = LastSaveTimes[userId] or 0
		
		if currentTime - lastSave >= SAVE_INTERVAL then
			saveProfileWithRetry(userId, profile)
		end
	end
end

-- Global stats management
function SaveSystem.UpdateGlobalStats(statName: string, value: number)
	local success, errorMsg = pcall(function()
		local currentValue = GlobalDataStore:GetAsync(statName) or 0
		GlobalDataStore:SetAsync(statName, currentValue + value)
	end)
	
	if not success then
		warn("Failed to update global stat:", statName, "Error:", errorMsg)
	end
end

function SaveSystem.GetGlobalStats(statName: string): number?
	local success, result = pcall(function()
		return GlobalDataStore:GetAsync(statName)
	end)
	
	if success then
		return result
	else
		warn("Failed to get global stat:", statName, "Error:", result)
		return nil
	end
end

-- Utility functions for profile manipulation
function SaveSystem.AddXP(player: Player, amount: number)
	SaveSystem.UpdatePlayerProfile(player, function(profile)
		profile.xp = profile.xp + amount
		
		-- Check for level up
		local currentLevel = profile.level
		local newLevel = 1
		
		for level, requiredXP in pairs(Config.Economy.LevelXPRequirements) do
			if profile.xp >= requiredXP and level > newLevel then
				newLevel = level
			end
		end
		
		if newLevel > currentLevel then
			profile.level = newLevel
			Signals.Get("LevelUp"):Fire(player, newLevel)
		end
		
		Signals.Get("XPGained"):Fire(player, amount)
		return profile
	end)
end

function SaveSystem.AddCurrency(player: Player, amount: number)
	SaveSystem.UpdatePlayerProfile(player, function(profile)
		profile.currency = math.max(0, profile.currency + amount)
		Signals.Get("CurrencyChanged"):Fire(player, profile.currency)
		return profile
	end)
end

function SaveSystem.AddItemToStash(player: Player, itemId: string, quantity: number)
	SaveSystem.UpdatePlayerProfile(player, function(profile)
		if Items.ValidateItem(itemId) then
			profile.stash[itemId] = (profile.stash[itemId] or 0) + quantity
		end
		return profile
	end)
end

function SaveSystem.RemoveItemFromStash(player: Player, itemId: string, quantity: number): boolean
	local success = false
	
	SaveSystem.UpdatePlayerProfile(player, function(profile)
		local currentAmount = profile.stash[itemId] or 0
		if currentAmount >= quantity then
			profile.stash[itemId] = currentAmount - quantity
			if profile.stash[itemId] <= 0 then
				profile.stash[itemId] = nil
			end
			success = true
		end
		return profile
	end)
	
	return success
end

-- Initialize system
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (for testing)
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Start periodic save loop
task.spawn(function()
	while true do
		task.wait(30) -- Check every 30 seconds
		periodicSave()
	end
end)

-- Graceful shutdown
game:BindToClose(function()
	print("Server shutting down, saving all player data...")
	
	for userId, profile in pairs(PlayerProfiles) do
		saveProfileWithRetry(userId, profile)
	end
	
	-- Give time for saves to complete
	task.wait(5)
end)

return SaveSystem