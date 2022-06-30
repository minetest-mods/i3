local ItemStack = ItemStack
local loadstring = loadstring
local reg_items = core.registered_items
local translate = core.get_translated_string
local vec_new, vec_add, vec_mul = vector.new, vector.add, vector.multiply
local sort, concat, insert = table.sort, table.concat, table.insert
local min, floor, ceil = math.min, math.floor, math.ceil
local fmt, find, match, gmatch, sub, split, lower, upper =
	string.format, string.find, string.match, string.gmatch,
	string.sub, string.split, string.lower, string.upper

if not core.registered_privileges.creative then
	core.register_privilege("creative", {
		description = "Allow player to use creative inventory",
		give_to_singleplayer = false,
		give_to_admin = false,
	})
end

local old_is_creative_enabled = core.is_creative_enabled

function core.is_creative_enabled(name)
	if name == "" then
		return old_is_creative_enabled(name)
	end

	return core.check_player_privs(name, {creative = true}) or old_is_creative_enabled(name)
end

local S = core.get_translator"i3"
local ES = function(...) return core.formspec_escape(S(...)) end

local function is_num(x)
	return type(x) == "number"
end

local function is_str(x)
	return type(x) == "string"
end

local function is_table(x)
	return type(x) == "table"
end

local function is_func(x)
	return type(x) == "function"
end

local function true_str(str)
	return is_str(str) and str ~= ""
end

local function true_table(x)
	return is_table(x) and next(x)
end

local function reset_compression(data)
	data.alt_items = nil
	data.expand = ""
end

local function msg(name, str)
	local prefix = "[i3]"
	return core.chat_send_player(name, fmt("%s %s", core.colorize("#ff0", prefix), str))
end

local function err(str)
	return core.log("error", str)
end

local function round(num, decimal)
	local mul = 10 ^ decimal
	return floor(num * mul + 0.5) / mul
end

local function toupper(str)
	return str:gsub("%f[%w]%l", upper):gsub("_", " ")
end

local function utf8_len(str)
	local c = 0

	for _ in str:gmatch"([%z\1-\127\194-\244][\128-\191]*)" do -- Arguably working duct-tape code
		c++
	end

	return c
end

local function get_bag_description(data, stack)
	local desc = translate(data.lang_code, stack:get_description())
	      desc = split(desc, "(")[1] or desc
	      desc = toupper(desc:trim())

	return desc
end

local function search(data)
	reset_compression(data)

	local filter = data.filter
	local opt = "^(.-)%+([%w_]+)=([%w_,]+)"
	local search_filter = next(i3.search_filters) and match(filter, opt)
	local filters = {}

	if search_filter then
		search_filter = search_filter:trim()

		for filter_name, values in gmatch(filter, sub(opt, 6)) do
			if i3.search_filters[filter_name] then
				values = split(values, ",")
				filters[filter_name] = values
			end
		end
	end

	local filtered_list, c = {}, 0

	for i = 1, #data.items_raw do
		local item = data.items_raw[i]
		local def = reg_items[item]
		local desc = lower(translate(data.lang_code, def.description)) or ""
		local search_in = fmt("%s %s", item, desc)
		local temp, j, to_add = {}, 1

		if search_filter then
			for filter_name, values in pairs(filters) do
				if values then
					local func = i3.search_filters[filter_name]
					to_add = (j > 1 and temp[item] or j == 1) and
						func(item, values) and (search_filter == "" or
						find(search_in, search_filter, 1, true))

					if to_add then
						temp[item] = true
					end

					j++
				end
			end
		else
			local ok = true

			for keyword in gmatch(filter, "%S+") do
				if not find(search_in, keyword, 1, true) then
					ok = nil
					break
				end
			end

			if ok then
				to_add = true
			end
		end

		if to_add then
			c++
			filtered_list[c] = item
		end
	end

	data.items = filtered_list
end

local function table_replace(t, val, new)
	for k, v in pairs(t) do
		if v == val then
			t[k] = new
		end
	end
end

local function table_merge(t1, t2, hash)
	t1 = t1 or {}
	t2 = t2 or {}

	if hash then
		for k, v in pairs(t2) do
			t1[k] = v
		end
	else
		local c = #t1

		for i = 1, #t2 do
			c++
			t1[c] = t2[i]
		end
	end

	return t1
end

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
			c++
			diff[c] = v
		end
	end

	return diff
end

local function rcp_eq(rcp, rcp2)
	if rcp.type   ~= rcp2.type   then return end
	if rcp.width  ~= rcp2.width  then return end
	if #rcp.items ~= #rcp2.items then return end
	if rcp.output ~= rcp2.output then return end

	for i, item in pairs(rcp.items) do
		if item ~= rcp2.items[i] then return end
	end

	for i, item in pairs(rcp2.items) do
		if item ~= rcp.items[i] then return end
	end

	return true
