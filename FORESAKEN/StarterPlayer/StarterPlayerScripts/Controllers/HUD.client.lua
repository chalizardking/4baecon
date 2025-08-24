--[[
	FORESAKEN HUD Controller
	Manages the main game HUD and UI elements
	
	Features:
	- Health/Armor display
	- Weapon/Ammo display
	- Inventory weight display
	- Extract timer
	- Minimap
	- Kill feed
	- Notifications
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Items = require(ReplicatedStorage.Shared.Modules.Items)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- HUD Controller
local HUDController = {}

-- UI Elements
local mainHUD
local healthBar
local armorBar
local weaponDisplay
local ammoDisplay
local inventoryWeight
local extractTimer
local killFeed
local notificationArea
local crosshair

-- HUD State
local HUDState = {
	health = 100,
	maxHealth = 100,
	armor = 0,
	maxArmor = 100,
	currentWeapon = nil,
	currentAmmo = 0,
	maxAmmo = 0,
	inventoryWeight = 0,
	maxWeight = 30,
	inExtractZone = false,
	extractProgress = 0,
	extractDuration = 8
}

-- Create main HUD structure
local function createMainHUD()
	-- Main HUD ScreenGui
	mainHUD = Instance.new("ScreenGui")
	mainHUD.Name = "MainHUD"
	mainHUD.ResetOnSpawn = false
	mainHUD.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainHUD.Parent = playerGui
	
	-- Health Bar Container
	local healthContainer = Instance.new("Frame")
	healthContainer.Name = "HealthContainer"
	healthContainer.Size = UDim2.new(0, 300, 0, 60)
	healthContainer.Position = UDim2.new(0, 20, 1, -80)
	healthContainer.BackgroundTransparency = 1
	healthContainer.Parent = mainHUD
	
	-- Health Bar Background
	local healthBG = Instance.new("Frame")
	healthBG.Name = "HealthBackground"
	healthBG.Size = UDim2.new(1, 0, 0, 25)
	healthBG.Position = UDim2.new(0, 0, 0, 0)
	healthBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	healthBG.BorderSizePixel = 0
	healthBG.Parent = healthContainer
	
	-- Health Bar
	healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.Position = UDim2.new(0, 0, 0, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = healthBG
	
	-- Health Text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = "100/100"
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.GothamBold
	healthText.Parent = healthBG
	
	-- Armor Bar Background
	local armorBG = Instance.new("Frame")
	armorBG.Name = "ArmorBackground"
	armorBG.Size = UDim2.new(1, 0, 0, 25)
	armorBG.Position = UDim2.new(0, 0, 0, 35)
	armorBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	armorBG.BorderSizePixel = 0
	armorBG.Parent = healthContainer
	
	-- Armor Bar
	armorBar = Instance.new("Frame")
	armorBar.Name = "ArmorBar"
	armorBar.Size = UDim2.new(0, 0, 1, 0)
	armorBar.Position = UDim2.new(0, 0, 0, 0)
	armorBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	armorBar.BorderSizePixel = 0
	armorBar.Parent = armorBG
	
	-- Armor Text
	local armorText = Instance.new("TextLabel")
	armorText.Name = "ArmorText"
	armorText.Size = UDim2.new(1, 0, 1, 0)
	armorText.BackgroundTransparency = 1
	armorText.Text = "0/100"
	armorText.TextColor3 = Color3.fromRGB(255, 255, 255)
	armorText.TextScaled = true
	armorText.Font = Enum.Font.Gotham
	armorText.Parent = armorBG
end

-- Create weapon display
local function createWeaponDisplay()
	local weaponContainer = Instance.new("Frame")
	weaponContainer.Name = "WeaponContainer"
	weaponContainer.Size = UDim2.new(0, 200, 0, 80)
	weaponContainer.Position = UDim2.new(1, -220, 1, -100)
	weaponContainer.BackgroundTransparency = 1
	weaponContainer.Parent = mainHUD
	
	-- Weapon Name
	weaponDisplay = Instance.new("TextLabel")
	weaponDisplay.Name = "WeaponName"
	weaponDisplay.Size = UDim2.new(1, 0, 0, 30)
	weaponDisplay.Position = UDim2.new(0, 0, 0, 0)
	weaponDisplay.BackgroundTransparency = 1
	weaponDisplay.Text = "No Weapon"
	weaponDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
	weaponDisplay.TextScaled = true
	weaponDisplay.Font = Enum.Font.GothamBold
	weaponDisplay.TextXAlignment = Enum.TextXAlignment.Right
	weaponDisplay.Parent = weaponContainer
	
	-- Ammo Display
	ammoDisplay = Instance.new("TextLabel")
	ammoDisplay.Name = "AmmoDisplay"
	ammoDisplay.Size = UDim2.new(1, 0, 0, 40)
	ammoDisplay.Position = UDim2.new(0, 0, 0, 35)
	ammoDisplay.BackgroundTransparency = 1
	ammoDisplay.Text = "0/0"
	ammoDisplay.TextColor3 = Color3.fromRGB(200, 200, 200)
	ammoDisplay.TextScaled = true
	ammoDisplay.Font = Enum.Font.Gotham
	ammoDisplay.TextXAlignment = Enum.TextXAlignment.Right
	ammoDisplay.Parent = weaponContainer
end

-- Create inventory weight display
local function createInventoryDisplay()
	local inventoryContainer = Instance.new("Frame")
	inventoryContainer.Name = "InventoryContainer"
	inventoryContainer.Size = UDim2.new(0, 150, 0, 40)
	inventoryContainer.Position = UDim2.new(1, -170, 0, 20)
	inventoryContainer.BackgroundTransparency = 1
	inventoryContainer.Parent = mainHUD
	
	-- Weight Bar Background
	local weightBG = Instance.new("Frame")
	weightBG.Name = "WeightBackground"
	weightBG.Size = UDim2.new(1, 0, 0, 20)
	weightBG.Position = UDim2.new(0, 0, 0, 0)
	weightBG.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	weightBG.BorderSizePixel = 0
	weightBG.Parent = inventoryContainer
	
	-- Weight Bar
	inventoryWeight = Instance.new("Frame")
	inventoryWeight.Name = "WeightBar"
	inventoryWeight.Size = UDim2.new(0, 0, 1, 0)
	inventoryWeight.Position = UDim2.new(0, 0, 0, 0)
	inventoryWeight.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
	inventoryWeight.BorderSizePixel = 0
	inventoryWeight.Parent = weightBG
	
	-- Weight Text
	local weightText = Instance.new("TextLabel")
	weightText.Name = "WeightText"
	weightText.Size = UDim2.new(1, 0, 0, 20)
	weightText.Position = UDim2.new(0, 0, 0, 25)
	weightText.BackgroundTransparency = 1
	weightText.Text = "0/30 KG"
	weightText.TextColor3 = Color3.fromRGB(255, 255, 255)
	weightText.TextScaled = true
	weightText.Font = Enum.Font.Gotham
	weightText.TextXAlignment = Enum.TextXAlignment.Center
	weightText.Parent = inventoryContainer
end

-- Create extract timer
local function createExtractTimer()
	extractTimer = Instance.new("Frame")
	extractTimer.Name = "ExtractTimer"
	extractTimer.Size = UDim2.new(0, 300, 0, 80)
	extractTimer.Position = UDim2.new(0.5, -150, 0.5, -40)
	extractTimer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	extractTimer.BackgroundTransparency = 0.3
	extractTimer.BorderSizePixel = 0
	extractTimer.Visible = false
	extractTimer.Parent = mainHUD
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = extractTimer
	
	-- Extract Text
	local extractText = Instance.new("TextLabel")
	extractText.Name = "ExtractText"
	extractText.Size = UDim2.new(1, 0, 0, 30)
	extractText.Position = UDim2.new(0, 0, 0, 10)
	extractText.BackgroundTransparency = 1
	extractText.Text = "EXTRACTING..."
	extractText.TextColor3 = Color3.fromRGB(100, 255, 100)
	extractText.TextScaled = true
	extractText.Font = Enum.Font.GothamBold
	extractText.TextXAlignment = Enum.TextXAlignment.Center
	extractText.Parent = extractTimer
	
	-- Progress Bar Background
	local progressBG = Instance.new("Frame")
	progressBG.Name = "ProgressBackground"
	progressBG.Size = UDim2.new(0.8, 0, 0, 15)
	progressBG.Position = UDim2.new(0.1, 0, 0, 50)
	progressBG.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	progressBG.BorderSizePixel = 0
	progressBG.Parent = extractTimer
	
	-- Progress Bar
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	progressBar.BorderSizePixel = 0
	progressBar.Parent = progressBG
end

-- Create crosshair
local function createCrosshair()
	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 20, 0, 20)
	crosshair.Position = UDim2.new(0.5, -10, 0.5, -10)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = mainHUD
	
	-- Horizontal line
	local hLine = Instance.new("Frame")
	hLine.Size = UDim2.new(1, 0, 0, 2)
	hLine.Position = UDim2.new(0, 0, 0.5, -1)
	hLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	hLine.BorderSizePixel = 0
	hLine.Parent = crosshair
	
	-- Vertical line
	local vLine = Instance.new("Frame")
	vLine.Size = UDim2.new(0, 2, 1, 0)
	vLine.Position = UDim2.new(0.5, -1, 0, 0)
	vLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	vLine.BorderSizePixel = 0
	vLine.Parent = crosshair
end

-- Create kill feed
local function createKillFeed()
	killFeed = Instance.new("ScrollingFrame")
	killFeed.Name = "KillFeed"
	killFeed.Size = UDim2.new(0, 300, 0, 200)
	killFeed.Position = UDim2.new(1, -320, 0, 20)
	killFeed.BackgroundTransparency = 1
	killFeed.ScrollBarThickness = 0
	killFeed.CanvasSize = UDim2.new(0, 0, 0, 0)
	killFeed.Parent = mainHUD
	
	-- Auto-scroll layout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = killFeed
end

-- Create notification area
local function createNotificationArea()
	notificationArea = Instance.new("Frame")
	notificationArea.Name = "NotificationArea"
	notificationArea.Size = UDim2.new(0, 400, 0, 300)
	notificationArea.Position = UDim2.new(0.5, -200, 0, 100)
	notificationArea.BackgroundTransparency = 1
	notificationArea.Parent = mainHUD
	
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = notificationArea
end

-- Update functions
function HUDController.UpdateHealth(health: number, maxHealth: number?)
	HUDState.health = health
	HUDState.maxHealth = maxHealth or HUDState.maxHealth
	
	local healthPercent = HUDState.health / HUDState.maxHealth
	
	-- Animate health bar
	local tween = TweenService:Create(healthBar, 
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(healthPercent, 0, 1, 0)}
	)
	tween:Play()
	
	-- Update text
	healthBar.Parent.HealthText.Text = math.floor(HUDState.health) .. "/" .. HUDState.maxHealth
	
	-- Change color based on health
	if healthPercent > 0.6 then
		healthBar.BackgroundColor3 = Color3.fromRGB(220, 50, 50) -- Red
	elseif healthPercent > 0.3 then
		healthBar.BackgroundColor3 = Color3.fromRGB(255, 165, 0) -- Orange
	else
		healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Dark red
	end
end

function HUDController.UpdateArmor(armor: number, maxArmor: number?)
	HUDState.armor = armor
	HUDState.maxArmor = maxArmor or HUDState.maxArmor
	
	local armorPercent = HUDState.armor / HUDState.maxArmor
	
	-- Animate armor bar
	local tween = TweenService:Create(armorBar,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(armorPercent, 0, 1, 0)}
	)
	tween:Play()
	
	-- Update text
	armorBar.Parent.ArmorText.Text = math.floor(HUDState.armor) .. "/" .. HUDState.maxArmor
