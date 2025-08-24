--[[
	FORESAKEN Inventory Controller (Client)
	Manages player inventory, weight system, and inventory UI
	
	Features:
	- Weight-based inventory management
	- Dynamic inventory UI
	- Item organization and sorting
	- Quick-use slots
	- Drag and drop functionality
	- Item tooltips and information
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Items = require(ReplicatedStorage.Shared.Modules.Items)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Inventory Controller
local InventoryController = {}

-- Inventory state
local InventoryState = {
	items = {}, -- {slotIndex = {itemId, quantity}}
	maxWeight = Config.Inventory.BaseCap,
	currentWeight = 0,
	isOpen = false,
	selectedSlot = nil,
	quickSlots = {}, -- Quick access slots 1-5
	sortMode = "name" -- "name", "tier", "weight", "quantity"
}

-- UI elements
local inventoryFrame
local itemSlots = {}
local quickSlotFrames = {}
local weightBar
local weightLabel
local itemTooltip

-- Inventory UI configuration
local SLOT_SIZE = UDim2.new(0, 60, 0, 60)
local SLOTS_PER_ROW = 8
local MAX_SLOTS = 40

-- Initialize networking
NetEvents.Initialize()

-- Create inventory UI
local function createInventoryUI()
	-- Main inventory frame
	inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UDim2.new(0, 520, 0, 400)
	inventoryFrame.Position = UDim2.new(0.5, -260, 0.5, -200)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	inventoryFrame.BorderSizePixel = 0
	inventoryFrame.Visible = false
	inventoryFrame.Parent = playerGui
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = inventoryFrame
	
	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = inventoryFrame
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 10)
	titleCorner.Parent = titleBar
	
	-- Title text
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -80, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "INVENTORY"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "×"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = titleBar
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 5)
	closeCorner.Parent = closeButton
	
	-- Weight display
	local weightFrame = Instance.new("Frame")
	weightFrame.Name = "WeightFrame"
	weightFrame.Size = UDim2.new(1, -20, 0, 30)
	weightFrame.Position = UDim2.new(0, 10, 0, 50)
	weightFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	weightFrame.BorderSizePixel = 0
	weightFrame.Parent = inventoryFrame
	
	local weightFrameCorner = Instance.new("UICorner")
	weightFrameCorner.CornerRadius = UDim.new(0, 5)
	weightFrameCorner.Parent = weightFrame
	
	-- Weight bar background
	local weightBG = Instance.new("Frame")
	weightBG.Name = "WeightBackground"
	weightBG.Size = UDim2.new(0.7, 0, 0, 15)
	weightBG.Position = UDim2.new(0, 10, 0.5, -7.5)
	weightBG.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	weightBG.BorderSizePixel = 0
	weightBG.Parent = weightFrame
	
	-- Weight bar
	weightBar = Instance.new("Frame")
	weightBar.Name = "WeightBar"
	weightBar.Size = UDim2.new(0, 0, 1, 0)
	weightBar.Position = UDim2.new(0, 0, 0, 0)
	weightBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	weightBar.BorderSizePixel = 0
	weightBar.Parent = weightBG
	
	-- Weight label
	weightLabel = Instance.new("TextLabel")
	weightLabel.Name = "WeightLabel"
	weightLabel.Size = UDim2.new(0.3, -10, 1, 0)
	weightLabel.Position = UDim2.new(0.7, 0, 0, 0)
	weightLabel.BackgroundTransparency = 1
	weightLabel.Text = "0/" .. InventoryState.maxWeight .. " KG"
	weightLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	weightLabel.TextScaled = true
	weightLabel.Font = Enum.Font.Gotham
	weightLabel.TextXAlignment = Enum.TextXAlignment.Center
	weightLabel.Parent = weightFrame
	
	-- Items container
	local itemsContainer = Instance.new("ScrollingFrame")
	itemsContainer.Name = "ItemsContainer"
	itemsContainer.Size = UDim2.new(1, -20, 1, -100)
	itemsContainer.Position = UDim2.new(0, 10, 0, 90)
	itemsContainer.BackgroundTransparency = 1
	itemsContainer.BorderSizePixel = 0
	itemsContainer.ScrollBarThickness = 8
	itemsContainer.Parent = inventoryFrame
	
	-- Items grid layout
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = SLOT_SIZE
	gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = itemsContainer
	
	-- Create item slots
	for i = 1, MAX_SLOTS do
		local slot = createItemSlot(i)
		slot.Parent = itemsContainer
		itemSlots[i] = slot
	end
	
	-- Update canvas size based on grid
	local slotsPerRow = math.floor((itemsContainer.AbsoluteSize.X - 10) / (SLOT_SIZE.X.Offset + 5))
	local rows = math.ceil(MAX_SLOTS / slotsPerRow)
	itemsContainer.CanvasSize = UDim2.new(0, 0, 0, rows * (SLOT_SIZE.Y.Offset + 5))
	
	-- Connect close button
	closeButton.MouseButton1Click:Connect(function()
		InventoryController.CloseInventory()
	end)
