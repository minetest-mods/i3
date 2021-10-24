local translate = core.get_translated_string
local fmt, find, gmatch, match, sub, split, lower =
	string.format, string.find, string.gmatch, string.match, string.sub, string.split, string.lower
local reg_items, reg_nodes, reg_craftitems, reg_tools =
	core.registered_items, core.registered_nodes, core.registered_craftitems, core.registered_tools

local function reset_compression(data)
	data.alt_items = nil
	data.expand = ""
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
		local def = core.registered_items[item]
		local desc = lower(translate(data.lang_code, def and def.description)) or ""
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

					j = j + 1
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
			c = c + 1
			filtered_list[c] = item
		end
	end

	data.items = filtered_list
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
			c = c + 1
			t1[c] = t2[i]
		end
	end

	return t1
end

local function is_group(item)
	return sub(item, 1, 6) == "group:"
end

local function extract_groups(str)
	if sub(str, 1, 6) == "group:" then
		return split(sub(str, 7), ",")
	end
end

local function item_has_groups(item_groups, groups)
	for i = 1, #groups do
		local group = groups[i]
		if (item_groups[group] or 0) == 0 then return end
	end

	return true
end

local function show_item(def)
	return def and def.groups.not_in_creative_inventory ~= 1 and
		def.description and def.description ~= ""
end

local function groups_to_items(groups, get_all)
	if not get_all and #groups == 1 then
		local group = groups[1]
		local stereotype = i3.group_stereotypes[group]
		local def = reg_items[stereotype]

		if show_item(def) then
			return stereotype
		end
	end

	local names = {}

	for name, def in pairs(reg_items) do
		if show_item(def) and item_has_groups(def.groups, groups) then
			if get_all then
				names[#names + 1] = name
			else
				return name
			end
		end
	end

	return get_all and names or ""
end

local function apply_recipe_filters(recipes, player)
	for _, filter in pairs(i3.recipe_filters) do
		recipes = filter(recipes, player)
	end

	return recipes
end

local function compression_active(data)
	return i3.item_compression and not next(i3.recipe_filters) and data.filter == ""
end

local function compressible(item, data)
	return compression_active(data) and i3.compress_groups[item]
end

local function is_str(x)
	return type(x) == "string"
end

local function is_table(x)
	return type(x) == "table"
end

local function true_str(str)
	return is_str(str) and str ~= ""
end

local function is_fav(favs, query_item)
	local fav, i
	for j = 1, #favs do
		if favs[j] == query_item then
			fav = true
			i = j
			break
		end
	end

	return fav, i
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

		if data.current_itab == 2 then
			to_add = reg_nodes[item]
		elseif data.current_itab == 3 then
			to_add = reg_craftitems[item] or reg_tools[item]
		end

		if to_add then
			new[#new + 1] = item
		end
	end

	data.items = new
end

local function clean_name(item)
	if sub(item, 1, 1) == ":" or sub(item, 1, 1) == " " or sub(item, 1, 1) == "_" then
		item = sub(item, 2)
	end

	return item
end

local function msg(name, str)
	return core.chat_send_player(name, fmt("[i3] %s", str))
end

local function spawn_item(player, stack)
	local dir     = player:get_look_dir()
	local ppos    = player:get_pos()
	      ppos.y  = ppos.y + 1.625
	local look_at = vector.add(ppos, vector.multiply(dir, 1))

	core.add_item(look_at, stack)
end

local S = core.get_translator "i3"
local ES = function(...) return core.formspec_escape(S(...)) end

return {
	groups = {
		is_group = is_group,
		extract_groups = extract_groups,
		item_has_groups = item_has_groups,
		groups_to_items = groups_to_items,
	},

	compression = {
		compressible = compressible,
		compression_active = compression_active,
	},

	sorting = {
		search = search,
		sort_by_category = sort_by_category,
		apply_recipe_filters = apply_recipe_filters,
	},

	misc = {
		msg = msg,
		is_fav = is_fav,
		show_item = show_item,
		spawn_item = spawn_item,
		table_merge = table_merge,
	},

	core = {
		clr = core.colorize,
		ESC = core.formspec_escape,
		check_privs = core.check_player_privs,
	},

	reg = {
		reg_items = core.registered_items,
		reg_nodes = core.registered_nodes,
		reg_craftitems = core.registered_craftitems,
		reg_tools = core.registered_tools,
		reg_entities = core.registered_entities,
		reg_aliases = core.registered_aliases,
	},

	i18n = {
		S = S,
		ES = ES,
		translate = core.get_translated_string,
	},

	string = {
		fmt = string.format,
		find = string.find,
		gmatch = string.gmatch,
		match = string.match,
		sub = string.sub,
		split = string.split,
		upper = string.upper,
		lower = string.lower,

		is_str = is_str,
		true_str = true_str,
		clean_name = clean_name,
	},

	table = {
		maxn = table.maxn,
		sort = table.sort,
		concat = table.concat,
		copy = table.copy,
		insert = table.insert,
		remove = table.remove,
		indexof = table.indexof,

		is_table = is_table,
	},

	math = {
		min = math.min,
		max = math.max,
		floor = math.floor,
		ceil = math.ceil,
		random = math.random,
	},

	vec = {
		vec_new = vector.new,
		vec_add = vector.add,
		vec_mul = vector.multiply,
		vec_eq = vector.equals,
		vec_round = vector.round,
	},
}
