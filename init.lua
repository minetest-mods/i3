i3 = {
	modules = {},

	MAX_FAVS = 6,
	INV_SIZE = 4*9,
	HOTBAR_LEN = 9,
	ITEM_BTN_SIZE = 1.1,
	MIN_FORMSPEC_VERSION = 4,
	SAVE_INTERVAL = 600, -- Player data save interval (in seconds)

	BAG_SIZES = {
		4*9 + 3,
		4*9 + 6,
		4*9 + 9,
	},

	SUBCAT = {
		"bag",
		"armor",
		"skins",
		"awards",
		"waypoints",
	},

	META_SAVES = {
		bag_item = true,
		bag_size = true,
		waypoints = true,
		inv_items = true,
		known_recipes = true,
	},

	-- Caches
	init_items     = {},
	recipes_cache  = {},
	usages_cache   = {},
	fuel_cache     = {},
	recipe_filters = {},
	search_filters = {},
	craft_types    = {},
	tabs           = {},
}

local modpath = core.get_modpath "i3"
local http = core.request_http_api()
local storage = core.get_mod_storage()

i3.S = core.get_translator "i3"
local S, slz, dslz = i3.S, core.serialize, core.deserialize

i3.data = dslz(storage:get_string "data") or {}
i3.compress_groups, i3.compressed = dofile(modpath .. "/etc/compress.lua")
i3.group_stereotypes, i3.group_names = dofile(modpath .. "/etc/groups.lua")

local is_str, show_item, reset_compression = unpack(dofile(modpath .. "/etc/common.lua").init)
local groups_to_items, _, compressible, true_str, is_fav = unpack(dofile(modpath .. "/etc/common.lua").gui)

local search, table_merge, is_group, extract_groups, item_has_groups, apply_recipe_filters =
	unpack(dofile(modpath .. "/etc/common.lua").progressive)

local make_fs, get_inventory_fs = dofile(modpath .. "/etc/gui.lua")

local progressive_mode = core.settings:get_bool "i3_progressive_mode"

local reg_items = core.registered_items
local reg_nodes = core.registered_nodes
local reg_craftitems = core.registered_craftitems
local reg_tools = core.registered_tools
local reg_aliases = core.registered_aliases

local replacements = {fuel = {}}
local check_privs = core.check_player_privs
local after, clr = core.after, core.colorize
local create_inventory = core.create_detached_inventory

local maxn, sort, concat, copy, insert, remove, indexof =
	table.maxn, table.sort, table.concat, table.copy,
	table.insert, table.remove, table.indexof

local fmt, find, gmatch, match, sub, split, upper, lower =
	string.format, string.find, string.gmatch, string.match,
	string.sub, string.split, string.upper, string.lower

local min, ceil, random = math.min, math.ceil, math.random

local pairs, ipairs, next, type, tonum =
	pairs, ipairs, next, type, tonumber

local vec_new, vec_add, vec_mul, vec_eq, vec_round =
	vector.new, vector.add, vector.multiply, vector.equals, vector.round

local function err(str)
	return core.log("error", str)
end

local function msg(name, str)
	return core.chat_send_player(name, fmt("[i3] %s", str))
end

local function is_table(x)
	return type(x) == "table"
end

local function is_func(x)
	return type(x) == "function"
end

local function clean_name(item)
	if sub(item, 1, 1) == ":" or sub(item, 1, 1) == " " or sub(item, 1, 1) == "_" then
		item = sub(item, 2)
	end

	return item
end

local function table_replace(t, val, new)
	for k, v in pairs(t) do
		if v == val then
			t[k] = new
		end
	end
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

local function get_lang_code(info)
	return info and info.lang_code
end

local function get_formspec_version(info)
	return info and info.formspec_version or 1
end

local function outdated(name)
	local fs = fmt("size[6.3,1.3]image[0,0;1,1;i3_book.png]label[1,0;%s]button_exit[2.6,0.8;1,1;;OK]",
		"Your Minetest client is outdated.\nGet the latest version on minetest.net to play the game.")

	core.show_formspec(name, "i3_outdated", fs)
