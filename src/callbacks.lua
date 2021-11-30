local _, get_inventory_fs = i3.files.gui()
local set_fs = i3.set_fs

IMPORT("vec_eq", "vec_round")
IMPORT("reg_items", "reg_aliases")
IMPORT("sort", "copy", "insert", "remove", "indexof")
IMPORT("S", "min", "random", "translate", "ItemStack")
IMPORT("fmt", "find", "match", "sub", "lower", "split", "toupper")
IMPORT("msg", "is_fav", "pos_to_str", "str_to_pos", "add_hud_waypoint", "play_sound", "spawn_item")
IMPORT("search", "get_sorting_idx", "sort_inventory", "sort_by_category", "get_recipes", "get_detached_inv")
IMPORT("valid_item", "get_stack", "craft_stack", "clean_name", "compressible", "check_privs", "safe_teleport")

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
	data.show_settings = nil
	data.show_setting  = "home"
	data.items         = data.items_raw

	if data.itab > 1 then
		sort_by_category(data)
	end
end

i3.new_tab("inventory", {
	description = S"Inventory",
	formspec = get_inventory_fs,

	fields = function(player, data, fields)
		local name = data.player_name
		local inv = player:get_inventory()
		local sb_inv = fields.scrbar_inv

		if fields.skins then
			local id = tonumber(fields.skins)
			local _skins = skins.get_skinlist_for_player(name)
			skins.set_player_skin(player, _skins[id])
		end

		if fields.drop_items then
			local items = split(fields.drop_items, ",")
			data.drop_items = items
		end

		for field in pairs(fields) do
			if sub(field, 1, 4) == "btn_" then
				data.subcat = indexof(i3.SUBCAT, sub(field, 5))
				break

			elseif sub(field, 1, 3) == "cb_" then
				local str = sub(field, 4)
				data[str] = false

				if fields[field] == "true" then
					data[str] = true
				end

			elseif sub(field, 1, 8) == "setting_" then
				data.show_setting = match(field, "_(%w+)$")

			elseif find(field, "waypoint_%d+") then
				local id, action = match(field, "_(%d+)_(%w+)$")
				      id = tonumber(id)
				local waypoint = data.waypoints[id]
				if not waypoint then return end

				if action == "see" then
					if data.waypoint_see and data.waypoint_see == id then
						data.waypoint_see = nil
					else
						data.waypoint_see = id
					end

				elseif action == "delete" then
					player:hud_remove(waypoint.id)
					remove(data.waypoints, id)

				elseif action == "teleport" then
					local pos = str_to_pos(waypoint.pos)
					safe_teleport(player, pos)
					msg(name, S("Teleported to: @1", waypoint.name))

				elseif action == "refresh" then
					local color = random(0xffffff)
					waypoint.color = color
					player:hud_change(waypoint.id, "number", color)

				elseif action == "hide" then
					if waypoint.hide then
						local new_id = add_hud_waypoint(
							player, waypoint.name, str_to_pos(waypoint.pos), waypoint.color)

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

		if fields.quit then
			data.confirm_trash = nil
			data.show_settings = nil
			data.waypoint_see = nil
			data.bag_rename = nil

		elseif fields.trash then
			data.show_settings = nil
			data.confirm_trash = true

		elseif fields.settings then
			if not data.show_settings then
				data.confirm_trash = nil
				data.show_settings = true
			else
				data.show_settings = nil
			end

		elseif fields.confirm_trash_yes or fields.confirm_trash_no then
			if fields.confirm_trash_yes then
				inv:set_list("main", {})
				inv:set_list("craft", {})
			end

			data.confirm_trash = nil

		elseif fields.close_settings then
			data.show_settings = nil

		elseif fields.close_preview then
			data.waypoint_see = nil

		elseif fields.sort then
			sort_inventory(player, data)

		elseif fields.prev_sort or fields.next_sort then
			local idx = get_sorting_idx(data.sort)
			local tot = #i3.sorting_methods

			idx -= (fields.prev_sort and 1 or -1)

			if idx > tot then
				idx = 1
			elseif idx == 0 then
				idx = tot
			end

			data.sort = i3.sorting_methods[idx].name

		elseif fields.home then
			if not data.home then
				return msg(name, "No home set")
			elseif not check_privs(name, {home = true}) then
				return msg(name, "'home' privilege missing")
			end

			safe_teleport(player, str_to_pos(data.home))
			msg(name, S"Welcome back home!")

		elseif fields.set_home then
			data.home = pos_to_str(player:get_pos(), 1)

		elseif fields.bag_rename then
			data.bag_rename = true

		elseif fields.confirm_rename then
			local bag = get_detached_inv("bag", name)
			local bagstack = bag:get_stack("main", 1)
			local meta = bagstack:get_meta()
			local desc = translate(data.lang_code, bagstack:get_description())
			local fill = split(desc, "(")[2]
			local newname = fields.bag_newname:gsub("([%(%)])", "")
			      newname = toupper(newname:trim())

			if fill then
				newname = fmt("%s (%s", newname, fill)
			end

			meta:set_string("description", newname)
			bag:set_stack("main", 1, bagstack)

			data.bag = bagstack:to_string()
			data.bag_rename = nil

		elseif sb_inv and sub(sb_inv, 1, 3) == "CHG" then
			data.scrbar_inv = tonumber(match(sb_inv, "%d+"))
			return

		elseif fields.waypoint_add then
			local pos = player:get_pos()

			for _, v in ipairs(data.waypoints) do
				if vec_eq(vec_round(pos), vec_round(str_to_pos(v.pos))) then
					play_sound(name, "i3_cannot", 0.8)
					return msg(name, "You already set a waypoint at this position")
				end
			end

			local waypoint = fields.waypoint_name

			if fields.waypoint_name == "" then
				waypoint = "Waypoint"
			end

			local color = random(0xffffff)
			local id = add_hud_waypoint(player, waypoint, pos, color)

			insert(data.waypoints, {
				name  = waypoint,
				pos   = pos_to_str(pos, 1),
				color = color,
				id    = id,
			})

			data.scrbar_inv += 1000
		end

		return set_fs(player)
	end,
})

