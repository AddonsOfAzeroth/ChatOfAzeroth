-- Chat of Azeroth by DinX: right-click menus and the small extras.
-- Right-click a room: leave or mute a channel, keep it out of "All", close a
-- whisper, rename / move / delete your tab, clear the view, copy its text.
-- A quiet "new messages" bar when you scroll up, a "..." menu with Blizzard's
-- own chat buttons, and the view follows when you type /g or /w.
-- Every leave, ignore or send is your own click.
local _, ns = ...
local ChA = ns.ChA
local L = ChA.L
local S = ChA.Style
local St = ChA.Store
local W = ChA.Window

local function cfg() return ChA.char end

---------------------------------------------------------------------------
-- A small menu at the mouse: { { text, fn }, ... }; "-" is a line
---------------------------------------------------------------------------
local menu
function W:Menu(title, items)
	if not menu then
		menu = CreateFrame("Frame", "ChatOfAzerothMenu", UIParent, "BackdropTemplate")
		S:Backdrop(menu, 0.97)
		menu:SetFrameStrata("DIALOG")
		menu:SetClampedToScreen(true)
		menu:EnableMouse(true)
		menu.rows = {}
		W.menuFrame = menu
		menu.title = S:Font(menu, 10)
		menu.title:SetPoint("TOPLEFT", 8, -6)
		menu.title:SetTextColor(unpack(S.colors.muted))
		tinsert(UISpecialFrames, "ChatOfAzerothMenu")
		-- gone a moment after the mouse leaves it
		menu:SetScript("OnUpdate", function(self, el)
			if self:IsMouseOver() then self.away = 0 return end
			self.away = (self.away or 0) + el
			if self.away > 1.2 then self:Hide() end
		end)
	end
	menu.title:SetText(title or "")
	local y, w = -22, 140
	for _, r in ipairs(menu.rows) do r:Hide() end
	for i, it in ipairs(items) do
		local r = menu.rows[i]
		if not r then
			r = CreateFrame("Button", nil, menu)
			r:SetHeight(18)
			r.text = S:Font(r, 12)
			r.text:SetPoint("LEFT", 8, 0)
			r.line = r:CreateTexture(nil, "ARTWORK")
			r.line:SetColorTexture(unpack(S.colors.edge))
			r.line:SetHeight(1)
			r.line:SetPoint("LEFT", 6, 0)
			r.line:SetPoint("RIGHT", -6, 0)
			r:SetScript("OnEnter", function(b) if b.fn then b.text:SetTextColor(unpack(S.colors.accent)) end end)
			r:SetScript("OnLeave", function(b) b.text:SetTextColor(unpack(S.colors.text)) end)
			r:SetScript("OnClick", function(b) if b.fn then menu:Hide() b.fn() end end)
			menu.rows[i] = r
		end
		local sep = it == "-"
		r.fn = not sep and it[2] or nil
		r.text:SetText(sep and "" or it[1])
		r.text:SetTextColor(unpack(S.colors.text))
		r.line:SetShown(sep)
		r:SetHeight(sep and 7 or 18)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, y)
		r:SetPoint("TOPRIGHT", 0, y)
		r:Show()
		y = y - (sep and 7 or 18)
		if not sep then w = math.max(w, r.text:GetStringWidth() + 24) end
	end
	menu:SetSize(math.max(w, menu.title:GetStringWidth() + 16), -y + 6)
	local x, cy = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - 6, cy / s + 6)
	menu.away = 0
	menu:Show()
end

