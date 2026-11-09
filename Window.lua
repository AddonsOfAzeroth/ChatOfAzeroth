-- Chat of Azeroth by DinX: the window. Left: rooms (like Discord channels),
-- unread counts in bold, no blinking. Middle: the messages of the room you
-- picked. Bottom: Blizzard's own input box, set to that room, so you still
-- type and send every line yourself. "+ New tab" makes your own filtered tab.
local _, ns = ...
local ChA = ns.ChA
local L = ChA.L
local S = ChA.Style
local St = ChA.Store
local Safe, IsSecret = ChA.Safe, ChA.IsSecret

local W = ChA:NewModule("Window")

local HEAD, INPUT, ROW, PAD = 24, 26, 20, 4
local hider = CreateFrame("Frame")
hider:Hide()

-- fixed rooms, in this order; group rooms only when you are in one (or they have messages)
local FIXED = {
	{ key = "all", label = "All" },
	{ key = "system", label = "System" },
	{ key = "loot", label = "Loot" },
	{ key = "local", label = "Say and emotes" },
	{ key = "combatlog", label = "Combat log", need = function() return (_G.COMBATLOG or _G.ChatFrame2) ~= nil end },
	{ key = "guild", label = "Guild", need = function() return IsInGuild and IsInGuild() end },
	{ key = "party", label = "Party", need = function() return IsInGroup() end },
	{ key = "raid", label = "Raid", need = function() return IsInRaid() end },
	{ key = "instance", label = "Instance", need = function() return IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) end },
}
local KIND_LABEL = { system = "System", loot = "Loot", ["local"] = "Say and emotes", guild = "Guild", party = "Party",
	raid = "Raid", instance = "Instance", channels = "Channels", whispers = "Whispers" }
W.KIND_LABEL = KIND_LABEL

local function cfg() return ChA.char end

---------------------------------------------------------------------------
-- Where your typing goes: Blizzard's input box, set to the room you picked
---------------------------------------------------------------------------
local function editBox()
	return (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or _G.ChatFrame1EditBox
end

local function targetFor(key)
	if key == "local" then return "SAY" end
	if key == "guild" then return "GUILD" end
	if key == "party" then return "PARTY" end
	if key == "raid" then return "RAID" end
	if key == "instance" then return "INSTANCE_CHAT" end
	local ch = key:match("^ch:(.+)$")
	if ch and GetChannelName then
		local id = GetChannelName(ch)
		if id and id > 0 then return "CHANNEL", id end
	end
	local who = key:match("^dm:(.+)$")
	if who and who ~= "?" then return "WHISPER", who end
end

local function aimInput(key)
	local eb = editBox()
	local kind, target = targetFor(key)
	if not (eb and kind) then return end
	eb:SetAttribute("chatType", kind)
	if kind == "CHANNEL" then eb:SetAttribute("channelTarget", target) end
	if kind == "WHISPER" then eb:SetAttribute("tellTarget", target) end
	if ChatEdit_UpdateHeader then pcall(ChatEdit_UpdateHeader, eb) end
end

---------------------------------------------------------------------------
-- Blizzard's chat windows out of sight (their input box moves into ours)
---------------------------------------------------------------------------
local BLIZZARD_BITS = { "GeneralDockManager", "CombatLogQuickButtonFrame_Custom", "ChatFrameMenuButton", "ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton" }

function W:HideBlizzard()
	if not cfg().hideBlizzard then return end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local cf = _G["ChatFrame" .. i]
		if cf then
			cf:SetAlpha(0)
			cf:EnableMouse(false)
			if cf.EnableMouseWheel then cf:EnableMouseWheel(false) end
		end
		local tab = _G["ChatFrame" .. i .. "Tab"]
		if tab then tab:SetAlpha(0) tab:EnableMouse(false) end
		local bg = _G["ChatFrame" .. i .. "ButtonFrame"]
		if bg then bg:SetAlpha(0) end
	end
	for _, n in ipairs(BLIZZARD_BITS) do
		local f = _G[n]
		if f then f:SetAlpha(0) if f.EnableMouse then f:EnableMouse(false) end end
	end
end

function W:PlaceInput()
	local eb = editBox()
	if not (eb and self.frame) then return end
	eb:SetParent(self.frame)
	eb:ClearAllPoints()
	eb:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", cfg().sidebar + PAD, 2)
	eb:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -PAD, 2)
	eb:SetHeight(INPUT - 4)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function roomLabel(key)
	for _, r in ipairs(FIXED) do if r.key == key then return L[r.label] end end
	local ch = key:match("^ch:(.+)$")
	if ch then return "# " .. ch end
	local who = key:match("^dm:(.+)$")
	if who then return "@ " .. who end
	local n = tonumber(key:match("^tab:(%d+)$"))
	if n and ChA.db.tabs[n] then return "+ " .. ChA.db.tabs[n].name end
	return key
