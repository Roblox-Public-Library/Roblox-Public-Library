local RateLimiter = {}
RateLimiter.__index = RateLimiter
function RateLimiter.new(max, period)
	return setmetatable({
		max = max,
		period = period,
		uses = {}, -- {[player] = usage count}
	}, RateLimiter)
end
function RateLimiter:TryUse(player)
	local uses = self.uses
	local n = uses[player] or 0
	if n >= self.max then return false end
	uses[player] = n + 1
	task.delay(self.period, function()
		local n = uses[player]
		if n > 1 then
			uses[player] = n - 1
		else
			uses[player] = nil
		end
	end)
	return true
end
function RateLimiter:AtRateLimit(player)
	local uses = self.uses[player]
	return uses and uses >= self.max
end
function RateLimiter:Wrap(fn, onFailFn)
	return function(player, ...)
		if self:TryUse(player) then
			fn(player, ...)
		elseif onFailFn then
			onFailFn(player, ...)
		end
	end
end
return RateLimiter