end

local old_is_creative_enabled = core.is_creative_enabled

function core.is_creative_enabled(name)
	if name == "" then
		return old_is_creative_enabled(name)
	end

	return check_privs(name, {creative = true}) or old_is_creative_enabled(name)
end

function i3.register_craft_type(name, def)
	if not true_str(name) then
		return err "i3.register_craft_type: name missing"
	end

	if not is_str(def.description) then
		def.description = ""
	end

	i3.craft_types[name] = def
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
	i3.recipes_cache[item] = i3.recipes_cache[item] or {}

	def.custom = true
	def.width = width

	insert(i3.recipes_cache[item], def)
end

function i3.add_recipe_filter(name, f)
	if not true_str(name) then
		return err "i3.add_recipe_filter: name missing"
	elseif not is_func(f) then
		return err "i3.add_recipe_filter: function missing"
	end

	i3.recipe_filters[name] = f
end

function i3.set_recipe_filter(name, f)
	if not is_str(name) then
		return err "i3.set_recipe_filter: name missing"
	elseif not is_func(f) then
		return err "i3.set_recipe_filter: function missing"
	end

	i3.recipe_filters = {[name] = f}
end

function i3.add_search_filter(name, f)
	if not true_str(name) then
		return err "i3.add_search_filter: name missing"
	elseif not is_func(f) then
		return err "i3.add_search_filter: function missing"
	end

	i3.search_filters[name] = f
end

function i3.remove_search_filter(name)
	i3.search_filters[name] = nil
end

local function get_burntime(item)
	return core.get_craft_result{method = "fuel", items = {item}}.time
end

local function cache_fuel(item)
	local burntime = get_burntime(item)
	if burntime > 0 then
		i3.fuel_cache[item] = {
			type = "fuel",
			items = {item},
			burntime = burntime,
			replacements = replacements.fuel[item],
		}
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

