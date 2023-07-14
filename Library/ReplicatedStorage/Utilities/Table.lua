local Table = {}

function Table.DictKeysToList(dict)
	warn("Table.DictKeysToList is deprecated, use Table.KeysToList")
	return Table.KeysToList(dict)
end
function Table.KeysToList(t)
	local list = {}
	local n = 0
	for k, v in pairs(t) do
		n = n + 1
		list[n] = k
	end
	return list
end
local function ListToDict(list)
	warn("Table.ListToDict is deprecated, use List.ToDict")
	local dict = {}
	for i = 1, #list do
		dict[list[i]] = true
	end
	return dict
end
Table.ListToDict = ListToDict

function Table.Clone(t)
	local nt = {}
	for k, v in pairs(t) do
		nt[k] = v
	end
	return nt
end
local function DeepClone(t)
	if type(t) ~= "table" then return t end
	local nt = {}
	for k, v in pairs(t) do
		nt[k] = DeepClone(v)
	end
	return nt
end
Table.DeepClone = DeepClone
function Table.Contains(list, value)
	warn("Table.Contains is deprecated, use List.Contains")
	for i = 1, #list do
		if list[i] == value then return true end
	end
	return false
end
function Table.CountKeys(t)
	local c = 0;
	for _, _ in pairs(t) do c = c + 1 end
	return c
end
function Table.Equals(t1, t2)
	for k, v in pairs(t1) do
		if v ~= t2[k] then return false end
	end
	for k, v in pairs(t2) do
		if v ~= t1[k] then return false end
	end
	return true
end

function Table.ApplyClonedDefaults(dest, source)
	--	For string keys dest doesn't have, copy over values from source (using deep cloning on any tables)
	--	This is applied recursively if both dest and source have a table with the same key
	if not dest then dest = {} end
	for k, sv in source do
		if type(k) ~= "string" then continue end
		local dv = dest[k]
		if dv == nil then
			dest[k] = if type(sv) == "table" then Table.DeepClone(sv) else sv
		elseif type(dv) == "table" and type(sv) == "table" then
			Table.ApplyClonedDefaults(dv, sv)
		end
	end
	return dest
end

-- ToString section

local function isCustomEvent(v) -- assumes type(v) == "table"
	-- Just check for the 2 common functions
	return v.Fire and v.Connect
end
local formats = {
	number = " = %s",
	boolean = " = %s",
	string = ' = "%s"',
	["nil"] = " = %s",
	["function"] = ":function",
	["thread"] = "= thread",
	-- table and userdata covered by describeValue
}
local function isEasyList(v)
	for k, v in pairs(v) do
		if type(k) ~= "number" or type(v) == "table" then return false end
	end
	return true
end
local function easyListToString(v)
	local t = {}
	for i, v in ipairs(v) do
		t[i] = (type(v) == "string" and '"%s"' or "%s"):format(tostring(v))
	end
	local className = getmetatable(v) and v.ClassName
	return className
		and (" = %s{%s}"):format(className, table.concat(t, ","))
		or (" = {%s}"):format(table.concat(t, ","))
end
local function childCountIndicator(v)
	local c = 0
	for k, v in ipairs(v) do c = c + 1 end
	return c > 0 and (" (%d)"):format(c) or ""
end
local function describeValue(v, tableNames)
	local theType = type(v)
	return theType == "userdata" and (typeof(v) == "Instance" and ("%s:%s"):format(v.Name, v.ClassName or typeof(v)))
		or theType == "table" and (isEasyList(v)
			and ("%s %s"):format(easyListToString(v), tableNames[v])
			or (":%s%s %s"):format(isCustomEvent(v) and "Event" or v.ClassName or "table", childCountIndicator(v), tableNames[v]))
		or formats[theType]:format(tostring(v))
end
local function DescribeKeyValue(k, v, tableNames)
	return ("%s%s%s%s"):format(
		type(k) == "string" and "." or "[",
		tostring(k),
		type(k) == "string" and "" or "]",
		describeValue(v, tableNames))
end
Table.DescribeKeyValue = DescribeKeyValue
local function ShouldRecurse(k, v)
	return type(v) == "table" and not isCustomEvent(v) and not isEasyList(v)
end
Table.ShouldRecurse = ShouldRecurse
local Multiline = "\n"
local Condensed = ","
Table.Multiline = Multiline
Table.Condensed = Condensed
local function seenTableBefore(seen, t) -- also names the table
	if seen[t] then
		return true
	else
		seen.next = (seen.next or 0) + 1
		seen[t] = "#" .. seen.next
	end
end
function Table.GenToString(tab, betweenEntries, describeKV, shouldRecurse)
	tab = tab or "  "
	betweenEntries = betweenEntries or Multiline
	describeKV = describeKV or DescribeKeyValue
	shouldRecurse = shouldRecurse or ShouldRecurse
	local function TableToStringR(t, nTabs, seen, c)
		nTabs = nTabs or 0
		seen = seen or {} -- also doubles as the simplified name for each table
		c = c or {}
		--if seen[t] then return end
		local fullTab = string.rep(tab, nTabs)
		for k, v in pairs(t) do
			local seenBefore = type(v) == "table" and seenTableBefore(seen, v)
			local i = #c + 1
			c[#c + 1] = fullTab .. describeKV(k, v, seen)
			if not seenBefore and shouldRecurse(k, v) then
				TableToStringR(v, nTabs + 1, seen, c)
			end
		end
		return c
	end
	local function TableToString(t, nTabs, seen, c)
		--	t: the table to convert to a string
		--	nTabs: current tab depth
		--	seen: [table] = true if should not explore this table (because already seen)
		--	c: concat table. If provided, it will be returned instead of a string.
		--		It is extended with the assumption that each entry will be on its own line
		if c then
			seenTableBefore(seen, t)
			TableToStringR(t, nTabs, seen, c)
			return c
		else
			return table.concat(TableToStringR(t, nTabs, seen, c), "\n")
		end
	end
	return TableToString
end
function Table.GenToCondensedString(...)
	return Table.GenToString("", Condensed, ...)
end

return Table