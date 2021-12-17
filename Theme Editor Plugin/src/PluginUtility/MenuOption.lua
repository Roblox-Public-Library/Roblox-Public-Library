local MenuOption = {}
MenuOption.__index = MenuOption
function MenuOption.new(pluginAction)
	return setmetatable({
		pluginAction = pluginAction,
		enabled = true,
	}, MenuOption)
end
function MenuOption:SetEnabled(enabled)
	self.enabled = enabled
end
function MenuOption:AddToMenu(menu)
	local action = self.pluginAction
	if self.enabled then
		menu:AddAction(action)
	else
		if not self.tmpAction then
			self.tmpAction = menu:AddNewAction(action.ActionId .. "Tmp", "[Disabled] " .. action.Text, action.Icon)
		else
			menu:AddAction(self.tmpAction)
		end
	end
end
return MenuOption