-- ****************************************************************************
-- Funnctions and Variables from i3 init.lua
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

local function add_subtitle(fs, name, y, ctn_len, font_size, sep, label)
	fs(fmt("style[%s;font=bold;font_size=%u]", name, font_size))
	fs("button", 0, y, ctn_len, 0.5, name, ESC(label))

	if sep then
		fs("image", 0, y + 0.55, ctn_len, 0.035, PNG.bar)
	end
end

-- ****************************************************************************
-- Function to get detail info aout texture
-- Forked from skinsdb mod
local function get_skin_info_formspec(skin, xoffset, yoffset)
	local texture = skin:get_texture()
	local m_name = skin:get_meta_string("name")
	local m_author = skin:get_meta_string("author")
	local m_license = skin:get_meta_string("license")
	local m_format = skin:get_meta("format")
	-- overview page
	local raw_size = m_format == "1.8" and "2,2" or "2,1"

	--local lxoffs = 0.8 + xoffset
	local cxoffs = 2 + xoffset
	local rxoffs = 2 + xoffset

	local formspec = "" -- = "image["..lxoffs..","..0.6 + yoffset..";1,2;"..minetest.formspec_escape(skin:get_preview()).."]"
	if texture then
		formspec = formspec.."label["..rxoffs..","..2 + yoffset..";"..S("Raw texture")..":]"
		.."image["..1 + rxoffs..","..2.5 + yoffset..";"..raw_size..";"..texture.."]"
	end
	if m_name ~= "" then
		formspec = formspec.."label["..cxoffs..","..0.5 + yoffset..";"..S("Name")..": "..minetest.formspec_escape(m_name).."]"
	end
	if m_author ~= "" then
		formspec = formspec.."label["..cxoffs..","..1 + yoffset..";"..S("Author")..": "..minetest.formspec_escape(m_author).."]"
	end
	if m_license ~= "" then
		formspec = formspec.."label["..cxoffs..","..1.5 + yoffset..";"..S("License")..": "..minetest.formspec_escape(m_license).."]"
	end
	return formspec
end

local function get_skin_selection_formspec(player, context)
	context.skins_list = skins.get_skinlist_for_player(player:get_player_name())
	context.total_pages = 1
	local xoffs = 0.8
	local yoffs = 6.5
	local xspc = 1.1
	local yspc = 2.1
	local skinwidth = 1
	local skinheight = 2
	local xscale = 1
	local btn_y = yoffs + 4.5
	local drop_y = yoffs + 4.5
	local btn_width = 1
	local droppos = xoffs + 1.3
	local droplen = 6.2
	local btn_left = droppos - 1
	local btn_right = droppos + droplen
	local maxdisp = 16

	local ctrls_height = 0.5

	for i, skin in ipairs(context.skins_list ) do
		local page = math.floor((i-1) / maxdisp)+1
		skin:set_meta("inv_page", page)
		skin:set_meta("inv_page_index", (i-1)%maxdisp+1)
		context.total_pages = page
	end
	context.skins_page = context.skins_page or skins.get_player_skin(player):get_meta("inv_page") or 1
	context.dropdown_values = nil

	local page = context.skins_page
	local formspec = ""
	
	for i = (page-1)*maxdisp+1, page*maxdisp do
		local skin = context.skins_list[i]
		if not skin then
			break
		end

		local index_p = skin:get_meta("inv_page_index")
		local x = ((index_p-1) % 8) * xspc + xoffs
		local y
		if index_p > 8 then
			y = yoffs + yspc
		else
			y = yoffs
		end
		formspec = formspec..
			string.format("image_button[%f,%f;%f,%f;%s;skins_set$%i;]",
				x, y, skinwidth, skinheight,
				minetest.formspec_escape(skin:get_preview()), i)..
			"tooltip[skins_set$"..i..";"..minetest.formspec_escape(skin:get_meta_string("name")).."]"
	end
	
		if context.total_pages > 1 then
			local page_prev = page - 1
			local page_next = page + 1
			if page_prev < 1 then
				page_prev = context.total_pages
			end
			if page_next > context.total_pages then
				page_next = 1
			end
			local page_list = ""
			context.dropdown_values = {}
			for pg=1, context.total_pages do
				local pagename = S("Page").." "..pg.."/"..context.total_pages
				context.dropdown_values[pagename] = pg
				if pg > 1 then page_list = page_list.."," end
				page_list = page_list..pagename
			end
			formspec = formspec..
				string.format("button[%f,%f;%f,%f;skins_page$%i;<<]",
					btn_left, btn_y, btn_width, ctrls_height, page_prev)..
				string.format("button[%f,%f;%f,%f;skins_page$%i;>>]",
					btn_right, btn_y, btn_width, ctrls_height, page_next)..
				string.format("dropdown[%f,%f;%f,%f;skins_selpg;%s;%i]",
					droppos, drop_y, droplen, ctrls_height, page_list, page)
		end
		return formspec
