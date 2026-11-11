-- Chat of Azeroth by DinX: its line in the "Addons of Azeroth" minimap list (Hub.lua).
local ADDON, ns = ...

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	C_Timer.After(0, function()
		local hub = _G.AddonsOfAzerothHub
		if not hub then return end
		local ChA = ns.ChA
		hub:Register({
			key = "chat", addon = ADDON,
			click = function() SlashCmdList.CHATOFAZEROTH("") end,
		})
	end)
end)
