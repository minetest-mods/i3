local modpath = core.get_modpath "i3"

local function lf(path)
	return loadfile(modpath .. path)
end

i3 = {
	modules = {},
	http = core.request_http_api(),

	MAX_FAVS = 6,
	INV_SIZE = 4*9,
	HOTBAR_LEN = 9,
	ITEM_BTN_SIZE = 1.1,
	MIN_FORMSPEC_VERSION = 4,
	SAVE_INTERVAL = 600, -- Player data save interval (in seconds)

	BAG_SIZES = {
		4*9 + 3,
		4*9 + 6,
		4*9 + 9,
	},

	SUBCAT = {
		"bag",
		"armor",
		"skins",
		"awards",
		"waypoints",
	},

	META_SAVES = {
		bag_item = true,
		bag_size = true,
		waypoints = true,
		inv_items = true,
		known_recipes = true,
	},

	-- Caches
	init_items     = {},
	recipes_cache  = {},
	usages_cache   = {},
	fuel_cache     = {},
	recipe_filters = {},
	search_filters = {},
	craft_types    = {},
	tabs           = {},

	files = {
		api = lf("/etc/api.lua"),
		bags = lf("/etc/bags.lua"),
		common = lf("/etc/common.lua"),
		compress = lf("/etc/compress.lua"),
		groups = lf("/etc/groups.lua"),
		gui = lf("/etc/gui.lua"),
		inventory = lf("/etc/inventory.lua"),
		model_alias = lf("/etc/model_aliases.lua"),
		progressive = lf("/etc/progressive.lua"),
		recipes = lf("/etc/recipes.lua"),
		styles = lf("/etc/styles.lua"),
	},

	progressive_mode = core.settings:get_bool "i3_progressive_mode",
	item_compression = core.settings:get_bool("i3_item_compression", true),
}

local common = i3.files.common()

function i3.need(...)
	local t = {}

	for _, var in ipairs {...} do
		for name, func in pairs(common) do
			if var == name then
				t[#t + 1] = func
				break
			end
		end
	end

	return unpack(t)
end

local storage = core.get_mod_storage()
local slz, dslz = core.serialize, core.deserialize

i3.data = dslz(storage:get_string "data") or {}
i3.compress_groups, i3.compressed = i3.files.compress()
i3.group_stereotypes, i3.group_names = i3.files.groups()

local set_fs = i3.files.api()
local init_backpack = i3.files.bags()
i3.files.inventory()
local cache_drops, cache_fuel, cache_recipes, cache_usages, resolve_aliases = i3.files.recipes()

local fmt, sort, copy = i3.need("fmt", "sort", "copy")
local show_item, reg_items = i3.need("show_item", "reg_items")

local function get_lang_code(info)
	return info and info.lang_code
end

local function get_formspec_version(info)
	return info and info.formspec_version or 1
end

local function outdated(name)
	local fs = fmt("size[6.3,1.3]image[0,0;1,1;i3_book.png]label[1,0;%s]button_exit[2.6,0.8;1,1;;OK]",
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

local function get_init_items()
	local _select, _preselect = {}, {}

	for name, def in pairs(reg_items) do
		if name ~= "" and show_item(def) then
			cache_drops(name, def.drop)
			cache_fuel(name)
			cache_recipes(name)

			_preselect[name] = true
		end
	end

	for name in pairs(_preselect) do
		cache_usages(name)

		i3.init_items[#i3.init_items + 1] = name
		_select[name] = true
	end

	resolve_aliases(_select)
	sort(i3.init_items)

	if i3.http and type(i3.export_url) == "string" then
		local post_data = {
			recipes = i3.recipes_cache,
			usages  = i3.usages_cache,
		}

		i3.http.fetch_async {
			url = i3.export_url,
			post_data = core.write_json(post_data),
		}
	end
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

	data.filter        = ""
	data.pagenum       = 1
	data.items         = i3.init_items
	data.items_raw     = i3.init_items
	data.favs          = {}
	data.export_counts = {}
	data.current_tab   = 1
	data.current_itab  = 1
	data.subcat        = 1
	data.scrbar_inv    = 0
	data.lang_code     = get_lang_code(info)
	data.fs_version    = info.formspec_version

	core.after(0, set_fs, player)
end

local function init_waypoints(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	data.waypoints = data.waypoints or {}

	for _, v in ipairs(data.waypoints) do
		if not v.hide then
			local id = player:hud_add {
				hud_elem_type = "waypoint",
				name = v.name,
				text = " m",
				world_pos = v.pos,
				number = v.color,
				z_index = -300,
			}

			v.id = id
		end
	end
end

local function init_hudbar(player)
	core.after(0, function()
		player:hud_set_hotbar_itemcount(i3.HOTBAR_LEN)
		player:hud_set_hotbar_image("i3_hotbar.png")
	end)
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
	get_init_items()
	disable_inventories()
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local info = core.get_player_information and core.get_player_information(name)

	if not info or get_formspec_version(info) < i3.MIN_FORMSPEC_VERSION then
		i3.data[name] = nil
		return outdated(name)
	end

	init_data(player, info)
	init_backpack(player)
	init_waypoints(player)
	init_hudbar(player)
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

--dofile(modpath .. "/tests/test_tabs.lua")
--dofile(modpath .. "/tests/test_compression.lua")
--dofile(modpath .. "/tests/test_custom_recipes.lua")