end
	
-- ****************************************************************************
-- i3 Tab definition

i3.new_tab {
	name = "Skins",
	description = "Skins",
	image = "i3_skin.png",
	
	formspec = function(player, data, fs)
		--fs("label[3,1;Test 1]")
			local name = player:get_player_name()
			
			local ctn_len, ctn_hgt = 5.7, 6.3
			
			local yextra = 1
			local yoffset = 0
			local xpos = 5

			local _skins = skins.get_skinlist_for_player(name)
			local skin_name = skins.get_player_skin(player).name
			local sks, id = {}, 1
			
			local props = player:get_properties()

			for i, skin in ipairs(_skins) do
				if skin.name == skin_name then
					id = i
				end

				sks[#sks + 1] = skin.name
			end

			sks = concat(sks, ","):gsub(";", "")

			add_subtitle(fs, "player_name", 0, ctn_len + 4.5, 22, true, ESC(name))
			
			if props.mesh ~= "" then
				local anim = player:get_local_animation()
				local armor_skin = __3darmor or __skinsdb
				local t = {}

				for _, v in ipairs(props.textures) do
					t[#t + 1] = ESC(v):gsub(",", "!")
				end

				local textures = concat(t, ","):gsub("!", ",")
				local skinxoffset = 1.3

				--fs("style[player_model;bgcolor=black]")
				fs("model", skinxoffset, 0.2, armor_skin and 4 or 3.4, ctn_hgt,
					"player_model", props.mesh, textures, "0,-150", "false", "false",
					fmt("%u,%u%s", anim.x, anim.y, data.fs_version >= 5 and ";30" or ""))
			else
				local size = 2.5
				fs("image", 0.7, 0.2, size, size * props.visual_size.y, props.textures[1])
			end
			
			fs("label", xpos, yextra, fmt("%s:", ES"Select a skin"))
			fs(fmt("dropdown[%f,%f;4,0.6;skins;%s;%u;true]", xpos, yextra + 0.2, sks, id))
			
			local skin = skins.get_player_skin(player)
			local formspec = get_skin_info_formspec(skin, 3, 2)
			fs(formspec)
			--core.log("fs skins: "..dump(formspec))
			
			local context = skins.get_formspec_context(player)
			local formspec = get_skin_selection_formspec(player, context)
			--core.log("skins context: "..dump(context))
			--core.log("fs skins: "..dump(formspec))
			fs(formspec)
	end,
	
	fields = function(player, data, fields)
	 	local name = player:get_player_name()
		local sb_inv = fields.scrbar_inv
		
		core.log("fields: "..dump(fields))
		
		if fields.skins then
			local id = tonumber(fields.skins)
			local _skins = skins.get_skinlist_for_player(name)
			skins.set_player_skin(player, _skins[id])
		end
		return i3.set_fs(player)
	end,
}

-- ****************************************************************************
