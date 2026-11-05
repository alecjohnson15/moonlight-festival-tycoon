--!strict
-- Which first-time tip to show, and its words for the player's controls.

local TipConfig = require(script.Parent.Parent.Config.Tips)

export type Tip = { Id: string, Role: string, When: string, Text: string }

local Tips = {}

local byId: { [string]: Tip } = {}
for _, tip in TipConfig.List do
	byId[tip.Id] = tip
end

-- Whether id names a real tip (the server only saves those).
function Tips.valid(id: unknown): boolean
	return typeof(id) == "string" and byId[id :: string] ~= nil
end

-- The first tip for this role and moment the player hasn't seen, or nil.
function Tips.next(seen: { [string]: boolean }, role: string?, when: string): Tip?
	for _, tip in TipConfig.List do
		if tip.When == when and (tip.Role == "*" or tip.Role == role) and not seen[tip.Id] then
			return tip
		end
	end
	return nil
end

-- The tip's words with the moves filled in for input ("Keyboard", "Touch"
-- or "Gamepad").
function Tips.text(tip: Tip, input: string): string
	local keys = TipConfig.Keys[input] or TipConfig.Keys.Keyboard
	local text = string.gsub(tip.Text, "{(%a+)}", function(name)
		return keys[name] or name
	end)
	return text
end

return Tips
