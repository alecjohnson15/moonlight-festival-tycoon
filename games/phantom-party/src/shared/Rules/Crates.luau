--!strict
-- Opening a crate: first the rarity, by the crate's odds, then one of that
-- rarity's items, each equally likely. After Pity opens in a row without an
-- item of the crate's PityRarity or better, the next open picks only among
-- those rarities, in proportion to their odds.

local Items = require(script.Parent.Parent.Config.Items)
local CrateConfig = require(script.Parent.Parent.Config.Crates)

local Crates = {}

export type Odds = { Rarity: string, Percent: number, Items: { string } }

-- The crate's odds in rarity order, as percentages, for the crate's page.
function Crates.odds(crate: CrateConfig.Crate): { Odds }
	local total = 0
	for _, weight in crate.Odds do
		total += weight
	end
	local list = {}
	for _, rarity in Items.RARITIES do
		local weight = crate.Odds[rarity]
		if weight and weight > 0 then
			table.insert(list, {
				Rarity = rarity,
				Percent = math.floor(weight / total * 1000 + 0.5) / 10,
				Items = crate.Pools[rarity] or {},
			})
		end
	end
	return list
end

-- Opens the crate. pity is how many opens in a row have missed PityRarity.
-- Returns the item, its rarity and the new pity count.
function Crates.roll(crate: CrateConfig.Crate, pity: number, random: () -> number): (string, string, number)
	local floor = Items.rank(crate.PityRarity)
	local guaranteed = pity + 1 >= crate.Pity
	local total = 0
	for _, rarity in Items.RARITIES do
		local weight = crate.Odds[rarity] or 0
		if weight > 0 and (not guaranteed or Items.rank(rarity) >= floor) then
			total += weight
		end
	end
	local roll = random() * total
	local picked = crate.PityRarity
	for _, rarity in Items.RARITIES do
		local weight = crate.Odds[rarity] or 0
		if weight > 0 and (not guaranteed or Items.rank(rarity) >= floor) then
			roll -= weight
			picked = rarity
			if roll < 0 then
				break
			end
		end
	end
	local pool = crate.Pools[picked]
	local itemId = pool[math.min(#pool, math.floor(random() * #pool) + 1)]
	local nextPity = if Items.rank(picked) >= floor then 0 else pity + 1
	return itemId, picked, nextPity
end

return Crates
