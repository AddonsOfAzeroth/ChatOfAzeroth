-- Chat of Azeroth by DinX: a chat window in the style of Discord / mIRC.
-- Channels on the left, messages in the middle, Blizzard's own input box at
-- the bottom (so every line is still typed and sent by you).
local ADDON, ns = ...

local ChA = CreateFrame("Frame", "ChatOfAzerothCore")
ns.ChA = ChA
_G.ChatOfAzeroth = ChA

ChA.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "?"
ChA.modules = {}

local accountDefaults = {
	language = "auto",
	font = "roboto",
	fontOutline = false,
	tabs = {},        -- your own tabs: { name, kinds = { [kind] = true }, word = "text" or nil }
	whispers = {},    -- ["Name"] = { last messages } kept between sessions
}
local charDefaults = {
	enabled = true,
	hideBlizzard = true, -- Blizzard's chat windows out of sight while ours is on
	timestamps = true,
	othersCrafting = false, -- "X creates Y" from players around you
	fontSize = 13,
	width = 560,
	height = 230,
	sidebar = 130,
	current = "all",
	muted = {},        -- [room] = true: no unread count, greyed at the bottom
	notInAll = {},     -- [channel] = true: kept out of "All"
	collapsed = {},    -- [group] = true: folded in the sidebar
	bars = { locked = true },
	points = {},
}

ChA.SCHEMA = 1

local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function ChA:Print(...)
	print("|cff69ccf0Chat of Azeroth|r:", ...)
end

local handlers = {}
function ChA:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		local ok = pcall(self.RegisterEvent, self, event)
		if not ok then handlers[event] = nil return end
	end
	table.insert(handlers[event], fn)
end

ChA:SetScript("OnEvent", function(self, event, ...)
	local list = handlers[event]
	if list then
		for i = 1, #list do list[i](event, ...) end
	end
end)

function ChA:NewModule(name)
	local m = { name = name }
	self.modules[#self.modules + 1] = m
	self[name] = m
	return m
end

local callbacks = {}
function ChA:Listen(msg, fn)
	callbacks[msg] = callbacks[msg] or {}
	table.insert(callbacks[msg], fn)
end
function ChA:Fire(msg, ...)
	for _, fn in ipairs(callbacks[msg] or {}) do fn(...) end
end

local issecret = issecretvalue or function() return false end
ChA.IsSecret = issecret
function ChA.Safe(v, default)
	if issecret(v) then return default end
	if v == nil then return default end
	return v
end

function ChA:Casters()
	local c = _G.CastersOfAzeroth or _G.CasterKit
	if type(c) == "table" and type(c.char) == "table" then return c end
end

function ChA:FramesLocked()
	local c = self:Casters()
	if c and type(c.char.bars) == "table" then return c.char.bars.locked ~= false end
	return self.char.bars.locked
end

function ChA:SetFramesLocked(locked)
	self.char.bars.locked = locked
	local c = self:Casters()
	if c and type(c.char.bars) == "table" then
		c.char.bars.locked = locked
		if c.Fire then c:Fire("SETTINGS", "bars") end
	end
	self:Fire("SETTINGS", "bars")
end

ChA:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	ChatOfAzerothDB = type(ChatOfAzerothDB) == "table" and ChatOfAzerothDB or {}
	ChatOfAzerothCharDB = type(ChatOfAzerothCharDB) == "table" and ChatOfAzerothCharDB or {}
	merge(ChatOfAzerothDB, accountDefaults)
	merge(ChatOfAzerothCharDB, charDefaults)
	ChA.db = ChatOfAzerothDB
	ChA.char = ChatOfAzerothCharDB
	ChA.db.schemaVersion = ChA.SCHEMA
	local c = ChA:Casters()
	ChA.Style:LoadFont(c and c.db or ChA.db)
	for _, m in ipairs(ChA.modules) do
		if m.OnInit then pcall(m.OnInit, m) end
	end
end)

ChA:On("PLAYER_LOGIN", function()
	for _, m in ipairs(ChA.modules) do
		if m.OnEnable then
			local ok, err = pcall(m.OnEnable, m)
			if not ok then ChA:Print("|cffff5555" .. m.name .. ":|r " .. tostring(err)) end
		end
	end
	local c = ChA:Casters()
	if c and c.Listen then
		c:Listen("SETTINGS", function(group)
			if group == "bars" and ChA.Style then ChA.Style:UpdateMovers() end
		end)
	end
	if ChA.Style then ChA.Style:UpdateMovers() end
end)

SLASH_CHATOFAZEROTH1 = "/cha"
SLASH_CHATOFAZEROTH2 = "/chatofazeroth"
SlashCmdList.CHATOFAZEROTH = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	local L = ChA.L
	if msg == "" or msg == "config" or msg == "settings" then
		ChA:ToggleConfig()
	elseif msg == "unlock" or msg == "lock" then
		ChA:SetFramesLocked(msg == "lock")
		ChA:Print(msg == "lock" and L["Frames locked."] or L["Frames unlocked: drag the chat where you like, drag its corner to make it bigger, type /cha lock when done."])
	elseif msg == "toggle" then
		ChA.char.enabled = not ChA.char.enabled
		ChA:Fire("SETTINGS", "chat")
	else
		ChA:Print(L["/cha: settings. /cha toggle: our chat on/off. /cha unlock: move and resize it."])
	end
end

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_ACTION_BLOCKED")
	f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	f:SetScript("OnEvent", function(_, event, addon, func)
		if addon ~= ADDON then return end
		C_Timer.After(3, function() ChA:Print("|cffff5555blocked:|r " .. tostring(func)) end)
	end)
end
