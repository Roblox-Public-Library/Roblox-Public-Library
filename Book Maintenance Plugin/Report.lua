local Report = {}
function Report.new()
	--	Returns a report object that organizes messages into collectors so that the final output will have all the same messages in one place.
	--	Call report(collector, ...) to add a new entry to the given data collector. (Typically '...' will be 'msg' but this can depend on the collector.)
	--	Call report([order,] msg) to add a simple output message with no need for a collector.
	--	Call report:Compile(...) (returns a string) when done. '...' is not inherently required but will be passed on to collectors.
	--[[Collector interface:
		[.Init(data)]
		.Collect(data, ...)
		.Compile(data)
		.Order:number - all collectors with order 1 will be output before those with order 2
			A nil order is considered the same as 0
	]]
	local allData = {}
	local collectorList = {}
	local orderHeader = {}
	return setmetatable({
		OrderHeader = function(self, order, header)
			orderHeader[order] = header
		end,
		Compile = function(self, ...)
			local list = {}
			for i, collector in ipairs(collectorList) do
				list[i] = {collector.Order or 0, i, collector}
			end
			table.sort(list, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
			local s = {}
			local lastOrder = -math.huge
			for _, entry in ipairs(list) do
				local order = entry[1]
				if order > lastOrder then
					lastOrder = order
					if orderHeader[order] then
						s[#s + 1] = orderHeader[order]
					end
				end
				local collector = entry[3]
				s[#s + 1] = collector.Compile(allData[collector], ...)
			end
			return table.concat(s, "\n")
		end,
	}, {
		__call = function(report, collector, arg, ...)
			if type(collector) == "number" then
				arg, collector = collector, arg
			end
			if type(collector) == "string" then
				collectorList[#collectorList + 1] = {
					Order = arg,
					Compile = function() return collector end,
				}
			else
				local data = allData[collector]
				if not data then
					data = {}
					allData[collector] = data
					collectorList[#collectorList + 1] = collector
					if collector.Init then collector.Init(data) end
				end
				collector.Collect(data, arg, ...)
			end
		end,
	})
end
function Report.HandleMsg(n, msg1, msgN)
	return (n == 1 or not msgN) and msg1:format(n, n == 1 and "" or "s") or msgN:format(n)
end
function Report.NewListCollector(msg1, msgN, bulletPoint)
	--	msg1: message for if there is only 1 entry (supports %d [number] and %s ["s" if not 1])
	--	msgN: message for if there are 0 or 2+ entries (supports %d) - defaults to msg1
	--	Note: it's okay if msg1/msgN don't use %d/%s
	local combine = "\n" .. (bulletPoint or "\t")
	return {
		Init = function(data)
			data[1] = ""
		end,
		Collect = function(data, entry)
			data[#data + 1] = entry
		end,
		Compile = function(data)
			local n = #data - 1
			data[1] = Report.HandleMsg(n, msg1, msgN)
			return table.concat(data, combine)
		end,
	}
end
function Report.NewCountCollector(msg1, msgN)
	--	A collector that collects the number of occurrences as argument.
	--	msg1, msgN: see NewListCollector
	return {
		Init = function(data)
			data[1] = 0
		end,
		Collect = function(data, n)
			data[1] += n or 1
		end,
		Compile = function(data)
			return Report.HandleMsg(data[1], msg1, msgN)
		end,
	}
end
function Report.NewCategoryCollector(msg1, msgN, getCategory, getMsg, getCategoryMsg)
	--	getCategory(...):category
	--	getMsg(...):msg to include under the category. Will be double tabbed.
	--	getCategoryMsg(categoryName): how to transform the category name into an output entry. Will be singly tabbed.
	getCategory = getCategory or function(category, msg) return category end
	getMsg = getMsg or function(category, msg) return msg end
	return {
		-- data is treated as a list of category {Name = "", msg1, msg2, ...} and [name] = ref to that category's table
		Init = function(data)
			data.n = 0
		end,
		Collect = function(data, ...)
			local category = getCategory(...)
			local list = data[category]
			if not list then
				list = {Name = category}
				data[#data + 1] = list
				data[category] = list
			end
			list[#list + 1] = getMsg(...)
			data.n += 1
		end,
		Compile = function(data)
			local s = {Report.HandleMsg(data.n, msg1, msgN)}
			for _, category in ipairs(data) do
				s[#s + 1] = "\t" .. (getCategoryMsg and getCategoryMsg(category.Name) or category.Name .. ":")
				for _, msg in ipairs(category) do
					s[#s + 1] = "\t\t" .. msg
				end
			end
			return table.concat(s, "\n")
		end,
	}
end
function Report.ExtendInit(collector, init)
	if collector.Init then
		local base = collector.Init
		function collector.Init(data)
			if base then base(data) end
			init(data)
		end
	else
		collector.Init = init
	end
	return collector
end
function Report.PreventDuplicates(collector, init, isDuplicate)
	--	PreventDuplicates(collector, isDuplicate) is also valid
	--	isDuplicate(data, ...):bool
	if not isDuplicate then isDuplicate = init; init = nil end
	if init then
		Report.ExtendInit(collector, init)
	end
	local base = collector.Collect
	function collector.Collect(...)
		if isDuplicate(...) then return end
		base(...)
	end
	return collector
end
return Report