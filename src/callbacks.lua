local http, storage = ...
local init_bags = i3.files.bags()
local fill_caches = i3.files.caches(http)
local init_detached = i3.files.detached()
local init_hud = i3.files.hud()
local set_fs = i3.set_fs

IMPORT("slz", "min", "insert", "copy", "ItemStack")
IMPORT("spawn_item", "reset_data", "get_detached_inv", "play_sound", "update_inv_size")

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

	if i3.settings.drop_bag_on_die then
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

if core.global_exists"armor" then
	i3.modules.armor = true

	local group_indexes = {
		{"armor_head",   "i3_heavy_helmet"},
		{"armor_torso",  "i3_heavy_armor"},
		{"armor_legs",   "i3_heavy_leggings"},
		{"armor_feet",   "i3_heavy_boots"},
		{"armor_shield", "i3_heavy_shield"},
	}

	local function check_group(def, group)
		return def.groups[group] and def.groups[group] > 0
	end

	armor:register_on_equip(function(player, idx, stack)
		local _, armor_inv = armor:get_valid_player(player, "3d_armor")
		local def = stack:get_definition()
		local name = player:get_player_name()
		local data = i3.data[name]

		for i, v in ipairs(group_indexes) do
			local group, sound = unpack(v)
			local stackname = stack:get_name()

			if stackname:find"wood" or stackname:find"stone" or stackname:find"cactus" then
				sound = sound:gsub("heavy", "light")
			end

			if i == idx and check_group(def, group) then
				data.armor_allow = sound
				return armor:register_on_update(set_fs)
			end
		end

		data.armor_disallow = true
		armor_inv:remove_item("armor", stack)
	end)

	armor:register_on_update(function(player)
		local _, armor_inv = armor:get_valid_player(player, "3d_armor")
		if not armor_inv then return end

		for i = 1, 5 do
			local stack = armor_inv:get_stack("armor", i)
			local def = stack:get_definition()

			for j, v in ipairs(group_indexes) do
				local group = v[1]

				if check_group(def, group) and i ~= j then
					armor_inv:set_stack("armor", i, armor_inv:get_stack("armor", j))
					armor_inv:set_stack("armor", j, stack)

					return play_sound(player:get_player_name(), "i3_cannot", 0.8)
				end
			end
		end
	end)

	core.register_on_player_inventory_action(function(player, action, _, info)
		if action ~= "take" then return end
		local name = player:get_player_name()
		local data = i3.data[name]

		if data.armor_disallow then
			local inv = player:get_inventory()
			inv:set_stack("main", info.index, info.stack)
			data.armor_disallow = nil
			play_sound(name, "i3_cannot", 0.8)

		elseif data.armor_allow then
			play_sound(name, data.armor_allow, 0.8)
			data.armor_allow = nil
		end
	end)
end

if core.global_exists"skins" then
	i3.modules.skins = true
end

if core.global_exists"awards" then
	i3.modules.awards = true

	core.register_on_craft(function(_, player)
		set_fs(player)
	end)

	core.register_on_dignode(function(_, _, player)
		set_fs(player)
	end)

	core.register_on_placenode(function(_, _, player)
		set_fs(player)
	end)

	core.register_on_chat_message(function(name)
		local player = core.get_player_by_name(name)
		set_fs(player)
	end)
end

local function disable_inventories()
	if rawget(_G, "sfinv") then
		function sfinv.set_player_inventory_formspec() return end
		sfinv.enabled = false
	end

	if rawget(_G, "unified_inventory") then
		function unified_inventory.set_inventory_formspec() return end
	end
end

core.register_on_mods_loaded(function()
	fill_caches()
	disable_inventories()
end)

local function get_lang_code(info)
	return info and info.lang_code
end

local function get_formspec_version(info)
	return info and info.formspec_version or 1
end

local function outdated(name)
	core.show_formspec(name, "i3_outdated",
		("size[6.5,1.3]image[0,0;1,1;i3_book.png]label[1,0;%s]button_exit[2.6,0.8;1,1;;OK]"):format(
		"Your Minetest client is outdated.\nGet the latest version on minetest.net to play the game."))
end

local function init_data(player, info)
	local name = player:get_player_name()
	i3.data[name] = i3.data[name] or {}
	local data = i3.data[name]

	data.player_name     = name
	data.filter          = ""
	data.pagenum         = 1
	data.skin_pagenum    = 1
	data.items           = i3.init_items
	data.items_raw       = i3.init_items
	data.favs            = {}
	data.show_setting    = "home"
	data.ignore_hotbar   = false
	data.auto_sorting    = false
	data.reverse_sorting = false
	data.inv_compress    = true
	data.crafting_counts = {}
	data.sort            = 1
	data.tab             = 1
	data.itab            = 1
	data.subcat          = 1
	data.scrbar_inv      = 0
	data.font_size       = data.font_size or 0
	data.lang_code       = get_lang_code(info)
	data.fs_version      = info.formspec_version

	update_inv_size(player, data)

	core.after(0, set_fs, player)
end

local function save_data(player_name)
	local _data = copy(i3.data)

	for name, v in pairs(_data) do
	for dat in pairs(v) do
		if not i3.saves[dat] then
			_data[name][dat] = nil

			if player_name and i3.data[player_name] then
				i3.data[player_name][dat] = nil -- To free up some memory
			end
		end
	end
	end

	storage:set_string("data", slz(_data))
end

insert(core.registered_on_joinplayers, 1, function(player)
	local name = player:get_player_name()
	local info = core.get_player_information and core.get_player_information(name)

	if not info or get_formspec_version(info) < i3.settings.min_fs_version then
		return outdated(name)
	end

	init_data(player, info)
	init_bags(player)
	init_detached(player)
	init_hud(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	save_data(name)
end)

core.register_on_shutdown(save_data)

local function routine()
	save_data()
	core.after(i3.settings.save_interval, routine)
end

core.after(i3.settings.save_interval, routine)
