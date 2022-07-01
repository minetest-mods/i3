local set_fs = i3.set_fs

IMPORT("vec_eq", "vec_round")
IMPORT("reg_items", "reg_aliases")
IMPORT("S", "random", "translate", "ItemStack")
IMPORT("sort", "copy", "insert", "remove", "indexof")
IMPORT("fmt", "find", "match", "sub", "lower", "split", "toupper")
IMPORT("msg", "is_fav", "pos_to_str", "str_to_pos", "add_hud_waypoint", "play_sound", "reset_data")
IMPORT("search", "get_sorting_idx", "sort_inventory", "sort_by_category", "get_recipes", "get_detached_inv")
IMPORT("valid_item", "get_stack", "craft_stack", "clean_name", "compressible", "check_privs", "safe_teleport")

local function inv_fields(player, data, fields)
	local name = data.player_name
	local inv = player:get_inventory()
	local sb_inv = fields.scrbar_inv

	if sb_inv and sub(sb_inv, 1, 3) == "CHG" then
		data.scrbar_inv = tonumber(match(sb_inv, "%d+"))
		return
	end

	if fields.drop_items then
		local items = split(fields.drop_items, ",")
		data.drop_items = items
	end

	for field in pairs(fields) do
		if sub(field, 1, 4) == "btn_" then
			data.subcat = indexof(i3.categories, sub(field, 5))
			break

		elseif sub(field, 1, 3) == "cb_" then
			local str = sub(field, 4)
			data[str] = false

			if fields[field] == "true" then
				data[str] = true
			end

		elseif sub(field, 1, 8) == "setting_" then
			data.show_setting = match(field, "_(%w+)$")

		elseif sub(field, 1, 9) == "skin_btn_" then
			local id = tonumber(field:match("%d+"))
			local _skins = skins.get_skinlist_for_player(name)
			skins.set_player_skin(player, _skins[id])

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

		if data.filter == "" then
			data.enable_search = nil
		end

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

	elseif fields.waypoint_add then
		local max_waypoints = i3.settings.max_waypoints

		if #data.waypoints >= max_waypoints then
			play_sound(name, "i3_cannot", 0.8)
			return msg(name, fmt("Waypoints limit reached (%u)", max_waypoints))
		end

		local pos = player:get_pos()

		for _, v in ipairs(data.waypoints) do
			if vec_eq(vec_round(pos), vec_round(str_to_pos(v.pos))) then
				play_sound(name, "i3_cannot", 0.8)
				return msg(name, S"You already set a waypoint at this position")
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

	elseif fields.hide_debug_grid then
		data.hide_debug_grid = not data.hide_debug_grid
	end

	return set_fs(player)
end

local function select_item(player, data, fields)
	local item

	for field in pairs(fields) do
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

	if fields.filter and fields.filter == "" then
		data.enable_search = nil
	end

	if fields.cancel then
		reset_data(data)

	elseif fields.exit then
		data.query_item = nil

	elseif fields.enable_search then
		data.enable_search = true
		return set_fs(player)

	elseif fields.filter and (fields.key_enter_field == "filter" or fields.search) then
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

	elseif fields.prev_skin or fields.next_skin then
		if data.skin_pagemax == 1 then return end
		data.skin_pagenum -= (fields.prev_skin and 1 or -1)

		if data.skin_pagenum > data.skin_pagemax then
			data.skin_pagenum = 1
		elseif data.skin_pagenum == 0 then
			data.skin_pagenum = data.skin_pagemax
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
		local fav = is_fav(data)

		if #data.favs < i3.settings.max_favs and not fav then
			insert(data.favs, data.query_item)
		elseif fav then
			remove(data.favs, fav)
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
		return false, core.kick_player(name,
			S"Come back when your Minetest client is up-to-date (www.minetest.net).")
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

return inv_fields
