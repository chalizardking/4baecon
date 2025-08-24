--[[
	FORESAKEN Table Utilities Module
	Common table manipulation and utility functions
	
	Usage:
	local TableUtil = require(ReplicatedStorage.Shared.Modules.Util.Tables)
	local deepCopy = TableUtil.DeepCopy(originalTable)
]]

local TableUtil = {}

-- Table manipulation functions
function TableUtil.DeepCopy(original: any): any
	local copy
	if type(original) == "table" then
		copy = {}
		for key, value in pairs(original) do
			copy[TableUtil.DeepCopy(key)] = TableUtil.DeepCopy(value)
		end
		setmetatable(copy, TableUtil.DeepCopy(getmetatable(original)))
	else
		copy = original
	end
	return copy
end

function TableUtil.ShallowCopy(original: {[any]: any}): {[any]: any}
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = value
	end
	return copy
end

function TableUtil.Merge(target: {[any]: any}, source: {[any]: any}): {[any]: any}
	for key, value in pairs(source) do
		target[key] = value
	end
	return target
end

function TableUtil.DeepMerge(target: {[any]: any}, source: {[any]: any}): {[any]: any}
	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			target[key] = TableUtil.DeepMerge(target[key], value)
		else
			target[key] = value
		end
	end
	return target
end

-- Array functions
function TableUtil.Contains(array: {any}, value: any): boolean
	for _, item in ipairs(array) do
		if item == value then
			return true
		end
	end
	return false
end

function TableUtil.IndexOf(array: {any}, value: any): number?
	for i, item in ipairs(array) do
		if item == value then
			return i
		end
	end
	return nil
end

function TableUtil.Remove(array: {any}, value: any): boolean
	local index = TableUtil.IndexOf(array, value)
	if index then
		table.remove(array, index)
		return true
	end
	return false
end

function TableUtil.RemoveAt(array: {any}, index: number): any
	return table.remove(array, index)
end

function TableUtil.Insert(array: {any}, value: any, index: number?): ()
	if index then
		table.insert(array, index, value)
	else
		table.insert(array, value)
	end
end

function TableUtil.Clear(array: {any}): ()
	for i = #array, 1, -1 do
		array[i] = nil
	end
end

function TableUtil.Reverse(array: {any}): {any}
	local reversed = {}
	for i = #array, 1, -1 do
		table.insert(reversed, array[i])
	end
	return reversed
end

function TableUtil.Shuffle(array: {any}): {any}
	local shuffled = TableUtil.ShallowCopy(array)
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

function TableUtil.Slice(array: {any}, startIndex: number, endIndex: number?): {any}
	local sliced = {}
	local endIdx = endIndex or #array
	
	for i = startIndex, endIdx do
		if array[i] ~= nil then
			table.insert(sliced, array[i])
		end
	end
	
	return sliced
end

function TableUtil.Concat(array1: {any}, array2: {any}): {any}
	local result = TableUtil.ShallowCopy(array1)
	for _, value in ipairs(array2) do
		table.insert(result, value)
	end
	return result
end

-- Functional programming helpers
function TableUtil.Map(array: {any}, func: (any) -> any): {any}
	local mapped = {}
	for i, value in ipairs(array) do
		mapped[i] = func(value)
	end
	return mapped
end

function TableUtil.Filter(array: {any}, predicate: (any) -> boolean): {any}
	local filtered = {}
	for _, value in ipairs(array) do
		if predicate(value) then
			table.insert(filtered, value)
		end
	end
	return filtered
end

function TableUtil.Find(array: {any}, predicate: (any) -> boolean): any
	for _, value in ipairs(array) do
		if predicate(value) then
			return value
		end
	end
	return nil
end

function TableUtil.FindIndex(array: {any}, predicate: (any) -> boolean): number?
	for i, value in ipairs(array) do
		if predicate(value) then
			return i
		end
	end
	return nil
end

function TableUtil.Reduce(array: {any}, func: (any, any) -> any, initialValue: any?): any
	local accumulator = initialValue
	local startIndex = 1
	
	if accumulator == nil then
		if #array == 0 then
			error("Reduce of empty array with no initial value")
		end
		accumulator = array[1]
		startIndex = 2
	end
	
	for i = startIndex, #array do
		accumulator = func(accumulator, array[i])
	end
	
	return accumulator
end

function TableUtil.Every(array: {any}, predicate: (any) -> boolean): boolean
	for _, value in ipairs(array) do
		if not predicate(value) then
			return false
		end
	end
	return true
end

function TableUtil.Some(array: {any}, predicate: (any) -> boolean): boolean
	for _, value in ipairs(array) do
		if predicate(value) then
			return true
		end
	end
	return false
end

function TableUtil.ForEach(array: {any}, func: (any, number) -> ()): ()
	for i, value in ipairs(array) do
		func(value, i)
	end
end

-- Dictionary functions
function TableUtil.Keys(dict: {[any]: any}): {any}
	local keys = {}
	for key in pairs(dict) do
		table.insert(keys, key)
	end
	return keys
end

function TableUtil.Values(dict: {[any]: any}): {any}
	local values = {}
	for _, value in pairs(dict) do
		table.insert(values, value)
	end
	return values
