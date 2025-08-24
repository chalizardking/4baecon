--[[
	FORESAKEN Net Events Module
	Defines all networking events and functions for client-server communication
	
	Usage:
	local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)
	NetEvents.SendToServer("Damage", damageData)
]]

local NetEvents = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Event Types
local EventTypes = {
	RELIABLE = "Reliable",
	UNRELIABLE = "Unreliable"
}

-- Network Event Registry
local NetworkEvents = {
	-- Combat Events (Client -> Server)
	Damage = {
		type = EventTypes.RELIABLE,
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.targetId) == "string" and
				   type(data.weaponId) == "string" and
				   type(data.damage) == "number" and
				   data.damage > 0 and data.damage <= 100
		end
	},
	
	WeaponFire = {
		type = EventTypes.UNRELIABLE,
		direction = "ClientToServer", 
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.weaponId) == "string" and
				   type(data.direction) == "table"
		end
	},
	
	-- Loot Events
	LootPickup = {
		type = EventTypes.RELIABLE,
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.lootId) == "string"
		end
	},
	
	LootDrop = {
		type = EventTypes.RELIABLE,
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.itemId) == "string" and
				   type(data.quantity) == "number"
		end
	},
	
	-- Extraction Events
	ExtractEnter = {
		type = EventTypes.RELIABLE,
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.zoneId) == "string"
		end
	},
	
	ExtractExit = {
		type = EventTypes.RELIABLE,
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.zoneId) == "string"
		end
	},
	
	-- Inventory Events
	ItemUse = {
		type = EventTypes.RELIABLE,
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.itemId) == "string" and
				   type(data.slot) == "number"
		end
	},
	
	-- Server -> Client Events
	PlayerDamaged = {
		type = EventTypes.RELIABLE,
		direction = "ServerToClient"
	},
	
	LootSpawned = {
		type = EventTypes.RELIABLE,
		direction = "ServerToClient"
	},
	
	ExtractComplete = {
		type = EventTypes.RELIABLE,
		direction = "ServerToClient"
	},
	
	InventoryUpdate = {
		type = EventTypes.RELIABLE,
		direction = "ServerToClient"
	},
	
	HudUpdate = {
		type = EventTypes.UNRELIABLE,
		direction = "ServerToClient"
	},
	
	NotificationSend = {
		type = EventTypes.RELIABLE,
		direction = "ServerToClient"
	}
}

-- Network Function Registry (RemoteFunctions)
local NetworkFunctions = {
	-- Client -> Server Functions
	RequestLootRoll = {
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.containerId) == "string"
		end,
		ratelimit = {
			maxCalls = 10,
			timeWindow = 60
		}
	},
	
	RequestCraft = {
		direction = "ClientToServer", 
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.recipeId) == "string"
		end,
		ratelimit = {
			maxCalls = 20,
			timeWindow = 60
		}
	},
	
	RequestLoadout = {
		direction = "ClientToServer",
		validation = function(player, data)
			return type(data) == "table" and
				   type(data.slot) == "number"
		end,
		ratelimit = {
			maxCalls = 5,
			timeWindow = 10
		}
	},
	
	RequestPlayerData = {
		direction = "ClientToServer",
		validation = function(player, data)
			return true -- No validation needed
		end,
		ratelimit = {
			maxCalls = 3,
			timeWindow = 10
		}
	}
}

-- Rate limiting
local RateLimits = {}

local function checkRateLimit(player: Player, functionName: string): boolean
	local playerId = tostring(player.UserId)
	local now = tick()
	
	if not RateLimits[playerId] then
		RateLimits[playerId] = {}
	end
	
	local playerLimits = RateLimits[playerId]
	local funcConfig = NetworkFunctions[functionName]
	
	if not funcConfig or not funcConfig.ratelimit then
		return true
	end
	
	local limit = funcConfig.ratelimit
	local key = functionName
	
	if not playerLimits[key] then
		playerLimits[key] = {
			calls = {},
			count = 0
		}
	end
	
	local callData = playerLimits[key]
	
	-- Clean up old calls outside time window
	local cutoff = now - limit.timeWindow
	local newCalls = {}
	for _, callTime in ipairs(callData.calls) do
		if callTime > cutoff then
			table.insert(newCalls, callTime)
		end
	end
	callData.calls = newCalls
	callData.count = #newCalls
	
	-- Check if under limit
	if callData.count >= limit.maxCalls then
		return false
	end
	
	-- Record this call
	table.insert(callData.calls, now)
	callData.count = callData.count + 1
	
	return true
end

-- Event Management
local CreatedEvents = {}
local CreatedFunctions = {}

local function getRemotesFolder()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	return remotesFolder
end

local function createRemoteEvent(eventName: string): RemoteEvent
	local remotesFolder = getRemotesFolder()
	local remoteEvent = remotesFolder:FindFirstChild(eventName)
	
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = eventName
		remoteEvent.Parent = remotesFolder
	end
	
	return remoteEvent
end

local function createRemoteFunction(functionName: string): RemoteFunction
	local remotesFolder = getRemotesFolder()
	local remoteFunction = remotesFolder:FindFirstChild(functionName)
	
	if not remoteFunction then
		remoteFunction = Instance.new("RemoteFunction")
		remoteFunction.Name = functionName
		remoteFunction.Parent = remotesFolder
	end
	
	return remoteFunction
end