local function select_item(player, data, _f)
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
					if valid_item(reg_items[clean_name(v)]) then
						insert(data.alt_items, idx + i, v)
						i++
					end
				end
			end
		end
	else
		if sub(item, 1, 1) == "_" then
			item = sub(item, 2)
		elseif sub(item, 1, 6) == "group!" then
			item = match(item, "([%w:_]+)$")
		end

		item = reg_aliases[item] or item
		if not reg_items[item] then return end

		if core.is_creative_enabled(data.player_name) then
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

local function rcp_fields(player, data, fields)
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

		if data.itab > 1 then
			sort_by_category(data)
		end

	elseif fields.prev_page or fields.next_page then
		if data.pagemax == 1 then return end
		data.pagenum -= (fields.prev_page and 1 or -1)

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
		select_item(player, data, fields)
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()

	if formname == "i3_outdated" then
		return false, core.kick_player(name, S"Come back when your client is up-to-date.")
	elseif formname ~= "" then
		return false
	end

	-- No-op buttons
	if fields.player_name or fields.awards or fields.home_pos or fields.pagenum or
	   fields.no_item or fields.no_rcp or fields.select_sorting or fields.sort_method or
	   fields.bg_content then
		return false
	end

	--print(dump(fields))
	local data = i3.data[name]
	if not data then return end

	for f in pairs(fields) do
		if sub(f, 1, 4) == "tab_" then
			local tabname = sub(f, 5)
			i3.set_tab(player, tabname)
			break
		elseif sub(f, 1, 5) == "itab_" then
			data.pagenum = 1
			data.itab = tonumber(f:sub(-1))
			sort_by_category(data)
			break
		end
	end

	rcp_fields(player, data, fields)

	local tab = i3.tabs[data.tab]

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

	if i3.DROP_BAG_ON_DIE then
		local bagstack = ItemStack(data.bag)
		spawn_item(player, bagstack)
	end

	data.bag = nil
	local bag = get_detached_inv("bag", name)
	local content = get_detached_inv("bag_content", name)

	bag:set_list("main", {})
	content:set_list("main", {})

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