end

function TableUtil.HasKey(dict: {[any]: any}, key: any): boolean
	return dict[key] ~= nil
end

function TableUtil.GetDeepValue(dict: {[any]: any}, path: {any}): any
	local current = dict
	for _, key in ipairs(path) do
		if type(current) ~= "table" or current[key] == nil then
			return nil
		end
		current = current[key]
	end
	return current
end

function TableUtil.SetDeepValue(dict: {[any]: any}, path: {any}, value: any): ()
	local current = dict
	for i = 1, #path - 1 do
		local key = path[i]
		if type(current[key]) ~= "table" then
			current[key] = {}
		end
		current = current[key]
	end
	current[path[#path]] = value
end

-- Comparison functions
function TableUtil.Equal(table1: {[any]: any}, table2: {[any]: any}): boolean
	if table1 == table2 then
		return true
	end
	
	if type(table1) ~= "table" or type(table2) ~= "table" then
		return false
	end
	
	-- Check if all keys in table1 exist in table2 with equal values
	for key, value in pairs(table1) do
		if not TableUtil.Equal(value, table2[key]) then
			return false
		end
	end
	
	-- Check if table2 has any keys that table1 doesn't have
	for key in pairs(table2) do
		if table1[key] == nil then
			return false
		end
	end
	
	return true
end

function TableUtil.IsEmpty(table: {[any]: any}): boolean
	return next(table) == nil
end

function TableUtil.Count(table: {[any]: any}): number
	local count = 0
	for _ in pairs(table) do
		count = count + 1
	end
	return count
end

-- Utility functions
function TableUtil.Print(table: any, indent: string?): ()
	local indentStr = indent or ""
	
	if type(table) ~= "table" then
		print(indentStr .. tostring(table))
		return
	end
	
	print(indentStr .. "{")
	for key, value in pairs(table) do
		local keyStr = type(key) == "string" and key or "[" .. tostring(key) .. "]"
		if type(value) == "table" then
			print(indentStr .. "  " .. keyStr .. " =")
			TableUtil.Print(value, indentStr .. "    ")
		else
			print(indentStr .. "  " .. keyStr .. " = " .. tostring(value))
		end
	end
	print(indentStr .. "}")
end

function TableUtil.ToString(table: any): string
	if type(table) ~= "table" then
		return tostring(table)
	end
	
	local parts = {}
	table.insert(parts, "{")
	
	for key, value in pairs(table) do
		local keyStr = type(key) == "string" and key or "[" .. tostring(key) .. "]"
		local valueStr = type(value) == "table" and TableUtil.ToString(value) or tostring(value)
		table.insert(parts, "  " .. keyStr .. " = " .. valueStr .. ",")
	end
	
	table.insert(parts, "}")
	return table.concat(parts, "\n")
end

-- Serialization helpers
function TableUtil.ToJSON(table: {[any]: any}): string
	local HttpService = game:GetService("HttpService")
	return HttpService:JSONEncode(table)
end

function TableUtil.FromJSON(jsonString: string): {[any]: any}
	local HttpService = game:GetService("HttpService")
	return HttpService:JSONDecode(jsonString)
end

-- Set operations
function TableUtil.Union(set1: {any}, set2: {any}): {any}
	local union = TableUtil.ShallowCopy(set1)
	for _, value in ipairs(set2) do
		if not TableUtil.Contains(union, value) then
			table.insert(union, value)
		end
	end
	return union
end

function TableUtil.Intersection(set1: {any}, set2: {any}): {any}
	local intersection = {}
	for _, value in ipairs(set1) do
		if TableUtil.Contains(set2, value) then
			table.insert(intersection, value)
		end
	end
	return intersection
end

function TableUtil.Difference(set1: {any}, set2: {any}): {any}
	local difference = {}
	for _, value in ipairs(set1) do
		if not TableUtil.Contains(set2, value) then
			table.insert(difference, value)
		end
	end
	return difference
end

-- Sorting
function TableUtil.Sort(array: {any}, compareFunc: ((any, any) -> boolean)?): {any}
	local sorted = TableUtil.ShallowCopy(array)
	if compareFunc then
		table.sort(sorted, compareFunc)
	else
		table.sort(sorted)
	end
	return sorted
end

function TableUtil.SortBy(array: {any}, keyFunc: (any) -> any): {any}
	return TableUtil.Sort(array, function(a, b)
		return keyFunc(a) < keyFunc(b)
	end)
end

-- Grouping
function TableUtil.GroupBy(array: {any}, keyFunc: (any) -> any): {[any]: {any}}
	local groups = {}
	for _, value in ipairs(array) do
		local key = keyFunc(value)
		if not groups[key] then
			groups[key] = {}
		end
		table.insert(groups[key], value)
	end
	return groups
end

-- Validation
function TableUtil.ValidateSchema(table: {[any]: any}, schema: {[any]: string}): boolean
	for key, expectedType in pairs(schema) do
		local value = table[key]
		if value == nil then
			return false
		end
		if type(value) ~= expectedType then
			return false
		end
	end
	return true
end

return TableUtil