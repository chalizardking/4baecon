--[[
	FORESAKEN RemoteEvents and RemoteFunctions Setup
	This script creates and manages all networking objects
	
	Place this in ReplicatedStorage/Remotes/
]]

-- Create RemoteEvents
local LootPickup = Instance.new("RemoteEvent")
LootPickup.Name = "LootPickup"
LootPickup.Parent = script.Parent

local Damage = Instance.new("RemoteEvent") 
Damage.Name = "Damage"
Damage.Parent = script.Parent

local ExtractEnter = Instance.new("RemoteEvent")
ExtractEnter.Name = "ExtractEnter"
ExtractEnter.Parent = script.Parent

local ExtractExit = Instance.new("RemoteEvent")
ExtractExit.Name = "ExtractExit"
ExtractExit.Parent = script.Parent

local ExtractComplete = Instance.new("RemoteEvent")
ExtractComplete.Name = "ExtractComplete" 
ExtractComplete.Parent = script.Parent

local ItemUse = Instance.new("RemoteEvent")
ItemUse.Name = "ItemUse"
ItemUse.Parent = script.Parent

local WeaponFire = Instance.new("RemoteEvent")
WeaponFire.Name = "WeaponFire"
WeaponFire.Parent = script.Parent

local LootDrop = Instance.new("RemoteEvent")
LootDrop.Name = "LootDrop"
LootDrop.Parent = script.Parent

-- Server to Client Events
local PlayerDamaged = Instance.new("RemoteEvent")
PlayerDamaged.Name = "PlayerDamaged"
PlayerDamaged.Parent = script.Parent

local LootSpawned = Instance.new("RemoteEvent")
LootSpawned.Name = "LootSpawned" 
LootSpawned.Parent = script.Parent

local InventoryUpdate = Instance.new("RemoteEvent")
InventoryUpdate.Name = "InventoryUpdate"
InventoryUpdate.Parent = script.Parent

local HudUpdate = Instance.new("RemoteEvent")
HudUpdate.Name = "HudUpdate"
HudUpdate.Parent = script.Parent

local NotificationSend = Instance.new("RemoteEvent")
NotificationSend.Name = "NotificationSend"
NotificationSend.Parent = script.Parent

-- Create RemoteFunctions
local RequestLootRoll = Instance.new("RemoteFunction")
RequestLootRoll.Name = "RequestLootRoll"
RequestLootRoll.Parent = script.Parent

local RequestCraft = Instance.new("RemoteFunction")
RequestCraft.Name = "RequestCraft"
RequestCraft.Parent = script.Parent

local RequestLoadout = Instance.new("RemoteFunction")
RequestLoadout.Name = "RequestLoadout" 
RequestLoadout.Parent = script.Parent

local RequestPlayerData = Instance.new("RemoteFunction")
RequestPlayerData.Name = "RequestPlayerData"
RequestPlayerData.Parent = script.Parent

return {}