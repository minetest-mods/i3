local set_fs, set_tab = i3.files.api()
local _, get_inventory_fs = i3.files.gui()

local S, clr = i3.need("S", "clr")
local min, ceil, random = i3.need("min", "ceil", "random")
local reg_items, reg_aliases = i3.need("reg_items", "reg_aliases")
local fmt, find, match, sub, lower = i3.need("fmt", "find", "match", "sub", "lower")
local vec_new, vec_mul, vec_eq, vec_round = i3.need("vec_new", "vec_mul", "vec_eq", "vec_round")
local sort, copy, insert, remove, indexof = i3.need("sort", "copy", "insert", "remove", "indexof")

local is_group, extract_groups, groups_to_items = i3.need("is_group", "extract_groups", "groups_to_items")
local search, sort_by_category, apply_recipe_filters = i3.need("search", "sort_by_category", "apply_recipe_filters")
local msg, is_str, is_fav, show_item, spawn_item, clean_name, compressible =
	i3.need("msg", "is_str", "is_fav", "show_item", "spawn_item", "clean_name", "compressible")

local old_is_creative_enabled = core.is_creative_enabled

function core.is_creative_enabled(name)
	if name == "" then
		return old_is_creative_enabled(name)
	end

	return core.check_player_privs(name, {creative = true}) or old_is_creative_enabled(name)
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

local function get_stack(player, stack)
	local inv = player:get_inventory()

	if inv:room_for_item("main", stack) then
		inv:add_item("main", stack)
	else
		spawn_item(player, stack)
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
			local id = tonumber(fields.skins)
			local _skins = skins.get_skinlist_for_player(name)
			skins.set_player_skin(player, _skins[id])
		end

		for field in pairs(fields) do
			if sub(field, 1, 4) == "btn_" then
				data.subcat = indexof(i3.SUBCAT, sub(field, 5))
				break

			elseif find(field, "waypoint_%d+") then
				local id, action = match(field, "_(%d+)_(%w+)$")
				id = tonumber(id)
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
			data.scrbar_inv = tonumber(match(sb_inv, "%d+"))
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
		data.scrbar_rcp = sb_rcp and tonumber(match(sb_rcp, "%d+"))
		data.scrbar_usg = sb_usg and tonumber(match(sb_usg, "%d+"))

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
			data.current_itab = tonumber(f:sub(-1))
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

core.register_on_chatcommand(function(name)
	local player = core.get_player_by_name(name)
	core.after(0, set_fs, player)
end)

core.register_on_priv_grant(function(name, _, priv)
	if priv == "creative" or priv == "all" then
		local data = i3.data[name]
		reset_data(data)
		data.favs = {}

		local player = core.get_player_by_name(name)
		core.after(0, set_fs, player)
	end
end)

core.register_on_player_inventory_action(function(player, _, _, info)
	local name = player:get_player_name()

	if not core.is_creative_enabled(name) and
	  ((info.from_list == "main"  and info.to_list == "craft") or
	   (info.from_list == "craft" and info.to_list == "main")  or
	   (info.from_list == "craftresult" and info.to_list == "main")) then
		set_fs(player)
	end
end)

local trash = core.create_detached_inventory("i3_trash", {
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

local output_rcp = core.create_detached_inventory("i3_output_rcp", {})
output_rcp:set_size("main", 1)

local output_usg = core.create_detached_inventory("i3_output_usg", {})
output_usg:set_size("main", 1)
