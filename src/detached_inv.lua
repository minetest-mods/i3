local set_fs = i3.set_fs
IMPORT("fmt", "play_sound", "create_inventory")

local trash = create_inventory("i3_trash", {
	allow_put = function(_, _, _, stack)
		return stack:get_count()
	end,

	on_put = function(inv, listname, _, _, player)
		inv:set_list(listname, {})

		local name = player:get_player_name()
		play_sound(name, "i3_trash", 1.0)

		if not core.is_creative_enabled(name) then
			set_fs(player)
		end
	end,
})

trash:set_size("main", 1)

local function init_detached(player)
	local name = player:get_player_name()

	local output_rcp = create_inventory(fmt("i3_output_rcp_%s", name), {}, name)
	output_rcp:set_size("main", 1)

	local output_usg = create_inventory(fmt("i3_output_usg_%s", name), {}, name)
	output_usg:set_size("main", 1)
end

return init_detached
