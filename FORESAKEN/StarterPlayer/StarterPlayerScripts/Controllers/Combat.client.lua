--[[
	FORESAKEN Combat Controller (Client)
	Handles client-side combat mechanics and weapon interaction
	
	Features:
	- Weapon firing input
	- Recoil and spread simulation
	- Visual effects
	- Sound effects
	- Weapon switching
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

-- Get shared modules
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Items = require(ReplicatedStorage.Shared.Modules.Items)
local Signals = require(ReplicatedStorage.Shared.Modules.Signals)
local NetEvents = require(ReplicatedStorage.Shared.Modules.Net.Events)
local MathUtil = require(ReplicatedStorage.Shared.Modules.Util.Math)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Combat Controller
local CombatController = {}

-- Combat state
local CombatState = {
	currentWeapon = nil,
	currentAmmo = 0,
	maxAmmo = 0,
	isReloading = false,
	isFiring = false,
	isAiming = false,
	lastFireTime = 0,
	recoilOffset = Vector2.new(0, 0),
	weaponEquipped = false,
	
	-- Weapon stats (loaded from config)
	damage = 0,
	rpm = 0,
	spread = 0,
	range = 0,
	reloadTime = 0
}

-- Visual effects
local muzzleFlash = nil
local bulletTracer = nil

-- Initialize networking
NetEvents.Initialize()

-- Create muzzle flash effect
local function createMuzzleFlash(): BasePart
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Size = Vector3.new(2, 2, 0.1)
	flash.Material = Enum.Material.Neon
	flash.BrickColor = BrickColor.new("Bright orange")
	flash.CanCollide = false
	flash.Anchored = true
	flash.Transparency = 0.3
	
	-- Add particle effect
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/fire_main.dds"
	particles.EmissionDirection = Enum.NormalId.Front
	particles.Rate = 500
	particles.Lifetime = NumberRange.new(0.1, 0.3)
	particles.Speed = NumberRange.new(10, 20)
	particles.Parent = flash
	
	return flash
end

-- Create bullet tracer
local function createBulletTracer(startPos: Vector3, endPos: Vector3)
	local tracer = Instance.new("Part")
	tracer.Name = "BulletTracer"
	tracer.Size = Vector3.new(0.1, 0.1, (endPos - startPos).Magnitude)
	tracer.Material = Enum.Material.Neon
	tracer.BrickColor = BrickColor.new("Bright yellow")
	tracer.CanCollide = false
	tracer.Anchored = true
	tracer.Transparency = 0.5
	
	-- Position between start and end
	tracer.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -tracer.Size.Z/2)
	tracer.Parent = workspace
	
	-- Fade out animation
	local tween = TweenService:Create(tracer,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 1}
	)
	tween:Play()
	
	tween.Completed:Connect(function()
		tracer:Destroy()
	end)
end

-- Apply weapon recoil
local function applyRecoil(weaponId: string)
	local weaponConfig = Config.Weapons[weaponId]
	if not weaponConfig then return end
	
	-- Calculate recoil based on weapon spread
	local recoilAmount = weaponConfig.spread * 0.5
	local recoilX = (math.random() - 0.5) * recoilAmount
	local recoilY = math.random() * recoilAmount * 0.5 -- Mostly upward recoil
	
	CombatState.recoilOffset = CombatState.recoilOffset + Vector2.new(recoilX, recoilY)
	
	-- Apply recoil to camera (if camera controller exists)
	Signals.Get("ApplyRecoil"):Fire(recoilX, recoilY)
	
	-- Gradually reduce recoil
	task.spawn(function()
		task.wait(0.1)
		local reduction = Vector2.new(recoilX, recoilY) * 0.8
		CombatState.recoilOffset = CombatState.recoilOffset - reduction
		
		if CombatState.recoilOffset.Magnitude < 0.1 then
			CombatState.recoilOffset = Vector2.new(0, 0)
		end
	end)
end