-- Initialize network events
function NetEvents.Initialize()
	-- Create RemoteEvents
	for eventName, eventConfig in pairs(NetworkEvents) do
		local remoteEvent = createRemoteEvent(eventName)
		CreatedEvents[eventName] = remoteEvent
		
		-- Set up server-side validation if running on server
		if RunService:IsServer() and eventConfig.direction == "ClientToServer" then
			remoteEvent.OnServerEvent:Connect(function(player, ...)
				if eventConfig.validation then
					local args = {...}
					if not eventConfig.validation(player, args[1]) then
						warn("Invalid data received for event " .. eventName .. " from player " .. player.Name)
						return
					end
				end
			end)
		end
	end
	
	-- Create RemoteFunctions
	for functionName, functionConfig in pairs(NetworkFunctions) do
		local remoteFunction = createRemoteFunction(functionName)
		CreatedFunctions[functionName] = remoteFunction
		
		-- Set up server-side rate limiting and validation
		if RunService:IsServer() and functionConfig.direction == "ClientToServer" then
			remoteFunction.OnServerInvoke = function(player, ...)
				-- Rate limiting
				if not checkRateLimit(player, functionName) then
					warn("Rate limit exceeded for function " .. functionName .. " from player " .. player.Name)
					return nil
				end
				
				-- Validation
				if functionConfig.validation then
					local args = {...}
					if not functionConfig.validation(player, args[1]) then
						warn("Invalid data received for function " .. functionName .. " from player " .. player.Name)
						return nil
					end
				end
				
				-- Function will be handled by game logic
				return nil
			end
		end
	end
end

-- Client-side functions
function NetEvents.SendToServer(eventName: string, data: any)
	if not RunService:IsClient() then
		warn("SendToServer can only be called from client")
		return
	end
	
	local remoteEvent = CreatedEvents[eventName]
	if remoteEvent then
		remoteEvent:FireServer(data)
	else
		warn("Event " .. eventName .. " not found")
	end
end

function NetEvents.CallServer(functionName: string, data: any): any
	if not RunService:IsClient() then
		warn("CallServer can only be called from client")
		return nil
	end
	
	local remoteFunction = CreatedFunctions[functionName]
	if remoteFunction then
		return remoteFunction:InvokeServer(data)
	else
		warn("Function " .. functionName .. " not found")
		return nil
	end
end

-- Server-side functions
function NetEvents.SendToClient(player: Player, eventName: string, data: any)
	if not RunService:IsServer() then
		warn("SendToClient can only be called from server")
		return
	end
	
	local remoteEvent = CreatedEvents[eventName]
	if remoteEvent then
		remoteEvent:FireClient(player, data)
	else
		warn("Event " .. eventName .. " not found")
	end
end

function NetEvents.SendToAllClients(eventName: string, data: any)
	if not RunService:IsServer() then
		warn("SendToAllClients can only be called from server")
		return
	end
	
	local remoteEvent = CreatedEvents[eventName]
	if remoteEvent then
		remoteEvent:FireAllClients(data)
	else
		warn("Event " .. eventName .. " not found")
	end
end

-- Event connection functions
function NetEvents.OnServerEvent(eventName: string, callback: (Player, any) -> ())
	if not RunService:IsServer() then
		warn("OnServerEvent can only be called from server")
		return
	end
	
	local remoteEvent = CreatedEvents[eventName]
	if remoteEvent then
		return remoteEvent.OnServerEvent:Connect(callback)
	else
		warn("Event " .. eventName .. " not found")
	end
end

function NetEvents.OnClientEvent(eventName: string, callback: (any) -> ())
	if not RunService:IsClient() then
		warn("OnClientEvent can only be called from client")
		return
	end
	
	local remoteEvent = CreatedEvents[eventName]
	if remoteEvent then
		return remoteEvent.OnClientEvent:Connect(callback)
	else
		warn("Event " .. eventName .. " not found")
	end
end

function NetEvents.OnServerInvoke(functionName: string, callback: (Player, any) -> any)
	if not RunService:IsServer() then
		warn("OnServerInvoke can only be called from server")
		return
	end
	
	local remoteFunction = CreatedFunctions[functionName]
	if remoteFunction then
		remoteFunction.OnServerInvoke = callback
	else
		warn("Function " .. functionName .. " not found")
	end
end

-- Utility functions
function NetEvents.GetEventNames(): {string}
	local names = {}
	for name in pairs(NetworkEvents) do
		table.insert(names, name)
	end
	return names
end

function NetEvents.GetFunctionNames(): {string}
	local names = {}
	for name in pairs(NetworkFunctions) do
		table.insert(names, name)
	end
	return names
end

-- Clean up rate limits periodically
if RunService:IsServer() then
	task.spawn(function()
		while true do
			task.wait(60) -- Clean up every minute
			local now = tick()
			for playerId, playerLimits in pairs(RateLimits) do
				for functionName, callData in pairs(playerLimits) do
					local funcConfig = NetworkFunctions[functionName]
					if funcConfig and funcConfig.ratelimit then
						local cutoff = now - funcConfig.ratelimit.timeWindow
						local newCalls = {}
						for _, callTime in ipairs(callData.calls) do
							if callTime > cutoff then
								table.insert(newCalls, callTime)
							end
						end
						callData.calls = newCalls
						callData.count = #newCalls
					end
				end
			end
		end
	end)
end

return NetEvents