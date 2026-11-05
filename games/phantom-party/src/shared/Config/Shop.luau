-- The coin shop: cosmetics sold for coins at a fixed price, with no chance
-- involved. What you click is what you get. Coins are only ever earned by
-- playing; nothing sells them for Robux.

export type Offer = { Item: string, Price: number }

local Shop = {}

Shop.Offers = {
	{ Item = "mask_velvet", Price = 300 },
	{ Item = "trail_mist", Price = 400 },
	{ Item = "blade_umbrella", Price = 500 },
	{ Item = "blaster_gumdrop", Price = 800 },
	{ Item = "fx_confetti", Price = 900 },
	{ Item = "mask_cat", Price = 1200 },
} :: { Offer }

function Shop.price(itemId: string): number?
	for _, offer in Shop.Offers do
		if offer.Item == itemId then
			return offer.Price
		end
	end
	return nil
end

return Shop