-- Calculate spread for weapon accuracy
local function calculateSpread(weaponId: string): Vector3
	local weaponConfig = Config.Weapons[weaponId]
	if not weaponConfig then return Vector3.new(0, 0, -1) end
	
	local spread = weaponConfig.spread
	
	-- Increase spread when not aiming
	if not CombatState.isAiming then
		spread = spread * 1.5
	end
	
	-- Add recoil to spread
	spread = spread + CombatState.recoilOffset.Magnitude
	
	-- Calculate random spread direction
	local spreadAngle = math.rad(spread)
	local randomX = (math.random() - 0.5) * spreadAngle
	local randomY = (math.random() - 0.5) * spreadAngle
	
	-- Get camera direction and apply spread
	local cameraDirection = camera.CFrame.LookVector
	local rightVector = camera.CFrame.RightVector
	local upVector = camera.CFrame.UpVector
	
	local spreadDirection = cameraDirection + 
		(rightVector * randomX) + 
		(upVector * randomY)
	
	return spreadDirection.Unit
end

-- Play weapon sound
local function playWeaponSound(weaponId: string, soundType: string)
	local soundId = ""
	
	-- Map weapon and sound type to sound IDs
	if weaponId == "Pistol" then
		if soundType == "fire" then
			soundId = "rbxasset://sounds/electronicpingshoot.wav"
		elseif soundType == "reload" then
			soundId = "rbxasset://sounds/switch.wav"
		end
	elseif weaponId == "SMG" then
		if soundType == "fire" then
			soundId = "rbxasset://sounds/electronicpingshoot.wav"
		end
	elseif weaponId == "BRifle" then
		if soundType == "fire" then
			soundId = "rbxasset://sounds/snap.wav"
		end
	end
	
	if soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.5
		sound.Parent = workspace
		sound:Play()
		
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

-- Fire weapon
local function fireWeapon()
	if not CombatState.weaponEquipped or not CombatState.currentWeapon then return end
	if CombatState.isReloading or CombatState.currentAmmo <= 0 then return end
	
	local weaponConfig = Config.Weapons[CombatState.currentWeapon]
	if not weaponConfig then return end
	
	local currentTime = tick()
	local minInterval = 60 / weaponConfig.rpm
	
	-- Check fire rate
	if currentTime - CombatState.lastFireTime < minInterval then return end
	
	CombatState.lastFireTime = currentTime
	
	-- Get firing direction with spread
	local fireDirection = calculateSpread(CombatState.currentWeapon)
	
	-- Get firing origin
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local fireOrigin = humanoidRootPart.Position + Vector3.new(0, 1.5, 0)
	
	-- Create muzzle flash
	if muzzleFlash then
		muzzleFlash.CFrame = CFrame.lookAt(fireOrigin, fireOrigin + fireDirection)
		muzzleFlash.Transparency = 0.3
		muzzleFlash.Parent = workspace
		
		-- Fade out muzzle flash
		local flashTween = TweenService:Create(muzzleFlash,
			TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Transparency = 1}
		)
		flashTween:Play()
		
		flashTween.Completed:Connect(function()
			muzzleFlash.Parent = nil
		end)
	end
	
	-- Send fire event to server
	NetEvents.SendToServer("WeaponFire", {
		weaponId = CombatState.currentWeapon,
		direction = fireDirection,
		origin = fireOrigin
	})
	
	-- Apply visual effects
	applyRecoil(CombatState.currentWeapon)
	playWeaponSound(CombatState.currentWeapon, "fire")
	
	-- Update ammo (optimistic update)
	CombatState.currentAmmo = math.max(0, CombatState.currentAmmo - 1)
	Signals.Get("AmmoChanged"):Fire(CombatState.currentAmmo, CombatState.maxAmmo)
end

-- Reload weapon
local function reloadWeapon()
	if not CombatState.weaponEquipped or not CombatState.currentWeapon then return end
	if CombatState.isReloading or CombatState.currentAmmo >= CombatState.maxAmmo then return end
	
	local weaponConfig = Config.Weapons[CombatState.currentWeapon]
	if not weaponConfig then return end
	
	CombatState.isReloading = true
	
	-- Play reload sound
	playWeaponSound(CombatState.currentWeapon, "reload")
	
	-- Show reload notification
	Signals.Get("ShowNotification"):Fire("Reloading...", weaponConfig.reloadTime, "info")
	
	-- Wait for reload time
	task.wait(weaponConfig.reloadTime)
	
	-- Restore ammo
	CombatState.currentAmmo = CombatState.maxAmmo
	CombatState.isReloading = false
	
	-- Update HUD
	Signals.Get("AmmoChanged"):Fire(CombatState.currentAmmo, CombatState.maxAmmo)
	Signals.Get("ShowNotification"):Fire("Reload Complete", 1, "success")
