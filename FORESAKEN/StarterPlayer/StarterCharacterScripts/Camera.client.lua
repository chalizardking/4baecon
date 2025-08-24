--[[
	FORESAKEN Camera Controller
	Handles camera movement, zoom, and view modes
	
	Features:
	- Third-person default view
	- First-person aiming mode
	- Smooth camera transitions
	- Camera collision detection
	- Mouse look sensitivity
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local MathUtil = require(ReplicatedStorage.Shared.Modules.Util.Math)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- Camera Controller
local CameraController = {}

-- Camera state
local CameraState = {
	viewMode = "ThirdPerson", -- "ThirdPerson" or "FirstPerson"
	isAiming = false,
	mouseSensitivity = 0.2,
	thirdPersonDistance = 8,
	aimZoomDistance = 2,
	currentDistance = 8,
	
	-- Camera angles
	yaw = 0,   -- Horizontal rotation
	pitch = 0, -- Vertical rotation
	
	-- Camera limits
	maxPitch = math.rad(80),  -- 80 degrees up
	minPitch = math.rad(-80), -- 80 degrees down
	
	-- Smooth transition
	targetDistance = 8,
	transitionSpeed = 8,
	
	-- Camera collision
	collisionEnabled = true,
	raycastParams = nil
}

-- Initialize raycast parameters for collision detection
local function initializeRaycast()
	CameraState.raycastParams = RaycastParams.new()
	CameraState.raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	CameraState.raycastParams.FilterDescendantsInstances = {player.Character}
end

-- Calculate camera position with collision detection
local function calculateCameraPosition(character: Model, distance: number): Vector3
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return camera.CFrame.Position
	end
	
	-- Calculate desired camera position
	local headPosition = humanoidRootPart.Position + Vector3.new(0, 2, 0)
	local yawCFrame = CFrame.Angles(0, CameraState.yaw, 0)
	local pitchCFrame = CFrame.Angles(CameraState.pitch, 0, 0)
	
	local combinedCFrame = yawCFrame * pitchCFrame
	local offset = combinedCFrame:VectorToWorldSpace(Vector3.new(0, 0, distance))
	local desiredPosition = headPosition + offset
	
	-- Perform collision detection
	if CameraState.collisionEnabled and CameraState.raycastParams then
		local direction = desiredPosition - headPosition
		local raycastResult = workspace:Raycast(headPosition, direction, CameraState.raycastParams)
		
		if raycastResult then
			-- Adjust position to avoid clipping through walls
			local hitDistance = (raycastResult.Position - headPosition).Magnitude
			local safeDistance = math.max(hitDistance - 0.5, 0.5) -- Keep 0.5 studs from wall
			
			local safeDirection = direction.Unit * safeDistance
			return headPosition + safeDirection
		end
	end
	
	return desiredPosition
end

-- Update camera position and orientation
local function updateCamera()
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	-- Update current distance with smooth transition
	CameraState.currentDistance = MathUtil.Approach(
		CameraState.currentDistance, 
		CameraState.targetDistance, 
		CameraState.transitionSpeed * RunService.Heartbeat:Wait()
	)
	
	-- Calculate camera position
	local cameraPosition = calculateCameraPosition(character, CameraState.currentDistance)
	local lookAtPosition = humanoidRootPart.Position + Vector3.new(0, 2, 0)
	
	-- Set camera CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
end

-- Handle mouse movement for camera rotation
local function onMouseMoved()
	local mouseDelta = UserInputService:GetMouseDelta()
	
	-- Apply mouse sensitivity
	local deltaX = mouseDelta.X * CameraState.mouseSensitivity * 0.01
	local deltaY = mouseDelta.Y * CameraState.mouseSensitivity * 0.01
	
	-- Update camera angles
	CameraState.yaw = CameraState.yaw - deltaX
	CameraState.pitch = MathUtil.Clamp(
		CameraState.pitch - deltaY, 
		CameraState.minPitch, 
		CameraState.maxPitch
	)
	
	-- Normalize yaw to prevent overflow
	CameraState.yaw = MathUtil.NormalizeAngle(CameraState.yaw)
end

-- Switch to first-person view
function CameraController.EnterFirstPerson()
	CameraState.viewMode = "FirstPerson"
	CameraState.targetDistance = 0.5
	
	-- Hide character parts in first-person
	local character = player.Character
	if character then
		for _, part in pairs(character:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.LocalTransparencyModifier = 1
			end
		end
	end
	
	Signals.Get("CameraModeChanged"):Fire("FirstPerson")
end

-- Switch to third-person view
function CameraController.EnterThirdPerson()
	CameraState.viewMode = "ThirdPerson"
	CameraState.targetDistance = CameraState.thirdPersonDistance
	
	-- Show character parts in third-person
	local character = player.Character
	if character then
		for _, part in pairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
	end
	
	Signals.Get("CameraModeChanged"):Fire("ThirdPerson")
end

-- Enter aiming mode
function CameraController.StartAiming()
	CameraState.isAiming = true
	
	if CameraState.viewMode == "ThirdPerson" then
		CameraState.targetDistance = CameraState.aimZoomDistance
	else
		-- Already in first-person, maybe add scope overlay or zoom
		CameraState.targetDistance = 0.3
	end
	
	-- Reduce mouse sensitivity while aiming
	CameraState.mouseSensitivity = 0.1
	
	Signals.Get("AimStarted"):Fire()
end

-- Exit aiming mode
function CameraController.StopAiming()
	CameraState.isAiming = false
	
	if CameraState.viewMode == "ThirdPerson" then
		CameraState.targetDistance = CameraState.thirdPersonDistance
	else
		CameraState.targetDistance = 0.5
	end
	
	-- Restore normal mouse sensitivity
	CameraState.mouseSensitivity = 0.2
	
	Signals.Get("AimStopped"):Fire()
end

-- Set camera distance
function CameraController.SetDistance(distance: number)
	CameraState.thirdPersonDistance = MathUtil.Clamp(distance, 2, 20)
	if CameraState.viewMode == "ThirdPerson" and not CameraState.isAiming then
		CameraState.targetDistance = CameraState.thirdPersonDistance
	end
end

-- Set mouse sensitivity
function CameraController.SetSensitivity(sensitivity: number)
	CameraState.mouseSensitivity = MathUtil.Clamp(sensitivity, 0.05, 1.0)
end

-- Get camera direction (for weapon firing)
function CameraController.GetCameraDirection(): Vector3
	return camera.CFrame.LookVector
end

-- Get camera position
function CameraController.GetCameraPosition(): Vector3
	return camera.CFrame.Position
end

-- Get camera CFrame
function CameraController.GetCameraCFrame(): CFrame
	return camera.CFrame
end

-- Screen to world ray (for mouse interaction)
function CameraController.ScreenToWorldRay(screenPosition: Vector2): Ray
	local unitRay = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	return Ray.new(unitRay.Origin, unitRay.Direction * 1000)
end

-- World to screen point
function CameraController.WorldToScreenPoint(worldPosition: Vector3): Vector2
	local screenPosition, onScreen = camera:WorldToScreenPoint(worldPosition)
	return Vector2.new(screenPosition.X, screenPosition.Y), onScreen
end

-- Camera shake effect
function CameraController.Shake(intensity: number, duration: number)
	local originalCFrame = camera.CFrame
	local startTime = tick()
	
	local shakeConnection
	shakeConnection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration then
			shakeConnection:Disconnect()
			return
		end
		
		local progress = elapsed / duration
		local currentIntensity = intensity * (1 - progress) -- Fade out over time
		
		local randomOffset = Vector3.new(
			(math.random() - 0.5) * currentIntensity,
			(math.random() - 0.5) * currentIntensity,
			(math.random() - 0.5) * currentIntensity
		)
		
		local shakeCFrame = originalCFrame + randomOffset
		camera.CFrame = shakeCFrame
	end)
end

-- Camera effects
function CameraController.ZoomTo(targetDistance: number, duration: number?)
	local tweenInfo = TweenInfo.new(
		duration or 0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	local tween = TweenService:Create(CameraState, tweenInfo, {
		currentDistance = targetDistance
	})
	
	tween:Play()
	return tween
end

-- Handle character spawning
local function onCharacterAdded(character: Model)
	-- Wait for character to be fully loaded
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	
	-- Reset camera state
	CameraState.yaw = 0
	CameraState.pitch = 0
	CameraState.currentDistance = CameraState.thirdPersonDistance
	CameraState.targetDistance = CameraState.thirdPersonDistance
	
	-- Initialize raycast parameters
	initializeRaycast()
	
	-- Set initial camera position
	task.wait(0.1) -- Small delay to ensure character is positioned
	updateCamera()
end

-- Handle character removal
local function onCharacterRemoving()
	-- Reset to default camera
	camera.CameraType = Enum.CameraType.Custom
end

-- Settings management
function CameraController.GetSettings(): {[string]: any}
	return {
		mouseSensitivity = CameraState.mouseSensitivity,
		thirdPersonDistance = CameraState.thirdPersonDistance,
		viewMode = CameraState.viewMode
	}
end

function CameraController.ApplySettings(settings: {[string]: any})
	if settings.mouseSensitivity then
		CameraController.SetSensitivity(settings.mouseSensitivity)
	end
	if settings.thirdPersonDistance then
		CameraController.SetDistance(settings.thirdPersonDistance)
	end
	if settings.viewMode then
		if settings.viewMode == "FirstPerson" then
			CameraController.EnterFirstPerson()
		else
			CameraController.EnterThirdPerson()
		end
	end
end

-- Public API
function CameraController.Initialize()
	-- Connect to input signals
	Signals.Get("AimToggle"):Connect(function(isAiming)
		if isAiming then
			CameraController.StartAiming()
		else
			CameraController.StopAiming()
		end
	end)
	
	-- Connect to character events
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
	
	-- Connect mouse movement
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			onMouseMoved()
		end
	end)
	
	-- Start camera update loop
	RunService.Heartbeat:Connect(updateCamera)
	
	-- Lock mouse to center (for camera control)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	
	print("Camera Controller initialized")
end

function CameraController.Destroy()
	-- Reset camera
	camera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	
	-- Disconnect all connections would go here if we tracked them
	-- For now, the RunService connections will clean up when the script is destroyed
end

return CameraController