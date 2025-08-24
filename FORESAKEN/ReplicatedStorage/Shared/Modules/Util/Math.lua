--[[
	FORESAKEN Math Utilities Module
	Common mathematical functions and calculations for game systems
	
	Usage:
	local MathUtil = require(ReplicatedStorage.Shared.Modules.Util.Math)
	local distance = MathUtil.Distance3D(pos1, pos2)
]]

local MathUtil = {}

-- Constants
MathUtil.PI = math.pi
MathUtil.TAU = math.pi * 2
MathUtil.SQRT2 = math.sqrt(2)
MathUtil.EPSILON = 1e-10

-- Basic math functions
function MathUtil.Clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

function MathUtil.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function MathUtil.InverseLerp(a: number, b: number, value: number): number
	if math.abs(b - a) < MathUtil.EPSILON then
		return 0
	end
	return (value - a) / (b - a)
end

function MathUtil.Map(value: number, fromMin: number, fromMax: number, toMin: number, toMax: number): number
	local t = MathUtil.InverseLerp(fromMin, fromMax, value)
	return MathUtil.Lerp(toMin, toMax, t)
end

function MathUtil.Round(value: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(value * mult + 0.5) / mult
end

function MathUtil.Sign(value: number): number
	if value > 0 then return 1 end
	if value < 0 then return -1 end
	return 0
end

function MathUtil.Approach(current: number, target: number, increment: number): number
	local difference = target - current
	if math.abs(difference) <= increment then
		return target
	end
	return current + MathUtil.Sign(difference) * increment
end

-- Angle functions
function MathUtil.NormalizeAngle(angle: number): number
	while angle > math.pi do
		angle = angle - MathUtil.TAU
	end
	while angle < -math.pi do
		angle = angle + MathUtil.TAU
	end
	return angle
end

function MathUtil.AngleDifference(a: number, b: number): number
	local diff = b - a
	return MathUtil.NormalizeAngle(diff)
end

function MathUtil.LerpAngle(a: number, b: number, t: number): number
	local diff = MathUtil.AngleDifference(a, b)
	return a + diff * t
end

function MathUtil.DegreesToRadians(degrees: number): number
	return degrees * (math.pi / 180)
end

function MathUtil.RadiansToDegrees(radians: number): number
	return radians * (180 / math.pi)
end

-- Vector3 functions
function MathUtil.Distance3D(pos1: Vector3, pos2: Vector3): number
	return (pos2 - pos1).Magnitude
end

function MathUtil.Distance2D(pos1: Vector3, pos2: Vector3): number
	local diff = pos2 - pos1
	return math.sqrt(diff.X * diff.X + diff.Z * diff.Z)
end

function MathUtil.DistanceSquared3D(pos1: Vector3, pos2: Vector3): number
	local diff = pos2 - pos1
	return diff:Dot(diff)
end

function MathUtil.DistanceSquared2D(pos1: Vector3, pos2: Vector3): number
	local diff = pos2 - pos1
	return diff.X * diff.X + diff.Z * diff.Z
end

function MathUtil.Direction3D(from: Vector3, to: Vector3): Vector3
	return (to - from).Unit
end

function MathUtil.Direction2D(from: Vector3, to: Vector3): Vector3
	local diff = to - from
	local dir2D = Vector3.new(diff.X, 0, diff.Z)
	return dir2D.Unit
end

function MathUtil.ProjectOnPlane(vector: Vector3, planeNormal: Vector3): Vector3
	local dot = vector:Dot(planeNormal)
	return vector - planeNormal * dot
end

function MathUtil.Reflect(vector: Vector3, normal: Vector3): Vector3
	local dot = vector:Dot(normal)
	return vector - 2 * dot * normal
end

-- Random functions
function MathUtil.RandomFloat(min: number, max: number): number
	return min + math.random() * (max - min)
end

function MathUtil.RandomInt(min: number, max: number): number
	return math.random(min, max)
end

function MathUtil.RandomBool(probability: number?): boolean
	local prob = probability or 0.5
	return math.random() < prob
end

function MathUtil.RandomChoice(choices: {any}): any
	if #choices == 0 then return nil end
	return choices[math.random(1, #choices)]
end

function MathUtil.WeightedChoice(choices: {any}, weights: {number}): any
	if #choices == 0 or #choices ~= #weights then return nil end
	
	local totalWeight = 0
	for _, weight in ipairs(weights) do
		totalWeight = totalWeight + weight
	end
	
	if totalWeight <= 0 then return nil end
	
	local random = math.random() * totalWeight
	local currentWeight = 0
	
	for i, weight in ipairs(weights) do
		currentWeight = currentWeight + weight
		if random <= currentWeight then
			return choices[i]
		end
	end
	
	return choices[#choices] -- Fallback
end

function MathUtil.RandomPointInSphere(radius: number): Vector3
	local u = math.random()
	local v = math.random()
	local theta = u * 2.0 * math.pi
	local phi = math.acos(2.0 * v - 1.0)
	local r = radius * (math.random() ^ (1/3))
	
	local sinTheta = math.sin(theta)
	local cosTheta = math.cos(theta)
	local sinPhi = math.sin(phi)
	local cosPhi = math.cos(phi)
	
	return Vector3.new(
		r * sinPhi * cosTheta,
		r * sinPhi * sinTheta,
		r * cosPhi
	)
end

function MathUtil.RandomPointOnSphere(radius: number): Vector3
	local u = math.random()
	local v = math.random()
	local theta = u * 2.0 * math.pi
	local phi = math.acos(2.0 * v - 1.0)
	
	local sinTheta = math.sin(theta)
	local cosTheta = math.cos(theta)
	local sinPhi = math.sin(phi)
	local cosPhi = math.cos(phi)
	
	return Vector3.new(
		radius * sinPhi * cosTheta,
		radius * sinPhi * sinTheta,
		radius * cosPhi
	)
end

-- Easing functions
function MathUtil.EaseInQuad(t: number): number
	return t * t
end

function MathUtil.EaseOutQuad(t: number): number
	return t * (2 - t)
end

function MathUtil.EaseInOutQuad(t: number): number
	if t < 0.5 then
		return 2 * t * t
	else
		return -1 + (4 - 2 * t) * t
	end
end

function MathUtil.EaseInCubic(t: number): number
	return t * t * t
end

function MathUtil.EaseOutCubic(t: number): number
	local t1 = t - 1
	return t1 * t1 * t1 + 1
end

function MathUtil.EaseInOutCubic(t: number): number
	if t < 0.5 then
		return 4 * t * t * t
	else
		local t1 = 2 * t - 2
		return 1 + t1 * t1 * t1 / 2
	end
end

function MathUtil.EaseInElastic(t: number): number
	if t == 0 then return 0 end
	if t == 1 then return 1 end
	
	local p = 0.3
	local s = p / 4
	local postFix = math.pow(2, 10 * (t - 1))
	
	return -(postFix * math.sin((t - 1 - s) * MathUtil.TAU / p))
end

function MathUtil.EaseOutElastic(t: number): number
	if t == 0 then return 0 end
	if t == 1 then return 1 end
	
	local p = 0.3
	local s = p / 4
	
	return math.pow(2, -10 * t) * math.sin((t - s) * MathUtil.TAU / p) + 1
end

-- Collision and intersection functions
function MathUtil.PointInTriangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2): boolean
	local function sign(p1: Vector2, p2: Vector2, p3: Vector2): number
		return (p1.X - p3.X) * (p2.Y - p3.Y) - (p2.X - p3.X) * (p1.Y - p3.Y)
	end
	
	local d1 = sign(point, a, b)
	local d2 = sign(point, b, c)
	local d3 = sign(point, c, a)
	
	local hasNeg = (d1 < 0) or (d2 < 0) or (d3 < 0)
	local hasPos = (d1 > 0) or (d2 > 0) or (d3 > 0)
	
	return not (hasNeg and hasPos)
end

function MathUtil.RayPlaneIntersection(rayOrigin: Vector3, rayDirection: Vector3, planePoint: Vector3, planeNormal: Vector3): Vector3?
	local denom = planeNormal:Dot(rayDirection)
	if math.abs(denom) < MathUtil.EPSILON then
		return nil -- Ray is parallel to plane
	end
	
	local t = (planePoint - rayOrigin):Dot(planeNormal) / denom
	if t < 0 then
		return nil -- Intersection is behind ray origin
	end
	
	return rayOrigin + rayDirection * t
end

-- Smoothing and filtering
function MathUtil.ExponentialSmoothing(current: number, target: number, smoothing: number, deltaTime: number): number
	local alpha = 1 - math.exp(-smoothing * deltaTime)
	return MathUtil.Lerp(current, target, alpha)
end

function MathUtil.SpringDamper(current: number, target: number, velocity: number, springConstant: number, dampingRatio: number, deltaTime: number): (number, number)
	local omega = math.sqrt(springConstant)
	local dampingCoeff = 2 * dampingRatio * omega
	
	local force = springConstant * (target - current) - dampingCoeff * velocity
	local newVelocity = velocity + force * deltaTime
	local newPosition = current + newVelocity * deltaTime
	
	return newPosition, newVelocity
end

-- Statistical functions
function MathUtil.Average(values: {number}): number
	if #values == 0 then return 0 end
	
	local sum = 0
	for _, value in ipairs(values) do
		sum = sum + value
	end
	return sum / #values
end

function MathUtil.Median(values: {number}): number
	if #values == 0 then return 0 end
	
	local sorted = {}
	for _, value in ipairs(values) do
		table.insert(sorted, value)
	end
	table.sort(sorted)
	
	local mid = math.ceil(#sorted / 2)
	if #sorted % 2 == 1 then
		return sorted[mid]
	else
		return (sorted[mid] + sorted[mid + 1]) / 2
	end
end

function MathUtil.StandardDeviation(values: {number}): number
	if #values <= 1 then return 0 end
	
	local avg = MathUtil.Average(values)
	local sumSquaredDiff = 0
	
	for _, value in ipairs(values) do
		local diff = value - avg
		sumSquaredDiff = sumSquaredDiff + diff * diff
	end
	
	return math.sqrt(sumSquaredDiff / (#values - 1))
end

return MathUtil