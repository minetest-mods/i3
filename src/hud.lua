IMPORT("max", "ceil", "remove", "str_to_pos")
IMPORT("get_connected_players", "add_hud_waypoint")

local function init_hud(player)
	local name = player:get_player_name()
	local data = i3.data[name]

	local wdesc_y = -90

	if core.global_exists"hb" then
		wdesc_y -= ceil(hb.hudbars_count / 2) * 5
	elseif not i3.settings.damage_enabled then
		wdesc_y += 15
	end

	data.hud = {
		notifs = {},

		wielditem = player:hud_add {
			hud_elem_type = "text",
			position      = {x = 0.5, y = 1},
			offset        = {x = 0,   y = wdesc_y},
			alignment     = {x = 0,   y = -1},
			number        = 0xffffff,
			text          = "",
			z_index       = 0xDEAD,
			style         = 1,
		}
	}
end

local function get_progress(offset, max_val)
	local progress = offset * (1 / (max_val - 5))
	return 1 - (progress ^ 4)
end

local function show_hud(player, data, notif, idx, dt)
	local hud_info_bg = player:hud_get(notif.elems.bg)
	local offset = hud_info_bg.offset

	if offset.y < notif.max.y then
		notif.show = false
		notif.hud_timer += dt
	end

	player:hud_change(notif.elems.text, "text", notif.hud_msg)

	if notif.hud_img then
		player:hud_change(notif.elems.img, "text", notif.hud_img)
	end

	if notif.show then
		local speed = i3.settings.hud_speed * (100 * get_progress(offset.y, notif.max.y)) * dt

		for _, def in pairs(notif.elems) do
			local hud_info = player:hud_get(def)

			player:hud_change(def, "offset", {
				x = hud_info.offset.x,
				y = hud_info.offset.y - (speed * max(1, (#data.hud.notifs - idx + 1) / 1.45))
			})
		end
	elseif notif.show == false and notif.hud_timer >= i3.settings.hud_timer_max then
		local speed = (i3.settings.hud_speed * 2.6) * (100 * get_progress(offset.x, notif.max.x)) * dt

		for _, def in pairs(notif.elems) do
			local hud_info = player:hud_get(def)

			player:hud_change(def, "offset", {
				x = hud_info.offset.x - speed,
				y = hud_info.offset.y
			})

			if hud_info.offset.x < notif.max.x then
				player:hud_remove(def)
				remove(data.hud.notifs, idx)
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

		for idx, notif in ipairs(data.hud.notifs) do
			if notif.show ~= nil then
				show_hud(player, data, notif, idx, dt)
			end
		end

		local has_text = player:hud_get(data.hud.wielditem).text ~= ""

		if not data.wielditem_hud then
			if has_text then
				player:hud_change(data.hud.wielditem, "text", "")
			end
			return
		end

		data.timer = (data.timer or 0) + dt
		local wieldidx = player:get_wield_index()

		if wieldidx == data.old_wieldidx then
			if data.timer >= i3.settings.wielditem_fade_after and has_text then
				player:hud_change(data.hud.wielditem, "text", "")
			end
			return
		end

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