end

-- Equip weapon
function CombatController.EquipWeapon(weaponId: string)
	local weaponConfig = Config.Weapons[weaponId]
	if not weaponConfig then
		warn("Invalid weapon ID:", weaponId)
		return
	end
	
	CombatState.currentWeapon = weaponId
	CombatState.damage = weaponConfig.dmg
	CombatState.rpm = weaponConfig.rpm
	CombatState.spread = weaponConfig.spread
	CombatState.range = weaponConfig.range
	CombatState.reloadTime = weaponConfig.reloadTime
	CombatState.maxAmmo = 30 -- Default, should come from weapon data
	CombatState.currentAmmo = CombatState.maxAmmo
	CombatState.weaponEquipped = true
	
	-- Update HUD
	Signals.Get("WeaponChanged"):Fire(weaponId, CombatState.currentAmmo, CombatState.maxAmmo)
	
	print("Equipped weapon:", weaponId)
end

-- Unequip weapon
function CombatController.UnequipWeapon()
	CombatState.currentWeapon = nil
	CombatState.weaponEquipped = false
	CombatState.currentAmmo = 0
	CombatState.maxAmmo = 0
	
	Signals.Get("WeaponChanged"):Fire(nil, 0, 0)
	
	print("Weapon unequipped")
end

-- Get current weapon info
function CombatController.GetCurrentWeapon(): string?
	return CombatState.currentWeapon
end

function CombatController.GetCurrentAmmo(): number
	return CombatState.currentAmmo
end

function CombatController.GetMaxAmmo(): number
	return CombatState.maxAmmo
end

function CombatController.IsReloading(): boolean
	return CombatState.isReloading
end

-- Continuous firing for automatic weapons
local function handleContinuousFiring()
	if CombatState.isFiring and CombatState.weaponEquipped then
		local weaponConfig = Config.Weapons[CombatState.currentWeapon]
		if weaponConfig and weaponConfig.fireMode == "Auto" then
			fireWeapon()
		end
	end
end

-- Connect to input signals
local function connectInputSignals()
	Signals.Get("WeaponFire"):Connect(function()
		if CombatState.weaponEquipped then
			local weaponConfig = Config.Weapons[CombatState.currentWeapon]
			if weaponConfig then
				if weaponConfig.fireMode == "Semi" then
					fireWeapon()
				else
					CombatState.isFiring = true
				end
			end
		end
	end)
	
	Signals.Get("WeaponReload"):Connect(function()
		task.spawn(reloadWeapon)
	end)
	
	Signals.Get("AimToggle"):Connect(function(isAiming)
		CombatState.isAiming = isAiming
	end)
	
	-- Handle fire release for automatic weapons
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			CombatState.isFiring = false
		end
	end)
end

-- Connect to network events
local function connectNetworkEvents()
	NetEvents.OnClientEvent("WeaponFired", function(data)
		-- Show visual effects for other players' weapon fires
		if data.player ~= player.Name and data.hit then
			createBulletTracer(data.origin, data.hit)
		end
	end)
	
	NetEvents.OnClientEvent("PlayerDamaged", function(data)
		if data.type == "death" then
			-- Show kill feed
			Signals.Get("PlayerKilled"):Fire(data.killer, data.victim, data.weapon)
		end
	end)
end

-- Initialize combat controller
function CombatController.Initialize()
	-- Create visual effects
	muzzleFlash = createMuzzleFlash()
	
	-- Connect input signals
	connectInputSignals()
	
	-- Connect network events
	connectNetworkEvents()
	
	-- Start continuous firing loop for automatic weapons
	RunService.Heartbeat:Connect(handleContinuousFiring)
	
	print("Combat Controller initialized")
end

-- Cleanup
function CombatController.Destroy()
	CombatState.isFiring = false
	CombatState.weaponEquipped = false
	
	if muzzleFlash then
		muzzleFlash:Destroy()
	end
end

-- Initialize on script load
CombatController.Initialize()

return CombatController