end

local function clean_name(item)
	if sub(item, 1, 1) == ":" or sub(item, 1, 1) == " " or sub(item, 1, 1) == "_" then
		item = sub(item, 2)
	end

	return item
end

local function is_group(item)
	return sub(item, 1, 6) == "group:"
end

local function extract_groups(str)
	return split(sub(str, 7), ",")
end

local function item_has_groups(item_groups, groups)
	for i = 1, #groups do
		local group = groups[i]
		if (item_groups[group] or 0) == 0 then return end
	end

	return true
end

local function valid_item(def)
	return def and def.groups.not_in_creative_inventory ~= 1 and
		def.description and def.description ~= ""
end

local function get_group_stereotype(group)
	local stereotype = i3.group_stereotypes[group]
	local def = reg_items[stereotype]

	if valid_item(def) then
		return stereotype
	end
end

local function groups_to_items(groups)
	local names = {}

	for name, def in pairs(reg_items) do
		if valid_item(def) and item_has_groups(def.groups, groups) then
			insert(names, name)
		end
	end

	sort(names)

	return names
end

local function is_cube(drawtype)
	return drawtype == "normal" or drawtype == "liquid" or
		sub(drawtype, 1, 9) == "glasslike" or
		sub(drawtype, 1, 8) == "allfaces"
end

local function get_cube(tiles)
	if not true_table(tiles) then
		return "i3_blank.png"
	end

	local top = tiles[1] or "i3_blank.png"
	if is_table(top) then
		top = top.name or top.image
	end

	local left = tiles[3] or top or "i3_blank.png"
	if is_table(left) then
		left = left.name or left.image
	end

	local right = tiles[5] or left or "i3_blank.png"
	if is_table(right) then
		right = right.name or right.image
	end

	return core.inventorycube(top, left, right)
end

local function apply_recipe_filters(recipes, player)
	for _, filter in pairs(i3.recipe_filters) do
		recipes = filter(recipes, player)
	end

	return recipes
end

local function compression_active(data)
	return i3.settings.item_compression and not next(i3.recipe_filters) and data.filter == ""
end

local function compressible(item, data)
	return compression_active(data) and i3.compress_groups[item]
end

local function is_fav(data)
	for i = 1, #data.favs do
		if data.favs[i] == data.query_item then
			return i
		end
	end
end

local function sort_by_category(data)
	reset_compression(data)
	local items = data.items_raw

	if data.filter ~= "" then
		search(data)
		items = data.items
	end

	local new = {}

	for i = 1, #items do
		local item = items[i]
		local to_add = true

		if data.itab == 2 then
			to_add = core.registered_nodes[item]
		elseif data.itab == 3 then
			to_add = core.registered_craftitems[item] or core.registered_tools[item]
		end

		if to_add then
			insert(new, item)
		end
	end

	data.items = new
end

local function spawn_item(player, stack)
	local dir     = player:get_look_dir()
	local ppos    = player:get_pos()
	      ppos.y  = ppos.y + player:get_properties().eye_height
	local look_at = vec_add(ppos, vec_mul(dir, 1))

	core.add_item(look_at, stack)
end

local function get_recipes(player, item)
	item = core.registered_aliases[item] or item
	local recipes = i3.recipes_cache[item]
	local usages = i3.usages_cache[item]

	if recipes then
		recipes = apply_recipe_filters(recipes, player)
	end

	local no_recipes = not recipes or #recipes == 0
	if no_recipes and not usages then return end
	usages = apply_recipe_filters(usages, player)
	local no_usages = not usages or #usages == 0

	return not no_recipes and recipes or nil,
	       not no_usages  and usages  or nil
end

local function get_stack(player, stack)
	local inv = player:get_inventory()

	if inv:room_for_item("main", stack) then
		inv:add_item("main", stack)
	else
		spawn_item(player, stack)
	end
end

