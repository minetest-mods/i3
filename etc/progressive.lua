local POLL_FREQ = 0.25
local HUD_TIMER_MAX = 1.5

local search, table_merge, is_group, extract_groups, item_has_groups, apply_recipe_filters =
	unpack(i3.files.common().progressive)

local singleplayer = core.is_singleplayer()
local fmt, after, pairs = string.format, core.after, pairs
local set_fs = i3.set_fs

local function array_diff(t1, t2)
	local hash = {}

	for i = 1, #t1 do
		local v = t1[i]
		hash[v] = true
	end

	for i = 1, #t2 do
		local v = t2[i]
		hash[v] = nil
	end

	local diff, c = {}, 0

	for i = 1, #t1 do
		local v = t1[i]
		if hash[v] then
			c = c + 1
			diff[c] = v
		end
	end

	return diff
end

local function get_filtered_items(player, data)
	local items, known, c = {}, 0, 0

	for i = 1, #i3.init_items do
		local item = i3.init_items[i]
		local recipes = i3.recipes_cache[item]
		local usages = i3.usages_cache[item]

		recipes = #apply_recipe_filters(recipes or {}, player)
		usages = #apply_recipe_filters(usages or {}, player)

		if recipes > 0 or usages > 0 then
			c = c + 1
			items[c] = item

			if data then
				known = known + recipes + usages
			end
		end
	end

	if data then
		data.known_recipes = known
	end

	return items
end

local function item_in_inv(item, inv_items)
	local inv_items_size = #inv_items

	if is_group(item) then
		local groups = extract_groups(item)

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
			c = c + 1
			filtered[c] = recipe
		end
	end

	return filtered
end

local item_lists = {"main", "craft", "craftpreview"}

local function get_inv_items(player)
	local inv = player:get_inventory()
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
				c = c + 1
				inv_items[c] = name
			end
		end
	end

	return inv_items
end

local function init_hud(player, data)
	data.hud = {
		bg = player:hud_add {
			hud_elem_type = "image",
			position      = {x = 0.78, y = 1},
			alignment     = {x = 1,    y = 1},
			scale         = {x = 370,  y = 112},
			text          = "i3_bg.png",
			z_index       = 0xDEAD,
		},

		book = player:hud_add {
			hud_elem_type = "image",
			position      = {x = 0.79, y = 1.02},
			alignment     = {x = 1,    y = 1},
			scale         = {x = 4,    y = 4},
			text          = "i3_book.png",
			z_index       = 0xDEAD,
		},

		text = player:hud_add {
			hud_elem_type = "text",
			position      = {x = 0.84, y = 1.04},
			alignment     = {x = 1,    y = 1},
			number        = 0xffffff,
			text          = "",
			z_index       = 0xDEAD,
			style         = 1,
		},
	}
end

local function show_hud_success(player, data)
	-- It'd better to have an engine function `hud_move` to only need
	-- 2 calls for the notification's back and forth.

	local hud_info_bg = player:hud_get(data.hud.bg)
	local dt = 0.016

	if hud_info_bg.position.y <= 0.9 then
		data.show_hud = false
		data.hud_timer = (data.hud_timer or 0) + dt
	end

	if data.show_hud then
		for _, def in pairs(data.hud) do
			local hud_info = player:hud_get(def)

			player:hud_change(def, "position", {
				x = hud_info.position.x,
				y = hud_info.position.y - (dt / 5)
			})
		end

		player:hud_change(data.hud.text, "text",
			fmt("%u new recipe%s unlocked!", data.discovered, data.discovered > 1 and "s" or ""))

	elseif data.show_hud == false then
		if data.hud_timer >= HUD_TIMER_MAX then
			for _, def in pairs(data.hud) do
				local hud_info = player:hud_get(def)

				player:hud_change(def, "position", {
					x = hud_info.position.x,
					y = hud_info.position.y + (dt / 5)
				})
			end

			if hud_info_bg.position.y >= 1 then
				data.show_hud = nil
				data.hud_timer = nil
			end
		end
	end
end

-- Workaround. Need an engine call to detect when the contents of
-- the player inventory changed, instead.
local function poll_new_items()
	local players = core.get_connected_players()

	for i = 1, #players do
		local player = players[i]
		local name = player:get_player_name()
		local data = i3.data[name]
		if not data then return end

		local inv_items = get_inv_items(player)
		local diff = array_diff(inv_items, data.inv_items)

		if #diff > 0 then
			data.inv_items = table_merge(diff, data.inv_items)
			local oldknown = data.known_recipes or 0
			local items = get_filtered_items(player, data)
			data.discovered = data.known_recipes - oldknown

			if data.show_hud == nil and data.discovered > 0 then
				data.show_hud = true
			end

			data.items_raw = items
			data.current_itab = 1

			search(data)
			set_fs(player)
		end
	end

	after(POLL_FREQ, poll_new_items)
end

poll_new_items()

if singleplayer then
	core.register_globalstep(function()
		local name = "singleplayer"
		local player = core.get_player_by_name(name)
		local data = i3.data[name]

		if data and data.show_hud ~= nil then
			show_hud_success(player, data)
		end
	end)
end

i3.add_recipe_filter("Default progressive filter", progressive_filter)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	if not data then return end

	data.inv_items = data.inv_items or {}
	data.known_recipes = data.known_recipes or 0

	local oldknown = data.known_recipes
	local items = get_filtered_items(player, data)
	data.discovered = data.known_recipes - oldknown

	data.items_raw = items
	search(data)

	if singleplayer then
		init_hud(player, data)

		if data.show_hud == nil and data.discovered > 0 then
			data.show_hud = true
		end
	end
end)