end

function HUDController.UpdateWeapon(weaponId: string?, currentAmmo: number?, maxAmmo: number?)
	HUDState.currentWeapon = weaponId
	HUDState.currentAmmo = currentAmmo or 0
	HUDState.maxAmmo = maxAmmo or 0
	
	if weaponId then
		local weaponData = Items.GetItem(weaponId)
		weaponDisplay.Text = weaponData and weaponData.name or weaponId
	else
		weaponDisplay.Text = "No Weapon"
	end
	
	ammoDisplay.Text = HUDState.currentAmmo .. "/" .. HUDState.maxAmmo
end

function HUDController.UpdateInventoryWeight(weight: number, maxWeight: number?)
	HUDState.inventoryWeight = weight
	HUDState.maxWeight = maxWeight or HUDState.maxWeight
	
	local weightPercent = HUDState.inventoryWeight / HUDState.maxWeight
	
	-- Animate weight bar
	local tween = TweenService:Create(inventoryWeight,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(weightPercent, 0, 1, 0)}
	)
	tween:Play()
	
	-- Update text
	inventoryWeight.Parent.Parent.WeightText.Text = math.floor(HUDState.inventoryWeight) .. "/" .. HUDState.maxWeight .. " KG"
	
	-- Change color based on weight
	if weightPercent > 0.9 then
		inventoryWeight.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- Red - overloaded
	elseif weightPercent > 0.7 then
		inventoryWeight.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Orange - heavy
	else
		inventoryWeight.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green - normal
	end
