return function(tests, t)


local ThemeEditorPlugin = game:GetService("ServerStorage"):FindFirstChild("Theme Editor Plugin")
if not ThemeEditorPlugin then return end
local PropsSerializer = require(ThemeEditorPlugin.PluginUtility.PropsSerializer)

function tests.Works()
	local simple = {0, 0.001, 0.156, 1}
	local materials = {Enum.Material.Plastic, Enum.Material.Ice, Enum.Material.Glass}
	local colors = {Color3.fromRGB(0, 0, 0), Color3.fromRGB(1, 2, 3), Color3.fromRGB(255, 255, 254), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0)}
	local unique = {}
	for _, tr in ipairs(simple) do
		for _, r in ipairs(simple) do
			for _, m in ipairs(materials) do
				for _, c in ipairs(colors) do
					local n = PropsSerializer.PropsToNum(tr, r, m, c)
					local tt, rr, mm, cc = PropsSerializer.NumToProps(n)
					if tr ~= tt or r ~= rr or m ~= mm or c.R ~= cc.R or c.G ~= cc.G or c.B ~= cc.B then
						print("In:", tr, r, m, c)
						print("Out:", tt, rr, mm, cc)
						error("Not equal!")
					end
					if unique[n] then
						print("In:", tr, r, m, c)
						print("Number:", n)
						error("Already seen this combination")
					end
					unique[n] = true
				end
			end
		end
	end
end


end -- function(tests, t)