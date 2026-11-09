-- Chat of Azeroth by DinX: where messages go. Every chat event lands in a
-- "room": system, loot, local (say, yell, emotes, NPCs), guild, party, raid,
-- instance, one per channel ("ch:Trade") and one per whisper partner
-- ("dm:Name"). Your own tabs are filters over all of them. In combat or in
-- instances Blizzard can hide the text from addons: such lines are shown
-- as they are, without our timestamp or name colours, and never filtered.
local _, ns = ...
local ChA = ns.ChA
local Safe, IsSecret = ChA.Safe, ChA.IsSecret

local St = ChA:NewModule("Store")

local MAX_ROOM, MAX_ALL, KEEP_WHISPERS = 300, 500, 40

-- event (without CHAT_MSG_) -> room and the kind your own tabs filter on
local MAP = {
	SAY = "local", YELL = "local", EMOTE = "local", TEXT_EMOTE = "local",
	MONSTER_SAY = "local", MONSTER_YELL = "local", MONSTER_EMOTE = "local", MONSTER_PARTY = "party",
	GUILD = "guild", OFFICER = "guild", GUILD_ACHIEVEMENT = "guild",
	PARTY = "party", PARTY_LEADER = "party",
	RAID = "raid", RAID_LEADER = "raid", RAID_WARNING = "raid",
	INSTANCE_CHAT = "instance", INSTANCE_CHAT_LEADER = "instance",
	LOOT = "loot", MONEY = "loot", CURRENCY = "loot",
	SYSTEM = "system", SKILL = "system", ACHIEVEMENT = "system", COMBAT_XP_GAIN = "system",
	COMBAT_HONOR_GAIN = "system", COMBAT_FACTION_CHANGE = "system", TRADESKILLS = "system", OPENING = "system",
	PET_INFO = "system", AFK = "system", DND = "system", IGNORED = "system", CHANNEL_NOTICE = "system",
	BG_SYSTEM_NEUTRAL = "system", BG_SYSTEM_ALLIANCE = "system", BG_SYSTEM_HORDE = "system",
	WHISPER = "dm", WHISPER_INFORM = "dm", BN_WHISPER = "dm", BN_WHISPER_INFORM = "dm", MONSTER_WHISPER = "dm",
	CHANNEL = "channel",
}
St.MAP = MAP
-- which Blizzard colour a kind of message gets (ChatTypeInfo)
local COLOR_TYPE = { WHISPER_INFORM = "WHISPER", BN_WHISPER_INFORM = "BN_WHISPER", TEXT_EMOTE = "EMOTE",
	MONSTER_PARTY = "PARTY" }

St.rooms = {}   -- [key] = { list of messages }
St.all = {}     -- every message, newest last
St.unread = {}  -- [key] = count
St.seen = {}    -- [key] = time of the last message (for the order of whispers)

