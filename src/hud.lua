IMPORT("ceil", "get_connected_players", "str_to_pos", "add_hud_waypoint")

local function init_hud(player)
	local name = player:get_player_name()
	local data = i3.data[name]

	local wdesc_y = -90

	if core.global_exists"hb" then
		wdesc_y = wdesc_y - ceil(hb.hudbars_count / 2) * 5
	elseif not i3.settings.damage_enabled then
		wdesc_y = wdesc_y + 15
	end

	data.hud = {
		bg = player:hud_add {
			hud_elem_type = "image",
			position      = {x = 1,    y = 1},
			offset        = {x = -320, y = 0},
			alignment     = {x = 1,    y = 1},
			scale         = {x = 300,  y = 105},
			text          = "i3_bg.png",
			z_index       = 0xDEAD,
		},

		img = player:hud_add {
			hud_elem_type = "image",
			position      = {x = 1,    y = 1},
			offset        = {x = -310, y = 20},
			alignment     = {x = 1,    y = 1},
			scale         = {x = 1,    y = 1},
			text          = "",
			z_index       = 0xDEAD,
		},

		text = player:hud_add {
			hud_elem_type = "text",
			position      = {x = 1,    y = 1},
			offset        = {x = -235, y = 40},
			alignment     = {x = 1,    y = 1},
			number        = 0xffffff,
			text          = "",
			z_index       = 0xDEAD,
			style         = 1,
		},

		wielditem = player:hud_add {
			hud_elem_type = "text",
			position      = {x = 0.5, y = 1},
			offset        = {x = 0,   y = wdesc_y},
			alignment     = {x = 0,   y = -1},
			number        = 0xffffff,
			text          = "",
			z_index       = 0xDEAD,
			style         = 1,
		},
	}
end

local function show_hud(player, data)
	local hud_info_bg = player:hud_get(data.hud.bg)
	local dt = 0.016
	local offset_y = hud_info_bg.offset.y
	local speed = 5 * i3.settings.hud_speed

	if offset_y < -100 then
		data.show_hud = false
		data.hud_timer = (data.hud_timer or 0) + dt
	end

	if data.hud_msg then
		player:hud_change(data.hud.text, "text", data.hud_msg)
	end
	
	if data.hud_img then
		player:hud_change(data.hud.img, "text", data.hud_img)
	end

	if data.show_hud then
		for name, def in pairs(data.hud) do
			if name ~= "wielditem" then
				local hud_info = player:hud_get(def)

				player:hud_change(def, "offset", {
					x = hud_info.offset.x,
					y = hud_info.offset.y - speed
				})
			end
		end
	elseif data.show_hud == false then
		if data.hud_timer >= i3.settings.hud_timer_max then
			for name, def in pairs(data.hud) do
				if name ~= "wielditem" then
					local hud_info = player:hud_get(def)

					player:hud_change(def, "offset", {
						x = hud_info.offset.x,
						y = hud_info.offset.y + speed
					})
				end
			end

			if offset_y > 0 then
				data.show_hud  = nil
				data.hud_timer = nil
				data.hud_msg   = nil
				data.hud_img   = nil
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
		
		if data and data.show_hud ~= nil then
			show_hud(player, data)
		end
		
		-- If wielditem hud desactivated
		if not data.wielditem_hud then
			-- If was activated before, reset
			if data.old_wieldidx then
				player:hud_change(data.hud.wielditem, "text", "")
				data.old_wieldidx = nil
			end
			return
		end

		data.timer = (data.timer or 0)
		local wieldidx = player:get_wield_index()

		-- No change, test if fade needed
		if wieldidx == data.old_wieldidx then
			-- Increase timer for fading
			if data.timer < i3.settings.wielditem_fade_after then
				data.timer = data.timer + dt
				
				-- Reset if timer after
				if data.timer >= i3.settings.wielditem_fade_after then
					player:hud_change(data.hud.wielditem, "text", "")
				end
			end
			return
		end
		
		-- Wielditem have changed, need update
		data.timer = 0
		data.old_wieldidx = wieldidx

		local wielditem = player:get_wielded_item()
		local meta = wielditem:get_meta()

		local meta_desc = meta:get_string"short_description"
		      meta_desc = meta_desc:gsub("\27", "")
		      meta_desc = core.strip_colors(meta_desc)

		local desc = meta_desc ~= "" and meta_desc or wielditem:get_short_description()
		player:hud_change(data.hud.wielditem, "text", desc:trim())
	end
end)


local function init_waypoints(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	data.waypoints = data.waypoints or {}

	for _, v in ipairs(data.waypoints) do
		if not v.hide then
			local id = add_hud_waypoint(player, v.name, str_to_pos(v.pos), v.color, v.image)
			v.id = id
		end
	end
end

return function(player)
	init_hud(player)
	init_waypoints(player)
end
