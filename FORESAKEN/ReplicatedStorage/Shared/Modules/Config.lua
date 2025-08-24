--[[
	FORESAKEN Config Module
	Contains all game configuration parameters and constants
	
	Usage:
	local Config = require(ReplicatedStorage.Shared.Modules.Config)
	print(Config.Match.MaxPlayers) -- 12
]]

local Config = {}

-- Match Configuration
Config.Match = {
	MaxPlayers = 12,
	SessionMinutes = 15,
	ExtractOpenAt = { 
		t = 5, -- Minutes into match when extraction opens
		zones = {"ZoneA", "ZoneB"} 
	},
	SpectateTimeSeconds = 30,
	CombatLogTimeSeconds = 30,
	ExtractChannelTimeSeconds = 8
}

-- Inventory System
Config.Inventory = { 
	BaseCap = 30, 
	WeightPerTier = {1, 2, 3, 4, 5} -- Common, Uncommon, Rare, Epic, Legendary
}

-- Loot Drop Tables
Config.DropTable = {
	Common = 0.55, 
	Uncommon = 0.25, 
	Rare = 0.12, 
	Epic = 0.06, 
	Legendary = 0.02
}

-- Weapon Statistics
Config.Weapons = {
	Pistol = {
		dmg = 18, 
		rpm = 360, 
		spread = 2.0, 
		range = 60,
		fireMode = "Semi",
		reloadTime = 1.5
	},
	SMG = {
		dmg = 14, 
		rpm = 720, 
		spread = 3.5, 
		range = 40,
		fireMode = "Auto",
		reloadTime = 2.0
	},
	BRifle = {
		dmg = 26, 
		rpm = 450, 
		spread = 1.4, 
		range = 80,
		fireMode = "Semi",
		reloadTime = 2.5
	}
}

-- Enemy Configuration
Config.Enemies = {
	BanditScout = {
		health = 50,
		damage = 12,
		speed = 16,
		detectRange = 40,
		attackRange = 35,
		fleeHealthPercent = 0.3
	},
	BanditBruiser = {
		health = 120,
		damage = 25,
		speed = 12,
		detectRange = 25,
		attackRange = 8,
		chargeSpeed = 20
	},
	SentryDrone = {
		health = 80,
		damage = 15,
		speed = 8,
		detectRange = 50,
		attackRange = 45,
		reinforcementCooldown = 30
	}
}

-- Economy and Progression
Config.Economy = {
	StartingCredits = 500,
	LevelXPRequirements = {
		[1] = 0,
		[2] = 100,
		[3] = 250,
		[4] = 450,
		[5] = 700,
		[6] = 1000,
		[7] = 1350,
		[8] = 1750,
		[9] = 2200,
		[10] = 2700
	},
	ExtractXP = 50,
	KillXP = 25,
	SurvivalXPPerMinute = 10
}

-- Hideout Configuration
Config.Hideout = {
	MaxTier = 3,
	UpgradeCosts = {
		[2] = 2000, -- Tier 1 to 2
		[3] = 5000  -- Tier 2 to 3
	},
	CraftingBenches = {
		[1] = {"Basic"},
		[2] = {"Basic", "Advanced"},
		[3] = {"Basic", "Advanced", "Expert"}
	}
}

-- Performance Targets
Config.Performance = {
	TargetFPS = {
		PC = 60,
		Console = 60,
		Mobile = 30
	},
	MaxPartsLive = 3000,
	MaxStreamedAssetsMB = 200,
	ServerStepTarget = 16 -- milliseconds
}

-- Anti-Exploit Settings
Config.AntiExploit = {
	MaxMovementSpeed = 25,
	MaxJumpHeight = 50,
	DamageValidationWindow = 0.5,
	FireRateTolerancePercent = 0.1,
	MaxDistanceFromSpawn = 2000
}

-- UI Configuration
Config.UI = {
	Colors = {
		Common = Color3.fromRGB(150, 150, 150),    -- Gray
		Uncommon = Color3.fromRGB(30, 255, 0),     -- Green
		Rare = Color3.fromRGB(0, 112, 255),        -- Blue
		Epic = Color3.fromRGB(163, 53, 238),       -- Purple
		Legendary = Color3.fromRGB(255, 128, 0)    -- Gold
	},
	TierNames = {
		[1] = "Common",
		[2] = "Uncommon", 
		[3] = "Rare",
		[4] = "Epic",
		[5] = "Legendary"
	}
}

-- Analytics Events
Config.Analytics = {
	Events = {
		MatchStart = "match_start",
		MatchEnd = "match_end", 
		LootPick = "loot_pick",
		Combat = "combat",
		Extract = "extract",
		Spend = "spend"
	}
}

-- Game Rules
Config.GameRules = {
	TeamingAllowed = false,
	RespawnEnabled = false,
	SafeLogoutOnlyInExtract = true,
	RequiredExtractTime = 8, -- seconds
	MaxSessionTime = 18 * 60 -- 18 minutes in seconds
}

return Config