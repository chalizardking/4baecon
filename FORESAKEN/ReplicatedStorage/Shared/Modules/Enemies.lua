--[[
	FORESAKEN Enemies Module
	Defines enemy types, behaviors, and AI states
	
	Usage:
	local Enemies = require(ReplicatedStorage.Shared.Modules.Enemies)
	local scoutData = Enemies.GetEnemyData("BanditScout")
]]

local Enemies = {}

-- Enemy States Enum
local EnemyStates = {
	IDLE = "Idle",
	PATROL = "Patrol", 
	INVESTIGATE = "Investigate",
	CHASE = "Chase",
	ATTACK = "Attack",
	FLEE = "Flee",
	DEAD = "Dead",
	STAGGER = "Stagger",
	ROAM = "Roam",
	CHARGE = "Charge",
	HOVER = "Hover",
	PING = "Ping",
	BURST_FIRE = "BurstFire",
	CALL_REINFORCEMENTS = "CallReinforcements"
}

-- Enemy Type definitions
export type EnemyData = {
	id: string,
	name: string,
	health: number,
	damage: number,
	speed: number,
	detectRange: number,
	attackRange: number,
	lootTable: {string},
	aiStates: {string},
	special: {[string]: any}?
}

-- Enemy Database
local EnemyDatabase = {
	["BanditScout"] = {
		id = "BanditScout",
		name = "Bandit Scout",
		health = 50,
		damage = 12,
		speed = 16,
		detectRange = 40,
		attackRange = 35,
		lootTable = {"PistolAmmo", "Bandage", "Scrap"},
		aiStates = {
			EnemyStates.IDLE,
			EnemyStates.PATROL,
			EnemyStates.INVESTIGATE, 
			EnemyStates.ATTACK,
			EnemyStates.FLEE
		},
		special = {
			fleeHealthPercent = 0.3,
			alertRadius = 20,
			patrolDistance = 15
		}
	},
	
	["BanditBruiser"] = {
		id = "BanditBruiser", 
		name = "Bandit Bruiser",
		health = 120,
		damage = 25,
		speed = 12,
		detectRange = 25,
		attackRange = 8,
		lootTable = {"SMGAmmo", "Medkit", "Scrap", "Cloth"},
		aiStates = {
			EnemyStates.IDLE,
			EnemyStates.ROAM,
			EnemyStates.CHARGE,
			EnemyStates.ATTACK,
			EnemyStates.STAGGER
		},
		special = {
			chargeSpeed = 20,
			staggerDuration = 2,
			staggerCooldown = 8
		}
	},
	
	["SentryDrone"] = {
		id = "SentryDrone",
		name = "Sentry Drone", 
		health = 80,
		damage = 15,
		speed = 8,
		detectRange = 50,
		attackRange = 45,
		lootTable = {"Electronics", "RifleAmmo", "Scrap"},
		aiStates = {
			EnemyStates.HOVER,
			EnemyStates.PING,
			EnemyStates.BURST_FIRE,
			EnemyStates.CALL_REINFORCEMENTS
		},
		special = {
			reinforcementCooldown = 30,
			burstCount = 3,
			burstDelay = 0.3,
			hoverHeight = 15
		}
	}
}

