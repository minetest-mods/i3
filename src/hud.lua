IMPORT("ceil", "get_connected_players", "str_to_pos", "add_hud_waypoint")

local function init_hud(player)
	local name = player:get_player_name()
	local data = i3.data[name]

	data.hud = {
		bg = player:hud_add {
			hud_elem_type = "image",
			position      = {x = 0.78, y = 1},
			alignment     = {x = 1,    y = 1},
			scale         = {x = 370,  y = 112},
			text          = "i3_bg.png",
			z_index       = 0xDEAD,
		},

		img = player:hud_add {
			hud_elem_type = "image",
			position      = {x = 0.79, y = 1.02},
			alignment     = {x = 1,    y = 1},
			scale         = {x = 4,    y = 4},
			text          = "",
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

		wielditem = player:hud_add {
			hud_elem_type = "text",
			position      = {x = 0.5, y = 1},
			offset        = {x = 0,   y = -65 - (i3.modules.hudbars and (ceil(hb.hudbars_count / 2) * 25) or 25)},
			alignment     = {x = 0,   y = -1},
			number        = 0xffffff,
			text          = "",
			z_index       = 0xDEAD,
			style         = 1,
		},
	}
end

local function show_hud(player, data)
	-- It would better to have an engine function `hud_move` to only need
	-- 2 calls for the notification's back and forth.

	local hud_info_bg = player:hud_get(data.hud.bg)
	local dt = 0.016

	if hud_info_bg.position.y <= 0.9 then
		data.show_hud = false
		data.hud_timer = (data.hud_timer or 0) + dt
	end

	player:hud_change(data.hud.text, "text", data.hud_msg)

	if data.hud_img then
		player:hud_change(data.hud.img, "text", data.hud_img)
	end

	if data.show_hud then
		for _, def in pairs(data.hud) do
			local hud_info = player:hud_get(def)

			player:hud_change(def, "position", {
				x = hud_info.position.x,
				y = hud_info.position.y - ((dt / 5) * i3.settings.hud_speed)
			})
		end

	elseif data.show_hud == false then
		if data.hud_timer >= i3.settings.hud_timer_max then
			for _, def in pairs(data.hud) do
				local hud_info = player:hud_get(def)

				player:hud_change(def, "position", {
					x = hud_info.position.x,
					y = hud_info.position.y + ((dt / 5) * i3.settings.hud_speed)
				})
			end

			if hud_info_bg.position.y >= 1 then
				data.show_hud = nil
				data.hud_timer = nil
				data.hud_msg = nil
				data.hud_img = nil
			end
		end
	end
end

core.register_globalstep(function(dt)
	local players = get_connected_players()
	players[0] = #players

	for i = 1, players[0] do
		local player = players[i]
		local name = player:get_player_name()
		local data = i3.data[name]
		if not data then return end

		local function reset()
			player:hud_change(data.hud.wielditem, "text", "")
			data.timer = 0
		end

		if not data.wielditem_hud then
			return reset()
		end

		data.timer = (data.timer or 0) + dt

		local wielditem = player:get_wielded_item()
		local wieldname = wielditem:get_name()

		if wieldname == data.old_wielditem then
			if data.timer >= i3.settings.wielditem_fade_after then
				return reset()
			end
			return
		end

		data.old_wielditem = wieldname

		local meta = wielditem:get_meta()
		local meta_desc = meta:get_string"short_description"
		      meta_desc = meta_desc:gsub("\27", "")
		      meta_desc = core.strip_colors(meta_desc)

		local desc = meta_desc ~= "" and meta_desc or wielditem:get_short_description()

		player:hud_change(data.hud.wielditem, "text", desc:trim())
	end
end)

core.register_globalstep(function()
	local players = get_connected_players()
	players[0] = #players

	for i = 1, players[0] do
		local player = players[i]
		local name = player:get_player_name()
		local data = i3.data[name]

		if data and data.show_hud ~= nil then
			show_hud(player, data)
		end
	end
end)

local function init_waypoints(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	data.waypoints = data.waypoints or {}

	for _, v in ipairs(data.waypoints) do
		if not v.hide then
			local id = add_hud_waypoint(player, v.name, str_to_pos(v.pos), v.color)
			v.id = id
		end
	end
end

return function(player)
	init_hud(player)
	init_waypoints(player)
end