local function push(list, m, max)
	list[#list + 1] = m
	if #list > max then table.remove(list, 1) end
end

local function shortName(name)
	if type(name) ~= "string" then return name end
	return (name:gsub("%-.*$", ""))
end

local function classColor(guid)
	if type(guid) ~= "string" or not GetPlayerInfoByGUID then return end
	local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
	local c = ok and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return ("%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
end

-- the line as shown, or nil when Blizzard hides parts of it (shown as is)
function St.Format(m)
	if m.secret then return nil end
	local parts = {}
	if ChA.char.timestamps then parts[#parts + 1] = "|cff7f8790" .. date("%H:%M", m.t) .. "|r " end
	-- the channel number only for channel messages shown outside their own room
	if m.event == "CHANNEL" and m.channelNum and m.channelNum > 0 and m.room ~= "ch:" .. (m.channel or "") then
		parts[#parts + 1] = "[" .. m.channelNum .. "] "
	end
	local name = m.author
	if type(name) == "string" and name ~= "" then
		local short = shortName(name)
		local hex = m.color or "ffffff"
		local shown = "|cff" .. hex .. short .. "|r"
		if m.event == "WHISPER_INFORM" or m.event == "BN_WHISPER_INFORM" then shown = "-> " .. shown end
		-- NPCs get no player link (no right-click menu for them)
		local npc = m.event:find("^MONSTER") ~= nil
		local who = npc and shown or ("|Hplayer:" .. name .. "|h" .. shown .. "|h")
		local text = m.text or ""
		if text:find("%s", 1, true) then
			-- emotes like "%s attempts to run away in fear!": the name goes in its place
			parts[#parts + 1] = (text:gsub("%%s", function() return who end, 1))
		elseif m.event:find("EMOTE") then
			parts[#parts + 1] = who .. " " .. text
		else
			parts[#parts + 1] = who .. ": " .. text
		end
	else
		parts[#parts + 1] = m.text or ""
	end
	return table.concat(parts)
end

function St.Color(m)
	local info = ChatTypeInfo and ChatTypeInfo[COLOR_TYPE[m.event] or m.event]
	if m.event == "CHANNEL" and ChatTypeInfo and m.channelNum then info = ChatTypeInfo["CHANNEL" .. m.channelNum] or info end
	if info then return info.r or 1, info.g or 1, info.b or 1 end
	return 1, 1, 1
end

-- what room a message goes to
local function roomOf(event, author, channelName)
	local kind = MAP[event]
	if kind == "dm" then
		if IsSecret(author) or type(author) ~= "string" then return "dm:?", "whispers" end
		return "dm:" .. shortName(author), "whispers"
	elseif kind == "channel" then
		return "ch:" .. (channelName or "?"), "channels"
	end
	return kind, kind
end
St.RoomOf = roomOf

function St:Add(event, text, author, channelString, guid, channelNum, channelBase)
	-- other players' crafting ("X creates Y") only when you want it
	if event == "TRADESKILLS" and not ChA.char.othersCrafting and not IsSecret(author) and not IsSecret(text) then
		local me = UnitName("player")
		if type(author) == "string" and author ~= "" then
			if shortName(author) ~= me then return end
		elseif type(text) == "string" and not text:find("^You ") and not (me and text:find(me, 1, true)) then
			return -- the crafter's name is only in the text
		end
	end
	local secret = IsSecret(text) or IsSecret(author) or IsSecret(channelBase)
	local base = not IsSecret(channelBase) and channelBase or nil
	if (not base or base == "") and type(channelString) == "string" and not IsSecret(channelString) then
		base = channelString:gsub("^%d+%.%s*", ""):gsub("%s*%-.*$", "")
	end
	local room, kind = roomOf(event, author, base)
	local m = { t = time(), event = event, text = text, author = author, room = room, kind = kind,
		secret = secret or nil, channel = base, channelNum = not IsSecret(channelNum) and channelNum or nil,
		color = not secret and classColor(Safe(guid, nil)) or nil }
	self.rooms[room] = self.rooms[room] or {}
	push(self.rooms[room], m, MAX_ROOM)
	push(self.all, m, MAX_ALL)
	self.seen[room] = m.t
	-- whispers are kept between sessions (plain text only)
	if kind == "whispers" and not secret then
		local key = room:sub(4)
		local keep = ChA.db.whispers[key] or {}
		push(keep, { t = m.t, event = event, text = text, author = author }, KEEP_WHISPERS)
		ChA.db.whispers[key] = keep
	end
	local mine = event == "WHISPER_INFORM" or event == "BN_WHISPER_INFORM"
	if room ~= ChA.char.current and not mine then self.unread[room] = (self.unread[room] or 0) + 1 end
	ChA:Fire("MESSAGE", m)
	return m
end

-- your own tabs: does this message belong in it?
function St.Matches(tab, m)
	if not tab then return false end
	-- a whole kind, or (for channels) just the channels you ticked
	local yes = tab.kinds and tab.kinds[m.kind]
	if not yes and m.kind == "channels" and tab.channels and m.channel then yes = tab.channels[m.channel] end
	if not yes then return false end
	if tab.word and tab.word ~= "" then
		if m.secret or type(m.text) ~= "string" then return false end
		return m.text:lower():find(tab.word:lower(), 1, true) ~= nil
	end
	return true
end

-- messages of a room key ("all", a room, or "tab:<n>")
function St:List(key)
	if key == "all" then return self.all end
	local n = type(key) == "string" and tonumber(key:match("^tab:(%d+)$"))
	if n then
		local tab, out = ChA.db.tabs[n], {}
		for _, m in ipairs(self.all) do if St.Matches(tab, m) then out[#out + 1] = m end end
		return out
	end
	return self.rooms[key] or {}
end

function St:Read(key)
	self.unread[key] = nil
end

function St:OnEnable()
	-- whispers from earlier sessions come back as their rooms
	for key, list in pairs(ChA.db.whispers) do
		local room = "dm:" .. key
		self.rooms[room] = {}
		for _, w in ipairs(list) do
			local m = { t = w.t, event = w.event, text = w.text, author = w.author, room = room, kind = "whispers", old = true }
			push(self.rooms[room], m, MAX_ROOM)
			self.seen[room] = math.max(self.seen[room] or 0, w.t or 0)
		end
	end
	for event in pairs(MAP) do
		ChA:On("CHAT_MSG_" .. event, function(ev, text, author, _, channelString, _, _, _, channelNum, channelBase, _, _, guid)
			local ok, err = pcall(St.Add, St, ev:sub(10), text, author, channelString, guid, channelNum, channelBase)
			if not ok and ChA.debug then ChA:Print("store: " .. tostring(err)) end
		end)
	end
end
