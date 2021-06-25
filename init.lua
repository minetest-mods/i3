i3 = {}

local modpath = core.get_modpath "i3"
local storage = core.get_mod_storage()
local slz, dslz = core.serialize, core.deserialize
local pdata = dslz(storage:get_string "pdata") or {}

-- Caches
local init_items    = {}
local searches      = {}
local recipes_cache = {}
local usages_cache  = {}
local fuel_cache    = {}
local replacements  = {fuel = {}}
local toolrepair

local tabs = {}

local model_aliases = loadfile(modpath .. "/etc/model_aliases.lua")()
local PNG, styles, fs_elements = loadfile(modpath .. "/etc/styles.lua")()
local compress_groups, compressed = loadfile(modpath .. "/etc/compress.lua")()
local group_stereotypes, group_names = loadfile(modpath .. "/etc/groups.lua")()

local progressive_mode = core.settings:get_bool "i3_progressive_mode"
local item_compression = core.settings:get_bool "i3_item_compression"
local damage_enabled = core.settings:get_bool "enable_damage"

local __3darmor, __skinsdb, __awards
local __sfinv, old_sfinv_fn
local __unified_inventory, old_unified_inventory_fn

local http = core.request_http_api()
local singleplayer = core.is_singleplayer()

local log = core.log
local after = core.after
local clr = core.colorize

local reg_items = core.registered_items
local reg_nodes = core.registered_nodes
local reg_craftitems = core.registered_craftitems
local reg_tools = core.registered_tools
local reg_entities = core.registered_entities
local reg_aliases = core.registered_aliases

local check_privs = core.check_player_privs
local translate = core.get_translated_string
local create_inventory = core.create_detached_inventory

local ESC = core.formspec_escape
local S = core.get_translator "i3"

local ES = function(...)
	return ESC(S(...))
end

local maxn, sort, concat, copy, insert, remove, indexof =
	table.maxn, table.sort, table.concat, table.copy,
	table.insert, table.remove, table.indexof

local sprintf, find, gmatch, match, sub, split, upper, lower =
	string.format, string.find, string.gmatch, string.match,
	string.sub, string.split, string.upper, string.lower

local min, max, floor, ceil, random =
	math.min, math.max, math.floor, math.ceil, math.random

local pairs, ipairs, next, type, setmetatable, tonum, unpack, select =
	pairs, ipairs, next, type, setmetatable, tonumber, unpack, select

local vec_new, vec_add, vec_mul, vec_eq, vec_round =
	vector.new, vector.add, vector.multiply, vector.equals, vector.round

local MAX_FAVS = 6
local ITEM_BTN_SIZE = 1.1

local INV_SIZE = 36
local HOTBAR_COUNT = 9

-- Players data interval
local SAVE_INTERVAL = 600

-- Progressive mode
local POLL_FREQ = 0.25
local HUD_TIMER_MAX = 1.5

local MIN_FORMSPEC_VERSION = 4

local BAG_SIZES = {
	small  = INV_SIZE + 3,
	medium = INV_SIZE + 6,
	large  = INV_SIZE + 9,
}

local SUBCAT = {
	"bag",
	"armor",
	"skins",
	"awards",
	"waypoints",
}

local function get_lang_code(info)
	return info and info.lang_code
end

local function get_formspec_version(info)
	return info and info.formspec_version or 1
end

local function outdated(name)
	local fs = sprintf("size[5.8,1.3]image[0,0;1,1;%s]label[1,0;%s]button_exit[2.4,0.8;1,1;;OK]",
		PNG.book,
		"Your Minetest client is outdated.\nGet the latest version on minetest.net to use i3")

	core.show_formspec(name, "i3", fs)
end

local old_is_creative_enabled = core.is_creative_enabled

function core.is_creative_enabled(name)
	return check_privs(name, {creative = true}) or old_is_creative_enabled(name)
end

local function err(str)
	return log("error", str)
end

local function msg(name, str)
	return core.chat_send_player(name, sprintf("[i3] %s", str))
end

local function is_num(x)
	return type(x) == "number"
end

local function is_str(x)
	return type(x) == "string"
end

local function true_str(str)
	return is_str(str) and str ~= ""
end

local function is_table(x)
	return type(x) == "table"
end

local function is_func(x)
	return type(x) == "function"
end

local function is_group(item)
	return sub(item, 1, 6) == "group:"
end

local function fmt(elem, ...)
	if not fs_elements[elem] then
		return sprintf(elem, ...)
	end

	return sprintf(fs_elements[elem], ...)
end

local function clean_name(item)
	if sub(item, 1, 1) == ":" or sub(item, 1, 1) == " " or sub(item, 1, 1) == "_" then
		item = sub(item, 2)
	end

	return item
end

local function round(num, decimal)
	local mul = 10 ^ decimal
	return floor(num * mul + 0.5) / mul
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

local function table_replace(t, val, new)
	for k, v in pairs(t) do
		if v == val then
			t[k] = new
		end
	end
end

local craft_types = {}

function i3.register_craft_type(name, def)
	if not true_str(name) then
		return err "i3.register_craft_type: name missing"
	end

	if not is_str(def.description) then
		def.description = ""
	end

	craft_types[name] = def
end

function i3.register_craft(def)
	local width, c = 0, 0

	if true_str(def.url) then
		if not http then
			return err(fmt([[i3.register_craft(): Unable to reach %s.
				No HTTP support for this mod: add it to the `secure.http_mods` or
				`secure.trusted_mods` setting.]], def.url))
		end

		http.fetch({url = def.url}, function(result)
			if result.succeeded then
				local t = core.parse_json(result.data)
				if is_table(t) then
					return i3.register_craft(t)
				end
			end
		end)

		return
	end

	if not is_table(def) or not next(def) then
		return err "i3.register_craft: craft definition missing"
	end

	if #def > 1 then
		for _, v in pairs(def) do
			i3.register_craft(v)
		end
		return
	end

	if def.result then
		def.output = def.result -- Backward compatibility
		def.result = nil
	end

	if not true_str(def.output) then
		return err "i3.register_craft: output missing"
	end

	if not is_table(def.items) then
		def.items = {}
	end

	if def.grid then
		if not is_table(def.grid) then
			def.grid = {}
		end

		if not is_table(def.key) then
			def.key = {}
		end

		local cp = copy(def.grid)
		sort(cp, function(a, b)
			return #a > #b
		end)

		width = #cp[1]

		for i = 1, #def.grid do
			while #def.grid[i] < width do
				def.grid[i] = def.grid[i] .. " "
			end
		end

		for symbol in gmatch(concat(def.grid), ".") do
			c = c + 1
			def.items[c] = def.key[symbol]
		end
	else
		local items, len = def.items, #def.items
		def.items = {}

		for i = 1, len do
			local rlen = #split(items[i], ",")

			if rlen > width then
				width = rlen
			end
		end

		for i = 1, len do
			while #split(items[i], ",") < width do
				items[i] = fmt("%s,", items[i])
			end
		end

		for name in gmatch(concat(items, ","), "[%s%w_:]+") do
			c = c + 1
			def.items[c] = clean_name(name)
		end
	end

	local item = match(def.output, "%S+")
	recipes_cache[item] = recipes_cache[item] or {}

	def.custom = true
	def.width = width

	insert(recipes_cache[item], def)
end

local recipe_filters = {}

function i3.add_recipe_filter(name, f)
	if not true_str(name) then
		return err "i3.add_recipe_filter: name missing"
	elseif not is_func(f) then
		return err "i3.add_recipe_filter: function missing"
	end

	recipe_filters[name] = f
end

function i3.set_recipe_filter(name, f)
	if not is_str(name) then
		return err "i3.set_recipe_filter: name missing"
	elseif not is_func(f) then
		return err "i3.set_recipe_filter: function missing"
	end

	recipe_filters = {[name] = f}
end

function i3.delete_recipe_filter(name)
	recipe_filters[name] = nil
end

function i3.get_recipe_filters()
	return recipe_filters
end

local function apply_recipe_filters(recipes, player)
	for _, filter in pairs(recipe_filters) do
		recipes = filter(recipes, player)
	end

	return recipes
end

local search_filters = {}

function i3.add_search_filter(name, f)
	if not true_str(name) then
		return err "i3.add_search_filter: name missing"
	elseif not is_func(f) then
		return err "i3.add_search_filter: function missing"
	end

	search_filters[name] = f
end

function i3.remove_search_filter(name)
	search_filters[name] = nil
end

function i3.get_search_filters()
	return search_filters
end

local function compression_active()
	return item_compression and not next(recipe_filters)
end

local function compressible(item)
	return compression_active() and compress_groups[item]
end

local function weird_desc(str)
	return not true_str(str) or find(str, "\n") or not find(str, "%u")
end

local function toupper(str)
	return str:gsub("%f[%w]%l", upper):gsub("_", " ")
end

local function snip(str, limit)
	return #str > limit and fmt("%s...", sub(str, 1, limit - 3)) or str
end

local function get_desc(item)
	if sub(item, 1, 1) == "_" then
		item = sub(item, 2)
	end

	local def = reg_items[item]

	if not def then
		return S("Unknown Item (@1)", item)
	end

	local desc = def.description

	if true_str(desc) then
		desc = desc:trim():match("[^\n]*"):gsub("_", " ")

		if not find(desc, "%u") then
			desc = toupper(desc)
		end

		return desc

	elseif true_str(item) then
		return toupper(match(item, ":(.*)"))
	end
end

local function item_has_groups(item_groups, groups)
	for i = 1, #groups do
		local group = groups[i]
		if (item_groups[group] or 0) == 0 then return end
	end

	return true
end

local function extract_groups(str)
	if sub(str, 1, 6) == "group:" then
		return split(sub(str, 7), ",")
	end
end

local function get_filtered_items(player, data)
	local items, known, c = {}, 0, 0

	for i = 1, #init_items do
		local item = init_items[i]
		local recipes = recipes_cache[item]
		local usages = usages_cache[item]

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

local function get_burntime(item)
	return core.get_craft_result{method = "fuel", items = {item}}.time
end

local function cache_fuel(item)
	local burntime = get_burntime(item)
	if burntime > 0 then
		fuel_cache[item] = {
			type = "fuel",
			items = {item},
			burntime = burntime,
			replacements = replacements.fuel[item],
		}
	end
end

local function show_item(def)
	return def and def.groups.not_in_creative_inventory ~= 1 and
		def.description and def.description ~= ""
end

