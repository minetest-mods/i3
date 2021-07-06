local modpath = core.get_modpath "i3"

local maxn, sort, concat, copy, insert, remove, indexof =
	table.maxn, table.sort, table.concat, table.copy,
	table.insert, table.remove, table.indexof

local sprintf, find, gmatch, match, sub, split, upper, lower =
	string.format, string.find, string.gmatch, string.match,
	string.sub, string.split, string.upper, string.lower

local PNG, styles, fs_elements = loadfile(modpath .. "/etc/styles.lua")()

local ESC = core.formspec_escape
local S = core.get_translator "i3"

local ES = function(...)
	return ESC(S(...))
end

local function fmt(elem, ...)
	if not fs_elements[elem] then
		return sprintf(elem, ...)
	end

	return sprintf(fs_elements[elem], ...)
end

i3.new_tab {
	name = "Skins",
	description = "Skins",
	image = "i3_skin.png",

	formspec = function(player, data, fs)
		--fs("label[3,1;Test 1]")
			local name = player:get_player_name()
			local _skins = skins.get_skinlist_for_player(name)
			local sks = {}
			local yextra = 1

			for _, skin in ipairs(_skins) do
				sks[#sks + 1] = skin.name
			end

			sks = concat(sks, ","):gsub(";", "")

			fs("label", 1, yextra + 0.85, fmt("%s:", ES"Select a skin"))
			fs(fmt("dropdown[1,%f;4,0.6;skins;%s;%u;true]", yextra + 1.1, sks, data.skin_id or 1))
			--core.log("skin: ", dump(skins.get_player_skin(player).name))
	end,
}