end

function HUDController.ShowExtractTimer(duration: number?)
	HUDState.extractDuration = duration or 8
	extractTimer.Visible = true
	HUDState.inExtractZone = true
	HUDState.extractProgress = 0
end

function HUDController.HideExtractTimer()
	extractTimer.Visible = false
	HUDState.inExtractZone = false
	HUDState.extractProgress = 0
end

function HUDController.UpdateExtractProgress(progress: number)
	HUDState.extractProgress = progress
	local progressPercent = progress / HUDState.extractDuration
	
	-- Update progress bar
	local progressBar = extractTimer.ProgressBackground.ProgressBar
	local tween = TweenService:Create(progressBar,
		TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{Size = UDim2.new(progressPercent, 0, 1, 0)}
	)
	tween:Play()
end

function HUDController.AddKillFeedEntry(killerName: string, victimName: string, weaponName: string?)
	local killEntry = Instance.new("TextLabel")
	killEntry.Size = UDim2.new(1, 0, 0, 25)
	killEntry.BackgroundTransparency = 1
	killEntry.TextColor3 = Color3.fromRGB(255, 255, 255)
	killEntry.TextScaled = true
	killEntry.Font = Enum.Font.Gotham
	killEntry.TextXAlignment = Enum.TextXAlignment.Left
	
	local killText = killerName .. " killed " .. victimName
	if weaponName then
		killText = killText .. " with " .. weaponName
	end
	killEntry.Text = killText
	
	killEntry.Parent = killFeed
	
	-- Auto-remove after 10 seconds
	task.wait(10)
	killEntry:Destroy()
