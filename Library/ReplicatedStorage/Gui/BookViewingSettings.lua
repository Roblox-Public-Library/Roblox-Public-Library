local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookViewingSettings = require(ReplicatedStorage.Library.BookViewingSettings)
local bvs = require(ReplicatedStorage.Library.ProfileClient).BookViewingSettings

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local gui = ReplicatedStorage.Guis.BookViewingSettings
gui.Enabled = false
gui.Parent = localPlayer.PlayerGui

local f = gui.Frame

local family = f.ThreeD.ThreeD.FontFace.Family
local boldFont = Font.new(family, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local normalFont = Font.new(family, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local function setupButtonSet(valuePointer, valueToButton)
	local function update(value)
		for v, button in valueToButton do
			local selected = v == value
			button.FontFace = if selected then boldFont else normalFont
			button.BackgroundTransparency = if selected then 0 else 0.25
		end
	end
	update(valuePointer:Get())
	valuePointer.Changed:Connect(update)
	for v, button in valueToButton do
		button.Activated:Connect(function()
			valuePointer:Set(v)
		end)
	end
end

local f3D = f.ThreeD
setupButtonSet(bvs.ThreeD, {
	-- f.OnePage2D,
	-- f.TwoPage2D,
	[false] = f3D.TwoD,
	[true] = f3D.ThreeD,
})

-- local fPages = f.Pages
-- setupButtonSet(bvs.TwoPage, {
-- 	[false] = fPages.One,
-- 	[true] = fPages.Two,
-- })

local fDist = f.BookDistance
local vd = bvs.ViewDistance
-- Note: ViewDistance's Set handles bounds checking
fDist.Less.Activated:Connect(function()
	vd:Set(vd:Get() - 0.1)
end)
fDist.More.Activated:Connect(function()
	vd:Set(vd:Get() + 0.1)
end)
local function updateDist(d)
	fDist.Distance.Text = string.format("%.1f", d)
end
updateDist(vd:Get())
vd.Changed:Connect(updateDist)

local fPublic = f.PublicOptions
setupButtonSet(bvs.Public, {
	[true] = fPublic.Yes,
	[false] = fPublic.No,
})

local fColor = f.ColorMode
setupButtonSet(bvs.LightMode, {
	[true] = fColor.Light,
	[false] = fColor.Dark,
})

local module = {}
module.CloseOnCatchClick = false
function module:Open()
	gui.Enabled = true
end
function module:Close()
	gui.Enabled = false
end

return module