---------------------------------------------------------------------------
-- Yes / no, and a name to type (Blizzard's own popups)
---------------------------------------------------------------------------
local function confirm(text, yes)
	StaticPopupDialogs.CHATOFAZEROTH_CONFIRM = StaticPopupDialogs.CHATOFAZEROTH_CONFIRM or { button1 = YES, button2 = NO,
		timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
	local p = StaticPopupDialogs.CHATOFAZEROTH_CONFIRM
	p.text, p.OnAccept = text, yes
	StaticPopup_Show("CHATOFAZEROTH_CONFIRM")
end

local function ask(text, current, done)
	StaticPopupDialogs.CHATOFAZEROTH_ASK = StaticPopupDialogs.CHATOFAZEROTH_ASK or { button1 = OKAY, button2 = CANCEL,
		hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
	local p = StaticPopupDialogs.CHATOFAZEROTH_ASK
	local function box(popup) return popup.editBox or popup.EditBox end
	p.text = text
	p.OnShow = function(popup) local b = box(popup) if b then b:SetText(current or "") b:HighlightText() end end
	p.OnAccept = function(popup) local b = box(popup) local v = b and b:GetText() if v and not v:match("^%s*$") then done(v) end end
	p.EditBoxOnEnterPressed = function(b) p.OnAccept(b:GetParent()) b:GetParent():Hide() end
	StaticPopup_Show("CHATOFAZEROTH_ASK")
end

---------------------------------------------------------------------------
-- Copy: a box with plain text to select and Ctrl+C
---------------------------------------------------------------------------
local function plain(s)
	if type(s) ~= "string" then return "" end
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
	return s
end
W.Plain = plain

function W:CopyBox(text, title)
	local f = self.copy
	if not f then
		f = CreateFrame("Frame", "ChatOfAzerothCopy", UIParent, "BackdropTemplate")
		S:Backdrop(f, 0.97)
		f:SetSize(520, 300)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:EnableMouse(true)
		tinsert(UISpecialFrames, "ChatOfAzerothCopy")
		f.title = S:Font(f, 11)
		f.title:SetPoint("TOPLEFT", 10, -8)
		f.title:SetTextColor(unpack(S.colors.muted))
		local close = CreateFrame("Button", nil, f)
		close:SetSize(18, 18)
		close:SetPoint("TOPRIGHT", -4, -4)
		close.t = S:Font(close, 13)
		close.t:SetPoint("CENTER")
		close.t:SetText("x")
		close:SetScript("OnClick", function() f:Hide() end)
		local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 10, -26)
		sf:SetPoint("BOTTOMRIGHT", -28, 10)
		local eb = CreateFrame("EditBox", nil, sf)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFont(S.font, 12, "")
		eb:SetWidth(480)
		eb:SetScript("OnEscapePressed", function() f:Hide() end)
		sf:SetScrollChild(eb)
		f.edit = eb
		self.copy = f
	end
	f.title:SetText(title or L["Select and press Ctrl+C to copy. Esc closes."])
	f.edit:SetText(text or "")
	f:Show()
	f.edit:SetFocus()
	f.edit:HighlightText()
end

function W:CopyRoom(key)
	local list, out = St:List(key), {}
	for i = math.max(1, #list - 99), #list do
		local m = list[i]
		local line = not m.secret and St.Format(m)
		out[#out + 1] = line and plain(line) or L["(a line Blizzard hides from add-ons)"]
	end
	self:CopyBox(table.concat(out, "\n"))
end

---------------------------------------------------------------------------
-- The right-click menu of a room
---------------------------------------------------------------------------
local function fullChannelName(base)
	if not GetChannelList then return end
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		if type(list[i + 1]) == "string" and St.BaseName(list[i + 1]) == base then return list[i + 1], list[i] end
	end
end

local function leave(ch)
	local full = fullChannelName(ch) or ch
	local ok = pcall(LeaveChannelByName, full)
	if not ok then ChA:Print(L["Couldn't leave that channel now (try again out of combat)."]) end
	C_Timer.After(0.5, function() W:Select("all") end)
end

local function ignore(name)
	local f = (C_FriendList and C_FriendList.AddIgnore) or AddIgnore
	if f then pcall(f, name) end
end

local function moveTab(n, d)
	local tabs = ChA.db.tabs
	local m = n + d
	if m < 1 or m > #tabs then return end
	tabs[n], tabs[m] = tabs[m], tabs[n]
	St.unread["tab:" .. n], St.unread["tab:" .. m] = St.unread["tab:" .. m], St.unread["tab:" .. n]
	if cfg().current == "tab:" .. n then cfg().current = "tab:" .. m elseif cfg().current == "tab:" .. m then cfg().current = "tab:" .. n end
	W:Select(cfg().current)
end

function W:RoomMenu(key)
	if key == "combatlog" then return end
	local items = {}
	local function add(text, fn) items[#items + 1] = { text, fn } end
	local ch = key:match("^ch:(.+)$")
	local who = key:match("^dm:(.+)$")
	local n = tonumber(key:match("^tab:(%d+)$"))
	if ch then
		add(cfg().muted[key] and L["Unmute"] or L["Mute (no unread count)"], function()
			cfg().muted[key] = not cfg().muted[key] or nil
			St:Read(key)
			W:RenderSidebar()
		end)
		add(cfg().notInAll[ch] and L["Show in \"All\" again"] or L["Not in \"All\""], function()
			cfg().notInAll[ch] = not cfg().notInAll[ch] or nil
			if cfg().current == "all" then W:Select("all") end
		end)
		add(L["Leave channel"], function() leave(ch) end)
		items[#items + 1] = "-"
	elseif who then
		add(L["Close conversation"], function()
			St:Forget(key)
			if cfg().current == key then W:Select("all") else W:RenderSidebar() end
		end)
		if who ~= "?" then
			add(L["Ignore %s"]:format(who), function()
				confirm(L["Ignore %s? Their messages won't reach you any more."]:format(who), function() ignore(who) end)
			end)
		end
		items[#items + 1] = "-"
	elseif n and ChA.db.tabs[n] then
		local tab = ChA.db.tabs[n]
		add(L["Rename"], function() ask(L["New name for this tab:"], tab.name, function(v) tab.name = v W:Select(cfg().current) end) end)
		add(L["What it shows..."], function() W:OpenTabEditor(n) end)
		if n > 1 then add(L["Move up"], function() moveTab(n, -1) end) end
		if n < #ChA.db.tabs then add(L["Move down"], function() moveTab(n, 1) end) end
		add(L["Delete..."], function()
			confirm(L["Delete tab \"%s\"?"]:format(tab.name), function()
				table.remove(ChA.db.tabs, n)
				St.unread[key] = nil
				if cfg().current == key then W:Select("all") else W:RenderSidebar() end
			end)
		end)
		items[#items + 1] = "-"
	end
	add(L["Clear window"], function()
		if cfg().current ~= key then W:Select(key) end
		W.messages:Clear()
		W:NewLines(0)
	end)
	add(L["Copy text..."], function() W:CopyRoom(key) end)
	self:Menu(W.RoomLabel(key), items)
end

---------------------------------------------------------------------------
-- "New messages" bar: you scrolled up and lines came in
---------------------------------------------------------------------------
function W:NewLines(n)
	self.newCount = n
	local b = self.newBar
	if not b then
		if n == 0 or not self.messages then return end
		b = CreateFrame("Button", nil, self.frame, "BackdropTemplate")
		b:SetHeight(16)
		b:SetPoint("BOTTOMLEFT", self.messages, "BOTTOMLEFT", 0, 0)
		b:SetPoint("BOTTOMRIGHT", self.messages, "BOTTOMRIGHT", 0, 0)
		b:SetFrameLevel(self.messages:GetFrameLevel() + 5)
		b:SetBackdrop({ bgFile = S.flat })
		b:SetBackdropColor(0.10, 0.20, 0.26, 0.95)
		b.text = S:Font(b, 11)
		b.text:SetPoint("CENTER")
		b.text:SetTextColor(unpack(S.colors.accent))
		b:SetScript("OnClick", function() W.messages:ScrollToBottom() W:NewLines(0) end)
		self.newBar = b
	end
	b.text:SetText(L["%d new: click to go down"]:format(n))
	b:SetShown(n > 0)
end

---------------------------------------------------------------------------
-- "..." in the header: Blizzard's own chat buttons we hid
---------------------------------------------------------------------------
function W:MoreButton()
	local f = self.frame
	local b = CreateFrame("Button", nil, f)
	b:SetSize(22, 18)
	b:SetPoint("TOPRIGHT", -80, -3)
	b.text = S:Font(b, 13)
	b.text:SetPoint("CENTER")
	b.text:SetText("...")
	b.text:SetTextColor(unpack(S.colors.muted))
	b:SetScript("OnEnter", function(s) s.text:SetTextColor(unpack(S.colors.accent)) end)
	b:SetScript("OnLeave", function(s) s.text:SetTextColor(unpack(S.colors.muted)) end)
	b:SetScript("OnClick", function()
		local items = {}
		if ToggleFriendsFrame then items[#items + 1] = { L["Friends"], function() ToggleFriendsFrame() end } end
		if ToggleChannelFrame then items[#items + 1] = { L["Chat channels"], function() ToggleChannelFrame() end } end
		local menuButton = _G.ChatFrameMenuButton
		if menuButton and menuButton.Click then
			items[#items + 1] = { L["Emotes and language"], function()
				menuButton:ClearAllPoints()
				menuButton:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, 0)
				pcall(menuButton.Click, menuButton)
			end }
		end
		items[#items + 1] = { L["Copy text..."], function() W:CopyRoom(cfg().current) end }
		W:Menu(nil, items)
	end)
	self.more = b
end

---------------------------------------------------------------------------
-- The view follows your typing: /g shows Guild, /w Name that whisper.
-- In "All" or your own tab the header says where your line goes instead.
---------------------------------------------------------------------------
local TYPE_ROOM = { SAY = "local", YELL = "local", EMOTE = "local", GUILD = "guild", OFFICER = "guild",
	PARTY = "party", PARTY_LEADER = "party", RAID = "raid", RAID_WARNING = "raid", RAID_LEADER = "raid",
	INSTANCE_CHAT = "instance" }

local function roomOfInput(eb)
	local t = eb:GetAttribute("chatType")
	if TYPE_ROOM[t] then return TYPE_ROOM[t] end
	if t == "WHISPER" then
		local who = eb:GetAttribute("tellTarget")
		if type(who) == "string" and who ~= "" then return "dm:" .. who:gsub("%-.*$", "") end
	elseif t == "CHANNEL" then
		local id = tonumber(eb:GetAttribute("channelTarget"))
		local _, name = id and GetChannelName and GetChannelName(id)
		if type(name) == "string" then return "ch:" .. St.BaseName(name) end
	end
end
W.RoomOfInput = roomOfInput

function W:UpdateTopic()
	local cur = cfg().current
	if cur ~= "all" and not cur:match("^tab:") then return end
	local eb = W.EditBox()
	local room = eb and roomOfInput(eb)
	self.topic:SetText(room and L["typing to: %s"]:format(W.RoomLabel(room)) or "")
end

local function followInput(eb)
	if W.aiming or not (W.frame and cfg().enabled) or eb ~= W.EditBox() then return end
	local room = roomOfInput(eb)
	local cur = cfg().current
	if not room or room == cur then return end
	if cur == "all" or cur:match("^tab:") or cur == "combatlog" then return W:UpdateTopic() end
	W:Select(room)
end

local M = ChA:NewModule("Menus")
function M:OnEnable()
	if W.frame then W:MoreButton() end
	if hooksecurefunc and ChatEdit_UpdateHeader then
		hooksecurefunc("ChatEdit_UpdateHeader", function(eb)
			local ok, err = pcall(followInput, eb)
			if not ok and ChA.debug then ChA:Print("follow: " .. tostring(err)) end
		end)
	end
end