local function search(data)
	data.alt_items = nil
	data.expand = ""

	local filter = data.filter

	if searches[filter] then
		data.items = searches[filter]
		return
	end

	local opt = "^(.-)%+([%w_]+)=([%w_,]+)"
	local search_filter = next(search_filters) and match(filter, opt)
	local filters = {}

	if search_filter then
		for filter_name, values in gmatch(filter, sub(opt, 6)) do
			if search_filters[filter_name] then
				values = split(values, ",")
				filters[filter_name] = values
			end
		end
	end

	local filtered_list, c = {}, 0

	for i = 1, #data.items_raw do
		local item = data.items_raw[i]
		local def = reg_items[item]
		local desc = lower(translate(data.lang_code, def and def.description)) or ""
		local search_in = fmt("%s %s", item, desc)
		local temp, j, to_add = {}, 1

		if search_filter then
			for filter_name, values in pairs(filters) do
				if values then
					local func = search_filters[filter_name]
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
			to_add = find(search_in, filter, 1, true)
		end

		if to_add then
			c = c + 1
			filtered_list[c] = item
		end
	end

	if not next(recipe_filters) then
		-- Cache the results only if searched 2 times
		if searches[filter] == nil then
			searches[filter] = false
		else
			searches[filter] = filtered_list
		end
	end

	data.items = filtered_list
end

local function get_item_usages(item, recipe, added)
	local groups = extract_groups(item)

	if groups then
		for name, def in pairs(reg_items) do
			if not added[name] and show_item(def) and item_has_groups(def.groups, groups) then
				local usage = copy(recipe)
				table_replace(usage.items, item, name)

				usages_cache[name] = usages_cache[name] or {}
				insert(usages_cache[name], 1, usage)

				added[name] = true
			end
		end
	elseif show_item(reg_items[item]) then
		usages_cache[item] = usages_cache[item] or {}
		insert(usages_cache[item], 1, recipe)
	end
end

local function get_usages(recipe)
	local added = {}

	for _, item in pairs(recipe.items) do
		item = reg_aliases[item] or item

		if not added[item] then
			get_item_usages(item, recipe, added)
			added[item] = true
		end
	end
end

local function cache_usages(item)
	local recipes = recipes_cache[item] or {}

	for i = 1, #recipes do
		get_usages(recipes[i])
	end

	if fuel_cache[item] then
		usages_cache[item] = table_merge(usages_cache[item] or {}, {fuel_cache[item]})
	end
end

local function drop_table(name, drop)
	local count_sure = 0
	local drop_items = drop.items or {}
	local max_items = drop.max_items

	for i = 1, #drop_items do
		local di = drop_items[i]
		local valid_rarity = di.rarity and di.rarity > 1

		if di.rarity or not max_items or
				(max_items and not di.rarity and count_sure < max_items) then
			for j = 1, #di.items do
				local dstack = ItemStack(di.items[j])
				local dname  = dstack:get_name()
				local dcount = dstack:get_count()
				local empty  = dstack:is_empty()

				if not empty and (dname ~= name or (dname == name and dcount > 1)) then
					local rarity = valid_rarity and di.rarity

					i3.register_craft{
						type   = rarity and "digging_chance" or "digging",
						items  = {name},
						output = fmt("%s %u", dname, dcount),
						rarity = rarity,
						tools  = di.tools,
					}
				end
			end
		end

		if not di.rarity then
			count_sure = count_sure + 1
		end
	end
end

local function cache_drops(name, drop)
	if true_str(drop) then
		local dstack = ItemStack(drop)
		local dname  = dstack:get_name()
		local empty  = dstack:is_empty()

		if not empty and dname ~= name then
			i3.register_craft{
				type = "digging",
				items = {name},
				output = drop,
			}
		end
	elseif is_table(drop) then
		drop_table(name, drop)
	end
end

