local damage_enabled = i3.settings.damage_enabled
local debug_mode = i3.settings.debug_mode

local model_aliases = i3.files.model_alias()
local PNG, styles, fs_elements, colors = i3.files.styles()

local sprintf = string.format
local VoxelArea, VoxelManip = VoxelArea, VoxelManip

IMPORT("vec", "vec_round")
IMPORT("find", "match", "sub", "upper")
IMPORT("clr", "ESC", "msg", "check_privs")
IMPORT("min", "max", "floor", "ceil", "round")
IMPORT("true_str", "is_fav", "is_num", "str_to_pos")
IMPORT("reg_items", "reg_nodes", "reg_tools", "reg_entities")
IMPORT("get_bag_description", "get_detached_inv", "get_recipes")
IMPORT("compression_active", "compressible", "recipe_filter_set")
IMPORT("S", "ES", "translate", "ItemStack", "toupper", "utf8_len")
IMPORT("maxn", "sort", "concat", "copy", "insert", "remove", "unpack")
IMPORT("extract_groups", "groups_to_items", "is_group", "item_has_groups", "get_group")

local function fmt(elem, ...)
	if not fs_elements[elem] then
		return sprintf(elem, ...)
	end

	return sprintf(fs_elements[elem], ...)
end

local function repairable(tool)
	local def = reg_tools[tool]
	return i3.toolrepair and def and def.groups and def.groups.disable_repair ~= 1
end

local function weird_desc(str)
	return not true_str(str) or find(str, "\n") or not find(str, "%u")
end

local function snip(str, limit, font_size)
	limit -= (font_size > 3 and font_size + 1 or font_size)

	if utf8_len(str) > limit then
		return fmt("%s...", sub(str, 1, limit - 3))
	end
end

local function get_desc(item, lang_code)
	if sub(item, 1, 1) == "_" then
		item = sub(item, 2)
	end

	local def = reg_items[item]
	if not def then
		return S("Unknown Item (@1)", item)
	end

	local desc = ItemStack(item):get_short_description()
	      desc = translate(lang_code, desc)

	if true_str(desc) then
		desc = desc:trim():gsub("_", " ")

		if not find(desc, "%u") then
			desc = toupper(desc)
		end

		return desc

	elseif true_str(item) then
		return toupper(match(item, ":(.*)"))
	end
end

local function get_stack_max(inv, data, is_recipe, rcp)
	local list = inv:get_list"main"
	local size = inv:get_size"main"
	local counts_inv, counts_rcp, counts = {}, {}, {}
	local rcp_usg = is_recipe and "recipe" or "usage"

	for _, it in pairs(rcp.items) do
		counts_rcp[it] = (counts_rcp[it] or 0) + 1
	end

	data.crafting_counts[rcp_usg] = {}
	data.crafting_counts[rcp_usg].rcp = counts_rcp

	for i = 1, size do
		local stack = list[i]

		if not stack:is_empty() then
			local item = stack:get_name()
			local count = stack:get_count()

			for name in pairs(counts_rcp) do
				if is_group(name) then
					local def = reg_items[item]

					if def then
						local group_cache = i3.groups[name:sub(7)]
						local groups = group_cache and group_cache.groups or extract_groups(name)

						if item_has_groups(def.groups, groups) then
							counts_inv[name] = (counts_inv[name] or 0) + count
						end
					end
				end
			end

			counts_inv[item] = (counts_inv[item] or 0) + count
		end
	end

	data.crafting_counts[rcp_usg].inv = counts_inv

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

local function add_subtitle(fs, name, y, ctn_len, font_size, sep, label)
	fs("style[%s;font=bold;font_size=%u]", name, font_size)
	button(0, y, ctn_len, 0.5, name, ESC(label))

	if sep then
		image(0, y + 0.55, ctn_len, 0.035, PNG.bar)
	end
end

local function get_award_list(data, fs, ctn_len, yextra, award_list, awards_unlocked, award_list_nb)
	local percent = fmt("%.1f%%", (awards_unlocked * 100) / award_list_nb):gsub("%.0", "")

	add_subtitle(fs, "awards", yextra, ctn_len, 18, false,
		ES("Achievements: @1 of @2 (@3)", awards_unlocked, award_list_nb, percent))

	for i = 1, award_list_nb do
		local award = award_list[i]
		local y = yextra - 0.6 + i + (i * 0.3)

		local def, progress = award.def, award.progress
		local title, desc = def.title, def.description

		title = translate(data.lang_code, title)
		desc = translate(data.lang_code, desc):gsub("%.$", "")

		local title_lim, desc_lim = 27, 39
		local icon_size = 1.1

		local _title = snip(title, title_lim, data.font_size) or title
		local _desc = snip(desc, desc_lim, data.font_size) or desc

		if not award.unlocked and def.secret then
			title = ES"Secret award"
			desc = ES"Unlock this award to find out what it is"
		end

		local icon = def.icon or "awards_unknown.png"

		if not award.unlocked then
			icon = fmt("%s^\\[colorize:#000:220", icon)
		end

		insert(fs, fmt("image", 0, y, icon_size, icon_size, icon))
		insert(fs, "style_type[box;colors=#bababa30,#bababa30,#bababa05,#bababa05]")
		insert(fs, fmt("box", 0, y, ctn_len, icon_size, ""))

		if progress then
			local box_len = ctn_len - icon_size - 0.15
			local current, target = progress.current, progress.target
			local curr_bar = (current * box_len) / target

			insert(fs, fmt("box", icon_size + 0.15, y + 0.8, box_len, 0.3, "#101010"))
			insert(fs, "style_type[box;colors=#9dc34c80,#9dc34c,#9dc34c,#9dc34c80]")
			insert(fs, fmt("box", icon_size + 0.15, y + 0.8, curr_bar, 0.3, ""))
			insert(fs, "style_type[label;font_size=14]")
			insert(fs, fmt("label", icon_size + 0.55, y + 0.97, fmt("%u / %u", current, target)))

			y -= 0.14
		end

		local end_title = ESC(_title or title)
		local end_desc = ESC(_desc or desc)

		insert(fs, "style_type[label;font=bold;font_size=17]")
		insert(fs, fmt("label", icon_size + 0.2, y + 0.4, end_title))
		insert(fs, "style_type[label;font=normal;font_size=15]")
		insert(fs, fmt("label", icon_size + 0.2, y + 0.75, clr("#bbb", end_desc)))
		insert(fs, "style_type[label;font_size=16]")
		insert(fs, fmt("tooltip", 0, y, icon_size, icon_size, ESC(desc)))
	end
end

local function get_isometric_view(fs, pos, X, Y, t, cubes, depth, high)
	pos   = vec_round(pos)
	cubes = cubes or 0
	depth = depth or -1
	high  = high or math.huge

	t = t or {}
	t[depth] = {}

	local width = 8
	local base_height = 4
	local base_depth = depth == -1
	local max_depth = -7
	local height = base_depth and (base_height - 1) or depth

	local pos1 = vec(pos.x - width, pos.y + depth, pos.z - width)
	local pos2 = vec(pos.x + width, pos.y + height, pos.z + width)

	local vm = VoxelManip(pos1, pos2)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	local data = vm:get_data()

	for idx in area:iterp(pos1, pos2) do
		local cube = i3.cubes[data[idx]]
		local plant = i3.plants[data[idx]]
		local img = cube or plant

		if img then
			local p = area:position(idx)
			      p -= pos

			local size = 0.25
			local x = 2 + (size / 2 * (p.z - p.x))
			local y = 1 + (size / 4 * (p.x + p.z - 2 * p.y))

			if y < high then
				high = y
			end

			if plant then
				size -= 0.05
			end

			cubes++
			insert(t[depth], {x + X, y + Y, size, size, img})
		end
	end

	local maxc = ((width * 2) ^ 2) * base_height

	if cubes < maxc and depth > max_depth then
		-- if there's not enough map to preview, go deeper
		depth -= 1
		return get_isometric_view(fs, pos, X, Y, t, cubes, depth, high)
	end

	local shift = -0.3 - high

	for i = max_depth, 0 do
		local dth = t[i]
		if dth then
			dth[0] = #dth
			for j = 1, dth[0] do
				local params = dth[j]
				      params[2] += shift
				insert(fs, fmt("image[%f,%f;%.1f,%.1f;%s]", unpack(params)))
			end
		end
	end

	shift += (base_depth and 0.45 or 0.95)
	animated_image(2.75, Y + shift, 3/14, 0.3, "i3_flag_anim.png", 4, 150)
