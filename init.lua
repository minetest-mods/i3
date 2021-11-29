local modpath = core.get_modpath"i3"
local _loadfile = dofile(modpath .. "/src/operators.lua")

local function lf(path)
	return _loadfile(modpath .. path)
end

i3 = {
	modules = {},
	http = core.request_http_api(),

	MAX_FAVS = 6,
	INV_SIZE = 4*9,
	HOTBAR_LEN = 9,
	ITEM_BTN_SIZE = 1.1,
	DROP_BAG_ON_DIE = true,
	MIN_FORMSPEC_VERSION = 4,
	SAVE_INTERVAL = 600, -- Player data save interval (in seconds)

	HUD_TIMER_MAX = 1.5,
	HUD_SPEED = 1,

	SUBCAT = {
		"bag",
		"armor",
		"skins",
		"awards",
		"waypoints",
	},

	META_SAVES = {
		bag = true,
		home = true,
		waypoints = true,
		inv_items = true,
		drop_items = true,
		known_recipes = true,
	},

	-- Caches
	init_items = {},
	fuel_cache = {},
	usages_cache = {},
	recipes_cache = {},
	cubes = {},

	tabs = {},
	craft_types = {},

	recipe_filters = {},
	search_filters = {},
	sorting_methods = {},

	files = {
		api = lf"/src/api.lua",
		bags = lf"/src/bags.lua",
		caches = lf"/src/caches.lua",
		callbacks = lf"/src/callbacks.lua",
		common = lf"/src/common.lua",
		compress = lf"/src/compress.lua",
		detached = lf"/src/detached_inv.lua",
		groups = lf"/src/groups.lua",
		gui = lf"/src/gui.lua",
		hud = lf"/src/hud.lua",
		model_alias = lf"/src/model_aliases.lua",
		progressive = lf"/src/progressive.lua",
		styles = lf"/src/styles.lua",

		tests = {
			tabs = lf"/tests/test_tabs.lua",
			operators = lf"/tests/test_operators.lua",
			compression = lf"/tests/test_compression.lua",
			custom_recipes = lf"/tests/test_custom_recipes.lua",
		}
	},

	progressive_mode = core.settings:get_bool"i3_progressive_mode",
	item_compression = core.settings:get_bool("i3_item_compression", true),
}

i3.files.common()
i3.files.api()
i3.files.compress()
i3.files.groups()
i3.files.callbacks()

local storage = core.get_mod_storage()
local slz, dslz, copy = i3.get("slz", "dslz", "copy")
local set_fs = i3.set_fs

i3.data = dslz(storage:get_string"data") or {}

local init_bags = i3.files.bags()
local init_detached = i3.files.detached()
local fill_caches = i3.files.caches()
local init_hud = i3.files.hud()

local function get_lang_code(info)
	return info and info.lang_code
end

local function get_formspec_version(info)
	return info and info.formspec_version or 1
end

local function outdated(name)
	local fs = ("size[6.3,1.3]image[0,0;1,1;i3_book.png]label[1,0;%s]button_exit[2.6,0.8;1,1;;OK]"):format(
		"Your Minetest client is outdated.\nGet the latest version on minetest.net to play the game.")

	core.show_formspec(name, "i3_outdated", fs)
end

if rawget(_G, "armor") then
	i3.modules.armor = true
	armor:register_on_update(set_fs)
end

if rawget(_G, "skins") then
	i3.modules.skins = true
end

if rawget(_G, "awards") then
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

local function init_data(player, info)
	local name = player:get_player_name()
	i3.data[name] = i3.data[name] or {}
	local data = i3.data[name]

	data.player_name     = name
	data.filter          = ""
	data.pagenum         = 1
	data.items           = i3.init_items
	data.items_raw       = i3.init_items
	data.favs            = {}
	data.sort            = "alphabetical"
	data.show_setting    = "home"
	data.ignore_hotbar   = false
	data.auto_sorting    = false
	data.reverse_sorting = false
	data.inv_compress    = true
	data.export_counts   = {}
	data.tab             = 1
	data.itab            = 1
	data.subcat          = 1
	data.scrbar_inv      = 0
	data.lang_code       = get_lang_code(info)
	data.fs_version      = info.formspec_version

	local inv = player:get_inventory()
	inv:set_size("main", i3.INV_SIZE)

	core.after(0, set_fs, player)
end

local function save_data(player_name)
	local _data = copy(i3.data)

	for name, v in pairs(_data) do
	for dat in pairs(v) do
		if not i3.META_SAVES[dat] then
			_data[name][dat] = nil

			if player_name and i3.data[player_name] then
				i3.data[player_name][dat] = nil -- To free up some memory
			end
		end
	end
	end

	storage:set_string("data", slz(_data))
end

core.register_on_mods_loaded(function()
	fill_caches()
	disable_inventories()
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local info = core.get_player_information and core.get_player_information(name)

	if not info or get_formspec_version(info) < i3.MIN_FORMSPEC_VERSION then
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
	core.after(i3.SAVE_INTERVAL, routine)
end

core.after(i3.SAVE_INTERVAL, routine)

if i3.progressive_mode then
	i3.files.progressive()
end

--i3.files.tests.tabs()
--i3.files.tests.operators()
--i3.files.tests.compression()
--i3.files.tests.custom_recipes()
