--[[
	FORESAKEN Signals Module
	Custom signal implementation for game events
	
	Usage:
	local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
	local signal = Signals.new()
	signal:Connect(function(data) print(data) end)
	signal:Fire("Hello World")
]]

local Signals = {}

-- Signal Class
local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = {
		_connections = {},
		_connectionCount = 0
	}
	setmetatable(self, Signal)
	return self
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Callback must be a function")
	
	self._connectionCount += 1
	local connectionId = self._connectionCount
	
	local connection = {
		_signal = self,
		_id = connectionId,
		_callback = callback,
		_connected = true
	}
	
	self._connections[connectionId] = connection
	
	-- Return connection object with Disconnect method
	return {
		Disconnect = function()
			if connection._connected then
				connection._connected = false
				self._connections[connectionId] = nil
			end
		end,
		Connected = connection._connected
	}
end

function Signal:Fire(...)
	local connections = {}
	
	-- Copy connections to avoid modification during iteration
	for _, connection in pairs(self._connections) do
		if connection._connected then
			table.insert(connections, connection)
		end
	end
	
	-- Fire all callbacks
	for _, connection in ipairs(connections) do
		if connection._connected then
			task.spawn(connection._callback, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	local returnValues = {}
	
	connection = self:Connect(function(...)
		returnValues = {...}
		connection:Disconnect()
		task.spawn(thread)
	end)
	
	coroutine.yield()
	return unpack(returnValues)
end

function Signal:DisconnectAll()
	for _, connection in pairs(self._connections) do
		connection._connected = false
	end
	self._connections = {}
end

function Signal:Destroy()
	self:DisconnectAll()
	setmetatable(self, nil)
end

-- Module Functions
function Signals.new()
	return Signal.new()
end

-- Game-specific signals registry
local GameSignals = {
	-- Combat Events
	PlayerDamaged = Signal.new(),
	PlayerKilled = Signal.new(),
	EnemyKilled = Signal.new(),
	WeaponFired = Signal.new(),
	
	-- Loot Events  
	LootSpawned = Signal.new(),
	LootPickedUp = Signal.new(),
	LootDropped = Signal.new(),
	InventoryChanged = Signal.new(),
	
	-- Match Events
	MatchStarted = Signal.new(),
	MatchEnded = Signal.new(),
	PlayerJoined = Signal.new(),
	PlayerLeft = Signal.new(),
	ExtractOpened = Signal.new(),
	ExtractStarted = Signal.new(),
	ExtractCompleted = Signal.new(),
	
	-- UI Events
	InventoryOpened = Signal.new(),
	InventoryClosed = Signal.new(),
	HudUpdated = Signal.new(),
	NotificationShown = Signal.new(),
	
	-- Progression Events
	LevelUp = Signal.new(),
	XPGained = Signal.new(),
	CurrencyChanged = Signal.new(),
	ItemCrafted = Signal.new(),
	HideoutUpgraded = Signal.new(),
	
	-- System Events
	DataLoaded = Signal.new(),
	DataSaved = Signal.new(),
	ErrorOccurred = Signal.new(),
	PerformanceWarning = Signal.new()
}

function Signals.Get(signalName: string)
	return GameSignals[signalName]
end

function Signals.GetAll()
	return GameSignals
end

-- Helper function for creating temporary signals
function Signals.CreateTemporary()
	return Signal.new()
end

-- Signal group management
local SignalGroups = {}

function Signals.CreateGroup(groupName: string, signalNames: {string})
	local group = {}
	for _, signalName in ipairs(signalNames) do
		group[signalName] = Signal.new()
	end
	SignalGroups[groupName] = group
	return group
end

function Signals.GetGroup(groupName: string)
	return SignalGroups[groupName]
end

function Signals.DisconnectGroup(groupName: string)
	local group = SignalGroups[groupName]
	if group then
		for _, signal in pairs(group) do
			signal:DisconnectAll()
		end
	end
end

-- Utility functions for common patterns
function Signals.Once(signal, callback)
	local connection
	connection = signal:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signals.Debounce(signal, delay, callback)
	local lastFired = 0
	return signal:Connect(function(...)
		local now = tick()
		if now - lastFired >= delay then
			lastFired = now
			callback(...)
		end
	end)
end

function Signals.Throttle(signal, interval, callback)
	local lastCall = 0
	local pending = false
	
	return signal:Connect(function(...)
		local now = tick()
		if now - lastCall >= interval then
			lastCall = now
			callback(...)
		elseif not pending then
			pending = true
			task.wait(interval - (now - lastCall))
			pending = false
			lastCall = tick()
			callback(...)
		end
	end)
end

-- Clean up all signals (for testing/reset)
function Signals.CleanupAll()
	for _, signal in pairs(GameSignals) do
		signal:DisconnectAll()
	end
	
	for _, group in pairs(SignalGroups) do
		for _, signal in pairs(group) do
			signal:DisconnectAll()
		end
	end
	
	SignalGroups = {}
end

return Signals