end

local function get_waypoint_fs(fs, data, player, yextra, ctn_len)
	fs("box[0,%f;4.9,0.6;#bababa25]", yextra + 1.1)
	label(0, yextra + 0.85, ES"New waypoint" .. ":")
	fs("field[0.1,%f;4.8,0.6;waypoint_name;;]", yextra + 1.1)
	image_button(5.1, yextra + 1.15, 0.5, 0.5, "", "waypoint_add", "")
	fs("tooltip[waypoint_add;%s]", ES"Add waypoint")

	if #data.waypoints == 0 then return end
	fs"style_type[label;font=bold;font_size=17]"

	for i, v in ipairs(data.waypoints) do
		local y = yextra + 1.35 + (i - (i * 0.3))
		local icon_size, yi = 0.35, y + 0.12

		fs"style_type[box;colors=#bababa30,#bababa30,#bababa05,#bababa05]"
		box(0, y, ctn_len, 0.6, "")

		local waypoint_name, lim = v.name, 22
		waypoint_name = snip(waypoint_name, lim, data.font_size) or waypoint_name

		local hex = fmt("%02x", v.color)

		while #hex < 6 do
			hex = "0" .. hex
		end

		local teleport_priv = check_privs(player, {teleport = true})
		local waypoint_preview = data.waypoint_see and data.waypoint_see == i

		label(0.15, y + 0.33, clr(fmt("#%s", hex), waypoint_name))

		local tooltip = fmt("Name: %s\nPosition:%s", clr("#dbeeff", v.name),
					v.pos:sub(2,-2):gsub("(%-*%d*%.?%d+)", clr("#dbeeff", " %1")))

		if teleport_priv then
			tooltip = fmt("%s\n%s", tooltip, clr("#ff0", ES"[Click to teleport]"))
		end

		tooltip(0, y, ctn_len - 2.1, 0.65, tooltip)

		local del = fmt("waypoint_%u_delete", i)
		fs("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]", del, PNG.trash, PNG.trash_hover)
		image_button(ctn_len - 0.5, yi, icon_size, icon_size, "", del, "")
		fs("tooltip[%s;%s]", del, ES"Remove waypoint")

		local rfs = fmt("waypoint_%u_refresh", i)
		fs("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]", rfs, PNG.refresh, PNG.refresh_hover)
		image_button(ctn_len - 1, yi, icon_size, icon_size, "", rfs, "")
		fs("tooltip[%s;%s]", rfs, ES"Change color")

		local see = fmt("waypoint_%u_see", i)
		fs("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]",
			see, waypoint_preview and PNG.search_hover or PNG.search, PNG.search, PNG.search_hover)
		image_button(ctn_len - 1.5, yi, icon_size, icon_size, "", see, "")
		fs("tooltip[%s;%s]", see, ES"Preview the waypoint area")

		local vsb = fmt("waypoint_%u_hide", i)
		fs("style[%s;fgimg=%s;content_offset=0]", vsb, v.hide and PNG.nonvisible or PNG.visible)
		image_button(ctn_len - 2, yi, icon_size, icon_size, "", vsb, "")
		fs("tooltip[%s;%s]", vsb, v.hide and ES"Show waypoint" or ES"Hide waypoint")

		if teleport_priv then
			local tp = fmt("waypoint_%u_teleport", i)
			button(0, y, ctn_len - 2.1, 0.6, tp, "")
		end

		if waypoint_preview then
			image(0.25, y - 3.5, 5, 4, PNG.bg_content)
			fs"style[area_preview;font_size=16;textcolor=#ddd]"
			button(0.25, y - 3.35, 5, 0.55, "area_preview", v.name)
			image_button(4.65, y - 3.25, 0.25, 0.25, PNG.cancel_hover .. "^\\[brighten", "close_preview", "")

			local pos = str_to_pos(data.waypoints[i].pos)
			get_isometric_view(fs, pos, 0.6, y - 2.5)
		end
	end

	fs"style_type[label;font=normal;font_size=16;textcolor=#fff]"
end

local function get_bag_fs(fs, data, bag_size, yextra)
	fs("list[detached:i3_bag_%s;main;0,%f;1,1;]", data.player_name, yextra + 0.7)
	local bag = get_detached_inv("bag", data.player_name)
	if bag:is_empty"main" then return end

	local v = {{1.9, 2, 0.12}, {3.05, 5, 0.06}, {4.2, 10}, {4.75, 10}}
	local h, m, yy = unpack(v[bag_size])

	local bagstack = bag:get_stack("main", 1)
	local desc = ESC(get_bag_description(data, bagstack))

	image(0.5, yextra + 1.85, 0.6, 0.6, PNG.arrow_content)
	fs("style[bg_content;bgimg=%s;fgimg=i3_blank.png;bgimg_middle=10,%u;sound=]", PNG.bg_content, m)
	image_button(1.1, yextra + 0.5 + (yy or 0), 4.75, h, "", "bg_content", "")

	if not data.bag_rename then
		hypertext(1.3, yextra + 0.8, 4.3, 0.6, "content",
			fmt("<global size=16><center><b>%s</b></center>", desc))
		image_button(5.22, yextra + 0.835, 0.25, 0.25, "", "bag_rename", "")
		fs("tooltip[bag_rename;%s]", ES"Rename the bag")
	else
		box(1.7, yextra + 0.82, 2.6, 0.4, "#707070")
		fs("field[1.8,%f;2.5,0.4;bag_newname;;%s]", yextra + 0.82, desc)
		fs"field_close_on_enter[bag_newname;false]"
		hypertext(4.4, yextra + 0.88, 0.8, 0.6, "confirm_rename",
			fmt("<global size=16><tag name=action color=#fff hovercolor=%s>" ..
				"<center><b><action name=ok>OK</action></b></center>", colors.yellow))
	end

	local x, size, spacing = 1.45, 0.9, 0.12

	if bag_size == 4 then
		x, size, spacing = 1.7, 0.8, 0.1
	end

	fs("style_type[list;size=%f;spacing=%f]", size, spacing)
	fs("list[detached:i3_bag_content_%s;main;%f,%f;4,%u;]", data.player_name, x, yextra + 1.3, bag_size)
	fs"style_type[list;size=1;spacing=0.15]"
end