end

-- Create individual item slot
local function createItemSlot(slotIndex: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. slotIndex
	slot.Size = SLOT_SIZE
	slot.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	slot.BorderSizePixel = 1
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	
	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 5)
	slotCorner.Parent = slot
	
	-- Item icon
	local itemIcon = Instance.new("ImageLabel")
	itemIcon.Name = "ItemIcon"
	itemIcon.Size = UDim2.new(0.8, 0, 0.8, 0)
	itemIcon.Position = UDim2.new(0.1, 0, 0.1, 0)
	itemIcon.BackgroundTransparency = 1
	itemIcon.Image = ""
	itemIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	itemIcon.Parent = slot
	
	-- Quantity label
	local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Name = "QuantityLabel"
	quantityLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
	quantityLabel.Position = UDim2.new(0.6, 0, 0.7, 0)
	quantityLabel.BackgroundTransparency = 1
	quantityLabel.Text = ""
	quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	quantityLabel.TextScaled = true
	quantityLabel.Font = Enum.Font.GothamBold
	quantityLabel.TextStrokeTransparency = 0
	quantityLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	quantityLabel.Parent = slot
	
	-- Click detector
	local clickDetector = Instance.new("TextButton")
	clickDetector.Name = "ClickDetector"
	clickDetector.Size = UDim2.new(1, 0, 1, 0)
	clickDetector.BackgroundTransparency = 1
	clickDetector.Text = ""
	clickDetector.Parent = slot
	
	-- Connect click events
	clickDetector.MouseButton1Click:Connect(function()
		handleSlotClick(slotIndex)
	end)
	
	clickDetector.MouseEnter:Connect(function()
		showItemTooltip(slotIndex)
	end)
	
	clickDetector.MouseLeave:Connect(function()
		hideItemTooltip()
	end)
	
	return slot
end

-- Create item tooltip
local function createItemTooltip()
	itemTooltip = Instance.new("Frame")
	itemTooltip.Name = "ItemTooltip"
	itemTooltip.Size = UDim2.new(0, 200, 0, 100)
	itemTooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	itemTooltip.BorderSizePixel = 1
	itemTooltip.BorderColor3 = Color3.fromRGB(100, 100, 100)
	itemTooltip.Visible = false
	itemTooltip.ZIndex = 100
	itemTooltip.Parent = playerGui
	
	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, 5)
	tooltipCorner.Parent = itemTooltip
	
	-- Item name
	local itemName = Instance.new("TextLabel")
	itemName.Name = "ItemName"
	itemName.Size = UDim2.new(1, -10, 0, 25)
	itemName.Position = UDim2.new(0, 5, 0, 5)
	itemName.BackgroundTransparency = 1
	itemName.Text = ""
	itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
	itemName.TextScaled = true
	itemName.Font = Enum.Font.GothamBold
	itemName.TextXAlignment = Enum.TextXAlignment.Left
	itemName.Parent = itemTooltip
	
	-- Item description
	local itemDescription = Instance.new("TextLabel")
	itemDescription.Name = "ItemDescription"
	itemDescription.Size = UDim2.new(1, -10, 1, -30)
	itemDescription.Position = UDim2.new(0, 5, 0, 25)
	itemDescription.BackgroundTransparency = 1
	itemDescription.Text = ""
	itemDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
	itemDescription.TextWrapped = true
	itemDescription.TextYAlignment = Enum.TextYAlignment.Top
	itemDescription.Font = Enum.Font.Gotham
	itemDescription.TextSize = 12
	itemDescription.Parent = itemTooltip
