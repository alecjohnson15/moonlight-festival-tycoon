-- A tip card in the corner for a player's first few shows, saying what to
-- do in each part of the round, and the kiosk prompts in the plaza, which
-- open their menus. In a player's very first dressing room the card is a
-- three-step guide that ticks off as they go (put something on, change a
-- colour, press Ready); it never blocks anything and goes away by itself.

local ProximityPromptService = game:GetService("ProximityPromptService")

local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Corner = require(script.Parent.Corner)
local Menus = require(script.Parent.Menus)
local Wardrobe = require(script.Parent.Wardrobe)

local Tips = {}

local SHOWS_WITH_TIPS = 3

local TIPS = {
	Waiting = "Welcome to Catwalk Clash! A show starts as soon as everyone's in.",
	Lobby = "A show starts soon. Open the Wardrobe (👗) to try on looks while you wait.",
	ThemeVote = "Vote for the next theme on the cards below.",
	Reveal = "That's the theme! Dress to match it.",
	Dressing = "Pieces marked ✓ theme fit this round best. Colours count too. Press I'M READY when you're done.",
	Showtime = "Everyone lines up, then two walkers at a time: vote ◀ or ▶ for your favourite look! You can't vote for yourself, and votes count once both outfits have been seen.",
	Crowning = "The winner gets the crown and a statue in the plaza. Next round soon!",
}

local PROMPTS = {
	Boutique = "Shop",
	["Style Pass"] = "Pass",
	["My Closet"] = "Closet",
	Challenges = "Profile",
}

local card: Frame
local line: TextLabel
-- The first-outfit guide's steps, done or not.
local steps = { Equip = false, Paint = false, Ready = false }

local function guide(): string
	local function box(done: boolean): string
		return if done then "✅" else "⬜"
	end
	return table.concat({
		"Your first look:",
		`{box(steps.Equip)} Put on a piece marked ✓ theme, or tap ✨ Theme look`,
		`{box(steps.Paint)} Change a colour or finish`,
		`{box(steps.Ready)} Press I'M READY when you love it`,
	}, "\n")
end

local function update()
	local profile = State.Profile
	local shows = if profile then profile.Stats.Shows else 0
	if shows >= SHOWS_WITH_TIPS then
		card.Visible = false
		return
	end
	local text = TIPS[State.phase()]
	if State.phase() == "Dressing" and shows == 0 then
		text = guide()
	end
	if text then
		Corner.set(line, text)
		Corner.pop(card)
	else
		card.Visible = false
	end
end

function Tips.mount()
	card = Corner.card(Corner.Order.Tip, Ui.Colors.Aqua)
	Corner.title(card, { Text = "Tip", TextColor3 = Ui.Colors.Aqua })
	line = Corner.line(card)
	State.onRound(function(name)
		if name == "Phase" then
			update()
		end
	end)
	State.onProfile(function()
		if card.Visible then
			update()
		end
	end)
	Wardrobe.onAction(function(name)
		if name == "ThemeLook" then
			steps.Equip = true
		elseif steps[name] ~= nil then
			steps[name] = true
		end
		if State.phase() == "Dressing" and card.Visible then
			update()
		end
	end)
	update()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local menu = PROMPTS[prompt.ObjectText]
		if menu then
			Menus.open(menu)
		end
	end)
end

return Tips