-- Behavior Tree Definitions
local BehaviorTrees = {
	["BanditScout"] = {
		root = "selector",
		nodes = {
			{
				type = "sequence",
				name = "combat_sequence", 
				children = {
					{type = "condition", check = "has_target"},
					{type = "condition", check = "in_attack_range"},
					{type = "action", action = "attack_target"}
				}
			},
			{
				type = "sequence",
				name = "flee_sequence",
				children = {
					{type = "condition", check = "low_health"},
					{type = "action", action = "flee_from_target"}
				}
			},
			{
				type = "sequence", 
				name = "chase_sequence",
				children = {
					{type = "condition", check = "has_target"},
					{type = "action", action = "move_to_target"}
				}
			},
			{
				type = "action",
				action = "patrol"
			}
		}
	},
	
	["BanditBruiser"] = {
		root = "selector",
		nodes = {
			{
				type = "sequence",
				name = "stagger_sequence",
				children = {
					{type = "condition", check = "is_staggered"},
					{type = "action", action = "stagger_recovery"}
				}
			},
			{
				type = "sequence",
				name = "charge_sequence", 
				children = {
					{type = "condition", check = "has_target"},
					{type = "condition", check = "charge_ready"},
					{type = "action", action = "charge_target"}
				}
			},
			{
				type = "sequence",
				name = "attack_sequence",
				children = {
					{type = "condition", check = "has_target"},
					{type = "condition", check = "in_attack_range"},
					{type = "action", action = "melee_attack"}
				}
			},
			{
				type = "action",
				action = "roam"
			}
		}
	},
	
	["SentryDrone"] = {
		root = "selector", 
		nodes = {
			{
				type = "sequence",
				name = "reinforcement_sequence",
				children = {
					{type = "condition", check = "under_heavy_fire"},
					{type = "condition", check = "reinforcement_ready"},
					{type = "action", action = "call_reinforcements"}
				}
			},
			{
				type = "sequence",
				name = "burst_sequence",
				children = {
					{type = "condition", check = "has_target"},
					{type = "condition", check = "in_attack_range"},
					{type = "action", action = "burst_fire"}
				}
			},
			{
				type = "sequence",
				name = "ping_sequence", 
				children = {
					{type = "condition", check = "has_target"},
					{type = "action", action = "ping_target"}
				}
			},
			{
				type = "action",
				action = "hover_patrol"
			}
		}
	}
}

-- Utility Functions
function Enemies.GetEnemyData(enemyId: string): EnemyData?
	return EnemyDatabase[enemyId]
end

function Enemies.GetAllEnemies(): {[string]: EnemyData}
	return EnemyDatabase
end

function Enemies.GetBehaviorTree(enemyId: string)
	return BehaviorTrees[enemyId]
end

function Enemies.GetEnemyStates()
	return EnemyStates
end

function Enemies.ValidateEnemyId(enemyId: string): boolean
	return EnemyDatabase[enemyId] ~= nil
end

function Enemies.GetLootTable(enemyId: string): {string}?
	local enemy = Enemies.GetEnemyData(enemyId)
	return enemy and enemy.lootTable
end

function Enemies.GetSpecialProperty(enemyId: string, property: string): any
	local enemy = Enemies.GetEnemyData(enemyId)
	if not enemy or not enemy.special then return nil end
	return enemy.special[property]
end

-- AI Condition Checks
function Enemies.CheckCondition(enemyId: string, condition: string, context: any): boolean
	local enemy = Enemies.GetEnemyData(enemyId)
	if not enemy then return false end
	
	-- Common condition implementations
	if condition == "has_target" then
		return context.target ~= nil
	elseif condition == "in_attack_range" then
		if not context.target then return false end
		local distance = (context.position - context.target.position).Magnitude
		return distance <= enemy.attackRange
	elseif condition == "low_health" then
		local fleePercent = Enemies.GetSpecialProperty(enemyId, "fleeHealthPercent") or 0.2
		return context.currentHealth / enemy.health <= fleePercent
	elseif condition == "is_staggered" then
		return context.state == EnemyStates.STAGGER
	elseif condition == "charge_ready" then
		return context.chargeCooldown <= 0
	elseif condition == "under_heavy_fire" then
		return context.damageReceivedRecently > 30
	elseif condition == "reinforcement_ready" then
		return context.reinforcementCooldown <= 0
	end
	
	return false
end

-- Spawn Configuration
function Enemies.GetSpawnWeight(enemyId: string): number
	local weights = {
		["BanditScout"] = 50,
		["BanditBruiser"] = 30, 
		["SentryDrone"] = 20
	}
	return weights[enemyId] or 10
end

function Enemies.GetMaxSpawnCount(enemyId: string): number
	local maxCounts = {
		["BanditScout"] = 6,
		["BanditBruiser"] = 3,
		["SentryDrone"] = 2
	}
	return maxCounts[enemyId] or 1
end

return Enemies