end

-- Create quick slots UI
local function createQuickSlotsUI()
	local quickSlotsFrame = Instance.new("Frame")
	quickSlotsFrame.Name = "QuickSlotsFrame"
	quickSlotsFrame.Size = UDim2.new(0, 350, 0, 70)
	quickSlotsFrame.Position = UDim2.new(0.5, -175, 1, -90)
	quickSlotsFrame.BackgroundTransparency = 1
	quickSlotsFrame.Parent = playerGui
	
	for i = 1, 5 do
		local quickSlot = Instance.new("Frame")
		quickSlot.Name = "QuickSlot" .. i
		quickSlot.Size = UDim2.new(0, 60, 0, 60)
		quickSlot.Position = UDim2.new(0, (i - 1) * 70, 0, 5)
		quickSlot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		quickSlot.BorderSizePixel = 2
		quickSlot.BorderColor3 = Color3.fromRGB(100, 100, 100)
		quickSlot.Parent = quickSlotsFrame
		
		local quickCorner = Instance.new("UICorner")
		quickCorner.CornerRadius = UDim.new(0, 8)
		quickCorner.Parent = quickSlot
		
		-- Slot number label
		local slotNumber = Instance.new("TextLabel")
		slotNumber.Name = "SlotNumber"
		slotNumber.Size = UDim2.new(0.3, 0, 0.3, 0)
		slotNumber.Position = UDim2.new(0, 2, 0, 2)
		slotNumber.BackgroundTransparency = 1
		slotNumber.Text = tostring(i)
		slotNumber.TextColor3 = Color3.fromRGB(255, 255, 255)
		slotNumber.TextScaled = true
		slotNumber.Font = Enum.Font.GothamBold
		slotNumber.Parent = quickSlot
		
		-- Item icon (similar to inventory slots)
		local itemIcon = Instance.new("ImageLabel")
		itemIcon.Name = "ItemIcon"
		itemIcon.Size = UDim2.new(0.7, 0, 0.7, 0)
		itemIcon.Position = UDim2.new(0.15, 0, 0.15, 0)
		itemIcon.BackgroundTransparency = 1
		itemIcon.Image = ""
		itemIcon.Parent = quickSlot
		
		quickSlotFrames[i] = quickSlot
	end
end

-- Handle slot click
local function handleSlotClick(slotIndex: number)
	local itemData = InventoryState.items[slotIndex]
	if not itemData then return end
	
	-- Select/deselect slot
	if InventoryState.selectedSlot == slotIndex then
		InventoryState.selectedSlot = nil
		updateSlotSelection()
	else
		InventoryState.selectedSlot = slotIndex
		updateSlotSelection()
		
		-- Show item actions menu
		showItemActionsMenu(slotIndex, itemData)
	end
end

-- Show item actions menu
local function showItemActionsMenu(slotIndex: number, itemData: {itemId: string, quantity: number})
	-- Simple context menu for now
	local item = Items.GetItem(itemData.itemId)
	if not item then return end
	
	-- Check if item is usable
	if Items.HasTag(itemData.itemId, "medical") or Items.HasTag(itemData.itemId, "enhancement") then
		-- Use item
		NetEvents.SendToServer("ItemUse", {
			itemId = itemData.itemId,
			slot = slotIndex
		})
	elseif Items.HasTag(itemData.itemId, "weapon") then
		-- Equip weapon
		local CombatController = require(script.Parent.Combat)
		CombatController.EquipWeapon(itemData.itemId)
	end
end

-- Update slot selection visual
local function updateSlotSelection()
	for i, slot in pairs(itemSlots) do
		if i == InventoryState.selectedSlot then
			slot.BorderColor3 = Color3.fromRGB(255, 255, 100)
			slot.BorderSizePixel = 3
		else
			slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
			slot.BorderSizePixel = 1
		end
	end
