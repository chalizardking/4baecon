--[[
	FORESAKEN Items Module
	Defines all items, their properties, and utility functions
	
	Usage:
	local Items = require(ReplicatedStorage.Shared.Modules.Items)
	local pistol = Items.GetItem("Pistol")
]]

local Items = {}

-- Type definitions
export type Item = {
	id: string,
	name: string,
	tier: number,
	weight: number,
	stack: number?,
	tags: {string},
	description: string?,
	value: number?
}

-- Item Database
local ItemDatabase = {
	-- Weapons
	["Pistol"] = {
		id = "Pistol",
		name = "Combat Pistol",
		tier = 2,
		weight = 3,
		stack = 1,
		tags = {"weapon", "firearm", "sidearm"},
		description = "Reliable sidearm with moderate damage",
		value = 150
	},
	["SMG"] = {
		id = "SMG",
		name = "Submachine Gun",
		tier = 3,
		weight = 5,
		stack = 1,
		tags = {"weapon", "firearm", "automatic"},
		description = "High rate of fire, close range combat",
		value = 400
	},
	["BRifle"] = {
		id = "BRifle",
		name = "Battle Rifle",
		tier = 4,
		weight = 7,
		stack = 1,
		tags = {"weapon", "firearm", "rifle"},
		description = "High damage, long range precision weapon",
		value = 800
	},
	
	-- Ammunition
	["PistolAmmo"] = {
		id = "PistolAmmo",
		name = "Pistol Ammunition",
		tier = 1,
		weight = 1,
		stack = 50,
		tags = {"ammo", "pistol"},
		description = "Standard pistol rounds",
		value = 2
	},
	["SMGAmmo"] = {
		id = "SMGAmmo", 
		name = "SMG Ammunition",
		tier = 2,
		weight = 1,
		stack = 50,
		tags = {"ammo", "smg"},
		description = "High velocity SMG rounds",
		value = 3
	},
	["RifleAmmo"] = {
		id = "RifleAmmo",
		name = "Rifle Ammunition", 
		tier = 3,
		weight = 2,
		stack = 30,
		tags = {"ammo", "rifle"},
		description = "High caliber rifle rounds",
		value = 5
	},
	
	-- Medical Items
	["Medkit"] = {
		id = "Medkit",
		name = "Medical Kit",
		tier = 2,
		weight = 2,
		stack = 3,
		tags = {"medical", "healing"},
		description = "Restores 75 health over 3 seconds",
		value = 100
	},
	["Bandage"] = {
		id = "Bandage",
		name = "Bandage",
		tier = 1,
		weight = 1,
		stack = 5,
		tags = {"medical", "healing"},
		description = "Restores 25 health instantly",
		value = 25
	},
	["Stim"] = {
		id = "Stim", 
		name = "Combat Stimulant",
		tier = 3,
		weight = 1,
		stack = 2,
		tags = {"medical", "enhancement"},
		description = "Increases movement speed for 60 seconds",
		value = 200
	},
	
	-- Armor
	["ArmorI"] = {
		id = "ArmorI",
		name = "Light Armor",
		tier = 2,
		weight = 4,
		stack = 1,
		tags = {"armor", "protection"},
		description = "20% damage reduction",
		value = 300
	},
	["ArmorII"] = {
		id = "ArmorII",
		name = "Heavy Armor", 
		tier = 4,
		weight = 8,
		stack = 1,
		tags = {"armor", "protection"},
		description = "40% damage reduction",
		value = 800
	},
	
	-- Attachments
	["Scope"] = {
		id = "Scope",
		name = "Tactical Scope",
		tier = 3,
		weight = 2,
		stack = 1,
		tags = {"attachment", "optic"},
		description = "Improves weapon accuracy",
		value = 250
	},
	["Silencer"] = {
		id = "Silencer",
		name = "Sound Suppressor",
		tier = 3,
		weight = 2,
		stack = 1,
		tags = {"attachment", "muzzle"},
		description = "Reduces weapon noise",
		value = 300
	},
	
	-- Crafting Materials
	["Scrap"] = {
		id = "Scrap",
		name = "Metal Scrap",
		tier = 1,
		weight = 1,
		stack = 100,
		tags = {"material", "common"},
		description = "Common crafting material",
		value = 1
	},
	["Cloth"] = {
		id = "Cloth",
		name = "Cloth",
		tier = 1,
		weight = 1,
		stack = 50,
		tags = {"material", "common"},
		description = "Textile material for crafting",
		value = 2
	},
	["Electronics"] = {
		id = "Electronics",
		name = "Electronic Components",
		tier = 3,
		weight = 2,
		stack = 20,
		tags = {"material", "rare"},
		description = "Advanced crafting material",
		value = 15
	},
	["PrototypeCore"] = {
		id = "PrototypeCore",
		name = "Prototype Core",
		tier = 5,
		weight = 5,
		stack = 1,
		tags = {"material", "legendary", "special"},
		description = "Extremely rare crafting component",
		value = 1000
	}
}

-- Utility Functions
function Items.GetItem(itemId: string): Item?
	return ItemDatabase[itemId]
end

function Items.GetAllItems(): {[string]: Item}
	return ItemDatabase
end

function Items.GetItemsByTier(tier: number): {Item}
	local result = {}
	for _, item in pairs(ItemDatabase) do
		if item.tier == tier then
			table.insert(result, item)
		end
	end
	return result
end

function Items.GetItemsByTag(tag: string): {Item}
	local result = {}
	for _, item in pairs(ItemDatabase) do
		for _, itemTag in ipairs(item.tags) do
			if itemTag == tag then
				table.insert(result, item)
				break
			end
		end
	end
	return result
end

function Items.GetItemWeight(itemId: string, quantity: number?): number
	local item = Items.GetItem(itemId)
	if not item then return 0 end
	
	local qty = quantity or 1
	return item.weight * qty
end

function Items.GetItemValue(itemId: string, quantity: number?): number
	local item = Items.GetItem(itemId)
	if not item then return 0 end
	
	local qty = quantity or 1
	return (item.value or 0) * qty
end

function Items.IsStackable(itemId: string): boolean
	local item = Items.GetItem(itemId)
	if not item then return false end
	
	return item.stack and item.stack > 1
end

function Items.GetMaxStack(itemId: string): number
	local item = Items.GetItem(itemId)
	if not item then return 1 end
	
	return item.stack or 1
end

function Items.HasTag(itemId: string, tag: string): boolean
	local item = Items.GetItem(itemId)
	if not item then return false end
	
	for _, itemTag in ipairs(item.tags) do
		if itemTag == tag then
			return true
		end
	end
	return false
end

-- Validation
function Items.ValidateItem(itemId: string): boolean
	return ItemDatabase[itemId] ~= nil
end

function Items.GetTierColor(tier: number): Color3
	local Config = require(script.Parent.Config)
	local colors = {
		[1] = Config.UI.Colors.Common,
		[2] = Config.UI.Colors.Uncommon,
		[3] = Config.UI.Colors.Rare,
		[4] = Config.UI.Colors.Epic,
		[5] = Config.UI.Colors.Legendary
	}
	return colors[tier] or Config.UI.Colors.Common
end

function Items.GetTierName(tier: number): string
	local Config = require(script.Parent.Config)
	return Config.UI.TierNames[tier] or "Unknown"
end

return Items