end

function HUDController.ShowNotification(message: string, duration: number?, notificationType: string?)
	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(0, 350, 0, 60)
	notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	notification.BackgroundTransparency = 0.2
	notification.BorderSizePixel = 0
	notification.Parent = notificationArea
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification
	
	-- Notification text
	local notificationText = Instance.new("TextLabel")
	notificationText.Size = UDim2.new(1, -20, 1, -20)
	notificationText.Position = UDim2.new(0, 10, 0, 10)
	notificationText.BackgroundTransparency = 1
	notificationText.Text = message
	notificationText.TextColor3 = Color3.fromRGB(255, 255, 255)
	notificationText.TextWrapped = true
	notificationText.TextScaled = true
	notificationText.Font = Enum.Font.Gotham
	notificationText.Parent = notification
	
	-- Color based on type
	if notificationType == "error" then
		notification.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	elseif notificationType == "success" then
		notification.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	elseif notificationType == "warning" then
		notification.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	end
	
	-- Fade in animation
	notification.BackgroundTransparency = 1
	notificationText.TextTransparency = 1
	
	local fadeIn = TweenService:Create(notification,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0.2}
	)
	local textFadeIn = TweenService:Create(notificationText,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)
	
	fadeIn:Play()
	textFadeIn:Play()
	
	-- Auto-remove
	task.spawn(function()
		task.wait(duration or 5)
		
		local fadeOut = TweenService:Create(notification,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = 1}
		)
		local textFadeOut = TweenService:Create(notificationText,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{TextTransparency = 1}
		)
		
		fadeOut:Play()
		textFadeOut:Play()
		
		fadeOut.Completed:Connect(function()
			notification:Destroy()
		end)
	end)
end

-- Initialize HUD
function HUDController.Initialize()
	createMainHUD()
	createWeaponDisplay()
	createInventoryDisplay()
	createExtractTimer()
	createCrosshair()
	createKillFeed()
	createNotificationArea()
	
	-- Connect to signals
	Signals.Get("HudUpdate"):Connect(function(data)
		if data.health then
			HUDController.UpdateHealth(data.health, data.maxHealth)
		end
		if data.armor then
			HUDController.UpdateArmor(data.armor, data.maxArmor)
		end
		if data.weapon then
			HUDController.UpdateWeapon(data.weapon, data.currentAmmo, data.maxAmmo)
		end
		if data.inventoryWeight then
			HUDController.UpdateInventoryWeight(data.inventoryWeight, data.maxWeight)
		end
	end)
	
	-- Connect to network events
	NetEvents.OnClientEvent("HudUpdate", function(data)
		Signals.Get("HudUpdate"):Fire(data)
	end)
	
	NetEvents.OnClientEvent("NotificationSend", function(data)
		HUDController.ShowNotification(data.message, data.duration, data.type)
	end)
	
	print("HUD Controller initialized")
end

-- Cleanup
function HUDController.Destroy()
	if mainHUD then
		mainHUD:Destroy()
	end
end

-- Initialize on script load
HUDController.Initialize()

return HUDController