local function cache_recipes(item)
	local recipes = core.get_all_craft_recipes(item)

	if replacements[item] then
		local _recipes = {}

		for k, v in ipairs(recipes or {}) do
			_recipes[#recipes + 1 - k] = v
		end

		local shift = 0
		local size_rpl = maxn(replacements[item])
		local size_rcp = #_recipes

		if size_rpl > size_rcp then
			shift = size_rcp - size_rpl
		end

		for k, v in pairs(replacements[item]) do
			k = k + shift

			if _recipes[k] then
				_recipes[k].replacements = v
			end
		end

		recipes = _recipes
	end

	if recipes then
		recipes_cache[item] = table_merge(recipes, recipes_cache[item] or {})
	end
end

local function get_recipes(player, item)
	local clean_item = reg_aliases[item] or item
	local recipes = recipes_cache[clean_item]
	local usages = usages_cache[clean_item]

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

local function groups_to_items(groups, get_all)
	if not get_all and #groups == 1 then
		local group = groups[1]
		local stereotype = group_stereotypes[group]
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

local function __sort(inv, reverse)
	sort(inv, function(a, b)
		if not is_str(a) then
			a = a:get_name()
		end

		if not is_str(b) then
			b = b:get_name()
		end

		if reverse then
			return a > b
		end

		return a < b
	end)
end

local function sort_itemlist(player, az)
	local inv = player:get_inventory()
	local list = inv:get_list("main")
	local size = inv:get_size("main")
	local new_inv, stack_meta = {}, {}

	for i = 1, size do
		local stack = list[i]
		local name = stack:get_name()
		local count = stack:get_count()
		local empty = stack:is_empty()
		local meta = stack:get_meta():to_table()
		local wear = stack:get_wear() > 0

		if not empty then
			if next(meta.fields) or wear then
				stack_meta[#stack_meta + 1] = stack
			else
				new_inv[#new_inv + 1] = fmt("%s %u", name, count)
			end
		end
	end

	for i = 1, #stack_meta do
		new_inv[#new_inv + 1] = stack_meta[i]
	end

	if az then
		__sort(new_inv)
	else
		__sort(new_inv, true)
	end

	inv:set_list("main", new_inv)
end

local function compress_items(player)
	local inv = player:get_inventory()
	local list = inv:get_list("main")
	local size = inv:get_size("main")
	local new_inv, _new_inv, special = {}, {}, {}

	for i = 1, size do
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
		local iter = ceil(count / stackmax)
		local leftover = count

		for _ = 1, iter do
			_new_inv[#_new_inv + 1] = fmt("%s %u", name, min(stackmax, leftover))
			leftover = leftover - stackmax
		end
	end

	for i = 1, #special do
		_new_inv[#_new_inv + 1] = special[i]
	end

	__sort(_new_inv)
	inv:set_list("main", _new_inv)
end

local function get_stack_max(inv, data, is_recipe, rcp)
	local list = inv:get_list("main")
	local size = inv:get_size("main")
	local counts_inv, counts_rcp, counts = {}, {}, {}
	local rcp_usg = is_recipe and "recipe" or "usage"

	for _, it in pairs(rcp.items) do
		counts_rcp[it] = (counts_rcp[it] or 0) + 1
	end

	data.export_counts[rcp_usg] = {}
	data.export_counts[rcp_usg].rcp = counts_rcp

	for i = 1, size do
		local stack = list[i]

		if not stack:is_empty() then
			local item = stack:get_name()
			local count = stack:get_count()

			for name in pairs(counts_rcp) do
				if is_group(name) then
					local def = reg_items[item]

					if def then
						local groups = extract_groups(name)

						if item_has_groups(def.groups, groups) then
							counts_inv[name] = (counts_inv[name] or 0) + count
						end
					end
				end
			end

			counts_inv[item] = (counts_inv[item] or 0) + count
		end
	end

	data.export_counts[rcp_usg].inv = counts_inv

	for name in pairs(counts_rcp) do
		counts[name] = floor((counts_inv[name] or 0) / (counts_rcp[name] or 0))
	end

	local max_stacks = math.huge

	for _, count in pairs(counts) do
		if count < max_stacks then
			max_stacks = count
		end
	end

	return max_stacks
end

local function spawn_item(player, stack)
	local dir     = player:get_look_dir()
	local ppos    = player:get_pos()
	      ppos.y  = ppos.y + 1.625
	local look_at = vec_add(ppos, vec_mul(dir, 1))

	core.add_item(look_at, stack)
end

local function get_stack(player, stack, str)
	local inv = player:get_inventory()
	local name = player:get_player_name()

	if inv:room_for_item("main", stack) then
		inv:add_item("main", stack)
		msg(name, S("@1 added in your inventory", str))
	else
		spawn_item(player, stack)
		msg(name, S("@1 spawned", str))
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
			local item_groups = groups_to_items(groups, true)
			local remaining = count

			for _, item in ipairs(item_groups) do
			for _name, _count in pairs(data.export_counts[rcp_usg].inv) do
				if item == _name and remaining > 0 then
					local c = min(remaining, _count)
					items[item] = c
					remaining = remaining - c
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
	local desc = get_desc(stackname)
	local iter = ceil(count / stackmax)
	local leftover = count

	for _ = 1, iter do
		local c = min(stackmax, leftover)
		local str

		if c > 1 then
			str = clr("#ff0", fmt("%s x %s", c, desc))
		else
			str = clr("#ff0", fmt("%s", desc))
		end

		local stack = ItemStack(fmt("%s %s", stackname, c))
		get_stack(player, stack, str)
		leftover = leftover - stackmax
	end
end

local function select_item(player, name, data, _f)
	local item

	for field in pairs(_f) do
		if find(field, ":") then
			item = field
			break
		end
	end

	if not item then return end

	if compressible(item) then
		local idx

		for i = 1, #data.items do
			local it = data.items[i]
			if it == item then
				idx = i
				break
			end
		end

		if data.expand ~= "" then
			data.alt_items = nil

			if item == data.expand then
				data.expand = nil
				return
			end
		end

		if idx and item ~= data.expand then
			data.alt_items = copy(data.items)
			data.expand = item

			if compress_groups[item] then
				local items = copy(compress_groups[item])
				insert(items, fmt("_%s", item))

				sort(items, function(a, b)
					if a:sub(1, 1) == "_" then
						a = a:sub(2)
					end

					return a < b
				end)

				local i = 1

				for _, v in ipairs(items) do
					if show_item(reg_items[clean_name(v)]) then
						insert(data.alt_items, idx + i, v)
						i = i + 1
					end
				end
			end
		end
	else
		if sub(item, 1, 1) == "_" then
			item = sub(item, 2)
		elseif sub(item, 1, 6) == "group|" then
			item = match(item, "([%w:_]+)$")
		end

		item = reg_aliases[item] or item
		if not reg_items[item] then return end

		if core.is_creative_enabled(name) then
			local stack = ItemStack(item)
			local stackmax = stack:get_stack_max()
			stack = fmt("%s %s", item, stackmax)
			return get_stack(player, stack, clr("#ff0", fmt("%u x %s", stackmax, get_desc(item))))
		end

		if item == data.query_item then return end
		local recipes, usages = get_recipes(player, item)

		data.query_item = item
		data.recipes    = recipes
		data.usages     = usages
		data.rnum       = 1
		data.unum       = 1
		data.scrbar_rcp = 1
		data.scrbar_usg = 1
		data.export_rcp = nil
		data.export_usg = nil
	end
end

local function repairable(tool)
	local def = reg_tools[tool]
	return toolrepair and def and def.groups and def.groups.disable_repair ~= 1
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

local function get_tooltip(item, info, pos)
	local tooltip

	if info.groups then
		sort(info.groups)
		tooltip = group_names[concat(info.groups, ",")]

		if not tooltip then
			local groupstr = {}

			for i = 1, #info.groups do
				insert(groupstr, clr("#ff0", info.groups[i]))
			end

			groupstr = concat(groupstr, ", ")
			tooltip = S("Any item belonging to the groups: @1", groupstr)
		end
	else
		tooltip = info.meta_desc or get_desc(item)
	end

	local function add(str)
		return fmt("%s\n%s", tooltip, str)
	end

	if info.cooktime then
		tooltip = add(S("Cooking time: @1", clr("#ff0", info.cooktime)))
	end

	if info.burntime then
		tooltip = add(S("Burning time: @1", clr("#ff0", info.burntime)))
	end

	if info.replace then
		for i = 1, #info.replace.items do
			local rpl = match(info.replace.items[i], "%S+")
			local desc = clr("#ff0", get_desc(rpl))

			if info.replace.type == "cooking" then
				tooltip = add(S("Replaced by @1 on smelting", desc))
			elseif info.replace.type == "fuel" then
				tooltip = add(S("Replaced by @1 on burning", desc))
			else
				tooltip = add(S("Replaced by @1 on crafting", desc))
			end
		end
	end

	if info.repair then
		tooltip = add(S("Repairable by step of @1", clr("#ff0", toolrepair .. "%")))
	end

	if info.rarity then
		local chance = (1 / max(1, info.rarity)) * 100
		tooltip = add(S("@1 of chance to drop", clr("#ff0", chance .. "%")))
	end

	if info.tools then
		local several = #info.tools > 1
		local names = several and "\n" or ""

		if several then
			for i = 1, #info.tools do
				names = fmt("%s\t\t- %s\n", names, clr("#ff0", get_desc(info.tools[i])))
			end

			tooltip = add(S("Only drop if using one of these tools: @1", sub(names, 1, -2)))
		else
			tooltip = add(S("Only drop if using this tool: @1",
				clr("#ff0", get_desc(info.tools[1]))))
		end
	end

	if pos then
		return fmt("tooltip", pos.x, pos.y, ITEM_BTN_SIZE, ITEM_BTN_SIZE, ESC(tooltip))
	end

	return fmt("tooltip[%s;%s]", item, ESC(tooltip))
end

local function get_output_fs(fs, data, rcp, is_recipe, shapeless, right, btn_size, _btn_size)
	local custom_recipe = craft_types[rcp.type]

	if custom_recipe or shapeless or rcp.type == "cooking" then
		local icon = custom_recipe and custom_recipe.icon or shapeless and "shapeless" or "furnace"

		if not custom_recipe then
			icon = fmt("i3_%s.png^\\[resize:16x16", icon)
		end

		local pos_x = right + btn_size + 0.42
		local pos_y = data.yoffset + 0.9

		if sub(icon, 1, 10) == "i3_furnace" then
			fs("animated_image", pos_x, pos_y, 0.5, 0.5, PNG.furnace_anim, 8, 180)
		else
			fs("image", pos_x, pos_y, 0.5, 0.5, icon)
		end

		local tooltip = custom_recipe and custom_recipe.description or
				shapeless and S"Shapeless" or S"Cooking"

		fs("tooltip", pos_x, pos_y, 0.5, 0.5, ESC(tooltip))
	end

	local arrow_X = right + 0.2 + (_btn_size or ITEM_BTN_SIZE)
	local X = arrow_X + 1.2
	local Y = data.yoffset + 1.4

	fs("image", arrow_X, Y + 0.06, 1, 1, PNG.arrow)

	if rcp.type == "fuel" then
		fs("animated_image", X + 0.05, Y, ITEM_BTN_SIZE, ITEM_BTN_SIZE, PNG.fire_anim, 8, 180)
	else
		local item = ItemStack(rcp.output)
		local meta = item:get_meta()
		local name = item:get_name()
		local count = item:get_count()
		local bt_s = ITEM_BTN_SIZE * 1.2
		local _name = fmt("_%s", name)
		local pos

		if meta:get_string("color") ~= "" or meta:get_string("palette_index") ~= "" then
			local rcp_usg = is_recipe and "rcp" or "usg"

			fs(fmt("style_type[list;size=%f]", ITEM_BTN_SIZE))
			fs("listcolors[#bababa50;#bababa99]")
			fs(fmt("list[detached:i3_output_%s;main;%f,%f;1,1;]", rcp_usg, X + 0.11, Y))
			fs("button",  X + 0.11, Y, ITEM_BTN_SIZE, ITEM_BTN_SIZE, _name, "")

			local inv = core.get_inventory {
				type = "detached",
				name = fmt("i3_output_%s", rcp_usg)
			}

			inv:set_stack("main", 1, item)
			pos = {x = X + 0.11, y = Y}
		else
			fs("image", X, Y - 0.11, bt_s, bt_s, PNG.slot)

			fs("item_image_button",
				X + 0.11, Y, ITEM_BTN_SIZE, ITEM_BTN_SIZE,
				fmt("%s %u", name, count * (is_recipe and data.scrbar_rcp or data.scrbar_usg or 1)),
				_name, "")
		end

		local def = reg_items[name]
		local unknown = not def or nil
		local desc = def and def.description
		local weird = name ~= "" and desc and weird_desc(desc) or nil
		local burntime = fuel_cache[name] and fuel_cache[name].burntime

		local short_desc = meta:get_string("short_description")
		local long_desc  = meta:get_string("description")
		local meta_desc  = (short_desc ~= "" and short_desc) or (long_desc ~= "" and long_desc)

		local infos = {
			unknown   = unknown,
			weird     = weird,
			burntime  = burntime,
			repair    = repairable(name),
			rarity    = rcp.rarity,
			tools     = rcp.tools,
			meta_desc = meta_desc,
		}

		if next(infos) then
			fs(get_tooltip(_name, infos, pos))
		end
	end
end

local function get_grid_fs(fs, data, rcp, is_recipe)
	local width = rcp.width or 1
	local right, btn_size, _btn_size = 0, ITEM_BTN_SIZE
	local cooktime, shapeless

	if rcp.type == "cooking" then
		cooktime, width = width, 1
	elseif width == 0 and not rcp.custom then
		shapeless = true
		local n = #rcp.items
		width = (n < 5 and n > 1) and 2 or min(3, max(1, n))
	end

	local rows = ceil(maxn(rcp.items) / width)
	local large_recipe = width > 3 or rows > 3

	if large_recipe then
		fs("style_type[item_image_button;border=true]")
	end

	for i = 1, width * rows do
		local item  = rcp.items[i] or ""
		      item  = ItemStack(item)
		local meta  = item:get_meta()
		local name  = item:get_name()
		local count = item:get_count()

		local X = ceil((i - 1) % width - width)
		X = X + (X * 0.2) + data.inv_width + 3.9

		local Y = ceil(i / width) - min(2, rows)
		Y = Y + (Y * 0.15)  + data.yoffset + 1.4

		if large_recipe then
			btn_size = (3 / width) * (3 / rows) + 0.3
			_btn_size = btn_size

			local xi = (i - 1) % width
			local yi = floor((i - 1) / width)

			X = btn_size * xi + data.inv_width + 0.3 + (xi * 0.05)
			Y = btn_size * yi + data.yoffset + 0.2 + (yi * 0.05)
		end

		if X > right then
			right = X
		end

		local groups

		if is_group(name) then
			groups = extract_groups(name)
			name = groups_to_items(groups)
		end

		local label = groups and "\nG" or ""
		local replace

		for j = 1, #(rcp.replacements or {}) do
			local replacement = rcp.replacements[j]
			if replacement[1] == name then
				replace = replace or {type = rcp.type, items = {}}

				local added

				for _, v in ipairs(replace.items) do
					if replacement[2] == v then
						added = true
						break
					end
				end

				if not added then
					label = fmt("%s%s\nR", label ~= "" and "\n" or "", label)
					replace.items[#replace.items + 1] = replacement[2]
				end
			end
		end

		if not large_recipe then
			fs("image", X, Y, btn_size, btn_size, PNG.slot)
		end

		local btn_name = groups and fmt("group|%s|%s", groups[1], name) or name

		fs("item_image_button", X, Y, btn_size, btn_size,
			fmt("%s %u", name, count * (is_recipe and data.scrbar_rcp or data.scrbar_usg or 1)),
			btn_name, label)

		local def = reg_items[name]
		local unknown = not def or nil
		      unknown = not groups and unknown or nil
		local desc = def and def.description
		local weird = name ~= "" and desc and weird_desc(desc) or nil
		local burntime = fuel_cache[name] and fuel_cache[name].burntime

		local short_desc = meta:get_string("short_description")
		local long_desc  = meta:get_string("description")
		local meta_desc  = (short_desc ~= "" and short_desc) or (long_desc ~= "" and long_desc) or nil

		local infos = {
			unknown   = unknown,
			weird     = weird,
			groups    = groups,
			burntime  = burntime,
			cooktime  = cooktime,
			replace   = replace,
			meta_desc = meta_desc,
		}

		if next(infos) then
			fs(get_tooltip(btn_name, infos))
		end
	end

	if large_recipe then
		fs("style_type[item_image_button;border=false]")
	end

	get_output_fs(fs, data, rcp, is_recipe, shapeless, right, btn_size, _btn_size)
end

local function get_rcp_lbl(fs, data, panel, rn, is_recipe)
	local rcp = is_recipe and panel.rcp[data.rnum] or panel.rcp[data.unum]

	if rcp.custom then
		fs("hypertext", data.inv_width + 4.8, data.yoffset + 0.12, 3, 0.6, "custom_rcp",
			fmt("<global size=16><right><i>%s</i></right>", ES"Custom recipe"))
	end

	local lbl = ES("Usage @1 of @2", data.unum, rn)

	if is_recipe then
		lbl = ES("Recipe @1 of @2", data.rnum, rn)
	end

	local one = rn == 1
	local y = data.yoffset + 3.3

	fs("hypertext", data.inv_width + (one and 4.7 or 3.95), y, 3, 0.6, "rcp_num",
		fmt("<global size=16><right>%s</right>", lbl))

	if not one then
		local btn_suffix = is_recipe and "recipe" or "usage"
		local prev_name = fmt("prev_%s", btn_suffix)
		local next_name = fmt("next_%s", btn_suffix)
		local size = 0.3

		fs("image_button", data.inv_width + 7.05, y, size, size, "", prev_name, "")
		fs("image_button", data.inv_width + 7.5,  y, size, size, "", next_name, "")
	end

	get_grid_fs(fs, data, rcp, is_recipe)
end

local function get_model_fs(fs, data, def, model_alias)
	if model_alias then
		if model_alias.drawtype == "entity" then
			def = reg_entities[model_alias.name]
			local init_props = def.initial_properties
			def.textures = init_props and init_props.textures or def.textures
			def.mesh = init_props and init_props.mesh or def.mesh
		else
			def = reg_items[model_alias.name]
		end
	end

	local tiles = def.tiles or def.textures or {}
	local t = {}

	for _, v in ipairs(tiles) do
		local _name

		if v.color then
			if is_num(v.color) then
				local hex = fmt("%02x", v.color)

				while #hex < 8 do
					hex = "0" .. hex
				end

				_name = fmt("%s^[multiply:%s", v.name,
					fmt("#%s%s", sub(hex, 3), sub(hex, 1, 2)))
			else
				_name = fmt("%s^[multiply:%s", v.name, v.color)
			end
		elseif v.animation then
			_name = fmt("%s^[verticalframe:%u:0", v.name, v.animation.aspect_h)
		end

		t[#t + 1] = _name or v.name or v
	end

	while #t < 6 do
		t[#t + 1] = t[#t]
	end

	fs("model", data.inv_width + 6.6, data.yoffset + 0.05, 1.3, 1.3, "preview",
		def.mesh, concat(t, ","), "0,0", "true", "true",
		model_alias and model_alias.frames or "")
end

local function get_header(fs, data)
	local fav = is_fav(data.favs, data.query_item)
	local nfavs = #data.favs
	local star_x, star_y, size = data.inv_width + 0.3, data.yoffset + 0.2, 0.4

	if nfavs < MAX_FAVS or (nfavs == MAX_FAVS and fav) then
		local fav_marked = fmt("i3_fav%s.png", fav and "_off" or "")

		fs(fmt("style[fav;fgimg=%s;fgimg_hovered=%s;fgimg_pressed=%s]",
			fmt("i3_fav%s.png", fav and "" or "_off"), fav_marked, fav_marked))
		fs("image_button", star_x, star_y, size, size, "", "fav", "")
		fs(fmt("tooltip[fav;%s]", fav and ES"Unmark this item" or ES"Mark this item"))
	else
		fs(fmt("style[nofav;fgimg=%s;fgimg_hovered=%s;fgimg_pressed=%s]",
			"i3_fav_off.png", PNG.cancel, PNG.cancel))
		fs("image_button", star_x, star_y, size, size, "", "nofav", "")
		fs(fmt("tooltip[nofav;%s]", ES"Cannot mark this item. Bookmark limit reached."))
	end

	fs("image_button", star_x + 0.05, star_y + 0.6, size, size, "", "exit", "")
	fs(fmt("tooltip[exit;%s]", ES"Back to item list"))

	local desc_lim, name_lim = 34, 35
	local desc = translate(data.lang_code, get_desc(data.query_item))
	      desc = ESC(desc)
	local tech_name = data.query_item
	local X = data.inv_width + 0.95
	local Y1 = data.yoffset + 0.47
	local Y2 = Y1 + 0.5

	if #desc > desc_lim then
		fs("tooltip", X, Y1 - 0.1, 5.7, 0.24, desc)
		desc = snip(desc, desc_lim)
	end

	if #tech_name > name_lim then
		fs("tooltip", X, Y2 - 0.1, 5.7, 0.24, tech_name)
		tech_name = snip(tech_name, name_lim)
	end

	fs("style_type[label;font=bold;font_size=20]")
	fs("label", X, Y1, desc)
	fs("style_type[label;font=mono;font_size=16]")
	fs("label", X, Y2, clr("#7bf", tech_name))
	fs("style_type[label;font=normal;font_size=16]")

	local def = reg_items[data.query_item]
	local model_alias = model_aliases[data.query_item]

	if def.drawtype == "mesh" or model_alias then
		get_model_fs(fs, data, def, model_alias)
	else
		fs("item_image", data.inv_width + 6.8, data.yoffset + 0.17, 1.1, 1.1, data.query_item)
	end
end

local function get_export_fs(fs, data, is_recipe, is_usage, max_stacks_rcp, max_stacks_usg)
	local name = is_recipe and "rcp" or "usg"
	local show_export = (is_recipe and data.export_rcp) or (is_usage and data.export_usg)

	fs(fmt("style[export_%s;fgimg=%s;fgimg_hovered=%s]",
		name, fmt("%s", show_export and PNG.export_hover or PNG.export), PNG.export_hover))
	fs("image_button", data.inv_width + 7.35, data.yoffset + 0.2, 0.45, 0.45, "", fmt("export_%s", name), "")
	fs(fmt("tooltip[export_%s;%s]", name, ES"Quick crafting"))

	if not show_export then return end

	local craft_max = is_recipe and max_stacks_rcp or max_stacks_usg
	local stack_fs = (is_recipe and data.scrbar_rcp) or (is_usage and data.scrbar_usg) or 1

	if stack_fs > craft_max then
		stack_fs = craft_max

		if is_recipe then
			data.scrbar_rcp = craft_max
		elseif is_usage then
			data.scrbar_usg = craft_max
		end
	end

	fs(fmt("style[scrbar_%s;noclip=true]", name),
	   fmt("scrollbaroptions[min=1;max=%u;smallstep=1]", craft_max))
	fs("scrollbar", data.inv_width + 8.1, data.yoffset, 3, 0.35, "horizontal", fmt("scrbar_%s", name), stack_fs)
	fs("button", data.inv_width + 8.1, data.yoffset + 0.4, 3, 0.7, fmt("craft_%s", name),
		ES("Craft (x@1)", stack_fs))
end

local function get_rcp_extra(player, fs, data, panel, is_recipe, is_usage)
	fs("container[0,0.075]")
	local rn = panel.rcp and #panel.rcp

	if rn then
		local rcp_ok = is_recipe and panel.rcp[data.rnum].type == "normal"
		local usg_ok = is_usage and panel.rcp[data.unum].type == "normal"
		local max_stacks_rcp, max_stacks_usg = 0, 0
		local inv = player:get_inventory()

		if rcp_ok then
			max_stacks_rcp = get_stack_max(inv, data, is_recipe, panel.rcp[data.rnum])
		end

		if usg_ok then
			max_stacks_usg = get_stack_max(inv, data, is_recipe, panel.rcp[data.unum])
		end

		if is_recipe and max_stacks_rcp == 0 then
			data.export_rcp = nil
			data.scrbar_rcp = 1
		elseif is_usage and max_stacks_usg == 0 then
			data.export_usg = nil
			data.scrbar_usg = 1
		end

		if max_stacks_rcp > 0 or max_stacks_usg > 0 then
			get_export_fs(fs, data, is_recipe, is_usage, max_stacks_rcp, max_stacks_usg)
		end

		get_rcp_lbl(fs, data, panel, rn, is_recipe)
	else
		local lbl = is_recipe and ES"No recipes" or ES"No usages"
		fs("button", data.inv_width + 0.1, data.yoffset + (panel.height / 2) - 0.5,
			7.8, 1, "no_rcp", lbl)
	end

	fs("container_end[]")
end

local function get_items_fs(fs, data, extend)
	if compression_active() then
		local new = {}

		for i = 1, #data.items do
			local item = data.items[i]
			if not compressed[item] then
				new[#new + 1] = item
			end
		end

		data.items = new
	end

	local items = data.alt_items or data.items
	local rows = 8
	local lines = extend and 12 or 9
	local ipp = rows * lines
	local size = 0.85

	fs(fmt("box[%f,0.2;4.05,0.6;#bababa25]", data.inv_width + 0.3),
	   "set_focus[filter]",
	   fmt("field[%f,0.2;2.95,0.6;filter;;%s]", data.inv_width + 0.35, ESC(data.filter)),
	   "field_close_on_enter[filter;false]")

	fs("image_button", data.inv_width + 3.35, 0.35, 0.3,  0.3,  "", "cancel", "")
	fs("image_button", data.inv_width + 3.85, 0.32, 0.35, 0.35, "", "search", "")
	fs("image_button", data.inv_width + 5.27, 0.3,  0.35, 0.35, "", "prev_page", "")
	fs("image_button", data.inv_width + 7.45, 0.3,  0.35, 0.35, "", "next_page", "")

	data.pagemax = max(1, ceil(#items / ipp))

	fs("button", data.inv_width + 5.6, 0.14, 1.88, 0.7, "pagenum",
		fmt("%s / %u", clr("#ff0", data.pagenum), data.pagemax))

	if #items == 0 then
		local lbl = ES"No item to show"

		if next(recipe_filters) and #init_items > 0 and data.filter == "" then
			lbl = ES"Collect items to reveal more recipes"
		end

		fs("button", data.inv_width + 0.1, 3, 8, 1, "no_item", lbl)
	else
		local first_item = (data.pagenum - 1) * ipp

		for i = first_item, first_item + ipp - 1 do
			local item = items[i + 1]
			if not item then break end

			local _compressed = item:sub(1, 1) == "_"
			local name = _compressed and item:sub(2) or item

			local X = i % rows
			      X = X - (X * 0.045) + data.inv_width + 0.28

			local Y = round((i % ipp - X) / rows + 1, 0)
			      Y = Y - (Y * (extend and 0.085 or 0.035)) + 0.95

			fs[#fs + 1] = fmt("item_image_button", X, Y, size, size, name, item, "")

			if compressible(item) then
				local expand = data.expand == name

				fs(fmt("tooltip[%s;%s]", item, expand and ES"Click to hide" or ES"Click to expand"))
				fs("style_type[label;font=bold;font_size=20]")
				fs("label", X + 0.65, Y + 0.7, expand and "-" or "+")
				fs("style_type[label;font=normal;font_size=16]")
			end
		end
	end
end

local function get_favs(fs, data)
	fs("label", data.inv_width + 0.4, data.yoffset + 0.4, ES"Bookmarks")

	for i = 1, #data.favs do
		local item = data.favs[i]
		local X = data.inv_width - 0.7 + (i * 1.2)
		local Y = data.yoffset + 0.8

		if data.query_item == item then
			fs("image", X, Y, ITEM_BTN_SIZE, ITEM_BTN_SIZE, PNG.slot)
		end

		fs("item_image_button", X, Y, ITEM_BTN_SIZE, ITEM_BTN_SIZE, item, item, "")
	end
end

local function get_panels(player, data, fs, full_height)
	local _title   = {name = "title", height = 1.4}
	local _favs    = {name = "favs",  height = 2.23}
	local _items   = {name = "items", height = 9.69}
	local _recipes = {name = "recipes", rcp = data.recipes, height = 4.045}
	local _usages  = {name = "usages",  rcp = data.usages,  height = 4.045}
	local panels, extend

	if data.query_item then
		panels = {_title, _recipes, _usages, _favs}
	else
		panels = {_items, _favs}

		if #data.favs == 0 then
			extend = true
			remove(panels, 2)
			_items.height = full_height
		end
	end

	for idx = 1, #panels do
		local panel = panels[idx]
		data.yoffset = 0

		if idx > 1 then
			for _idx = idx - 1, 1, -1 do
				data.yoffset = data.yoffset + panels[_idx].height + 0.1
			end
		end

		fs("bg9", data.inv_width + 0.1, data.yoffset, 7.9, panel.height, PNG.bg_full, 10)

		local is_recipe, is_usage = panel.name == "recipes", panel.name == "usages"

		if is_recipe or is_usage then
			get_rcp_extra(player, fs, data, panel, is_recipe, is_usage)
		elseif panel.name == "items" then
			get_items_fs(fs, data, extend)
		elseif panel.name == "title" then
			get_header(fs, data)
		elseif panel.name == "favs" then
			get_favs(fs, data)
		end
	end
end

local function add_subtitle(fs, name, y, ctn_len, font_size, sep, label)
	fs(fmt("style[%s;font=bold;font_size=%u]", name, font_size))
	fs("button", 0, y, ctn_len, 0.5, name, ESC(label))

	if sep then
		fs("image", 0, y + 0.55, ctn_len, 0.035, PNG.bar)
	end
end

local function get_award_list(data, fs, ctn_len, yextra, award_list, awards_unlocked, award_list_nb)
	local percent = fmt("%.1f%%", (awards_unlocked * 100) / award_list_nb):gsub(".0", "")

	add_subtitle(fs, "awards", yextra, ctn_len, 18, false,
		ES("Achievements: @1 of @2 (@3)", awards_unlocked, award_list_nb, percent))

	for i = 1, award_list_nb do
		local award = award_list[i]
		local y = yextra - 0.6 + i + (i * 0.3)

		local def, progress = award.def, award.progress
		local title, desc = def.title, def.description

		title = translate(data.lang_code, title)
		desc = translate(data.lang_code, desc):gsub("%.$", "")

		local title_lim, _title = 27
		local desc_lim, _desc = 39
		local icon_size = 1.1
		local box_len = ctn_len - icon_size + 0.1

		if #title > title_lim then
			_title = snip(title, title_lim)
		end

		if #desc > desc_lim then
			_desc = snip(desc, desc_lim)
		end

		if not award.unlocked and def.secret then
			title = ES"Secret award"
			desc = ES"Unlock this award to find out what it is"
		end

		local icon = def.icon or "awards_unknown.png"

		if not award.unlocked then
			icon = fmt("%s^\\[colorize:#000:180", icon)
		end

		fs[#fs + 1] = fmt("image", 0, y + 0.01, icon_size, icon_size, icon)
		fs[#fs + 1] = "style_type[box;colors=#bababa30,#bababa30,#bababa05,#bababa05]"
		fs[#fs + 1] = fmt("box", icon_size + 0.1, y, box_len, icon_size, "")

		if progress then
			local current, target = progress.current, progress.target
			local curr_bar = (current * box_len) / target

			fs[#fs + 1] = fmt("box", icon_size + 0.1, y + 0.8, box_len, 0.3, "#101010")
			fs[#fs + 1] = "style_type[box;colors=#9dc34c80,#9dc34c,#9dc34c,#9dc34c80]"
			fs[#fs + 1] = fmt("box", icon_size + 0.1, y + 0.8, curr_bar, 0.3, "")
			fs[#fs + 1] = "style_type[label;font_size=14]"
			fs[#fs + 1] = fmt("label", icon_size + 0.5, y + 0.97, fmt("%u / %u", current, target))

			y = y - 0.14
		end

		title = _title or title
		desc = _desc or desc

		fs[#fs + 1] = "style_type[label;font=bold;font_size=17]"
		fs[#fs + 1] = fmt("label", icon_size + 0.2, y + 0.4, title)
		fs[#fs + 1] = "style_type[label;font=normal;font_size=15]"
		fs[#fs + 1] = fmt("label", icon_size + 0.2, y + 0.75, clr("#bbbbbb", desc))
		fs[#fs + 1] = "style_type[label;font_size=16]"
	end
end

local function get_waypoint_fs(fs, data, player, yextra, ctn_len)
	fs(fmt("box[0,%f;4.9,0.6;#bababa25]", yextra + 1.1))
	fs("label", 0, yextra + 0.85, ES"Waypoint name:")
	fs(fmt("field[0.1,%f;4.8,0.6;waypoint_name;;]", yextra + 1.1))
	fs("image_button", 5.1, yextra + 1.15, 0.5, 0.5, "", "waypoint_add", "")
	fs(fmt("tooltip[waypoint_add;%s]", ES"Add waypoint"))

	if #data.waypoints == 0 then return end

	for i, v in ipairs(data.waypoints) do
		local y = yextra + 1.35 + (i - (i * 0.3))
		local icon_size, yi = 0.35, y + 0.12

		fs("style_type[box;colors=#bababa30,#bababa30,#bababa05,#bababa05]")
		fs("box", 0, y, ctn_len, 0.6, "")

		local waypoint_name, lim = v.name, 18

		if #v.name > lim then
			waypoint_name = snip(waypoint_name, lim)
		end

		fs("style_type[label;font_size=17]")

		local hex = fmt("%02x", v.color)

		while #hex < 6 do
			hex = "0" .. hex
		end

		fs("label", 0.15, y + 0.33, clr(fmt("#%s", hex), waypoint_name))

		fs("tooltip", 0, y, ctn_len - 2.5, 0.65,
			fmt("Name: %s\nPosition:%s", clr("#ff0", v.name),
				core.pos_to_string(v.pos, 0):sub(2,-2):gsub("(%-*%d+)", clr("#ff0", " %1"))))

		local del = fmt("waypoint_%u_delete", i)
		fs(fmt("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]", del, PNG.trash, PNG.trash_hover))
		fs("image_button", ctn_len - 0.5, yi, icon_size, icon_size, "", del, "")
		fs(fmt("tooltip[%s;%s]", del, ES"Remove waypoint"))

		local rfs = fmt("waypoint_%u_refresh", i)
		fs(fmt("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]", rfs, PNG.refresh, PNG.refresh_hover))
		fs("image_button", ctn_len - 1, yi, icon_size, icon_size, "", rfs, "")
		fs(fmt("tooltip[%s;%s]", rfs, ES"Change color"))

		local vsb = fmt("waypoint_%u_hide", i)
		fs(fmt("style[%s;fgimg=%s;content_offset=0]", vsb, v.hide and PNG.nonvisible or PNG.visible))
		fs("image_button", ctn_len - 1.5, yi, icon_size, icon_size, "", vsb, "")
		fs(fmt("tooltip[%s;%s]", vsb, v.hide and ES"Show waypoint" or ES"Hide waypoint"))

		if check_privs(player, {teleport = true}) then
			local tp = fmt("waypoint_%u_teleport", i)

			fs(fmt("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]",
				tp, PNG.teleport, PNG.teleport_hover))

			fs("image_button", ctn_len - 2, yi, icon_size, icon_size, "", tp, "")
			fs(fmt("tooltip[%s;%s]", tp, ES"Teleport to waypoint"))
		end
	end

	fs("style_type[label;font_size=16]")
end

local function get_ctn_content(fs, data, player, yoffset, ctn_len, award_list, awards_unlocked, award_list_nb)
	local name = player:get_player_name()
	add_subtitle(fs, "player_name", 0, ctn_len, 22, true, ESC(name))

	if damage_enabled then
		local hp = data.hp or player:get_hp() or 20
		local half = ceil((hp / 2) % 1)
		local hearts = (hp / 2) + half
		local heart_size = 0.35
		local heart_x, heart_h = 0.65, yoffset + 0.75

		for i = 1, 10 do
			fs("image", heart_x + ((i - 1) * (heart_size + 0.1)), heart_h,
				heart_size, heart_size, PNG.heart_grey)
		end

		for i = 1, hearts do
			fs("image", heart_x + ((i - 1) * (heart_size + 0.1)), heart_h,
				heart_size, heart_size,
				(half == 1 and i == floor(hearts)) and PNG.heart_half or PNG.heart)
		end
	else
		yoffset = yoffset - 0.5
	end

	fs(fmt("list[current_player;craft;%f,%f;3,3;]", 0, yoffset + 1.45))
	fs("image", 3.47, yoffset + 2.69, 0.85, 0.85, PNG.arrow)
	fs(fmt("list[current_player;craftpreview;%f,%f;1,1;]", 4.45, yoffset + 2.6),
	   fmt("list[detached:i3_trash;main;%f,%f;1,1;]", 4.45, yoffset + 3.75))
	fs("image", 4.45, yoffset + 3.75, 1, 1, PNG.trash)

	local yextra = damage_enabled and 5.5 or 5

	for i, title in ipairs(SUBCAT) do
		local btn_name = fmt("btn_%s", title)

		fs(fmt("style[btn_%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]", title,
			data.subcat == i and PNG[fmt("%s_hover", title)] or PNG[title],
			PNG[fmt("%s_hover", title)]))

		fs("image_button", 0.25 + ((i - 1) * 1.18), yextra - 0.2, 0.5, 0.5, "", btn_name, "")
		fs(fmt("tooltip[%s;%s]", btn_name, title:gsub("^%l", upper)))
	end

	fs("box", 0, yextra + 0.45, ctn_len, 0.045, "#bababa50")
	fs("box", (data.subcat - 1) * 1.18, yextra + 0.45, 1, 0.045, "#f9826c")

	local function not_installed(modname)
		fs("hypertext", 0, yextra + 0.9, ctn_len, 0.6, "not_installed",
			fmt("<center><style color=#7bf font=mono>%s</style> not installed</center>", modname))
	end

	if data.subcat == 1 then
		fs(fmt("list[detached:%s_backpack;main;0,%f;1,1;]", ESC(name), yextra + 0.7))

		if not data.bag:get_stack("main", 1):is_empty() then
			fs("hypertext", 1.2, yextra + 0.89, ctn_len - 1.9, 0.8, "bpk",
				ES("The inventory is extended by @1 slots", BAG_SIZES[data.bag_size] - INV_SIZE))
		end

	elseif data.subcat == 2 then
		if __3darmor then
			fs(fmt("list[detached:%s_armor;armor;0,%f;3,2;]", ESC(name), yextra + 0.7))

			local armor_def = armor.def[name]

			fs("label", 3.65, yextra + 1.55, fmt("%s: %s", ES"Level", armor_def.level))
			fs("label", 3.65, yextra + 2.05, fmt("%s: %s", ES"Heal", armor_def.heal))
		else
			not_installed("3d_armor")
		end

	elseif data.subcat == 3 then
		if __skinsdb then
			local _skins = skins.get_skinlist_for_player(name)
			local sks = {}

			for _, skin in ipairs(_skins) do
				sks[#sks + 1] = skin.name
			end

			sks = concat(sks, ","):gsub(";", "")

			fs("label", 0, yextra + 0.85, fmt("%s:", ES"Select a skin"))
			fs(fmt("dropdown[0,%f;4,0.6;skins;%s;%u;true]", yextra + 1.1, sks, data.skin_id or 1))
		else
			not_installed("skinsdb")
		end

	elseif data.subcat == 4 then
		if __awards then
			yextra = yextra + 0.7
			get_award_list(data, fs, ctn_len, yextra, award_list, awards_unlocked, award_list_nb)
		else
			not_installed("awards")
		end

	elseif data.subcat == 5 then
		get_waypoint_fs(fs, data, player, yextra, ctn_len)
	end
end

local function get_tabs_fs(player, data, fs, full_height)
	local tab_len, tab_hgh, c, over = 3, 0.5, 0
	local _tabs = copy(tabs)

	for i, def in ipairs(tabs) do
		if def.access and not def.access(player, data) then
			remove(_tabs, i)
		end
	end

	local shift = min(3, #_tabs)

	for i, def in ipairs(_tabs) do
		if not over and c > 2 then
			over = true
			c = 0
		end

		local btm = i <= 3

		if not btm then
			shift = #_tabs - 3
		end

		local selected = i == data.current_tab

		fs(fmt([[style_type[image_button;fgimg=%s;fgimg_hovered=%s;noclip=true;
			font_size=16;textcolor=%s;content_offset=0;sound=i3_tab] ]],
		selected and (btm and PNG.tab_hover or PNG.tab_hover_top) or (btm and PNG.tab or PNG.tab_top),
		btm and PNG.tab_hover or PNG.tab_hover_top, selected and "#fff" or "#ddd"))

		local X = (data.inv_width / 2) + (c * (tab_len + 0.1)) - ((tab_len + 0.05) * (shift / 2))
		local Y = btm and full_height or -tab_hgh

		fs("style_type[image_button:hovered;textcolor=#fff]")
		fs("image_button", X, Y, tab_len, tab_hgh, "", fmt("tab_%s", def.name), ESC(def.description))

		if def.image and def.image ~= "" then
			local desc = translate(data.lang_code, def.description)

			fs("style_type[image;noclip=true]")
			fs("image", X + (tab_len / 2) - ((#desc * 0.1) / 2) - 0.55,
				Y + 0.05, 0.35, 0.35, fmt("%s^\\[resize:16x16", def.image))
		end

		c = c + 1
	end
end

local function get_debug_grid(data, fs, full_height)
	local spacing = 0.2

	for x = 0, data.inv_width + 8, spacing do
		fs("box", x, 0, 0.01, full_height, "#ff0")
	end

	for y = 0, full_height, spacing do
		fs("box", 0, y, data.inv_width + 8, 0.01, "#ff0")
	end

	fs("box", data.inv_width / 2, 0, 0.01, full_height, "#f00")
	fs("box", 0, full_height / 2, data.inv_width, 0.01, "#f00")
end

local function make_fs(player, data)
	--local start = os.clock()

	local fs = setmetatable({}, {
		__call = function(t, ...)
			local args = {...}
			local elem = fs_elements[args[1]]

			if elem then
				t[#t + 1] = fmt(elem, select(2, ...))
			else
				t[#t + 1] = concat(args)
			end
		end
	})

	data.inv_width = 10.23
	local full_height = 12

	local tab = tabs[data.current_tab]

	fs(fmt("formspec_version[%u]size[%f,%f]no_prepend[]bgcolor[#0000]",
		MIN_FORMSPEC_VERSION, data.inv_width + 8, full_height), styles)

	fs("bg9", 0, 0, data.inv_width, full_height, PNG.bg_full, 10)

	if tab then
		tab.formspec(player, data, fs)
	end

	get_panels(player, data, fs, full_height)

	if #tabs > 1 then
		get_tabs_fs(player, data, fs, full_height)
	end

	--get_debug_grid(data, fs, full_height)
	--print("make_fs()", fmt("%.2f ms", (os.clock() - start) * 1000))

	return concat(fs)
end

function i3.set_fs(player, _fs)
	if not player or player.is_fake_player then return end
	local name = player:get_player_name()
	local data = pdata[name]
	if not data then return end

	local fs = fmt("%s%s", make_fs(player, data), _fs or "")
	player:set_inventory_formspec(fs)
end

local set_fs = i3.set_fs

function i3.new_tab(def)
	if not is_table(def) or not next(def) then
		return err "i3.new_tab: tab definition missing"
	end

	if not true_str(def.name) then
		return err "i3.new_tab: tab name missing"
	end

	if not true_str(def.description) then
		return err "i3.new_tab: description missing"
	end

	if #tabs == 6 then
		return err(fmt("i3.new_tab: cannot add '%s' tab. Limit reached (6).", def.name))
	end

	tabs[#tabs + 1] = def
end

function i3.get_tabs()
	return tabs
end

function i3.delete_tab(tabname)
	if not true_str(tabname) then
		return err "i3.delete_tab: tab name missing"
	end

	for i, def in ipairs(tabs) do
		if tabname == def.name then
			remove(tabs, i)
		end
	end
end

function i3.set_tab(player, tabname)
	local name = player:get_player_name()
	local data = pdata[name]

	if not tabname or tabname == "" then
		data.current_tab = 0
		return
	end

	local found

	for i, def in ipairs(tabs) do
		if not found and def.name == tabname then
			data.current_tab = i
			found = true
		end
	end

	if not found then
		return err(fmt("i3.set_tab: tab name '%s' does not exist", tabname))
	end
end

local set_tab = i3.set_tab

function i3.override_tab(tabname, newdef)
	if not is_table(newdef) or not next(newdef) then
		return err "i3.override_tab: tab definition missing"
	end

	if not true_str(newdef.name) then
		return err "i3.override_tab: tab name missing"
	end

	if not true_str(newdef.description) then
		return err "i3.override_tab: description missing"
	end

	for i, def in ipairs(tabs) do
		if def.name == tabname then
			tabs[i] = newdef
		end
	end
end

local function init_data(player, info)
	local name = player:get_player_name()
	pdata[name] = pdata[name] or {}
	local data = pdata[name]

	data.filter        = ""
	data.pagenum       = 1
	data.items         = init_items
	data.items_raw     = init_items
	data.favs          = {}
	data.export_counts = {}
	data.current_tab   = 1
	data.subcat        = 1
	data.scrbar_inv    = 0
	data.lang_code     = get_lang_code(info)
	data.fs_version    = info.formspec_version

	after(0, set_fs, player)
end

local function reset_data(data)
	data.filter      = ""
	data.expand      = ""
	data.pagenum     = 1
	data.rnum        = 1
	data.unum        = 1
	data.scrbar_rcp  = 1
	data.scrbar_usg  = 1
	data.query_item  = nil
	data.recipes     = nil
	data.usages      = nil
	data.export_rcp  = nil
	data.export_usg  = nil
	data.alt_items   = nil
	data.items       = data.items_raw
end

local function rcp_fields(player, data, fields)
	local name = player:get_player_name()
	local sb_rcp, sb_usg = fields.scrbar_rcp, fields.scrbar_usg

	if fields.cancel then
		reset_data(data)

	elseif fields.exit then
		data.query_item = nil

	elseif fields.key_enter_field == "filter" or fields.search then
		if fields.filter == "" then
			reset_data(data)
			return set_fs(player)
		end

		local str = lower(fields.filter)
		if data.filter == str then return end

		data.filter = str
		data.pagenum = 1

		search(data)

	elseif fields.prev_page or fields.next_page then
		if data.pagemax == 1 then return end
		data.pagenum = data.pagenum - (fields.prev_page and 1 or -1)

		if data.pagenum > data.pagemax then
			data.pagenum = 1
		elseif data.pagenum == 0 then
			data.pagenum = data.pagemax
		end

	elseif fields.prev_recipe or fields.next_recipe then
		local num = data.rnum + (fields.prev_recipe and -1 or 1)
		data.rnum = data.recipes[num] and num or (fields.prev_recipe and #data.recipes or 1)
		data.export_rcp = nil
		data.scrbar_rcp = 1

	elseif fields.prev_usage or fields.next_usage then
		local num = data.unum + (fields.prev_usage and -1 or 1)
		data.unum = data.usages[num] and num or (fields.prev_usage and #data.usages or 1)
		data.export_usg = nil
		data.scrbar_usg = 1

	elseif fields.fav then
		local fav, i = is_fav(data.favs, data.query_item)
		local total = #data.favs

		if total < MAX_FAVS and not fav then
			data.favs[total + 1] = data.query_item
		elseif fav then
			remove(data.favs, i)
		end

	elseif fields.export_rcp or fields.export_usg then
		if fields.export_rcp then
			data.export_rcp = not data.export_rcp

			if not data.export_rcp then
				data.scrbar_rcp = 1
			end
		else
			data.export_usg = not data.export_usg

			if not data.export_usg then
				data.scrbar_usg = 1
			end
		end

	elseif (sb_rcp and sub(sb_rcp, 1, 3) == "CHG") or (sb_usg and sub(sb_usg, 1, 3) == "CHG") then
		data.scrbar_rcp = sb_rcp and tonum(match(sb_rcp, "%d+"))
		data.scrbar_usg = sb_usg and tonum(match(sb_usg, "%d+"))

	elseif fields.craft_rcp or fields.craft_usg then
		craft_stack(player, data, fields.craft_rcp)
	else
		select_item(player, name, data, fields)
	end
end

local function get_inv_slots(data, fs)
	local inv_x, inv_y = 0.22, 6.9
	local width, size, spacing = HOTBAR_COUNT, 1, 0.1
	local bag = data.bag_size

	fs("style_type[box;colors=#77777710,#77777710,#777,#777]")

	for i = 0, HOTBAR_COUNT - 1 do
		fs("box", i * size + inv_x + (i * spacing), inv_y, size, size, "")
	end

	fs(fmt("style_type[list;size=%f;spacing=%f]", size, spacing),
	   fmt("list[current_player;main;%f,%f;%u,1;]", inv_x, inv_y, HOTBAR_COUNT))

	if bag then
		if bag == "small" then
			width, size = 10, 0.892
		elseif bag == "medium" then
			width, size = 11, 0.8
		elseif bag == "large" then
			width, size = 12, 0.726
		end
	end

	fs(fmt("style_type[list;size=%f;spacing=%f]", size, spacing),
	   fmt("list[current_player;main;%f,%f;%u,%u;%u]", inv_x, inv_y + 1.15,
		width, (bag and BAG_SIZES[data.bag_size] or INV_SIZE) / width, HOTBAR_COUNT),
	   "style_type[list;size=1;spacing=0.15]")

	fs("listring[current_player;craft]listring[current_player;main]")
end

local function get_inventory_fs(player, data, fs)
	fs("listcolors[#bababa50;#bababa99]")

	get_inv_slots(data, fs)

	local props = player:get_properties()
	local name = player:get_player_name()

	local ctn_len, ctn_hgt = 5.7, 6.3
	local yoffset = 0

	if props.mesh ~= "" then
		local anim = player:get_local_animation()
		local armor_skin = __3darmor or __skinsdb
		local t = {}

		for _, v in ipairs(props.textures) do
			t[#t + 1] = ESC(v):gsub(",", "!")
		end

		local textures = concat(t, ","):gsub("!", ",")

		--fs("style[player_model;bgcolor=black]")
		fs("model", 0.2, 0.2, armor_skin and 4 or 3.4, ctn_hgt,
			"player_model", props.mesh, textures, "0,-150", "false", "false",
			fmt("%u,%u%s", anim.x, anim.y, data.fs_version >= 5 and ";30" or ""))
	else
		local size = 2.5
		fs("image", 0.7, 0.2, size, size * props.visual_size.y, props.textures[1])
	end

	local award_list, award_list_nb
	local awards_unlocked = 0
	local max_val = damage_enabled and 12 or 7

	if __3darmor and data.subcat == 2 then
		if data.scrbar_inv >= max_val then
			data.scrbar_inv = data.scrbar_inv + 10
		end

		max_val = max_val + 10

	elseif __awards and data.subcat == 4 then
		award_list = awards.get_award_states(name)
		award_list_nb = #award_list

		for i = 1, award_list_nb do
			local award = award_list[i]

			if award.unlocked then
				awards_unlocked = awards_unlocked + 1
			end
		end

		max_val = max_val + (award_list_nb * 13)

	elseif data.subcat == 5 then
		local wp_nb = #data.waypoints

		if wp_nb > 0 then
			local mul = (wp_nb > 8 and 7) or (wp_nb > 4 and 6) or 5
			max_val = max_val + 11 + (wp_nb * mul)
		end
	end

	fs(fmt([[
		scrollbaroptions[arrows=hide;thumbsize=%u;max=%u]
		scrollbar[%f,0.2;0.2,%f;vertical;scrbar_inv;%u]
		scrollbaroptions[arrows=default;thumbsize=0;max=1000]
	]],
	(max_val * 4) / 12, max_val, 9.8, ctn_hgt, data.scrbar_inv))

	fs(fmt("scroll_container[3.9,0.2;%f,%f;scrbar_inv;vertical]", ctn_len, ctn_hgt))
		get_ctn_content(fs, data, player, yoffset, ctn_len, award_list, awards_unlocked, award_list_nb)
	fs("scroll_container_end[]")

	local btn = {
		{"trash", ES"Trash all items"},
		{"sort_az", ES"Sort items (A-Z)"},
		{"sort_za", ES"Sort items (Z-A)"},
		{"compress", ES"Compress items"},
	}

	for i, v in ipairs(btn) do
		local btn_name, tooltip = unpack(v)

		fs(fmt("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]",
			btn_name, PNG[btn_name], PNG[fmt("%s_hover", btn_name)]))

		fs("image_button", i + 3.447 - (i * 0.4), 11.43, 0.35, 0.35, "", btn_name, "")
		fs(fmt("tooltip[%s;%s]", btn_name, tooltip))
	end
end

i3.new_tab {
	name = "inventory",
	description = S"Inventory",
	formspec = get_inventory_fs,

	fields = function(player, data, fields)
		local name = player:get_player_name()
		local sb_inv = fields.scrbar_inv

		if fields.skins and data.skin_id ~= tonum(fields.skins) then
			data.skin_id = tonum(fields.skins)
			local _skins = skins.get_skinlist_for_player(name)
			skins.set_player_skin(player, _skins[data.skin_id])
		end

		for field in pairs(fields) do
			if sub(field, 1, 4) == "btn_" then
				data.subcat = indexof(SUBCAT, sub(field, 5))
				break

			elseif find(field, "waypoint_%d+") then
				local id, action = match(field, "_(%d+)_(%w+)$")
				id = tonum(id)
				local waypoint = data.waypoints[id]
				if not waypoint then return end

				if action == "delete" then
					player:hud_remove(waypoint.id)
					remove(data.waypoints, id)

				elseif action == "teleport" then
					local pos = vec_new(waypoint.pos)
					pos.y = pos.y + 0.5

					local vel = player:get_velocity()
					player:add_velocity(vec_mul(vel, -1))
					player:set_pos(pos)

					msg(name, fmt("Teleported to %s", clr("#ff0", waypoint.name)))

				elseif action == "refresh" then
					local color = random(0xffffff)
					waypoint.color = color
					player:hud_change(waypoint.id, "number", color)

				elseif action == "hide" then
					if waypoint.hide then
						local new_id = player:hud_add {
							hud_elem_type = "waypoint",
							name = waypoint.name,
							text = " m",
							world_pos = waypoint.pos,
							number = waypoint.color,
							z_index = -300,
						}

						waypoint.id = new_id
						waypoint.hide = nil
					else
						player:hud_remove(waypoint.id)
						waypoint.hide = true
					end
				end

				break
			end
		end

		if fields.trash then
			local inv = player:get_inventory()
			inv:set_list("main", {})
			inv:set_list("craft", {})

		elseif fields.compress then
			compress_items(player)

		elseif fields.sort_az or fields.sort_za then
			sort_itemlist(player, fields.sort_az)

		elseif sb_inv and sub(sb_inv, 1, 3) == "CHG" then
			data.scrbar_inv = tonum(match(sb_inv, "%d+"))
			return

		elseif fields.waypoint_add then
			local pos = player:get_pos()

			for _, v in ipairs(data.waypoints) do
				if vec_eq(vec_round(pos), vec_round(v.pos)) then
					return msg(name, "You already set a waypoint at this position")
				end
			end

			local waypoint = fields.waypoint_name

			if fields.waypoint_name == "" then
				waypoint = "Waypoint"
			end

			local color = random(0xffffff)

			local id = player:hud_add {
				hud_elem_type = "waypoint",
				name = waypoint,
				text = " m",
				world_pos = pos,
				number = color,
				z_index = -300,
			}

			insert(data.waypoints, {name = waypoint, pos = pos, color = color, id = id})
			data.scrbar_inv = data.scrbar_inv + 1000
		end

		return set_fs(player)
	end,
}

local trash = create_inventory("i3_trash", {
	allow_put = function(_, _, _, stack)
		return stack:get_count()
	end,
	on_put = function(inv, listname, _, _, player)
		inv:set_list(listname, {})

		local name = player:get_player_name()

		if not core.is_creative_enabled(name) then
			set_fs(player)
		end
	end,
})

trash:set_size("main", 1)

local output_rcp = create_inventory("i3_output_rcp", {})
output_rcp:set_size("main", 1)

local output_usg = create_inventory("i3_output_usg", {})
output_usg:set_size("main", 1)

core.register_on_player_inventory_action(function(player, _, _, info)
	local name = player:get_player_name()

	if not core.is_creative_enabled(name) and
	  ((info.from_list == "main"  and info.to_list == "craft") or
	   (info.from_list == "craft" and info.to_list == "main")  or
	   (info.from_list == "craftresult" and info.to_list == "main")) then
		set_fs(player)
	end
end)

if rawget(_G, "armor") then
	__3darmor = true
	armor:register_on_update(set_fs)
end

if rawget(_G, "skins") then
	__skinsdb = true
end

if rawget(_G, "awards") then
	__awards = true

	core.register_on_craft(function(_, player)
		set_fs(player)
	end)

	core.register_on_dignode(function(_, _, player)
		set_fs(player)
	end)

	core.register_on_placenode(function(_, _, player)
		set_fs(player)
	end)

	core.register_on_chat_message(function(name)
		local player = core.get_player_by_name(name)
		set_fs(player)
	end)

	core.register_on_dieplayer(set_fs)
end

core.register_on_chatcommand(function(name)
	local player = core.get_player_by_name(name)
	after(0, set_fs, player)
end)

core.register_on_priv_grant(function(name, _, priv)
	if priv == "creative" or priv == "all" then
		local data = pdata[name]
		reset_data(data)
		data.favs = {}

		local player = core.get_player_by_name(name)
		after(0, set_fs, player)
	end
end)

i3.register_craft_type("digging", {
	description = ES"Digging",
	icon = "i3_steelpick.png",
})

i3.register_craft_type("digging_chance", {
	description = ES"Digging (by chance)",
	icon = "i3_mesepick.png",
})

i3.add_search_filter("groups", function(item, groups)
	local def = reg_items[item]
	local has_groups = true

	for _, group in ipairs(groups) do
		if not def.groups[group] then
			has_groups = nil
			break
		end
	end

	return has_groups
end)

i3.add_search_filter("types", function(item, drawtypes)
	local t = {}

	for i, dt in ipairs(drawtypes) do
		t[i] = (dt == "node" and reg_nodes[item] and 1) or
		       (dt == "item" and reg_craftitems[item] and 1) or
		       (dt == "tool" and reg_tools[item] and 1) or nil
	end

	return #t > 0
end)

--[[	As `core.get_craft_recipe` and `core.get_all_craft_recipes` do not
	return the fuel, replacements and toolrepair recipes, we have to
	override `core.register_craft` and do some reverse engineering.
	See engine's issues #4901, #5745 and #8920.	]]

local old_register_craft = core.register_craft
local rcp_num = {}

core.register_craft = function(def)
	old_register_craft(def)

	if def.type == "toolrepair" then
		toolrepair = def.additional_wear * -100
	end

	local output = def.output or (true_str(def.recipe) and def.recipe) or nil
	if not output then return end
	output = {match(output, "%S+")}

	local groups

	if is_group(output[1]) then
		groups = extract_groups(output[1])
		output = groups_to_items(groups, true)
	end

	for i = 1, #output do
		local item = output[i]
		rcp_num[item] = (rcp_num[item] or 0) + 1

		if def.replacements then
			if def.type == "fuel" then
				replacements.fuel[item] = def.replacements
			else
				replacements[item] = replacements[item] or {}
				replacements[item][rcp_num[item]] = def.replacements
			end
		end
	end
end

local old_clear_craft = core.clear_craft

core.clear_craft = function(def)
	old_clear_craft(def)

	if true_str(def) then
		return -- TODO
	elseif is_table(def) then
		return -- TODO
	end
end

local function resolve_aliases(hash)
	for oldname, newname in pairs(reg_aliases) do
		cache_recipes(oldname)
		local recipes = recipes_cache[oldname]

		if recipes then
			if not recipes_cache[newname] then
				recipes_cache[newname] = {}
			end

			local similar

			for i = 1, #recipes_cache[oldname] do
				local rcp_old = recipes_cache[oldname][i]

				for j = 1, #recipes_cache[newname] do
					local rcp_new = copy(recipes_cache[newname][j])
					rcp_new.output = oldname

					if table_eq(rcp_old, rcp_new) then
						similar = true
						break
					end
				end

				if not similar then
					insert(recipes_cache[newname], rcp_old)
				end
			end
		end

		if newname ~= "" and recipes_cache[oldname] and not hash[newname] then
			init_items[#init_items + 1] = newname
		end
	end
end

local function get_init_items()
	local _select, _preselect = {}, {}

	for name, def in pairs(reg_items) do
		if name ~= "" and show_item(def) then
			cache_drops(name, def.drop)
			cache_fuel(name)
			cache_recipes(name)

			_preselect[name] = true
		end
	end

	for name in pairs(_preselect) do
		cache_usages(name)

		init_items[#init_items + 1] = name
		_select[name] = true
	end

	resolve_aliases(_select)
	sort(init_items)

	if http and true_str(i3.export_url) then
		local post_data = {
			recipes = recipes_cache,
			usages  = usages_cache,
		}

		http.fetch_async {
			url = i3.export_url,
			post_data = core.write_json(post_data),
		}
	end
end

core.register_on_mods_loaded(function()
	get_init_items()

	__sfinv = rawget(_G, "sfinv")

	if __sfinv then
		old_sfinv_fn = sfinv.set_player_inventory_formspec
		function sfinv.set_player_inventory_formspec() return end
		sfinv.enabled = false
	end

	__unified_inventory = rawget(_G, "unified_inventory")

	if __unified_inventory then
		old_unified_inventory_fn = unified_inventory.set_inventory_formspec
		function unified_inventory.set_inventory_formspec() return end
	end
end)

local function init_backpack(player)
	local name = player:get_player_name()
	local data = pdata[name]
	local inv = player:get_inventory()

	inv:set_size("main", data.bag_size and BAG_SIZES[data.bag_size] or INV_SIZE)

	data.bag = create_inventory(fmt("%s_backpack", name), {
		allow_put = function(_inv, listname, _, stack)
			local empty = _inv:get_stack(listname, 1):is_empty()

			if empty and sub(stack:get_name(), 1, 7) == "i3:bag_" then
				return 1
			end

			msg(name, ES"This is not a backpack")

			return 0
		end,

		on_put = function(_, _, _, stack)
			data.bag_size = match(stack:get_name(), "_(%w+)$")
			inv:set_size("main", BAG_SIZES[data.bag_size])
			set_fs(player)
		end,

		on_take = function()
			for i = INV_SIZE + 1, BAG_SIZES[data.bag_size] do
				local stack = inv:get_stack("main", i)

				if not stack:is_empty() then
					spawn_item(player, stack)
				end
			end

			data.bag_size = nil
			inv:set_size("main", INV_SIZE)

			set_fs(player)
		end,
	})

	data.bag:set_size("main", 1)

	if data.bag_size then
		data.bag:set_stack("main", 1, fmt("i3:bag_%s", data.bag_size))
	end
end

local function init_waypoints(player)
	local name = player:get_player_name()
	local data = pdata[name]
	data.waypoints = data.waypoints or {}

	for _, v in ipairs(data.waypoints) do
		if not v.hide then
			local id = player:hud_add {
				hud_elem_type = "waypoint",
				name = v.name,
				text = " m",
				world_pos = v.pos,
				number = v.color,
				z_index = -300,
			}

			v.id = id
		end
	end
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local info = core.get_player_information and core.get_player_information(name)

	if not info or get_formspec_version(info) < MIN_FORMSPEC_VERSION then
		if __sfinv then
			sfinv.set_player_inventory_formspec = old_sfinv_fn
			sfinv.enabled = true
		end

		if __unified_inventory then
			unified_inventory.set_inventory_formspec = old_unified_inventory_fn

			if __sfinv then
				sfinv.enabled = false
			end
		end

		pdata[name] = nil

		return outdated(name)
	end

	init_data(player, info)
	init_backpack(player)
	init_waypoints(player)

	after(0, function()
		player:hud_set_hotbar_itemcount(HOTBAR_COUNT)
		player:hud_set_hotbar_image(PNG.hotbar)
	end)
end)

core.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	local data = pdata[name]
	if not data then return end

	data.bag_size = nil
	data.bag:set_list("main", {})

	local inv = player:get_inventory()
	inv:set_size("main", INV_SIZE)

	set_fs(player)
end)

local META_SAVES = {
	bag_size = true,
	waypoints = true,
	skin_id = true,
	inv_items = true,
	known_recipes = true,
}

local function save_data(player_name)
	local _pdata = copy(pdata)

	for name, v in pairs(_pdata) do
	for dat in pairs(v) do
		if not META_SAVES[dat] then
			_pdata[name][dat] = nil

			if player_name then
				pdata[player_name][dat] = nil -- To free up some memory
			end
		end
	end
	end

	storage:set_string("pdata", slz(_pdata))
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	save_data(name)
end)

core.register_on_shutdown(save_data)

local function routine()
	save_data()
	after(SAVE_INTERVAL, routine)
end

after(SAVE_INTERVAL, routine)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" then
		return false
	end

	local name = player:get_player_name()
	local data = pdata[name]
	if not data then return end

	for f in pairs(fields) do
		if sub(f, 1, 4) == "tab_" then
			local tabname = sub(f, 5)
			set_tab(player, tabname)
			break
		end
	end

	rcp_fields(player, data, fields)

	local tab = tabs[data.current_tab]

	if tab and tab.fields then
		return true, tab.fields(player, data, fields)
	end

	return true, set_fs(player)
end)

core.register_on_player_hpchange(function(player, hpchange)
	local name = player:get_player_name()
	local data = pdata[name]
	if not data then return end

	local hp_max = player:get_properties().hp_max
	data.hp = min(hp_max, player:get_hp() + hpchange)

	set_fs(player)
end)

if progressive_mode then
	local function item_in_inv(item, inv_items)
		local inv_items_size = #inv_items

		if is_group(item) then
			local groups = extract_groups(item)

			for i = 1, inv_items_size do
				local def = reg_items[inv_items[i]]

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
		local data = pdata[name]

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
				if reg_items[name] then
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
				text          = PNG.bg,
				z_index       = 0xDEAD,
			},

			book = player:hud_add {
				hud_elem_type = "image",
				position      = {x = 0.79, y = 1.02},
				alignment     = {x = 1,    y = 1},
				scale         = {x = 4,    y = 4},
				text          = PNG.book,
				z_index       = 0xDEAD,
			},

			text = player:hud_add {
				hud_elem_type = "text",
				position      = {x = 0.84, y = 1.04},
				alignment     = {x = 1,    y = 1},
				number        = 0xffffff,
				text          = "",
				z_index       = 0xDEAD,
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
				S("@1 new recipe(s) discovered!", data.discovered))

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
			local data = pdata[name]

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
				search(data)
				set_fs(player)
			end
		end

		after(POLL_FREQ, poll_new_items)
	end

	poll_new_items()

	core.register_globalstep(function()
		local players = core.get_connected_players()

		for i = 1, #players do
			local player = players[i]
			local name = player:get_player_name()
			local data = pdata[name]

			if data.show_hud ~= nil and singleplayer then
				show_hud_success(player, data)
			end
		end
	end)

	i3.add_recipe_filter("Default progressive filter", progressive_filter)

	core.register_on_joinplayer(function(player)
		local name = player:get_player_name()
		local data = pdata[name]

		data.inv_items = data.inv_items or {}
		data.known_recipes = data.known_recipes or 0

		local items = get_filtered_items(player, data)
		data.items_raw = items
		search(data)

		if singleplayer then
			init_hud(player, data)
		end
	end)
end

local bag_recipes = {
	small = {
		{"", "farming:string", ""},
		{"group:wool", "group:wool", "group:wool"},
		{"group:wool", "group:wool", "group:wool"},
	},
	medium = {
		{"farming:string", "i3:bag_small", "farming:string"},
		{"farming:string", "i3:bag_small", "farming:string"},
	},
	large = {
		{"farming:string", "i3:bag_medium", "farming:string"},
		{"farming:string", "i3:bag_medium", "farming:string"},
	},
}

for size, rcp in pairs(bag_recipes) do
	local bagname = fmt("i3:bag_%s", size)

	core.register_craftitem(bagname, {
		description = fmt("%s Backpack", size:gsub("^%l", upper)),
		inventory_image = fmt("i3_bag_%s.png", size),
		stack_max = 1,
	})

	core.register_craft {output = bagname, recipe = rcp}
	core.register_craft {type = "fuel", recipe = bagname, burntime = 3}
end

--dofile(modpath .. "/etc/test_tabs.lua")
--dofile(modpath .. "/etc/test_custom_recipes.lua")