end

-- Show item tooltip
local function showItemTooltip(slotIndex: number)
	local itemData = InventoryState.items[slotIndex]
	if not itemData or not itemTooltip then return end
	
	local item = Items.GetItem(itemData.itemId)
	if not item then return end
	
	-- Update tooltip content
	itemTooltip.ItemName.Text = item.name
	itemTooltip.ItemName.TextColor3 = Items.GetTierColor(item.tier)
	itemTooltip.ItemDescription.Text = item.description or "No description available."
	
	-- Position tooltip near mouse
	local mouse = player:GetMouse()
	itemTooltip.Position = UDim2.new(0, mouse.X + 10, 0, mouse.Y - 50)
	itemTooltip.Visible = true
end

-- Hide item tooltip
local function hideItemTooltip()
	if itemTooltip then
		itemTooltip.Visible = false
	end
end

-- Update inventory display
local function updateInventoryDisplay()
	-- Update weight bar
	local weightPercent = InventoryState.currentWeight / InventoryState.maxWeight
	
	local tween = TweenService:Create(weightBar,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(weightPercent, 0, 1, 0)}
	)
	tween:Play()
	
	-- Update weight label
	weightLabel.Text = math.floor(InventoryState.currentWeight) .. "/" .. InventoryState.maxWeight .. " KG"
	
	-- Change weight bar color based on capacity
	if weightPercent > 0.9 then
		weightBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- Red - overloaded
	elseif weightPercent > 0.7 then
		weightBar.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Orange - heavy
	else
		weightBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green - normal
	end
	
	-- Update item slots
	for i = 1, MAX_SLOTS do
		local slot = itemSlots[i]
		local itemData = InventoryState.items[i]
		
		if itemData then
			local item = Items.GetItem(itemData.itemId)
			if item then
				-- Show item
				slot.ItemIcon.Image = "rbxasset://textures/face.png" -- Placeholder icon
				slot.ItemIcon.ImageColor3 = Items.GetTierColor(item.tier)
				slot.QuantityLabel.Text = itemData.quantity > 1 and tostring(itemData.quantity) or ""
				slot.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			end
		else
			-- Empty slot
			slot.ItemIcon.Image = ""
			slot.QuantityLabel.Text = ""
			slot.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		end
	end
	
	-- Update quick slots
	for i = 1, 5 do
		local quickSlot = quickSlotFrames[i]
		local quickItemData = InventoryState.quickSlots[i]
		
		if quickItemData and InventoryState.items[quickItemData.slotIndex] then
			local item = Items.GetItem(quickItemData.itemId)
			if item then
				quickSlot.ItemIcon.Image = "rbxasset://textures/face.png" -- Placeholder icon
				quickSlot.ItemIcon.ImageColor3 = Items.GetTierColor(item.tier)
			end
		else
			quickSlot.ItemIcon.Image = ""
		end
	end
end

-- Calculate total inventory weight
local function calculateTotalWeight(): number
	local totalWeight = 0
	
	for _, itemData in pairs(InventoryState.items) do
		local weight = Items.GetItemWeight(itemData.itemId, itemData.quantity)
		totalWeight = totalWeight + weight
	end
	
	return totalWeight
end

-- Add item to inventory
function InventoryController.AddItem(itemId: string, quantity: number): boolean
	local item = Items.GetItem(itemId)
	if not item then return false end
	
	local itemWeight = Items.GetItemWeight(itemId, quantity)
	
	-- Check weight limit
	if InventoryState.currentWeight + itemWeight > InventoryState.maxWeight then
		return false -- Inventory full
	end
	
	-- Try to stack with existing items
	if Items.IsStackable(itemId) then
		for slotIndex, itemData in pairs(InventoryState.items) do
			if itemData.itemId == itemId then
				local maxStack = Items.GetMaxStack(itemId)
				local canAdd = math.min(quantity, maxStack - itemData.quantity)
				
				if canAdd > 0 then
					itemData.quantity = itemData.quantity + canAdd
					quantity = quantity - canAdd
					
					if quantity <= 0 then
						break
					end
				end
			end
		end
	end
	
	-- Add remaining quantity to empty slots
	if quantity > 0 then
		for i = 1, MAX_SLOTS do
			if not InventoryState.items[i] then
				InventoryState.items[i] = {
					itemId = itemId,
					quantity = quantity
				}
				break
			end
		end
	end
	
	-- Update weight and display
	InventoryState.currentWeight = calculateTotalWeight()
	updateInventoryDisplay()
	
	-- Send weight update to HUD
	Signals.Get("InventoryChanged"):Fire(InventoryState.currentWeight, InventoryState.maxWeight)
	
	return true