local function craft_stack(player, data, craft_rcp)
	local inv = player:get_inventory()
	local rcp_usg = craft_rcp and "recipe" or "usage"
	local output = craft_rcp and data.recipes[data.rnum].output or data.usages[data.unum].output
	      output = ItemStack(output)
	local stackname, stackcount, stackmax = output:get_name(), output:get_count(), output:get_stack_max()
	local scrbar_val = data[fmt("scrbar_%s", craft_rcp and "rcp" or "usg")] or 1

	for name, count in pairs(data.export_counts[rcp_usg].rcp) do
		local items = {[name] = count}

		if is_group(name) then
			items = {}
			local groups = extract_groups(name)
			local groupname = name:sub(7)
			local item_groups = i3.groups[groupname].items or groups_to_items(groups)
			local remaining = count

			for _, item in ipairs(item_groups) do
			for _name, _count in pairs(data.export_counts[rcp_usg].inv) do
				if item == _name and remaining > 0 then
					local c = min(remaining, _count)
					items[item] = c
					remaining -= c
				end

				if remaining == 0 then break end
			end
			end
		end

		for k, v in pairs(items) do
			inv:remove_item("main", fmt("%s %s", k, v * scrbar_val))
		end
	end

	local count = stackcount * scrbar_val
	local iter = ceil(count / stackmax)
	local leftover = count

	for _ = 1, iter do
		local c = min(stackmax, leftover)
		local stack = ItemStack(fmt("%s %s", stackname, c))
		get_stack(player, stack)
		leftover -= stackmax
	end
end

local function play_sound(name, sound, volume)
	core.sound_play(sound, {to_player = name, gain = volume}, true)
end

local function safe_teleport(player, pos)
	local name = player:get_player_name()
	play_sound(name, "i3_teleport", 0.8)

	local vel = player:get_velocity()
	player:add_velocity(vec_mul(vel, -1))

	local p = vec_new(pos)
	      p.y += 0.25

	player:set_pos(p)
end

local function get_sorting_idx(name)
	local idx = 1

	for i, def in ipairs(i3.sorting_methods) do
		if name == def.name then
			idx = i
		end
	end

	return idx
end

local function sorter(inv, reverse, mode)
	sort(inv, function(a, b)
		if mode == 1 then
			a, b = a:get_name(), b:get_name()
		else
			a, b = a:get_count(), b:get_count()
		end

		if reverse then
			return a > b
		end

		return a < b
	end)
end

local function pre_sorting(list, start_i)
	local new_inv, special = {}, {}

	for i = start_i, #list do
		local stack = list[i]
		local empty = stack:is_empty()
		local meta  = stack:get_meta():to_table()
		local wear  = stack:get_wear() > 0

		if not empty then
			if next(meta.fields) or wear then
				insert(special, stack)
			else
				insert(new_inv, stack)
			end
		end
	end

	new_inv = table_merge(new_inv, special)
	return new_inv
end

local function compress_items(list, start_i)
	local hash, new_inv, special = {}, {}, {}

	for i = start_i, #list do
		local stack    = list[i]
		local name     = stack:get_name()
		local count    = stack:get_count()
		local stackmax = stack:get_stack_max()
		local empty    = stack:is_empty()
		local meta     = stack:get_meta():to_table()
		local wear     = stack:get_wear() > 0

		if not empty then
			if next(meta.fields) or wear or count >= stackmax then
				insert(special, stack)
			else
				hash[name] = hash[name] or 0
				hash[name] += count
			end
		end
	end

	for name, count in pairs(hash) do
		local stackmax = ItemStack(name):get_stack_max()
		local iter = ceil(count / stackmax)
		local leftover = count

		for _ = 1, iter do
			insert(new_inv, ItemStack(fmt("%s %u", name, min(stackmax, leftover))))
			leftover -= stackmax
		end
	end

	new_inv = table_merge(new_inv, special)
	return new_inv
end

local function drop_items(player, inv, list, start_i, rej, remove)
	for i = start_i, #list do
		local stack = list[i]
		local name = stack:get_name()

		for _, it in ipairs(rej) do
			if name == it then
				if not remove then
					spawn_item(player, stack)
				end

				inv:set_stack("main", i, ItemStack(""))
			end
		end
	end

	return inv:get_list"main"
end

local function sort_inventory(player, data)
	local inv = player:get_inventory()
	local list = inv:get_list"main"
	local size = inv:get_size"main"
	local start_i = data.ignore_hotbar and (i3.settings.hotbar_len + 1) or 1

	if true_table(data.drop_items) then
		list = drop_items(player, inv, list, start_i, data.drop_items, true)
	end

	if data.inv_compress then
		list = compress_items(list, start_i)
	else
		list = pre_sorting(list, start_i)
	end

	local idx = get_sorting_idx(data.sort)
	local new_inv = i3.sorting_methods[idx].func(list, data)
	if not new_inv then return end

	if not data.ignore_hotbar then
		inv:set_list("main", new_inv)
		return
	end

	for i = start_i, size do
		local index = i - start_i + 1
		inv:set_stack("main", i, new_inv[index] or "")
	end
end