local function get_container(fs, data, player, yoffset, ctn_len, award_list, awards_unlocked, award_list_nb, bag_size)
	local nametag = player:get_nametag_attributes()
	local name = true_str(nametag.text) and nametag.text or data.player_name
	local esc_name = ESC(name)

	add_subtitle(fs, "player_name", 0, ctn_len, 22, true, esc_name)

	if damage_enabled then
		local hp = data.hp or player:get_hp() or 20
		local half = ceil((hp / 2) % 1)
		local hearts = (hp / 2) + half
		local heart_size = 0.35
		local heart_x, heart_h = 0.65, yoffset + 0.75

		for i = 1, 10 do
			image(heart_x + ((i - 1) * (heart_size + 0.1)), heart_h,
				heart_size, heart_size, PNG.heart .. "^[colorize:#232428")
		end

		for i = 1, hearts do
			image(heart_x + ((i - 1) * (heart_size + 0.1)), heart_h,
				heart_size, heart_size,
				(half == 1 and i == floor(hearts)) and PNG.heart_half or PNG.heart)
		end
	else
		yoffset -= 0.5
	end

	fs("list[current_player;craft;%f,%f;3,3;]", 0, yoffset + 1.45)
	image(3.47, yoffset + 2.69, 0.85, 0.85, PNG.arrow)
	fs("list[current_player;craftpreview;%f,%f;1,1;]", 4.45, yoffset + 2.6)
	fs("list[detached:i3_trash;main;%f,%f;1,1;]", 4.45, yoffset + 3.75)
	image(4.45, yoffset + 3.75, 1, 1, PNG.trash)

	local yextra = damage_enabled and 5.5 or 5

	for i, title in ipairs(i3.categories) do
		local btn_name = fmt("btn_%s", title)
		fs("style[btn_%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]", title,
			data.subcat == i and PNG[fmt("%s_hover", title)] or PNG[title],
			PNG[fmt("%s_hover", title)])
		image_button(0.25 + ((i - 1) * 1.18), yextra - 0.2, 0.5, 0.5, "", btn_name, "")
		fs("tooltip[%s;%s]", btn_name, title:gsub("^%l", upper))
	end

	box(0, yextra + 0.45, ctn_len, 0.045, "#bababa50")
	image((data.subcat - 1) * 1.18, yextra + 0.45, 1, 0.045, PNG.highlight)

	local function not_installed(modname)
		hypertext(0, yextra + 0.9, ctn_len, 0.6, "not_installed",
			fmt("<global size=16><center><style color=%s font=mono>%s</style> not installed</center>",
				colors.blue, modname))
	end

	if data.subcat == 1 then
		get_bag_fs(fs, data, bag_size, yextra)

	elseif data.subcat == 2 then
		if not i3.modules.armor then
			return not_installed "3d_armor"
		end

		local armor_def = armor.def[data.player_name]
		local _, armor_inv = armor:get_valid_player(player, "3d_armor")

		fs("list[detached:%s_armor;armor;0,%f;5,1;]", esc_name, yextra + 0.7)

		for i = 1, 5 do
			local stack = armor_inv:get_stack("armor", i)

			if stack:is_empty() then
				local tips = {ES"Helmet", ES"Chest", ES"Leggings", ES"Boots", ES"Shield"}
				local x = (i - 1) + ((i - 1) * 0.15)
				local y = yextra + 0.7

				image(x, y, 1, 1, fmt("i3_armor_%u.png", i))
				tooltip(x, y, 1, 1, tips[i])
			end
		end

		local box_len, max_level, max_heal = 4, 85, 60
		local bar_lvl = (armor_def.level * box_len) / max_level
		local bar_heal = (armor_def.heal * box_len) / max_heal

		fs"style_type[label;font_size=15]"

		box(0.8, yextra + 1.95, box_len, 0.4, "#101010")
		fs"style_type[box;colors=#9dc34c80,#9dc34c,#9dc34c,#9dc34c80]"
		box(0.8, yextra + 1.95, bar_lvl, 0.4, "")
		label(1.1, yextra + 2.15, ES"Armor level")

		box(0.8, yextra + 2.55, box_len, 0.4, "#101010")
		fs"style_type[box;colors=#4466aa80,#4466aa,#4466aa,#4466aa80]"
		box(0.8, yextra + 2.55, bar_heal, 0.4, "")
		label(1.1, yextra + 2.75, ES"Armor healing")

		fs"style_type[label;font_size=16]"

	elseif data.subcat == 3 then
		if not i3.modules.skins then
			return not_installed "skinsdb"
		end

		local _skins = skins.get_skinlist_for_player(data.player_name)
		local skin_name = skins.get_player_skin(player).name
		local spp, add_y = 24, 0

		if #_skins > spp then
			local btn_y = yextra + 0.75
			add_y += 0.6

			data.skin_pagemax = max(1, ceil(#_skins / spp))

			image_button(1.5, btn_y, 0.35, 0.35, "", "prev_skin", "")
			image_button(3.85, btn_y, 0.35, 0.35, "", "next_skin", "")

			fs"style[skin_page;font=bold;font_size=18]"
			button(1.85, btn_y - 0.23, 2, 0.8, "skin_page",
				fmt("%s / %u", clr(colors.yellow, data.skin_pagenum), data.skin_pagemax))
		end

		local first = (data.skin_pagenum - 1) * spp
		local last = first + spp - 1

		for i = first, last do
			local skin = _skins[i + 1]
			if not skin then break end
			local btn_name = fmt("skin_btn_%u", i + 1)

			fs([[ style[%s;padding=10;fgimg=%s;bgimg=%s;bgimg_hovered=i3_btn9_hovered.png;
					bgimg_pressed=i3_btn9_pressed.png;bgimg_middle=4,6;sound=] ]],
				btn_name, skin:get_preview(),
				skin.name == skin_name and "i3_btn9_hovered.png" or "i3_btn9.png")

			local X = (i % 3) * 1.93

			local Y = ceil((i % spp - X) / 3 + 1)
			      Y += (Y * 2.45) + yextra - 2.75 + add_y

			image_button(X, Y, 1.86, 3.4, "", btn_name, "")
			fs("tooltip[%s;%s]", btn_name, ESC(skin.name))
		end

	elseif data.subcat == 4 then
		if not i3.modules.awards then
			return not_installed "awards"
		end

		yextra = yextra + 0.7
		get_award_list(data, fs, ctn_len, yextra, award_list, awards_unlocked, award_list_nb)

	elseif data.subcat == 5 then
		get_waypoint_fs(fs, data, player, yextra, ctn_len)
	end
end

local function show_settings(fs, data)
	if data.confirm_trash then
		image(2.8, 10.65, 4.6, 0.7, PNG.bg_goto)
		label(3.02, 11, "Confirm trash?")
		image_button(5.07, 10.75, 1, 0.5, "", "confirm_trash_yes", "Yes")
		image_button(6.17, 10.75, 1, 0.5, "", "confirm_trash_no", "No")

	elseif data.show_settings then
		fs"container[-0.06,0]"
		image(2.2, 9, 6.1, 2.35, PNG.bg_content)

		local show_home = data.show_setting == "home"
		local show_style = data.show_setting == "style"
		local show_sorting = data.show_setting == "sorting"

		fs"style[setting_home,setting_style,setting_sorting;font=bold;font_size=16;sound=i3_click]"
		fs("style[setting_home:hovered;textcolor=%s]", show_home and colors.yellow or "#fff")
		fs("style[setting_style:hovered;textcolor=%s]", show_style and colors.yellow or "#fff")
		fs("style[setting_sorting:hovered;textcolor=%s]", show_sorting and colors.yellow or "#fff")

		fs("style[setting_home;bgimg=%s;bgimg_hovered=%s;bgimg_middle=9;padding=-9;textcolor=%s]",
			show_home and PNG.pagenum_hover or "", PNG.pagenum_hover,
			show_home and colors.yellow or "#ddd")
		fs("style[setting_style;bgimg=%s;bgimg_hovered=%s;bgimg_middle=9;padding=-9;textcolor=%s]",
			show_style and PNG.pagenum_hover or "", PNG.pagenum_hover,
			show_style and colors.yellow or "#ddd")
		fs("style[setting_sorting;bgimg=%s;bgimg_hovered=%s;bgimg_middle=9;padding=-9;textcolor=%s]",
			show_sorting and PNG.pagenum_hover or "", PNG.pagenum_hover,
			show_sorting and colors.yellow or "#ddd")

		local X = 2.5
		button(X, 9.1, 1.6, 0.55, "setting_home", "Home")
		button(X + 1.7, 9.1, 1.6, 0.55, "setting_style", "Style")
		button(X + 3.4, 9.1, 1.6, 0.55, "setting_sorting", "Sorting")
		image_button(X + 5.12, 9.2, 0.25, 0.25, PNG.cancel_hover .. "^\\[brighten", "close_settings", "")

		if show_home then
			local coords, c, str = {"X", "Y", "Z"}, 0, ES"No home set"

			if data.home then
				str = data.home:gsub(",", "  "):sub(2,-2):gsub("%.%d", ""):gsub(
					"(%-?%d+)", function(a)
						c++
						return fmt("<b>%s: <style color=%s font=mono>%s</style></b>",
							coords[c], colors.blue, a)
					end)
			end

			hypertext(2.2, 9.9, 6, 0.6, "home_pos", fmt("<global size=16><center>%s</center>", str))
			fs("style[set_home;padding=20,10,-210,-10;fgimg=%s;fgimg_hovered=%s]", PNG.home_px, PNG.home_px_hover)
			image_button(4.1, 10.4, 2.2, 0.7, "", "set_home", "")
			label(4.9, 10.75, "Set home")

		elseif show_style then
			checkbox(2.6, 9.95, "cb_hide_tabs", "Hide tabs", tostring(data.hide_tabs))
			checkbox(2.6, 10.4, "cb_legacy_inventory", "Legacy inventory", tostring(data.legacy_inventory))
			checkbox(2.6, 10.85, "cb_wielditem_hud", "HUD description", tostring(data.wielditem_hud))

			if not recipe_filter_set() then
				checkbox(5.3, 10.85, "cb_collapse", "Collapse list", tostring(data.collapse))
			end

			local sign = (data.font_size > 0 and "+") or (data.font_size > 0 and "-") or ""
			label(5.3, 9.95, ES"Font size" .. fmt(": %s", sign .. data.font_size))

			local range = 5
			fs("scrollbaroptions[min=-%u;max=%u;smallstep=1;largestep=1;thumbsize=2]", range, range)
			fs("scrollbar[5.3,10.2;2.55,0.3;horizontal;sb_font_size;%d]", data.font_size)

			fs("tooltip[cb_hide_tabs;%s;#707070;#fff]",
				ES"Enable this option to change the style of the right panel")
			fs("tooltip[cb_legacy_inventory;%s;#707070;#fff]",
				ES"Enable this option to set the classic inventory size in Minetest")
			fs("tooltip[cb_wielditem_hud;%s;#707070;#fff]",
				ES"Enable this option to show the wielded item description in your HUD")
			fs("tooltip[cb_collapse;%s;#707070;#fff]",
				ES"Enable this option to collapse the inventory list by grouping some items")

		elseif show_sorting then
			checkbox(2.6, 9.95, "cb_inv_compress", "Compression", tostring(data.inv_compress))
			checkbox(2.6, 10.4,  "cb_reverse_sorting", "Reverse mode", tostring(data.reverse_sorting))
			checkbox(2.6, 10.85, "cb_ignore_hotbar", "Ignore hotbar", tostring(data.ignore_hotbar))
			checkbox(5.3, 9.95, "cb_auto_sorting", "Automation", tostring(data.auto_sorting))

			local methods = {}

			for _, v in ipairs(i3.sorting_methods) do
				local name = toupper(v.name)
				insert(methods, name)
			end

			label(5.3, 10.4, ES"Sorting method:")
			fs("dropdown[%f,%f;2.6,0.5;dd_sorting_method;%s;%u;true]",
				5.3, 10.6, concat(methods, ","), data.sort)

			local desc = i3.sorting_methods[data.sort].description
			if desc then
				tooltip(5.3, 10.6, 2.4, 0.5, ESC(desc))
			end

			fs("tooltip[cb_inv_compress;%s;#707070;#fff]",
				ES"Enable this option to compress your inventory")
			fs("tooltip[cb_reverse_sorting;%s;#707070;#fff]",
				ES"Enable this option to sort your inventory in reverse order")
			fs("tooltip[cb_ignore_hotbar;%s;#707070;#fff]",
				ES"Enable this option to sort your inventory except the hotbar slots")
			fs("tooltip[cb_auto_sorting;%s;#707070;#fff]",
				ES"Enable this option to sort your inventory automatically")
		end

		fs"container_end[]"
	end
end

local function get_footer(fs, data)
	local btn = {
		{"trash",    ES"Clear inventory"},
		{"sort",     ES"Sort inventory"},
		{"settings", ES"Settings"},
		{"home",     ES"Go home"},
	}

	for i, v in ipairs(btn) do
		local btn_name, tooltip = unpack(v)
		fs("style[%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]",
			btn_name, PNG[btn_name], PNG[fmt("%s_hover", btn_name)])
		image_button(i + 3.43 - (i * 0.4), 11.43, 0.35, 0.35, "", btn_name, "")
		fs("tooltip[%s;%s]", btn_name, tooltip)
	end

	show_settings(fs, data)
end

local function get_slots(fs, data)
	local legacy_inventory = data.legacy_inventory
	local hotbar_len = data.hotbar_len
	local inv_x = legacy_inventory and 0.23 or 0.22
	local inv_y = legacy_inventory and 6.7 or 6.9
	local spacing = legacy_inventory and 0.25 or 0.1
	local size = 1

	fs"style_type[box;colors=#77777710,#77777710,#777,#777]"

	for i = 0, hotbar_len - 1 do
		box(i * size + inv_x + (i * spacing), inv_y, size, size, "")
	end

	fs("style_type[list;size=%f;spacing=%f]", size, spacing)
	fs("list[current_player;main;%f,%f;%u,1;]", inv_x, inv_y, hotbar_len)

	fs("style_type[list;size=%f;spacing=%f,%f]", size, spacing, legacy_inventory and 0.15 or spacing)

	fs("list[current_player;main;%f,%f;%u,%u;%u]", inv_x, inv_y + (legacy_inventory and 1.25 or 1.15),
		hotbar_len, data.inv_size / hotbar_len, hotbar_len)

	fs"listring[current_player;craft]listring[current_player;main]"

	get_footer(fs, data)
end

local function get_inventory_fs(player, data, fs)
	local props = player:get_properties()
	local ctn_len = 5.7
	local ctn_hgt = data.legacy_inventory and 6.1 or 6.3
	local yoffset = 0

	if props.mesh ~= "" then
		local anim = player:get_local_animation()
		local armor_skin = i3.modules.armor or i3.modules.skins
		local t = {}

		for _, v in ipairs(props.textures) do
			insert(t, (ESC(v):gsub(",", "!")))
		end

		local textures = concat(t, ","):gsub("!", ",")

	--	fs"style[player_model;bgcolor=black]"
		model(0.2, 0.2, armor_skin and 4 or 3.4, ctn_hgt,
			"player_model", props.mesh, textures, "0,-150", "false", "false",
			fmt("%u,%u;30", anim.x, anim.y))
	else
		local size = 2.5
		image(0.7, 0.2, size, size * props.visual_size.y, props.textures[1])
	end

	local awards_unlocked, award_list, award_list_nb = 0
	local max_val = damage_enabled and 12 or 7
	      max_val += (data.legacy_inventory and 2 or 0)
	local bag_size = get_group(ItemStack(data.bag):get_name(), "bag")

	if data.subcat == 1 and bag_size > 0 then
		max_val += min(32, 6 + ((bag_size - 1) * 10))

	elseif i3.modules.armor and data.subcat == 2 then
		if data.scrbar_inv >= max_val then
			data.scrbar_inv += 10
		end

		max_val += 10

	elseif i3.modules.skins and data.subcat == 3 then
		local spp = 24
		local _skins = skins.get_skinlist_for_player(data.player_name)
		local nb = #_skins
		local num = max(1, min(spp, nb - ((data.skin_pagenum - 1) * spp)))

		max_val += ceil(num / 3) * (nb > spp and 34 or 31)

	elseif i3.modules.awards and data.subcat == 4 then
		award_list = awards.get_award_states(data.player_name)
		award_list_nb = #award_list

		for i = 1, award_list_nb do
			local award = award_list[i]

			if award.unlocked then
				awards_unlocked++
			end
		end

		max_val += (award_list_nb * 13)

	elseif data.subcat == 5 then
		local wp = #data.waypoints

		if wp > 0 then
			local mul = (wp > 8 and 7) or (wp > 4 and 6) or 5
			max_val += 11 + (wp * mul)
		end
	end

	fs([[   scrollbaroptions[arrows=hide;thumbsize=%d;max=%d]
		scrollbar[%f,0.2;0.2,%f;vertical;scrbar_inv;%u]
		scrollbaroptions[arrows=default;thumbsize=0;max=1000]   ]],
	(max_val * 4) / 12, max_val, 9.8, ctn_hgt, data.scrbar_inv)

	fs("scroll_container[3.9,0.2;%f,%f;scrbar_inv;vertical]", ctn_len, ctn_hgt)
	get_container(fs, data, player, yoffset, ctn_len, award_list, awards_unlocked, award_list_nb, bag_size)
	fs"scroll_container_end[]"
end

local function get_tooltip(item, info, lang_code)
	local tooltip

	if info.groups then
		sort(info.groups)
		tooltip = i3.group_names[concat(info.groups, ",")]

		if not tooltip then
			local groupstr = {}

			for i = 1, #info.groups do
				insert(groupstr, clr("#ff0", info.groups[i]))
			end

			groupstr = concat(groupstr, ", ")
			tooltip = S("Any item belonging to the groups: @1", groupstr)
		end
	else
		tooltip = info.meta_desc or get_desc(item, lang_code)
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
			local rpl = ItemStack(info.replace.items[i]):get_name()
			local desc = clr("#ff0", get_desc(rpl, lang_code))

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
		tooltip = add(S("Repairable by step of @1", clr("#ff0", i3.toolrepair .. "%")))
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
				names = fmt("%s\t\t- %s\n", names, clr("#ff0", get_desc(info.tools[i], lang_code)))
			end

			tooltip = add(S("Only drop if using one of these tools: @1", sub(names, 1, -2)))
		else
			tooltip = add(S("Only drop if using this tool: @1",
					clr("#ff0", get_desc(info.tools[1], lang_code))))
		end
	end

	return fmt("tooltip[%s;%s]", item, ESC(tooltip))
end

local function get_true_count(data, count, is_recipe, is_usage)
	local count_mul = 1

	if is_recipe then
		count_mul = data.scrbar_rcp
	elseif is_usage then
		count_mul = data.scrbar_usg
	end

	if count_mul then
		count *= count_mul
	end

	return count
end

local function get_output_fs(fs, data, rcp, is_recipe, is_usage, shapeless, right, btn_size, btn_size2)
	local custom_recipe = i3.craft_types[rcp.type]
	local cooking = rcp.type == "cooking"
	local fuel = rcp.type == "fuel"

	if custom_recipe or shapeless or cooking then
		local icon, tooltip = PNG.blank

		if custom_recipe and true_str(custom_recipe.icon) then
			icon = custom_recipe.icon
		elseif shapeless then
			icon = PNG.shapeless
		end

		local pos_x = right + btn_size + 0.42
		local pos_y = data.yoffset + 0.9

		if cooking then
			animated_image(pos_x, pos_y, 0.5, 0.5, PNG.furnace_anim, 8, 180)
		else
			image(pos_x, pos_y, 0.5, 0.5, icon)
		end

		if custom_recipe and true_str(custom_recipe.description) then
			tooltip = custom_recipe.description
		elseif shapeless then
			tooltip = S"Shapeless"
		elseif cooking then
			tooltip = S"Cooking"
		end

		if tooltip then
			tooltip(pos_x, pos_y, 0.5, 0.5, ESC(tooltip))
		end
	end

	local BTN_SIZE = i3.settings.item_btn_size
	local arrow_X = right + 0.2 + (btn_size2 or BTN_SIZE)
	local X = arrow_X + 1.2
	local Y = data.yoffset + 1.4

	image(arrow_X, Y + 0.06, 1, 1, PNG.arrow)

	if fuel then
		animated_image(X + 0.05, Y, BTN_SIZE, BTN_SIZE, PNG.fire_anim, 8, 180)
		return
	end

	local item  = ItemStack(rcp.output)
	local meta  = item:get_meta()
	local name  = item:get_name()
	local count = item:get_count()
	local _name = fmt("_%s", name)

	local size = BTN_SIZE * 1.2
	slot(X, Y - 0.11, size, size)

	count = get_true_count(data, count, is_recipe, is_usage)
	item:set_count(count)

	local itemstr = ESC(item:to_string())
	item_image_button(X + 0.11, Y, BTN_SIZE, BTN_SIZE, itemstr, _name, "")

	if item:get_stack_max() < count then
		label(X + 1.05, Y + 1, count)
	end

	local def = reg_items[name]
	local unknown = not def or nil
	local desc = def and def.description
	local weird = name ~= "" and desc and weird_desc(desc) or nil
	local burntime = i3.fuel_cache[name] and i3.fuel_cache[name].burntime

	local short_desc = meta:get_string"short_description"
	local long_desc  = meta:get_string"description"
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
		fs(get_tooltip(_name, infos, data.lang_code))
	end
end

local function get_grid_fs(fs, data, rcp, is_recipe, is_usage)
	local width = rcp.width or 1
	local right = 0
	local btn_size, _btn_size = i3.settings.item_btn_size
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
		fs"style_type[item_image_button;border=true]"
	end

	for i = 1, width * rows do
		local item  = rcp.items[i] or ""
		      item  = ItemStack(item)
		local meta  = item:get_meta()
		local name  = item:get_name()
		local count = item:get_count()
		local X, Y

		if large_recipe then
			local a, b = 3, 3
			local add_x, add_y = 0, 0

			if width < 3 then
				a, b = width * 2, 1
				add_x = 2
			elseif rows < 3 then
				a, b = 1, rows * 2
				add_y = 1.4
			end

			btn_size = (a / width) * (b / rows) + 0.3
			_btn_size = btn_size

			local xi = (i - 1) % width
			local yi = floor((i - 1) / width)

			X = btn_size * xi + data.inv_width + 0.3 + (xi * 0.05) + add_x
			Y = btn_size * yi + data.yoffset + 0.2 + (yi * 0.05) + add_y
		else
			X = ceil((i - 1) % width - width)
			X += (X * 0.2) + data.inv_width + 3.9

			Y = ceil(i / width) - min(2, rows)
			Y += (Y * 0.15) + data.yoffset + 1.4
		end

		if X > right then
			right = X
		end

		local groups
		local group_cache = i3.groups[name:sub(7)]

		if is_group(name) then
			groups = group_cache and group_cache.groups or extract_groups(name)
			name = group_cache and (group_cache.stereotype or group_cache.items[1]) or
				groups_to_items(groups)[1] or ""
		end

		local label = groups and "\nG" or ""
		local replace

		for _, replacement in ipairs(rcp.replacements or {}) do
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
					label = fmt("%s\nR", label)
					insert(replace.items, replacement[2])
				end
			end
		end

		local _, count_sub = label:gsub("\n", "")
		if count_sub == 2 then
			label = label:sub(2)
		end

		if not large_recipe then
			slot(X, Y, btn_size, btn_size)
		end

		local btn_name = groups and fmt("group!%s!%s", groups[1], name) or name
		count = get_true_count(data, count, is_recipe, is_usage)

		if group_cache and group_cache.sprite and not large_recipe then
			local sprite = ESC(group_cache.sprite)
			local size = btn_size - 0.02

			item_image_button(X, Y, btn_size, btn_size, "", btn_name, "")
			animated_image(X + 0.01, Y + 0.025, size, size, sprite, group_cache.count, 1500)
			label(X + 0.45, Y + 0.18, label)

			if count > 1 then
				label(X + 0.8, Y + 0.9, count)
			end
		else
			item:set_name(name)
			item:set_count(count)
			local itemstr = ESC(item:to_string())

			item_image_button(X, Y, btn_size, btn_size, itemstr, btn_name, label)

			if item:get_stack_max() < count then
				label(X + 0.95, Y + 0.95, count)
			end
		end

		local def = reg_items[name]
		local unknown = not def or nil
		      unknown = not groups and unknown or nil
		local desc = def and def.description
		local weird = name ~= "" and desc and weird_desc(desc) or nil
		local burntime = i3.fuel_cache[name] and i3.fuel_cache[name].burntime

		local short_desc = meta:get_string"short_description"
		local long_desc  = meta:get_string"description"
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
			fs(get_tooltip(btn_name, infos, data.lang_code))
		end
	end

	if large_recipe then
		fs"style_type[item_image_button;border=false]"
	end

	get_output_fs(fs, data, rcp, is_recipe, is_usage, shapeless, right, btn_size, _btn_size)
end

local function get_rcp_lbl(fs, data, panel, rn, is_recipe, is_usage)
	local rcp = is_recipe and panel.rcp[data.rnum] or panel.rcp[data.unum]

	if rcp.custom then
		local craft_type = i3.craft_types[rcp.type]
		if craft_type then
			local desc = craft_type.description
			hypertext(data.inv_width + 4.8, data.yoffset + 0.12, 3, 1, "custom_rcp",
				fmt("<right><i><global size=16>%s\n<global size=15>%s</i></right>",
					ES"Custom recipe", ESC(desc)))
		end
	end

	local lbl = ES("Usage @1 of @2", data.unum, rn)

	if is_recipe then
		lbl = ES("Recipe @1 of @2", data.rnum, rn)
	end

	local one = rn == 1
	local y = data.yoffset + 3.3

	hypertext(data.inv_width + (one and 4.7 or 3.95), y, 3, 0.6, "rcp_num",
		fmt("<global size=16><right>%s</right>", lbl))

	if not one then
		local btn_suffix = is_recipe and "recipe" or "usage"
		local prev_name = fmt("prev_%s", btn_suffix)
		local next_name = fmt("next_%s", btn_suffix)
		local size = 0.3

		image_button(data.inv_width + 7.05, y, size, size, "", prev_name, "")
		image_button(data.inv_width + 7.5,  y, size, size, "", next_name, "")
	end

	get_grid_fs(fs, data, rcp, is_recipe, is_usage)
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

				_name = fmt("%s^[multiply:%s", v.name, fmt("#%s%s", sub(hex, 3), sub(hex, 1, 2)))
			else
				_name = fmt("%s^[multiply:%s", v.name, v.color)
			end
		elseif v.animation then
			_name = fmt("%s^[verticalframe:%u:0", v.name, v.animation.frames_h or v.animation.aspect_h)
		end

		insert(t, _name or v.name or v)
	end

	while #t < 6 do
		insert(t, t[#t])
	end

	model(data.inv_width + 6.6, data.yoffset + 0.05, 1.3, 1.3, "preview",
		def.mesh, concat(t, ","), "0,0", "true", "true",
		model_alias and model_alias.frames or "")
end

local function get_header(fs, data)
	local fav = is_fav(data)
	local nfavs = #data.favs
	local max_favs = i3.settings.max_favs
	local star_x, star_y, size = data.inv_width + 0.3, data.yoffset + 0.2, 0.4

	if nfavs < max_favs or (nfavs == max_favs and fav) then
		local fav_marked = fmt("i3_fav%s.png", fav and "_off" or "")
		fs("style[fav;fgimg=%s;fgimg_hovered=%s;fgimg_pressed=%s]",
			fmt("i3_fav%s.png", fav and "" or "_off"), fav_marked, fav_marked)
		image_button(star_x, star_y, size, size, "", "fav", "")
		fs("tooltip[fav;%s]", fav and ES"Unmark this item" or ES"Mark this item")
	else
		fs("style[nofav;fgimg=%s;fgimg_hovered=%s;fgimg_pressed=%s]",
			"i3_fav_off.png", PNG.cancel, PNG.cancel)
		image_button(star_x, star_y, size, size, "", "nofav", "")
		fs("tooltip[nofav;%s]", ES"Cannot mark this item. Bookmark limit reached.")
	end

	image_button(star_x + 0.05, star_y + 0.6, size, size, "", "exit", "")
	fs("tooltip[exit;%s]", ES"Back to item list")

	local desc_lim, name_lim = 34, 35
	local desc = get_desc(data.query_item, data.lang_code)
	      desc = ESC(desc)
	local tech_name = data.query_item
	local X = data.inv_width + 0.95
	local Y1 = data.yoffset + 0.47
	local Y2 = Y1 + 0.5

	local _desc = snip(desc, desc_lim, data.font_size)
	if _desc then
		tooltip(X, Y1 - 0.1, 5.7, 0.24, desc)
	end

	local _tech_name = snip(tech_name, name_lim, data.font_size)
	if _tech_name then
		tooltip(X, Y2 - 0.1, 5.7, 0.24, tech_name)
	end

	fs"style_type[label;font=bold;font_size=20]"
	label(X, Y1, _desc or desc)
	fs"style_type[label;font=mono;font_size=16]"
	label(X, Y2, clr(colors.blue, _tech_name or tech_name))
	fs"style_type[label;font=normal;font_size=16]"

	local def = reg_items[data.query_item]
	local model_alias = model_aliases[data.query_item]

	if def.drawtype == "mesh" or model_alias then
		get_model_fs(fs, data, def, model_alias)
	else
		item_image(data.inv_width + 6.8, data.yoffset + 0.17, 1.1, 1.1, data.query_item)
	end
end

local function get_crafting_fs(fs, data, is_recipe, is_usage, max_stacks_rcp, max_stacks_usg)
	local name = is_recipe and "rcp" or "usg"
	local show_crafting = (is_recipe and data.crafting_rcp) or (is_usage and data.crafting_usg)

	fs("style[crafting_%s;fgimg=%s;fgimg_hovered=%s;content_offset=0]",
		name, fmt("%s", show_crafting and PNG.crafting_hover or PNG.crafting), PNG.crafting_hover)
	image_button(data.inv_width + 7.35, data.yoffset + 0.2, 0.45, 0.45, "", fmt("crafting_%s", name), "")
	fs("tooltip[crafting_%s;%s]", name, ES"Quick crafting")

	if not show_crafting then return end

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

	local x = data.inv_width + 6.8

	fs"style_type[image,button,image_button;noclip=true]"
	image(x, data.yoffset + 0.8, 3, 2, PNG.bg_content)
	fs"style[quick_crafting;font_size=16;textcolor=#ddd]"
	button(x, data.yoffset + 0.85, 3.05, 0.55, "quick_crafting", ES"Quick Crafting")

	fs("style[scrbar_%s;noclip=true]", name)
	fs("scrollbaroptions[min=1;max=%u;smallstep=1]", craft_max)

	scrollbar(x + 0.2, data.yoffset + 1.45, 2.5, 0.35, "horizontal", fmt("scrbar_%s", name), stack_fs)
	button(x + 0.2, data.yoffset + 1.85, 2.5, 0.7, fmt("craft_%s", name), ES("Craft (×@1)", stack_fs))

	fs"style_type[label;font_size=16;textcolor=#fff]"
	fs"style_type[image,button,image_button;noclip=false]"
end

local function get_rcp_extra(fs, data, player, panel, is_recipe, is_usage)
	fs"container[0,0.075]"
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
			data.crafting_rcp = nil
			data.scrbar_rcp = 1
		elseif is_usage and max_stacks_usg == 0 then
			data.crafting_usg = nil
			data.scrbar_usg = 1
		end

		if max_stacks_rcp > 0 or max_stacks_usg > 0 then
			get_crafting_fs(fs, data, is_recipe, is_usage, max_stacks_rcp, max_stacks_usg)
		end

		get_rcp_lbl(fs, data, panel, rn, is_recipe, is_usage)
	else
		local lbl = is_recipe and ES"No recipes" or ES"No usages"
		button(data.inv_width + 0.1, data.yoffset + (panel.height / 2) - 0.5, 7.8, 1, "no_rcp", lbl)
	end

	fs"container_end[]"
end

local function hide_items(player, data)
	if compression_active(data) then
		local new = {}

		for i = 1, #data.items do
			local item = data.items[i]
			if not i3.compressed[item] then
				insert(new, item)
			end
		end

		data.items = new
	end

	if not core.is_creative_enabled(data.player_name) and not recipe_filter_set() then
		local new = {}

		for i = 1, #data.items do
			local item = data.items[i]
			local recipes, usages = get_recipes(player, item)

			if recipes or usages then
				insert(new, item)
			end
		end

		data.items = new
	end
end

local function get_header_items_fs(fs, data)
	local X = data.inv_width
	fs"set_focus[filter;true]"

	if data.hide_tabs then
		fs("style[enable_search;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s]",
			data.enable_search and PNG.search_hover or PNG.search, PNG.search_hover, PNG.search_hover)
		image_button(X + 0.3, 0.2, 0.5, 0.5, "", "enable_search", "")
		fs("tooltip[enable_search;%s]", ES"Search")

		if data.enable_search then
			image(X + 0.4, 0.75, 3.4, 0.8, PNG.bg_goto)

			fs"style[filter;font_size=16]"
			fs("field[%f,%f;3,0.45;filter;;%s]", X + 0.6, 0.95, data.filter)
			fs"field_close_on_enter[filter;false]"
		end

		box(X + 1, 0.2, 0.01, 0.5, "#bababa50")

		local cat = {{"all", "all items"}}

		if not recipe_filter_set() then
			for _, v in ipairs(i3.minitabs) do
				if v.name == "nodes" then
					insert(cat, {"node", "nodes only"})
				end

				if v.name == "items" then
					insert(cat, {"item", "items only"})
				end
			end
		end

		for i in ipairs(cat) do
			local name, desc = unpack(cat[i])
			local active = PNG[name .. "_hover"]

			fs("style[itab_%u;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s;sound=i3_tab]",
				i, data.itab == i and active or PNG[name], active, active)
			image_button(X + 1.25 + ((i - 1) * 0.7), 0.2, 0.5, 0.5, "", fmt("itab_%s", i), "")
			fs("tooltip[itab_%u;Show %s]", i, desc)
		end
	else
		fs("style[search;bgimg=%s]", PNG.search_hover)
		image_button(X + 0.35, 0.32, 0.35, 0.35, "", "search", "")
		fs("tooltip[search;%s]", ES"Search")

		if data.enable_search then
			fs"style[filter;font_size=18]"
			fs("field[%f,0.2;3.35,0.6;filter;;%s]", X + 0.85, ESC(data.filter))
			fs"field_close_on_enter[filter;false]"

			if not true_str(data.filter) then
				image(X + 0.85, 0.75, 4, 0.01, PNG.search_outline_trim .. "^[opacity:100")
			end
		else
			fs"style_type[label;font=italic;font_size=18]"
			label(X + 0.9, 0.49, clr("#aaa", ES"Search..."))
			button(X + 0.8, 0.12, 4, 0.8, "enable_search", "")
			fs"style_type[label;font=normal;font_size=16]"
		end

		if true_str(data.filter) then
			image_button(X + 4.3, 0.4, 0.2, 0.2,  "", "cancel", "")
			fs("tooltip[cancel;%s]", ES"Clear")
			box(X + 0.85, 0.75, 3.74, 0.01, "#f9826c")
		end
	end

	image_button(X + 5.27, 0.3, 0.35, 0.35, "", "prev_page", "")
	image_button(X + 7.45, 0.3, 0.35, 0.35, "", "next_page", "")

	fs("style[pagenum;bgimg=%s;bgimg_hovered=%s;bgimg_middle=9;padding=-9;sound=i3_click]",
		data.goto_page and PNG.pagenum_hover or "", PNG.pagenum_hover)

	button(X + 5.8, 0.14, 1.48, 0.7, "pagenum",
		fmt("%s / %u", clr(colors.yellow, data.pagenum), data.pagemax))

	if data.goto_page then
		image(X + 4.8, 0.85, 2.9, 0.8, PNG.bg_goto)
		fs"style_type[label;font_size=16;textcolor=#ddd]"
		label(X + 5, 1.25, ES"Go to page" .. ":")
		box(X + 6.5, 1, 1, 0.45, "#bababa10")

		fs("style[goto_page;font=mono,bold;font_size=16;textcolor=%s]", colors.yellow)
		fs("field[%f,%f;1,0.45;goto_page;;%s]", X + 6.55, 1.05, data.pagenum)
		fs"field_close_on_enter[goto_page;false]"

		fs"style_type[label;font_size=16;textcolor=#fff]"
	end
end

local function get_minitabs(fs, data, player, full_height)
	local minitabs = {}

	for i, v in ipairs(i3.minitabs) do
		local access = v.access

		if access == nil or access(player, data) then
			minitabs[i] = v.description
		end
	end

	local tab_len, tab_hgh, i = 1.8, 0.5, 0

	for id, title in pairs(minitabs) do
		i++
		local top = i > 3
		local X = top and i - 3 or i
		local selected = id == data.itab
		local hover_texture = selected and PNG.tab_small_hover or PNG.tab_small
		local flip = top and "^[transformFY" or ""
		local tabname = fmt("itab_%u", id)

		fs([[ style[%s;bgimg=%s%s;bgimg_hovered=%s%s;noclip=true;font=bold;font_size=16;
			textcolor=%s;content_offset=0;sound=i3_tab;bgimg_middle=14,0,-14,-14;padding=-14,0,14,14] ]],
			tabname, hover_texture, flip, PNG.tab_small_hover, flip, selected and "#fff" or "#bbb")

		fs("style[%s:hovered;textcolor=#fff]", tabname)

		image_button((data.inv_width - 0.65) + (X * (tab_len + 0.1)),
			top and -tab_hgh or full_height, tab_len, tab_hgh, "", tabname, title)
	end
end

local function get_items_fs(fs, data, player, full_height)
	hide_items(player, data)
	bg9(data.inv_width + 0.1, 0, 7.9, full_height, PNG.bg_full)

	local items = data.alt_items or data.items or {}
	local rows, lines = 8, 12
	local ipp = rows * lines
	local size = 0.85

	data.pagemax = max(1, ceil(#items / ipp))

	if data.pagenum > data.pagemax then
		data.pagenum = data.pagemax
	end

	if #items == 0 then
		local lbl = ES"No item to show"
		local icon, width, offset = PNG.no_result, 4, 2

		if recipe_filter_set() and #i3.init_items > 0 and data.filter == "" then
			lbl = ES"Collect items to reveal more recipes" -- Progressive mode, etc.
			icon, width, offset = PNG.find_more, 2.5, 2.75
		end

		image(data.inv_width + offset, 3.5, width, width, icon)
		button(data.inv_width + 0.1, 7, 8, 1, "no_item", lbl)
	else
		local first_item = (data.pagenum - 1) * ipp

		for i = first_item, first_item + ipp - 1 do
			local item = items[i + 1]
			if not item then break end

			local _compressed = item:sub(1, 1) == "_"
			local name = _compressed and item:sub(2) or item

			local X = i % rows
			      X -= (X * 0.045) + data.inv_width + 0.28

			local Y = round((i % ipp - X) / rows + 1, 0)
			      Y -= (Y * 0.085) + 0.92

			local item_btn = fmt("item_image_button", X, Y, size, size, name, item, "")

			if recipe_filter_set() and data.itab == 1 then
				if data.items_progress[item] then
					insert(fs, item_btn)
				else
					local col = "^\\[colorize:#232428^\\[opacity:245"
					local img = reg_items[item].inventory_image .. col
					local nodedef = reg_nodes[item]

					if nodedef and not true_str(nodedef.inventory_image) then
						img = PNG.cube .. col
					end

					insert(fs, fmt("image", X, Y, size, size, img))
				end
			else
				insert(fs, item_btn)
			end

			if compressible(item, data) then
				local expand = data.expand == name

				fs("tooltip[%s;%s]", item, expand and ES"Click to hide" or ES"Click to expand")
				fs"style_type[label;font=bold;font_size=20]"
				label(X + 0.65, Y + 0.7, expand and "-" or "+")
				fs"style_type[label;font=normal;font_size=16]"
			end
		end
	end

	get_header_items_fs(fs, data)
end

local function get_favs(fs, data)
	local btn_size = i3.settings.item_btn_size
	label(data.inv_width + 0.4, data.yoffset + 0.4, ES"Bookmarks")

	for i, item in ipairs(data.favs) do
		local name = fmt("_%s", item)
		local X = data.inv_width - 0.7 + (i * 1.2)
		local Y = data.yoffset + 0.8

		if data.query_item == item then
			slot(X, Y, btn_size, btn_size)
		end

		item_image_button(X, Y, btn_size, btn_size, item, name, "")
	end
end

local function get_panels(fs, data, player)
	local title   = {name = "title", height = 1.4, func = get_header}
	local favs    = {name = "favs", height = 2.23, func = get_favs}
	local recipes = {name = "recipes", rcp = data.recipes, height = 4.045, func = get_rcp_extra}
	local usages  = {name = "usages", rcp = data.usages, height = 4.045, func = get_rcp_extra}
	local panels  = {title, recipes, usages, favs}
	data.yoffset  = 0

	for i, panel in ipairs(panels) do
		if i > 1 then
			data.yoffset += panels[i - 1].height + 0.1
		end

		bg9(data.inv_width + 0.1, data.yoffset, 7.9, panel.height, PNG.bg_full)

		local is_recipe, is_usage = panel.name == "recipes", panel.name == "usages"
		panel.func(fs, data, player, panel, is_recipe, is_usage)
	end
end

local function get_tabs_fs(fs, player, data, full_height)
	local tab_len, tab_hgh, c, over = 3, 0.5, 0
	local _tabs = copy(i3.tabs)

	for i, def in ipairs(i3.tabs) do
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

		local selected = i == data.tab
		local bgimg = selected and (btm and PNG.tab_hover or PNG.tab_hover_top) or
				(btm and PNG.tab or PNG.tab_top)
		local bgimg_hover = btm and PNG.tab_hover or PNG.tab_hover_top

		local middle = btm and "16,0,-16,-16" or "16,16,-16,-16"
		local padding = btm and "-16,0,16,16" or "-16,-16,16,16"

		local tabname = fmt("tab_%s", def.name)

		fs([[ style[%s;bgimg=%s;bgimg_hovered=%s;bgimg_middle=%s;padding=%s;noclip=true;
			font=bold;font_size=16;textcolor=%s;content_offset=0;sound=i3_tab] ]],
				tabname, bgimg, bgimg_hover, middle, padding, selected and "#fff" or "#bbb")

		local X = (data.inv_width / 2) + (c * (tab_len + 0.1)) - ((tab_len + 0.05) * (shift / 2))
		local Y = btm and full_height or -tab_hgh

		fs("style[%s:hovered;textcolor=#fff]", tabname)
		image_button(X, Y, tab_len, tab_hgh, "", tabname, ESC(def.description))

		if true_str(def.image) then
			local desc = translate(data.lang_code, def.description)
			local desc_len = utf8_len(desc) + data.font_size

			fs"style_type[image;noclip=true]"
			image(X + (tab_len / 2) - ((desc_len * 0.1) / 2) - 0.55, Y + 0.05, 0.35, 0.35, def.image)
			fs"style_type[image;noclip=false]"
		end

		c++
	end
end

local function get_debug_grid(data, fs, full_height)
	fs"style[hide_debug_grid;noclip=true]"
	button(-2, full_height - 1, 2, 1, "hide_debug_grid", "Toggle grid")
	if data.hide_debug_grid then return end

	fs"style_type[label;font_size=8;noclip=true]"
	local spacing, i = 0.2, 1

	for x = 0, data.inv_width + 8, spacing do
		box(x, 0, 0.01, full_height, "#ff0")
		label(x, full_height + 0.1, tostring(i))
		i++
	end

	i = 61

	for y = 0, full_height, spacing do
		box(0, y, data.inv_width + 8, 0.01, "#ff0")
		label(-0.15, y, tostring(i))
		i -= 1
	end

	box(data.inv_width / 2, 0, 0.01, full_height, "#f00")
	box(0, full_height / 2, data.inv_width, 0.01, "#f00")
	fs"style_type[label;font_size=16]"
end

local function make_fs(player, data)
	local start = debug_mode and core.get_us_time() or nil

	local fs = setmetatable({}, {
		__call = function(t, ...)
			local args = {...}

			if #args > 1 then
				local arg1 = args[1]
				local elem = fs_elements[arg1]
				insert(t, fmt(elem or arg1, select(2, ...)))
			else
				insert(t, concat(args))
			end
		end
	})

	data.inv_width = 10.23
	local full_height = 12

	fs("formspec_version[%u]size[%f,%f]no_prepend[]bgcolor[#0000]",
		i3.settings.min_fs_version, data.inv_width + 8, full_height)

	fs(styles)

	bg9(0, 0, data.inv_width, full_height, PNG.bg_full)

	local tab = i3.tabs[data.tab]

	if tab then
		if tab.formspec then
			tab.formspec(player, data, fs)
		end

		if tab.slots then
			get_slots(fs, data)
		end
	end

	if data.query_item then
		get_panels(fs, data, player)
	else
		get_items_fs(fs, data, player, full_height)

		if not data.hide_tabs then
			get_minitabs(fs, data, player, full_height)
		end
	end

	local visible_tabs = #i3.tabs

	for _, def in ipairs(i3.tabs) do
		if def.access and not def.access(player, data) then
			visible_tabs -= 1
		end
	end

	if visible_tabs > 1 then
		get_tabs_fs(fs, player, data, full_height)
	end

	if debug_mode then
		get_debug_grid(data, fs, full_height)
		msg(data.player_name, fmt("make_fs(): %.2f ms", (core.get_us_time() - start) / 1000))
		msg(data.player_name, fmt("#fs elements: %u", #fs))
	end

	fs = concat(fs)

	if data.font_size ~= 0 then
		fs = fs:gsub("([font][global]*)([%s_])size=(%d+)", function(a, b, c)
			return fmt("%s%ssize=%s", a, b, tostring(tonumber(c) + data.font_size))
		end)
	end

	return fs
end

return make_fs, get_inventory_fs
