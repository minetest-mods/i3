local translate = core.get_translated_string
local insert, remove, sort, vec_add, vec_mul =
	table.insert, table.remove, table.sort, vector.add, vector.mul
local fmt, find, gmatch, match, sub, split, lower =
	string.format, string.find, string.gmatch, string.match, string.sub, string.split, string.lower
local reg_items, reg_nodes, reg_craftitems, reg_tools =
	core.registered_items, core.registered_nodes, core.registered_craftitems, core.registered_tools

local S = core.get_translator "i3"
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
			c = c + 1
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
			c = c + 1
			diff[c] = v
		end
	end

	return diff
end

local function table_eq(T1, T2)
	local avoid_loops = {}

	local function recurse(t1, t2)
		if type(t1) ~= type(t2) then return end

		if not is_table(t1) then
			return t1 == t2
		end

		if avoid_loops[t1] then
			return avoid_loops[t1] == t2
		end

		avoid_loops[t1] = t2
		local t2k, t2kv = {}, {}

		for k in pairs(t2) do
			if is_table(k) then
				insert(t2kv, k)
			end

			t2k[k] = true
		end

		for k1, v1 in pairs(t1) do
			local v2 = t2[k1]
			if type(k1) == "table" then
				local ok
				for i = 1, #t2kv do
					local tk = t2kv[i]
					if table_eq(k1, tk) and recurse(v1, t2[tk]) then
						remove(t2kv, i)
						t2k[tk] = nil
						ok = true
						break
					end
				end

				if not ok then return end
			else
				if v2 == nil then return end
				t2k[k1] = nil
				if not recurse(v1, v2) then return end
			end
		end

		if next(t2k) then return end
		return true
	end

	return recurse(T1, T2)
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

local function clean_name(item)
	if sub(item, 1, 1) == ":" or sub(item, 1, 1) == " " or sub(item, 1, 1) == "_" then
		item = sub(item, 2)
	end

	return item
end

local function msg(name, str)
	return core.chat_send_player(name, fmt("[i3] %s", str))
end

local function err(str)
	return core.log("error", str)
end

local function round(num, decimal)
	local mul = 10 ^ decimal
	return math.floor(num * mul + 0.5) / mul
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

local function spawn_item(player, stack)
	local dir     = player:get_look_dir()
	local ppos    = player:get_pos()
	      ppos.y  = ppos.y + 1.625
	local look_at = vec_add(ppos, vec_mul(dir, 1))

	core.add_item(look_at, stack)
end

local function name_sort(inv, reverse)
	return sort(inv, function(a, b)
		a, b = a:get_name(), b:get_name()

		if reverse then
			return a > b
		end

		return a < b
	end)
end

local function count_sort(inv, reverse)
	return sort(inv, function(a, b)
		a, b = a:get_count(), b:get_count()

		if reverse then
			return a > b
		end

		return a < b
	end)
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

local function apply_sort(inv, size, data, new_inv, start_i)
	if not data.ignore_hotbar then
		inv:set_list("main", new_inv)
		return
	end

	for i = start_i, size do
		local idx = i - start_i + 1
		inv:set_stack("main", i, new_inv[idx] or "")
	end
end

local function compress_items(list, start_i)
	local new_inv, _new_inv, special = {}, {}, {}

	for i = start_i, #list do
		local stack = list[i]
		local name = stack:get_name()
		local count = stack:get_count()
		local stackmax = stack:get_stack_max()
		local empty = stack:is_empty()
		local meta = stack:get_meta():to_table()
		local wear = stack:get_wear() > 0

		if not empty then
			if next(meta.fields) or wear or count >= stackmax then
				special[#special + 1] = stack
			else
				new_inv[name] = new_inv[name] or 0
				new_inv[name] = new_inv[name] + count
			end
		end
	end

	for name, count in pairs(new_inv) do
		local stackmax = ItemStack(name):get_stack_max()
		local iter = math.ceil(count / stackmax)
		local leftover = count

		for _ = 1, iter do
			_new_inv[#_new_inv + 1] = ItemStack(fmt("%s %u", name, math.min(stackmax, leftover)))
			leftover = leftover - stackmax
		end
	end

	for i = 1, #special do
		_new_inv[#_new_inv + 1] = special[i]
	end

	return _new_inv
end

local function sort_inventory(player, data)
	local inv = player:get_inventory()
	local list = inv:get_list("main")
	local size = inv:get_size("main")
	local start_i = data.ignore_hotbar and 10 or 1

	if data.inv_compress then
		list = compress_items(list, start_i)
	end

	local sorts = {}

	for _, def in ipairs(i3.sorting_methods) do
		sorts[def.name] = def.func
	end

	local new_inv = sorts[data.sort](list, data)

	if new_inv then
		apply_sort(inv, size, data, new_inv, start_i)
	end
end

-------------------------------------------------------------------------------

local _ = {
	-- Groups
	is_group = is_group,
	extract_groups = extract_groups,
	item_has_groups = item_has_groups,
	groups_to_items = groups_to_items,

	-- Compression
	compressible = compressible,
	compression_active = compression_active,

	-- Sorting
	search = search,
	name_sort = name_sort,
	count_sort = count_sort,
	sort_inventory = sort_inventory,
	get_sorting_idx = get_sorting_idx,
	sort_by_category = sort_by_category,
	apply_recipe_filters = apply_recipe_filters,

	-- Misc. functions
	err = err,
	msg = msg,
	is_fav = is_fav,
	is_str = is_str,
	is_num = is_num,
	is_func = is_func,
	show_item = show_item,
	spawn_item = spawn_item,
	true_str = true_str,
	true_table = true_table,
	clean_name = clean_name,

	-- Core functions
	clr = core.colorize,
	slz = core.serialize,
	dslz = core.deserialize,
	ESC = core.formspec_escape,
	check_privs = core.check_player_privs,

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

	-- Table
	maxn = table.maxn,
	sort = table.sort,
	copy = table.copy,
	concat = table.concat,
	insert = table.insert,
	remove = table.remove,
	indexof = table.indexof,
	is_table = is_table,
	table_eq = table_eq,
	table_merge = table_merge,
	table_replace = table_replace,
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
	vec_round = vector.round,
	vec_eq = vector.equals,
	vec_mul = vector.multiply,
}

function i3.get(...)
	local t = {}

	for i, var in ipairs{...} do
		t[i] = _[var]
	end

	return unpack(t)
end