end
W.RoomLabel = roomLabel

function W:Build()
	local c = cfg()
	local f = CreateFrame("Frame", "ChatOfAzerothWindow", UIParent, "BackdropTemplate")
	S:Backdrop(f, 0.85)
	f:SetSize(c.width, c.height)
	f:SetFrameStrata("LOW")
	self.frame = f

	-- sidebar
	local side = CreateFrame("Frame", nil, f, "BackdropTemplate")
	side:SetPoint("TOPLEFT", 1, -1)
	side:SetPoint("BOTTOMLEFT", 1, 1)
	side:SetWidth(c.sidebar)
	side:SetBackdrop({ bgFile = S.flat })
	side:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
	side:EnableMouseWheel(true)
	side:SetScript("OnMouseWheel", function(_, d)
		W.sideOffset = math.max(0, (W.sideOffset or 0) - d)
		W:RenderSidebar()
	end)
	self.side = side
	self.buttons = {}

	-- header: the room you are in
	self.title = S:Font(f, 13)
	self.title:SetPoint("TOPLEFT", c.sidebar + 10, -6)
	self.title:SetTextColor(unpack(S.colors.accent))
	self.topic = S:Font(f, 10)
	self.topic:SetPoint("LEFT", self.title, "RIGHT", 8, 0)
	self.topic:SetTextColor(unpack(S.colors.muted))
	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(unpack(S.colors.edge))
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", c.sidebar + 1, -HEAD)
	line:SetPoint("TOPRIGHT", -1, -HEAD)

	-- messages
	local smf = CreateFrame("ScrollingMessageFrame", nil, f)
	smf:SetPoint("TOPLEFT", c.sidebar + 8, -HEAD - 4)
	smf:SetPoint("BOTTOMRIGHT", -8, INPUT + 2)
	smf:SetFont(S.font, c.fontSize, S.flags)
	smf:SetShadowColor(0, 0, 0, 1)
	smf:SetShadowOffset(1, -1)
	smf:SetJustifyH("LEFT")
	smf:SetFading(false)
	smf:SetMaxLines(500)
	smf:SetHyperlinksEnabled(true)
	smf:EnableMouseWheel(true)
	smf:SetScript("OnMouseWheel", function(self, d)
		if IsShiftKeyDown() then
			if d > 0 then self:ScrollToTop() else self:ScrollToBottom() end
		elseif d > 0 then self:ScrollUp() else self:ScrollDown() end
	end)
	smf:SetScript("OnHyperlinkClick", function(self, link, text, button)
		if SetItemRef then SetItemRef(link, text, button, DEFAULT_CHAT_FRAME) end
	end)
	smf:SetScript("OnHyperlinkEnter", function(self, link)
		local kind = link:match("^(%a+):")
		if kind == "item" or kind == "spell" or kind == "quest" or kind == "achievement" or kind == "enchant" then
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			pcall(GameTooltip.SetHyperlink, GameTooltip, link)
			GameTooltip:Show()
		end
	end)
	smf:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
	self.messages = smf

	-- input area background (Blizzard's input box sits on it)
	local inp = f:CreateTexture(nil, "BORDER")
	inp:SetColorTexture(0, 0, 0, 0.35)
	inp:SetPoint("BOTTOMLEFT", c.sidebar + 1, 1)
	inp:SetPoint("BOTTOMRIGHT", -1, 1)
	inp:SetHeight(INPUT)

	-- settings, always one click away
	local gear = CreateFrame("Button", nil, f)
	gear:SetHeight(18)
	gear:SetPoint("TOPRIGHT", -20, -3)
	gear.text = S:Font(gear, 10)
	gear.text:SetPoint("RIGHT")
	gear.text:SetText(L["Settings"])
	gear.text:SetTextColor(unpack(S.colors.muted))
	gear:SetWidth(gear.text:GetStringWidth() + 6)
	gear:SetScript("OnClick", function() ChA:ToggleConfig() end)
	gear:SetScript("OnEnter", function(b) b.text:SetTextColor(unpack(S.colors.accent)) end)
	gear:SetScript("OnLeave", function(b) b.text:SetTextColor(unpack(S.colors.muted)) end)

	-- the chat sits at the bottom of the screen: its grip is top-right and it grows upward
	local sizing = S:Sizing(f, "chat", { min = { 360, 140 }, max = { 1600, 900 }, apply = function(w, h)
		c.width, c.height = w or 560, h or 230
		f:SetSize(c.width, c.height)
		W:RenderSidebar()
	end })
	sizing.up = true
	S:RegisterMover(f, "chat", L["Chat"], function(fr)
		fr:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 8, 8)
	end, nil, sizing)