local function reset_data(data)
	data.filter        = ""
	data.expand        = ""
	data.pagenum       = 1
	data.rnum          = 1
	data.unum          = 1
	data.scrbar_rcp    = 1
	data.scrbar_usg    = 1
	data.query_item    = nil
	data.enable_search = nil
	data.recipes       = nil
	data.usages        = nil
	data.export_rcp    = nil
	data.export_usg    = nil
	data.alt_items     = nil
	data.confirm_trash = nil
	data.show_settings = nil
	data.show_setting  = "home"
	data.items         = data.items_raw

	if data.itab > 1 then
		sort_by_category(data)
	end
end

local function add_hud_waypoint(player, name, pos, color)
	return player:hud_add {
		hud_elem_type = "waypoint",
		name = name,
		text = "m",
		world_pos = pos,
		number = color,
		z_index = -300,
	}
end

local function get_detached_inv(name, player_name)
	return core.get_inventory {
		type = "detached",
		name = fmt("i3_%s_%s", name, player_name)
	}
end

-- Much faster implementation of `unpack`
local function createunpack(n)
	local ret = {"local t = ... return "}

	for k = 2, n do
		ret[2 + (k - 2) * 4] = "t["
		ret[3 + (k - 2) * 4] = k - 1
		ret[4 + (k - 2) * 4] = "]"

		if k ~= n then
			ret[5 + (k - 2) * 4] = ","
		end
	end

	return loadstring(concat(ret))
end

local newunpack = createunpack(33)

-------------------------------------------------------------------------------

local _ = {
	-- Groups
	is_group = is_group,
	extract_groups = extract_groups,
	item_has_groups = item_has_groups,
	groups_to_items = groups_to_items,
	get_group_stereotype = get_group_stereotype,

	-- Compression
	compressible = compressible,
	compression_active = compression_active,

	-- Sorting
	search = search,
	sorter = sorter,
	get_recipes = get_recipes,
	sort_inventory = sort_inventory,
	get_sorting_idx = get_sorting_idx,
	sort_by_category = sort_by_category,
	apply_recipe_filters = apply_recipe_filters,

	-- Type checks
	is_fav = is_fav,
	is_str = is_str,
	is_num = is_num,
	is_func = is_func,
	true_str = true_str,
	true_table = true_table,

	-- Console
	err = err,
	msg = msg,

	-- Misc. functions
	is_cube = is_cube,
	get_cube = get_cube,
	ItemStack = ItemStack,
	valid_item = valid_item,
	spawn_item = spawn_item,
	clean_name = clean_name,
	play_sound = play_sound,
	reset_data = reset_data,
	safe_teleport = safe_teleport,
	add_hud_waypoint = add_hud_waypoint,

	-- Core functions
	clr = core.colorize,
	slz = core.serialize,
	dslz = core.deserialize,
	ESC = core.formspec_escape,
	draw_cube = core.inventorycube,
	get_group = core.get_item_group,
	pos_to_str = core.pos_to_string,
	str_to_pos = core.string_to_pos,
	check_privs = core.check_player_privs,
	get_player_by_name = core.get_player_by_name,
	get_connected_players = core.get_connected_players,

	-- Inventory
	get_stack = get_stack,
	craft_stack = craft_stack,
	get_detached_inv = get_detached_inv,
	get_bag_description = get_bag_description,
	create_inventory = core.create_detached_inventory,

	-- Registered items
	reg_items = core.registered_items,
	reg_nodes = core.registered_nodes,
	reg_tools = core.registered_tools,
	reg_aliases = core.registered_aliases,
	reg_entities = core.registered_entities,
	reg_craftitems = core.registered_craftitems,

	-- i18n
	S = S,
	ES = ES,
	translate = core.get_translated_string,

	-- String
	sub = string.sub,
	find = string.find,
	fmt = string.format,
	upper = string.upper,
	lower = string.lower,
	split = string.split,
	match = string.match,
	gmatch = string.gmatch,
	toupper = toupper,
	utf8_len = utf8_len,

	-- Table
	maxn = table.maxn,
	sort = table.sort,
	copy = table.copy,
	concat = table.concat,
	insert = table.insert,
	remove = table.remove,
	indexof = table.indexof,
	unpack = newunpack,
	is_table = is_table,
	table_merge = table_merge,
	table_replace = table_replace,
	rcp_eq = rcp_eq,
	array_diff = array_diff,

	-- Math
	round = round,
	min = math.min,
	max = math.max,
	ceil = math.ceil,
	floor = math.floor,
	random = math.random,

	-- Vectors
	vec_new = vector.new,
	vec_add = vector.add,
	vec_sub = vector.subtract,
	vec_mul = vector.multiply,
	vec_round = vector.round,
	vec_eq = vector.equals,
}

function i3.get(...)
	local t = {}

	for i, var in ipairs{...} do
		t[i] = _[var]
	end

	return newunpack(t)
end
