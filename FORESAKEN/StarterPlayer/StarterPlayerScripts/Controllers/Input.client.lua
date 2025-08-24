--[[
	FORESAKEN Input Controller
	Handles all player input processing and key bindings
	
	Features:
	- Movement input
	- Combat input (shooting, aiming, reloading)
	- Interaction input
	- UI input
	- Mobile touch controls (future)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Input Controller
local InputController = {}

-- Input state tracking
local InputState = {
	Movement = {
		Forward = false,
		Backward = false,
		Left = false,
		Right = false,
		Jump = false,
		Sprint = false,
		Crouch = false
	},
	Combat = {
		Firing = false,
		Aiming = false,
		Reloading = false
	},
	UI = {
		InventoryOpen = false,
		MenuOpen = false
	},
	Interaction = {
		Interacting = false
	}
}

-- Key bindings
local KeyBindings = {
	-- Movement
	[Enum.KeyCode.W] = "MoveForward",
	[Enum.KeyCode.S] = "MoveBackward", 
	[Enum.KeyCode.A] = "MoveLeft",
	[Enum.KeyCode.D] = "MoveRight",
	[Enum.KeyCode.Space] = "Jump",
	[Enum.KeyCode.LeftShift] = "Sprint",
	[Enum.KeyCode.LeftControl] = "Crouch",
	
	-- Combat
	[Enum.KeyCode.R] = "Reload",
	[Enum.KeyCode.Q] = "Melee",
	
	-- Interaction
	[Enum.KeyCode.E] = "Interact",
	[Enum.KeyCode.F] = "Extract",
	
	-- UI
	[Enum.KeyCode.Tab] = "Inventory",
	[Enum.KeyCode.Escape] = "Menu",
	[Enum.KeyCode.M] = "Map",
	
	-- Quick slots
	[Enum.KeyCode.One] = "Slot1",
	[Enum.KeyCode.Two] = "Slot2", 
	[Enum.KeyCode.Three] = "Slot3",
	[Enum.KeyCode.Four] = "Slot4",
	[Enum.KeyCode.Five] = "Slot5"
}

-- Mouse bindings
local MouseBindings = {
	[Enum.UserInputType.MouseButton1] = "Fire",
	[Enum.UserInputType.MouseButton2] = "Aim"
}

-- Movement vector calculation
local function calculateMovementVector(): Vector3
	local moveVector = Vector3.new(0, 0, 0)
	
	if InputState.Movement.Forward then
		moveVector = moveVector + Vector3.new(0, 0, -1)
	end
	if InputState.Movement.Backward then
		moveVector = moveVector + Vector3.new(0, 0, 1)
	end
	if InputState.Movement.Left then
		moveVector = moveVector + Vector3.new(-1, 0, 0)
	end
	if InputState.Movement.Right then
		moveVector = moveVector + Vector3.new(1, 0, 0)
	end
	
	return moveVector.Unit
end

-- Input processing functions
local function processMovementInput(action: string, state: boolean)
	if action == "MoveForward" then
		InputState.Movement.Forward = state
	elseif action == "MoveBackward" then
		InputState.Movement.Backward = state
	elseif action == "MoveLeft" then
		InputState.Movement.Left = state
	elseif action == "MoveRight" then
		InputState.Movement.Right = state
	elseif action == "Jump" then
		InputState.Movement.Jump = state
	elseif action == "Sprint" then
		InputState.Movement.Sprint = state
	elseif action == "Crouch" then
		InputState.Movement.Crouch = state
	end
	
	-- Update movement vector
	local moveVector = calculateMovementVector()
	Signals.Get("MovementInput"):Fire(moveVector, InputState.Movement)
end

local function processCombatInput(action: string, state: boolean)
	if action == "Fire" then
		InputState.Combat.Firing = state
		if state then
			Signals.Get("WeaponFire"):Fire()
		end
	elseif action == "Aim" then
		InputState.Combat.Aiming = state
		Signals.Get("AimToggle"):Fire(state)
	elseif action == "Reload" and state then
		InputState.Combat.Reloading = true
		Signals.Get("WeaponReload"):Fire()
		task.wait(0.1)
		InputState.Combat.Reloading = false
	elseif action == "Melee" and state then
		Signals.Get("MeleeAttack"):Fire()
	end
end

local function processInteractionInput(action: string, state: boolean)
	if action == "Interact" and state then
		Signals.Get("InteractPressed"):Fire()
	elseif action == "Extract" and state then
		Signals.Get("ExtractPressed"):Fire()
	end
end

local function processUIInput(action: string, state: boolean)
	if action == "Inventory" and state then
		InputState.UI.InventoryOpen = not InputState.UI.InventoryOpen
		Signals.Get("InventoryToggle"):Fire(InputState.UI.InventoryOpen)
	elseif action == "Menu" and state then
		InputState.UI.MenuOpen = not InputState.UI.MenuOpen
		Signals.Get("MenuToggle"):Fire(InputState.UI.MenuOpen)
	elseif action == "Map" and state then
		Signals.Get("MapToggle"):Fire()
	end
end

local function processQuickSlotInput(action: string, state: boolean)
	if state then
		local slotNumber = tonumber(action:sub(-1)) -- Extract number from "Slot1", "Slot2", etc.
		if slotNumber then
			Signals.Get("QuickSlotPressed"):Fire(slotNumber)
		end
	end
end

-- Input event handlers
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	
	local action = KeyBindings[input.KeyCode] or MouseBindings[input.UserInputType]
	if not action then return end
	
	-- Route to appropriate processor
	if action:match("Move") or action == "Jump" or action == "Sprint" or action == "Crouch" then
		processMovementInput(action, true)
	elseif action == "Fire" or action == "Aim" or action == "Reload" or action == "Melee" then
		processCombatInput(action, true)
	elseif action == "Interact" or action == "Extract" then
		processInteractionInput(action, true)
	elseif action == "Inventory" or action == "Menu" or action == "Map" then
		processUIInput(action, true)
	elseif action:match("Slot") then
		processQuickSlotInput(action, true)
	end
end

local function onInputEnded(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	
	local action = KeyBindings[input.KeyCode] or MouseBindings[input.UserInputType]
	if not action then return end
	
	-- Route to appropriate processor
	if action:match("Move") or action == "Jump" or action == "Sprint" or action == "Crouch" then
		processMovementInput(action, false)
	elseif action == "Fire" or action == "Aim" then
		processCombatInput(action, false)
	end
end

-- Mouse movement for camera/aiming
local function onMouseMoved()
	if InputState.Combat.Aiming then
		local mousePos = UserInputService:GetMouseLocation()
		Signals.Get("AimInput"):Fire(mousePos)
	end
	
	-- Send mouse position for general use
	Signals.Get("MouseMoved"):Fire(mouse.Hit.Position, mouse.Target)
end

-- Touch controls for mobile (future implementation)
local function setupTouchControls()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		-- TODO: Implement touch controls for mobile
		print("Mobile touch controls not yet implemented")
	end
end

-- Context actions for special inputs
local function setupContextActions()
	-- Extract action (hold F)
	ContextActionService:BindAction("Extract", function(actionName, inputState, inputObj)
		if inputState == Enum.UserInputState.Begin then
			Signals.Get("ExtractStart"):Fire()
		elseif inputState == Enum.UserInputState.End then
			Signals.Get("ExtractStop"):Fire()
		end
	end, false, Enum.KeyCode.F)
	
	-- Interaction action (hold E)
	ContextActionService:BindAction("Interact", function(actionName, inputState, inputObj)
		if inputState == Enum.UserInputState.Begin then
			Signals.Get("InteractStart"):Fire()
		elseif inputState == Enum.UserInputState.End then
			Signals.Get("InteractStop"):Fire()
		end
	end, false, Enum.KeyCode.E)
end

-- Public API
function InputController.Initialize()
	-- Connect input events
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	
	-- Connect mouse movement
	mouse.Move:Connect(onMouseMoved)
	
	-- Setup touch controls for mobile
	setupTouchControls()
	
	-- Setup context actions
	setupContextActions()
	
	print("Input Controller initialized")
end

function InputController.GetMovementState()
	return InputState.Movement
end

function InputController.GetCombatState()
	return InputState.Combat
end

function InputController.GetUIState()
	return InputState.UI
end

function InputController.SetKeyBinding(keyCode: Enum.KeyCode, action: string)
	KeyBindings[keyCode] = action
end

function InputController.GetKeyBinding(keyCode: Enum.KeyCode): string?
	return KeyBindings[keyCode]
end

function InputController.IsActionPressed(action: string): boolean
	-- Check if any key bound to this action is currently pressed
	for keyCode, boundAction in pairs(KeyBindings) do
		if boundAction == action and UserInputService:IsKeyDown(keyCode) then
			return true
		end
	end
	
	for inputType, boundAction in pairs(MouseBindings) do
		if boundAction == action and UserInputService:IsMouseButtonPressed(inputType) then
			return true
		end
	end
	
	return false
end

-- Input state utilities
function InputController.IsMoving(): boolean
	local movement = InputState.Movement
	return movement.Forward or movement.Backward or movement.Left or movement.Right
end

function InputController.IsSprinting(): boolean
	return InputState.Movement.Sprint and InputController.IsMoving()
end

function InputController.IsCrouching(): boolean
	return InputState.Movement.Crouch
end

function InputController.IsAiming(): boolean
	return InputState.Combat.Aiming
end

function InputController.IsFiring(): boolean
	return InputState.Combat.Firing
end

-- Camera utilities
function InputController.GetMouseWorldPosition(): Vector3
	return mouse.Hit.Position
end

function InputController.GetMouseTarget(): BasePart?
	return mouse.Target
end

function InputController.GetMouseRay(): Ray
	local unitRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
	return Ray.new(unitRay.Origin, unitRay.Direction * 1000)
end

-- Cleanup
function InputController.Destroy()
	UserInputService.InputBegan:Disconnect()
	UserInputService.InputEnded:Disconnect()
	ContextActionService:UnbindAllActions()
	
	-- Clear input state
	for category, states in pairs(InputState) do
		for state, _ in pairs(states) do
			states[state] = false
		end
	end
end

-- Initialize on script load
InputController.Initialize()

return InputController