end

-- one sidebar entry
local function button(i)
	local b = W.buttons[i]
	if b then return b end
	b = CreateFrame("Button", nil, W.side)
	b:SetHeight(ROW)
	b:SetPoint("LEFT", 2, 0)
	b:SetPoint("RIGHT", -2, 0)
	b.hl = b:CreateTexture(nil, "BACKGROUND")
	b.hl:SetAllPoints()
	b.hl:SetColorTexture(0.41, 0.80, 0.94, 0.18)
	b.hl:Hide()
	b.text = S:Font(b, 12)
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -26, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	b.count = S:Font(b, 10)
	b.count:SetPoint("RIGHT", -6, 0)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, btn)
		if self.header then return end
		if self.key == "newtab" then return W:OpenTabEditor() end
		if self.key == "join" then return W:JoinChannel() end
		if btn == "RightButton" and self.key and self.key:match("^tab:") then return W:TabMenu(self.key) end
		W:Select(self.key)
	end)
	b:SetScript("OnEnter", function(self) if not self.header then self.text:SetTextColor(1, 1, 1) end end)
	b:SetScript("OnLeave", function() W:RenderSidebar() end)
	W.buttons[i] = b
	return b
end

-- the entries: { key, label, header = true for section titles }
function W:Entries()
	local out = {}
	local function add(key, label, header) out[#out + 1] = { key = key, label = label, header = header } end
	add(nil, L["Chat"], true)
	for _, r in ipairs(FIXED) do
		if not r.need or r.need() or (St.rooms[r.key] and #St.rooms[r.key] > 0) then add(r.key, L[r.label]) end
	end
	-- channels you are in (and ones with messages)
	local chans, seen = {}, {}
	if GetChannelList then
		local list = { GetChannelList() }
		for i = 1, #list, 3 do
			local name = list[i + 1]
			if type(name) == "string" and not seen[name] then seen[name] = true chans[#chans + 1] = name end
		end
	end
	for key in pairs(St.rooms) do
		local ch = key:match("^ch:(.+)$")
		if ch and not seen[ch] then seen[ch] = true chans[#chans + 1] = ch end
	end
	add(nil, L["Channels"], true)
	for _, ch in ipairs(chans) do add("ch:" .. ch, "# " .. ch) end
	add("join", L["+ Join channel"])
	-- whispers, the most recent first
	local dms = {}
	for key in pairs(St.rooms) do if key:match("^dm:") then dms[#dms + 1] = key end end
	table.sort(dms, function(a, b) return (St.seen[a] or 0) > (St.seen[b] or 0) end)
	if #dms > 0 then
		add(nil, L["Whispers"], true)
		for i = 1, math.min(8, #dms) do add(dms[i], "@ " .. dms[i]:sub(4)) end
	end
	add(nil, L["Your tabs"], true)
	for i, t in ipairs(ChA.db.tabs) do add("tab:" .. i, t.name) end
	add("newtab", L["+ New tab"])
	return out
end

function W:RenderSidebar()
	if not self.side then return end
	local entries = self:Entries()
	local fit = math.max(1, math.floor((self.frame:GetHeight() - 8) / ROW))
	self.sideOffset = math.min(self.sideOffset or 0, math.max(0, #entries - fit))
	local cur = cfg().current
	local n = 0
	for i = self.sideOffset + 1, math.min(#entries, self.sideOffset + fit) do
		local e = entries[i]
		n = n + 1
		local b = button(n)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", W.side, "TOPLEFT", 2, -4 - (n - 1) * ROW)
		b:SetPoint("TOPRIGHT", W.side, "TOPRIGHT", -2, -4 - (n - 1) * ROW)
		b.key, b.header = e.key, e.header
		b.text:SetText(e.label)
		local unread = e.key and St.unread[e.key]
		if e.header then
			S:ApplyFont(b.text, 10)
			b.text:SetTextColor(unpack(S.colors.muted))
			b.count:SetText("")
			b.hl:Hide()
		else
			S:ApplyFont(b.text, 12, unread and "OUTLINE" or nil)
			if e.key == cur then b.text:SetTextColor(unpack(S.colors.accent))
			elseif unread then b.text:SetTextColor(1, 1, 1)
			else b.text:SetTextColor(unpack(S.colors.text)) end
			b.count:SetText(unread and (unread > 99 and "99+" or unread) or "")
			b.hl:SetShown(e.key == cur)
		end
		b:Show()
	end
	for i = n + 1, #self.buttons do self.buttons[i]:Hide() end
end

-- add one message to the view (shown as is when Blizzard hides its text)
local function show(m)
	local smf = W.messages
	local line = St.Format(m)
	local r, g, b = St.Color(m)
	if line then
		smf:AddMessage(line, r, g, b)
	else
		pcall(smf.AddMessage, smf, m.text, r, g, b)
	end
end

-- Combat log: addons can't read it here, so Blizzard's own combat log window
-- is shown in our message area while you are in that room
local function combatLogFrame() return _G.COMBATLOG or _G.ChatFrame2 end

function W:ShowCombatLog(on)
	local cl = combatLogFrame()
	local qb = _G.CombatLogQuickButtonFrame_Custom
	if not cl then return end
	if on then
		cl:ClearAllPoints()
		cl:SetPoint("TOPLEFT", self.messages, "TOPLEFT", 0, qb and -22 or 0)
		cl:SetPoint("BOTTOMRIGHT", self.messages, "BOTTOMRIGHT", 0, 0)
		cl:SetAlpha(1)
		-- same text as the rest of our chat (not saved in Blizzard's chat settings)
		pcall(cl.SetFont, cl, S.font, cfg().fontSize, S.flags)
		cl:EnableMouse(true)
		if cl.EnableMouseWheel then cl:EnableMouseWheel(true) end
		if not cl:IsShown() then cl:Show() end
		if qb then qb:SetAlpha(1) qb:EnableMouse(true) end
		self.messages:Hide()
	else
		if cfg().hideBlizzard then
			cl:SetAlpha(0)
			cl:EnableMouse(false)
			if cl.EnableMouseWheel then cl:EnableMouseWheel(false) end
			if qb then qb:SetAlpha(0) qb:EnableMouse(false) end
		end
		self.messages:Show()
	end
end

function W:Select(key)
	local c = cfg()
	c.current = key or "all"
	St:Read(c.current)
	self.title:SetText(roomLabel(c.current))
	self:ShowCombatLog(c.current == "combatlog")
	if c.current == "combatlog" then
		self.topic:SetText(L["Blizzard's own combat log"])
		return self:RenderSidebar()
	end
	local kind, target = targetFor(c.current)
	self.topic:SetText(kind and L["typing goes here"] or "")
	self.messages:Clear()
	for _, m in ipairs(St:List(c.current)) do show(m) end
	self.messages:ScrollToBottom()
	aimInput(c.current)
	self:RenderSidebar()
end

function W:OnMessage(m)
	local cur = cfg().current
	local inView = cur == "all" or m.room == cur
	local n = type(cur) == "string" and tonumber(cur:match("^tab:(%d+)$"))
	if n then inView = St.Matches(ChA.db.tabs[n], m) end
	if inView then show(m) end
	self:RenderSidebar()
end

-- our chat off (or "hide Blizzard's" off): their windows and input box come back
function W:RestoreBlizzard()
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local cf = _G["ChatFrame" .. i]
		if cf then cf:SetAlpha(1) cf:EnableMouse(true) if cf.EnableMouseWheel then cf:EnableMouseWheel(true) end end
		local tab = _G["ChatFrame" .. i .. "Tab"]
		if tab then tab:SetAlpha(1) tab:EnableMouse(true) end
		local bg = _G["ChatFrame" .. i .. "ButtonFrame"]
		if bg then bg:SetAlpha(1) end
	end
	for _, n in ipairs(BLIZZARD_BITS) do
		local f = _G[n]
		if f then f:SetAlpha(1) if f.EnableMouse then f:EnableMouse(true) end end
	end
	local eb = editBox()
	if eb and _G.ChatFrame1 and eb:GetParent() == self.frame then
		eb:SetParent(_G.ChatFrame1)
		eb:ClearAllPoints()
		eb:SetPoint("TOPLEFT", _G.ChatFrame1, "BOTTOMLEFT", -5, -2)
		eb:SetPoint("TOPRIGHT", _G.ChatFrame1, "BOTTOMRIGHT", 5, -2)
	end
end

function W:Apply()
	local c = cfg()
	if not self.frame then return end
	self.frame:SetShown(c.enabled)
	if not c.enabled or not c.hideBlizzard then self:RestoreBlizzard() end
	if c.enabled then
		self:HideBlizzard()
		self:PlaceInput()
		self.messages:SetFont(S.font, c.fontSize, S.flags)
		self:Select(c.current)
	end
end

---------------------------------------------------------------------------
-- Your own tabs: a name, which kinds of messages, optionally a word
---------------------------------------------------------------------------
local KIND_ORDER = { "system", "loot", "local", "guild", "party", "raid", "instance", "channels", "whispers" }

function W:OpenTabEditor(index)
	local d = self.editor
	if not d then
		d = CreateFrame("Frame", "ChatOfAzerothTabEditor", UIParent, "BackdropTemplate")
		S:Backdrop(d, 0.97)
		d:SetSize(300, 420)
		d:SetPoint("CENTER")
		d:SetFrameStrata("DIALOG")
		d:EnableMouse(true)
		tinsert(UISpecialFrames, "ChatOfAzerothTabEditor")
		local t = S:Font(d, 13)
		t:SetPoint("TOPLEFT", 12, -10)
		t:SetText(L["Your own tab"])
		t:SetTextColor(unpack(S.colors.accent))
		local function edit(label, y)
			local l = S:Font(d, 11)
			l:SetPoint("TOPLEFT", 12, y)
			l:SetText(label)
			local e = CreateFrame("EditBox", nil, d, "BackdropTemplate")
			S:Backdrop(e, 1)
			e:SetSize(270, 22)
			e:SetPoint("TOPLEFT", 12, y - 16)
			e:SetFont(S.font, 12, "")
			e:SetTextInsets(6, 6, 0, 0)
			e:SetAutoFocus(false)
			e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
			return e
		end
		d.name = edit(L["Name"], -34)
		d.checks = {}
		for i, k in ipairs(KIND_ORDER) do
			local cb = CreateFrame("CheckButton", nil, d, "UICheckButtonTemplate")
			cb:SetSize(22, 22)
			cb:SetPoint("TOPLEFT", 12 + ((i - 1) % 2) * 140, -80 - math.floor((i - 1) / 2) * 24)
			local l = S:Font(d, 11)
			l:SetPoint("LEFT", cb, "RIGHT", 2, 0)
			l:SetText(L[KIND_LABEL[k]])
			cb.kind = k
			d.checks[i] = cb
		end
		-- single channels (only these, when "Channels" itself is off)
		d.chanLabel = S:Font(d, 11)
		d.chanLabel:SetPoint("TOPLEFT", 12, -204)
		d.chanLabel:SetText(L["Or only these channels:"])
		d.chanChecks = {}
		for i = 1, 8 do
			local cb = CreateFrame("CheckButton", nil, d, "UICheckButtonTemplate")
			cb:SetSize(22, 22)
			cb:SetPoint("TOPLEFT", 12 + ((i - 1) % 2) * 140, -220 - math.floor((i - 1) / 2) * 24)
			cb.label = S:Font(d, 11)
			cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
			d.chanChecks[i] = cb
		end
		d.word = edit(L["Only messages with this word (optional)"], -322)
		local function btn(label, x, fn)
			local b = CreateFrame("Button", nil, d, "BackdropTemplate")
			S:Backdrop(b, 1)
			b:SetSize(130, 22)
			b:SetPoint("BOTTOMLEFT", x, 12)
			b.text = S:Font(b, 12)
			b.text:SetPoint("CENTER")
			b.text:SetText(label)
			b:SetScript("OnClick", fn)
			b:SetScript("OnEnter", function() b:SetBackdropBorderColor(unpack(S.colors.accent)) end)
			b:SetScript("OnLeave", function() b:SetBackdropBorderColor(0, 0, 0, 1) end)
		end
		btn(L["Save"], 12, function()
			local name = d.name:GetText()
			if not name or name:match("^%s*$") then return end
			local tab = { name = name, kinds = {}, channels = {}, word = d.word:GetText() }
			for _, cb in ipairs(d.checks) do if cb:GetChecked() then tab.kinds[cb.kind] = true end end
			for _, cb in ipairs(d.chanChecks) do if cb:IsShown() and cb:GetChecked() then tab.channels[cb.channel] = true end end
			if d.index then ChA.db.tabs[d.index] = tab else table.insert(ChA.db.tabs, tab) d.index = #ChA.db.tabs end
			d:Hide()
			W:Select("tab:" .. d.index)
		end)
		btn(L["Cancel"], 158, function() d:Hide() end)
		self.editor = d
	end
	local tab = index and ChA.db.tabs[index]
	d.index = index
	d.name:SetText(tab and tab.name or "")
	d.word:SetText(tab and tab.word or "")
	for _, cb in ipairs(d.checks) do cb:SetChecked(tab and tab.kinds[cb.kind] or false) end
	-- the channels you are in
	local chans = {}
	if GetChannelList then
		local list = { GetChannelList() }
		for i = 1, #list, 3 do if type(list[i + 1]) == "string" then chans[#chans + 1] = list[i + 1] end end
	end
	for i, cb in ipairs(d.chanChecks) do
		local ch = chans[i]
		cb.channel = ch
		cb:SetShown(ch ~= nil)
		cb.label:SetShown(ch ~= nil)
		cb.label:SetText(ch and ("# " .. ch) or "")
		cb:SetChecked(ch and tab and tab.channels and tab.channels[ch] or false)
	end
	d.chanLabel:SetShown(#chans > 0)
	d:Show()
	d.name:SetFocus()
end

-- "+ Join channel": type a name, you join it (Blizzard's own join)
function W:JoinChannel()
	StaticPopupDialogs.CHATOFAZEROTH_JOIN = StaticPopupDialogs.CHATOFAZEROTH_JOIN or { button1 = OKAY, button2 = CANCEL,
		hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
	local p = StaticPopupDialogs.CHATOFAZEROTH_JOIN
	p.text = L["Which channel do you want to join?"]
	local function join(popup)
		local box = popup.editBox or popup.EditBox
		local name = box and box:GetText()
		if not name or name:match("^%s*$") then return end
		name = name:gsub("^#", ""):gsub("%s", "")
		if JoinPermanentChannel then JoinPermanentChannel(name) elseif JoinChannelByName then JoinChannelByName(name) end
		C_Timer.After(1, function() W:Select("ch:" .. name) end)
	end
	p.OnAccept = join
	p.EditBoxOnEnterPressed = function(box) join(box:GetParent()) box:GetParent():Hide() end
	StaticPopup_Show("CHATOFAZEROTH_JOIN")
end

-- right-click on your tab: change or delete it
function W:TabMenu(key)
	local n = tonumber(key:match("^tab:(%d+)$"))
	local tab = n and ChA.db.tabs[n]
	if not tab then return end
	StaticPopupDialogs.CHATOFAZEROTH_TAB = StaticPopupDialogs.CHATOFAZEROTH_TAB or { button1 = L["Change"],
		button2 = L["Delete"], button3 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
	local p = StaticPopupDialogs.CHATOFAZEROTH_TAB
	p.text = L["Your tab \"%s\""]:format(tab.name)
	p.OnAccept = function() W:OpenTabEditor(n) end
	p.OnCancel = function(_, _, reason)
		if reason == "clicked" then
			table.remove(ChA.db.tabs, n)
			if cfg().current == key then W:Select("all") else W:RenderSidebar() end
		end
	end
	StaticPopup_Show("CHATOFAZEROTH_TAB")
end

function W:OnEnable()
	self:Build()
	ChA:Listen("MESSAGE", function(m) local ok = pcall(W.OnMessage, W, m) end)
	ChA:Listen("SETTINGS", function(group) if group == "chat" then pcall(W.Apply, W) end end)
	ChA:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function() pcall(W.Apply, W) end) end)
	ChA:On("UPDATE_CHAT_WINDOWS", function() C_Timer.After(0.5, function()
		if not cfg().enabled then return end
		pcall(W.HideBlizzard, W)
		if cfg().current == "combatlog" then pcall(W.ShowCombatLog, W, true) end
	end) end)
	ChA:On("GROUP_ROSTER_UPDATE", function() pcall(W.RenderSidebar, W) end)
	ChA:On("CHANNEL_UI_UPDATE", function() pcall(W.RenderSidebar, W) end)
	pcall(W.Apply, W)
end
