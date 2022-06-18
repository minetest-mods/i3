local set_fs = i3.set_fs
local hud_notif = i3.hud_notif
local POLL_FREQ = 0.25

IMPORT("fmt", "search", "table_merge", "array_diff")
IMPORT("is_group", "extract_groups", "item_has_groups", "apply_recipe_filters")

local function get_filtered_items(player, data)
	local items, known, c = {}, 0, 0

	for i = 1, #i3.init_items do
		local item = i3.init_items[i]
		local recipes = i3.recipes_cache[item]
		local usages = i3.usages_cache[item]

		recipes = #apply_recipe_filters(recipes or {}, player)
		usages = #apply_recipe_filters(usages or {}, player)

		if recipes > 0 or usages > 0 then
			c++
			items[c] = item
			known += recipes + usages
		end
	end

	data.known_recipes = known

	return items
end

local function item_in_inv(item, inv_items)
	local inv_items_size = #inv_items

	if is_group(item) then
		local groupname = item:sub(7)
		local group_cache = i3.groups[groupname]
		local groups = group_cache and group_cache.groups or extract_groups(item)

		for i = 1, inv_items_size do
			local def = core.registered_items[inv_items[i]]

			if def then
				if item_has_groups(def.groups, groups) then
					return true
				end
			end
		end
	else
		for i = 1, inv_items_size do
			if inv_items[i] == item then
				return true
			end
		end
	end
end

local function recipe_in_inv(rcp, inv_items)
	for _, item in pairs(rcp.items) do
		if not item_in_inv(item, inv_items) then return end
	end

	return true
end

local function progressive_filter(recipes, player)
	if not recipes then
		return {}
	end

	local name = player:get_player_name()
	local data = i3.data[name]

	if #data.inv_items == 0 then
		return {}
	end

	local filtered, c = {}, 0

	for i = 1, #recipes do
		local recipe = recipes[i]
		if recipe_in_inv(recipe, data.inv_items) then
			c++
			filtered[c] = recipe
		end
	end

	return filtered
end

local item_lists = {"main", "craft", "craftpreview"}

local function get_inv_items(player)
	local inv = player:get_inventory()
	if not inv then
		return {}
	end

	local stacks = {}

	for i = 1, #item_lists do
		local list = inv:get_list(item_lists[i])
		table_merge(stacks, list)
	end

	local inv_items, c = {}, 0

	for i = 1, #stacks do
		local stack = stacks[i]

		if not stack:is_empty() then
			local name = stack:get_name()
			if core.registered_items[name] then
				c++
				inv_items[c] = name
			end
		end
	end

	return inv_items
end

-- Workaround. Need an engine call to detect when the contents of
-- the player inventory changed, instead.
local function poll_new_items(player, data, join)
	local inv_items = get_inv_items(player)
	local diff = array_diff(inv_items, data.inv_items)

	if join or #diff > 0 then
		data.inv_items = table_merge(diff, data.inv_items)
		local oldknown = data.known_recipes or 0
		local items = get_filtered_items(player, data)
		data.discovered = data.known_recipes - oldknown

		if data.discovered > 0 then
			local msg = fmt("%u new recipe%s unlocked!", data.discovered, data.discovered > 1 and "s" or "")
			hud_notif(data.player_name, msg, "i3_book.png")
		end

		data.items_raw = items
		data.itab = 1

		search(data)
		set_fs(player)
	end

	core.after(POLL_FREQ, poll_new_items, player, data)
end

i3.add_recipe_filter("Default progressive filter", progressive_filter)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	if not data then return end

	data.inv_items = data.inv_items or {}
	data.known_recipes = data.known_recipes or 0
	data.discovered = data.discovered or 0

	poll_new_items(player, data, true)
end)