local function get_item_usages(item, recipe, added)
	local groups = extract_groups(item)

	if groups then
		for name, def in pairs(reg_items) do
			if not added[name] and show_item(def) and item_has_groups(def.groups, groups) then
				local usage = copy(recipe)
				table_replace(usage.items, item, name)

				i3.usages_cache[name] = i3.usages_cache[name] or {}
				insert(i3.usages_cache[name], 1, usage)

				added[name] = true
			end
		end
	elseif show_item(reg_items[item]) then
		i3.usages_cache[item] = i3.usages_cache[item] or {}
		insert(i3.usages_cache[item], 1, recipe)
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
	local recipes = i3.recipes_cache[item] or {}

	for i = 1, #recipes do
		get_usages(recipes[i])
	end

	if i3.fuel_cache[item] then
		i3.usages_cache[item] = table_merge(i3.usages_cache[item] or {}, {i3.fuel_cache[item]})
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

					i3.register_craft {
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
			i3.register_craft {
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
		i3.recipes_cache[item] = table_merge(recipes, i3.recipes_cache[item] or {})
	end
end

function i3.get_recipes(item)
	return {
		recipes = i3.recipes_cache[item],
		usages = i3.usages_cache[item]
	}
end

local function get_recipes(player, item)
	local clean_item = reg_aliases[item] or item
	local recipes = i3.recipes_cache[clean_item]
	local usages = i3.usages_cache[clean_item]

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

local function spawn_item(player, stack)
	local dir     = player:get_look_dir()
	local ppos    = player:get_pos()
	      ppos.y  = ppos.y + 1.625
	local look_at = vec_add(ppos, vec_mul(dir, 1))

	core.add_item(look_at, stack)
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
	local iter = ceil(count / stackmax)
	local leftover = count

	for _ = 1, iter do
		local c = min(stackmax, leftover)
		local stack = ItemStack(fmt("%s %s", stackname, c))
		get_stack(player, stack)
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

	if compressible(item, data) then
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

			if i3.compress_groups[item] then
				local items = copy(i3.compress_groups[item])
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

			return get_stack(player, stack)
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

function i3.set_fs(player, _fs)
	if not player or player.is_fake_player then return end
	local name = player:get_player_name()
	local data = i3.data[name]
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

	if #i3.tabs == 6 then
		return err(fmt("i3.new_tab: cannot add '%s' tab. Limit reached (6).", def.name))
	end

	i3.tabs[#i3.tabs + 1] = def
end

function i3.get_tabs()
	return i3.tabs
end

function i3.remove_tab(tabname)
	if not true_str(tabname) then
		return err "i3.remove_tab: tab name missing"
	end

	for i, def in ipairs(i3.tabs) do
		if tabname == def.name then
			remove(i3.tabs, i)
		end
	end
end

function i3.get_current_tab(player)
	local name = player:get_player_name()
	local data = i3.data[name]

	return data.current_tab
end

function i3.set_tab(player, tabname)
	local name = player:get_player_name()
	local data = i3.data[name]

	if not tabname or tabname == "" then
		data.current_tab = 0
		return
	end

	local found

	for i, def in ipairs(i3.tabs) do
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

	for i, def in ipairs(i3.tabs) do
		if def.name == tabname then
			i3.tabs[i] = newdef
		end
	end
end

local function init_data(player, info)
	local name = player:get_player_name()
	i3.data[name] = i3.data[name] or {}
	local data = i3.data[name]

	data.filter        = ""
	data.pagenum       = 1
	data.items         = i3.init_items
	data.items_raw     = i3.init_items
	data.favs          = {}
	data.export_counts = {}
	data.current_tab   = 1
	data.current_itab  = 1
	data.subcat        = 1
	data.scrbar_inv    = 0
	data.lang_code     = get_lang_code(info)
	data.fs_version    = info.formspec_version

	after(0, set_fs, player)
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
	data.recipes       = nil
	data.usages        = nil
	data.export_rcp    = nil
	data.export_usg    = nil
	data.alt_items     = nil
	data.confirm_trash = nil
	data.items         = data.items_raw

	if data.current_itab > 1 then
		sort_by_category(data)
	end
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

		if data.current_itab > 1 then
			sort_by_category(data)
		end

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

		if total < i3.MAX_FAVS and not fav then
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

		if fields.craft_rcp then
			data.export_rcp = nil
			data.scrbar_rcp = 1
		else
			data.export_usg = nil
			data.scrbar_usg = 1
		end
	else
		select_item(player, name, data, fields)
	end
end

i3.new_tab {
	name = "inventory",
	description = S"Inventory",
	formspec = get_inventory_fs,

	fields = function(player, data, fields)
		local name = player:get_player_name()
		local sb_inv = fields.scrbar_inv

		if fields.skins then
			local id = tonum(fields.skins)
			local _skins = skins.get_skinlist_for_player(name)
			skins.set_player_skin(player, _skins[id])
		end

		for field in pairs(fields) do
			if sub(field, 1, 4) == "btn_" then
				data.subcat = indexof(i3.SUBCAT, sub(field, 5))
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
			data.confirm_trash = true

		elseif fields.confirm_trash_yes or fields.confirm_trash_no then
			if fields.confirm_trash_yes then
				local inv = player:get_inventory()
				inv:set_list("main", {})
				inv:set_list("craft", {})
			end

			data.confirm_trash = nil

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
	i3.modules.armor = true
	armor:register_on_update(set_fs)
end

if rawget(_G, "skins") then
	i3.modules.skins = true
end

if rawget(_G, "awards") then
	i3.modules.awards = true

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
end

core.register_on_chatcommand(function(name)
	local player = core.get_player_by_name(name)
	after(0, set_fs, player)
end)

core.register_on_priv_grant(function(name, _, priv)
	if priv == "creative" or priv == "all" then
		local data = i3.data[name]
		reset_data(data)
		data.favs = {}

		local player = core.get_player_by_name(name)
		after(0, set_fs, player)
	end
end)

i3.register_craft_type("digging", {
	description = S"Digging",
	icon = "i3_steelpick.png",
})

i3.register_craft_type("digging_chance", {
	description = S"Digging (by chance)",
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

--[[	As `core.get_craft_recipe` and `core.get_all_craft_recipes` do not
	return the fuel, replacements and toolrepair recipes, we have to
	override `core.register_craft` and do some reverse engineering.
	See engine's issues #4901, #5745 and #8920.	]]

local old_register_craft = core.register_craft
local rcp_num = {}

core.register_craft = function(def)
	old_register_craft(def)

	if def.type == "toolrepair" then
		i3.toolrepair = def.additional_wear * -100
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
		local recipes = i3.recipes_cache[oldname]

		if recipes then
			if not i3.recipes_cache[newname] then
				i3.recipes_cache[newname] = {}
			end

			local similar

			for i = 1, #i3.recipes_cache[oldname] do
				local rcp_old = i3.recipes_cache[oldname][i]

				for j = 1, #i3.recipes_cache[newname] do
					local rcp_new = copy(i3.recipes_cache[newname][j])
					rcp_new.output = oldname

					if table_eq(rcp_old, rcp_new) then
						similar = true
						break
					end
				end

				if not similar then
					insert(i3.recipes_cache[newname], rcp_old)
				end
			end
		end

		if newname ~= "" and i3.recipes_cache[oldname] and not hash[newname] then
			i3.init_items[#i3.init_items + 1] = newname
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

		i3.init_items[#i3.init_items + 1] = name
		_select[name] = true
	end

	resolve_aliases(_select)
	sort(i3.init_items)

	if http and true_str(i3.export_url) then
		local post_data = {
			recipes = i3.recipes_cache,
			usages  = i3.usages_cache,
		}

		http.fetch_async {
			url = i3.export_url,
			post_data = core.write_json(post_data),
		}
	end
end

core.register_on_mods_loaded(function()
	get_init_items()

	if rawget(_G, "sfinv") then
		function sfinv.set_player_inventory_formspec() return end
		sfinv.enabled = false
	end

	if rawget(_G, "unified_inventory") then
		function unified_inventory.set_inventory_formspec() return end
	end
end)

local function init_backpack(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	local inv = player:get_inventory()

	-- Legacy compat
	if data.bag_size and type(data.bag_size) == "string" then
		local convert = {
			small = 1,
			medium = 2,
			large = 3,
		}

		data.bag_item = fmt("i3:bag_%s", data.bag_size)
		data.bag_size = convert[data.bag_size]
	end

	inv:set_size("main", data.bag_size and i3.BAG_SIZES[data.bag_size] or i3.INV_SIZE)

	data.bag = create_inventory(fmt("%s_backpack", name), {
		allow_put = function(_inv, listname, _, stack)
			local empty = _inv:get_stack(listname, 1):is_empty()
			local item_group = minetest.get_item_group(stack:get_name(), "bag")

			if empty and item_group > 0 and item_group <= #i3.BAG_SIZES then
				return 1
			end

			msg(name, S"This is not a backpack")

			return 0
		end,

		on_put = function(_, _, _, stack)
			local stackname = stack:get_name()
			data.bag_item = stackname
			data.bag_size = minetest.get_item_group(stackname, "bag")

			inv:set_size("main", i3.BAG_SIZES[data.bag_size])
			set_fs(player)
		end,

		on_take = function()
			for i = i3.INV_SIZE + 1, i3.BAG_SIZES[data.bag_size] do
				local stack = inv:get_stack("main", i)

				if not stack:is_empty() then
					spawn_item(player, stack)
				end
			end

			data.bag_item = nil
			data.bag_size = nil

			inv:set_size("main", i3.INV_SIZE)
			set_fs(player)
		end,
	})

	data.bag:set_size("main", 1)

	if data.bag_item then
		data.bag:set_stack("main", 1, data.bag_item)
	end
end

local function init_waypoints(player)
	local name = player:get_player_name()
	local data = i3.data[name]
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

	if not info or get_formspec_version(info) < i3.MIN_FORMSPEC_VERSION then
		i3.data[name] = nil
		return outdated(name)
	end

	init_data(player, info)
	init_backpack(player)
	init_waypoints(player)

	after(0, function()
		player:hud_set_hotbar_itemcount(i3.HOTBAR_LEN)
		player:hud_set_hotbar_image("i3_hotbar.png")
	end)
end)

core.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	if not data then return end

	if data.bag_size then
		data.bag_item = nil
		data.bag_size = nil
		data.bag:set_list("main", {})

		local inv = player:get_inventory()
		inv:set_size("main", i3.INV_SIZE)
	end

	set_fs(player)
end)

local function save_data(player_name)
	local _data = copy(i3.data)

	for name, v in pairs(_data) do
	for dat in pairs(v) do
		if not i3.META_SAVES[dat] then
			_data[name][dat] = nil

			if player_name and i3.data[player_name] then
				i3.data[player_name][dat] = nil -- To free up some memory
			end
		end
	end
	end

	storage:set_string("data", slz(_data))
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	save_data(name)
end)

core.register_on_shutdown(save_data)

local function routine()
	save_data()
	after(i3.SAVE_INTERVAL, routine)
end

after(i3.SAVE_INTERVAL, routine)

core.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()

	if formname == "i3_outdated" then
		return false, core.kick_player(name, "Come back when your client is up-to-date.")
	elseif formname ~= "" then
		return false
	end

	local data = i3.data[name]
	if not data then return end

	for f in pairs(fields) do
		if sub(f, 1, 4) == "tab_" then
			local tabname = sub(f, 5)
			set_tab(player, tabname)
			break
		elseif sub(f, 1, 5) == "itab_" then
			data.pagenum = 1
			data.current_itab = tonum(f:sub(-1))
			sort_by_category(data)
		end
	end

	rcp_fields(player, data, fields)

	local tab = i3.tabs[data.current_tab]

	if tab and tab.fields then
		return true, tab.fields(player, data, fields)
	end

	return true, set_fs(player)
end)

core.register_on_player_hpchange(function(player, hpchange)
	local name = player:get_player_name()
	local data = i3.data[name]
	if not data then return end

	local hp_max = player:get_properties().hp_max
	data.hp = min(hp_max, player:get_hp() + hpchange)

	set_fs(player)
end)

if progressive_mode then
	dofile(modpath .. "/etc/progressive.lua")
end

local bag_recipes = {
	small = {
		rcp = {
			{"", "farming:string", ""},
			{"group:wool", "group:wool", "group:wool"},
			{"group:wool", "group:wool", "group:wool"},
		},
		size = 1,
	},
	medium = {
		rcp = {
			{"farming:string", "i3:bag_small", "farming:string"},
			{"farming:string", "i3:bag_small", "farming:string"},
		},
		size = 2,
	},
	large = {
		rcp = {
			{"farming:string", "i3:bag_medium", "farming:string"},
			{"farming:string", "i3:bag_medium", "farming:string"},
		},
		size = 3,
	},
}

for size, item in pairs(bag_recipes) do
	local bagname = fmt("i3:bag_%s", size)

	core.register_craftitem(bagname, {
		description = fmt("%s Backpack", size:gsub("^%l", upper)),
		inventory_image = fmt("i3_bag_%s.png", size),
		stack_max = 1,
		groups = {bag = item.size}
	})

	core.register_craft {output = bagname, recipe = item.rcp}
	core.register_craft {type = "fuel", recipe = bagname, burntime = 3}
end

--dofile(modpath .. "/tests/test_tabs.lua")
--dofile(modpath .. "/tests/test_custom_recipes.lua")
