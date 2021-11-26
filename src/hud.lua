local get_player_by_name = i3.get("get_player_by_name")

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
	}

	core.after(0, function()
		player:hud_set_hotbar_itemcount(i3.HOTBAR_LEN)
		player:hud_set_hotbar_image"i3_hotbar.png"
	end)
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
				y = hud_info.position.y - ((dt / 5) * i3.HUD_SPEED)
			})
		end

	elseif data.show_hud == false then
		if data.hud_timer >= i3.HUD_TIMER_MAX then
			for _, def in pairs(data.hud) do
				local hud_info = player:hud_get(def)

				player:hud_change(def, "position", {
					x = hud_info.position.x,
					y = hud_info.position.y + ((dt / 5) * i3.HUD_SPEED)
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

core.register_globalstep(function()
	for name, data in pairs(i3.data) do
		if data.show_hud ~= nil then
			local player = get_player_by_name(name)
			show_hud(player, data)
		end
	end
end)

return init_hud