end

-- Remove item from inventory
function InventoryController.RemoveItem(itemId: string, quantity: number): boolean
	local remainingToRemove = quantity
	
	for slotIndex, itemData in pairs(InventoryState.items) do
		if itemData.itemId == itemId and remainingToRemove > 0 then
			local removeFromSlot = math.min(remainingToRemove, itemData.quantity)
			itemData.quantity = itemData.quantity - removeFromSlot
			remainingToRemove = remainingToRemove - removeFromSlot
			
			if itemData.quantity <= 0 then
				InventoryState.items[slotIndex] = nil
			end
		end
	end
	
	-- Update weight and display
	InventoryState.currentWeight = calculateTotalWeight()
	updateInventoryDisplay()
	
	-- Send weight update to HUD
	Signals.Get("InventoryChanged"):Fire(InventoryState.currentWeight, InventoryState.maxWeight)
	
	return remainingToRemove == 0
end

-- Open inventory
function InventoryController.OpenInventory()
	if InventoryState.isOpen then return end
	
	InventoryState.isOpen = true
	inventoryFrame.Visible = true
	
	-- Animate opening
	inventoryFrame.Size = UDim2.new(0, 0, 0, 0)
	local openTween = TweenService:Create(inventoryFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = UDim2.new(0, 520, 0, 400)}
	)
	openTween:Play()
	
	updateInventoryDisplay()
	Signals.Get("InventoryOpened"):Fire()
end

-- Close inventory
function InventoryController.CloseInventory()
	if not InventoryState.isOpen then return end
	
	InventoryState.isOpen = false
	InventoryState.selectedSlot = nil
	
	-- Animate closing
	local closeTween = TweenService:Create(inventoryFrame,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Size = UDim2.new(0, 0, 0, 0)}
	)
	closeTween:Play()
	
	closeTween.Completed:Connect(function()
		inventoryFrame.Visible = false
	end)
	
	hideItemTooltip()
	Signals.Get("InventoryClosed"):Fire()
end

-- Toggle inventory
function InventoryController.ToggleInventory()
	if InventoryState.isOpen then
		InventoryController.CloseInventory()
	else
		InventoryController.OpenInventory()
	end
end

-- Get inventory state
function InventoryController.GetCurrentWeight(): number
	return InventoryState.currentWeight
end

function InventoryController.GetMaxWeight(): number
	return InventoryState.maxWeight
end

function InventoryController.GetItems(): {[number]: {itemId: string, quantity: number}}
	return InventoryState.items
end

function InventoryController.IsOpen(): boolean
	return InventoryState.isOpen
end

-- Connect to signals
local function connectSignals()
	Signals.Get("InventoryToggle"):Connect(function(open)
		if open then
			InventoryController.OpenInventory()
		else
			InventoryController.CloseInventory()
		end
	end)
	
	Signals.Get("QuickSlotPressed"):Connect(function(slotNumber)
		local quickSlot = InventoryState.quickSlots[slotNumber]
		if quickSlot and InventoryState.items[quickSlot.slotIndex] then
			handleSlotClick(quickSlot.slotIndex)
		end
	end)
end

-- Initialize inventory controller
function InventoryController.Initialize()
	createInventoryUI()
	createItemTooltip()
	createQuickSlotsUI()
	connectSignals()
	
	-- Initial display update
	updateInventoryDisplay()
	
	print("Inventory Controller initialized")
end

-- Initialize on script load
InventoryController.Initialize()

return InventoryController