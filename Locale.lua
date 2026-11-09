-- Chat of Azeroth by DinX: translations. Code uses English strings as keys: L["Text"].
local _, ns = ...
local ChA = ns.ChA

local NL = {}
ChA.translations = { nlNL = NL }

ChA.L = setmetatable({}, {
	__index = function(_, key)
		local lang = ChA.db and ChA.db.language or "auto"
		if lang == "auto" then -- follow Casters of Azeroth, else the client
			local c = ChA.Casters and ChA:Casters()
			lang = (c and c.db and c.db.language ~= "auto" and c.db.language) or (GetLocale() == "nlNL" and "nlNL") or "enUS"
		end
		local t = ChA.translations[lang]
		return t and t[key] or key
	end,
})

for k, v in pairs({
	-- rooms
	["All"] = "Alles",
	["System"] = "Systeem",
	["Loot"] = "Loot",
	["Say and emotes"] = "Say en emotes",
	["Combat log"] = "Combat log",
	["Blizzard's own combat log"] = "Blizzards eigen combat log",
	["Guild"] = "Guild",
	["Party"] = "Groep",
	["Raid"] = "Raid",
	["Instance"] = "Instance",
	["Channels"] = "Kanalen",
	["Whispers"] = "Fluisteren",
	["Chat"] = "Chat",
	["Your tabs"] = "Jouw tabs",
	["+ New tab"] = "+ Nieuwe tab",
	["Settings"] = "Instellingen",
	["+ Join channel"] = "+ Kanaal joinen",
	["Which channel do you want to join?"] = "Welk kanaal wil je joinen?",
	["Or only these channels:"] = "Of alleen deze kanalen:",
	["typing goes here"] = "je typt hierin",
	-- tab editor
	["Your own tab"] = "Jouw eigen tab",
	["Name"] = "Naam",
	["Only messages with this word (optional)"] = "Alleen berichten met dit woord (optioneel)",
	["Save"] = "Opslaan",
	["Cancel"] = "Annuleren",
	["Change"] = "Aanpassen",
	["Delete"] = "Verwijderen",
	["Your tab \"%s\""] = "Jouw tab \"%s\"",
	-- settings
	["Channels on the left, messages in the middle, Blizzard's own input box at the bottom: you type and send every line yourself. Right-click your own tab to change or delete it."] = "Kanalen links, berichten in het midden, Blizzards eigen invoerbalk onderaan: je typt en verstuurt elke zin zelf. Rechtsklik op je eigen tab om hem aan te passen of te verwijderen.",
	["Our chat window on"] = "Ons chatvenster aan",
	["Hide Blizzard's chat windows"] = "Blizzards chatvensters verbergen",
	["Their input box moves into our window."] = "Hun invoerbalk verhuist naar ons venster.",
	["Time in front of every line"] = "Tijd voor elke regel",
	["Show what other players craft"] = "Tonen wat andere spelers craften",
	["Off: only your own crafting shows."] = "Uit: alleen je eigen crafting verschijnt.",
	["Text size"] = "Tekstgrootte",
	["Language"] = "Taal",
	["Automatic"] = "Automatisch",
	["Unlock the frames (/cha unlock) to move the chat; drag its corner to make it bigger."] = "Ontgrendel de kaders (/cha unlock) om de chat te verplaatsen; sleep zijn hoek om hem groter te maken.",
	-- slash
	["Frames locked."] = "Kaders vergrendeld.",
	["Frames unlocked: drag the chat where you like, drag its corner to make it bigger, type /cha lock when done."] = "Kaders ontgrendeld: sleep de chat waar je wil, sleep zijn hoek om hem groter te maken, typ /cha lock als je klaar bent.",
	["/cha: settings. /cha toggle: our chat on/off. /cha unlock: move and resize it."] = "/cha: instellingen. /cha toggle: onze chat aan/uit. /cha unlock: verplaatsen en groter maken.",
	["Drag: make it bigger so more fits. Double-click: default size."] = "Slepen: groter maken zodat er meer in past. Dubbelklik: standaardgrootte.",
}) do NL[k] = v end
