print[[

	Powered by

	██╗██████╗
	██║╚════██╗
	██║ █████╔╝
	██║ ╚═══██╗
	██║██████╔╝
	╚═╝╚═════╝
]]

local modpath = core.get_modpath"i3"
local http = core.request_http_api()
local storage = core.get_mod_storage()
local _loadfile = dofile(modpath .. "/src/preprocessor.lua")

local function lf(path)
	return assert(_loadfile(modpath .. path))
end

i3 = {
	version = 174,
	data = core.deserialize(storage:get_string"data") or {},

	settings = {
		debug_mode = false,
		max_favs = 6,
		max_waypoints = 30,
		min_fs_version = 4,
		item_btn_size = 1.1,
		drop_bag_on_die = true,
		save_interval = 600, -- Player data save interval (in seconds)

		hud_speed = 1,
		hud_timer_max = 1.5,

		damage_enabled   = core.settings:get_bool"enable_damage",
		progressive_mode = core.settings:get_bool"i3_progressive_mode",
		legacy_inventory = core.settings:get_bool"i3_legacy_inventory",
		item_compression = core.settings:get_bool("i3_item_compression", true),
	},

	categories = {
		"bag",
		"armor",
		"skins",
		"awards",
		"waypoints",
	},

	saves = { -- Metadata to save
		bag = true,
		home = true,
		waypoints = true,
		inv_items = true,
		drop_items = true,
		known_recipes = true,
	},

	files = {
		api = lf"/src/api.lua",
		bags = lf"/src/bags.lua",
		caches = lf"/src/caches.lua",
		callbacks = lf"/src/callbacks.lua",
		common = lf"/src/common.lua",
		compress = lf"/src/compression.lua",
		detached = lf"/src/detached_inv.lua",
		fields = lf"/src/fields.lua",
		groups = lf"/src/groups.lua",
		gui = lf"/src/gui.lua",
		hud = lf"/src/hud.lua",
		model_alias = lf"/src/model_aliases.lua",
		progressive = lf"/src/progressive.lua",
		styles = lf"/src/styles.lua",
	},

	-- Caches
	init_items = {},
	fuel_cache = {},
	usages_cache = {},
	recipes_cache = {},

	tabs = {},
	cubes = {},
	groups = {},
	plants = {},
	modules = {},
	craft_types = {},

	recipe_filters = {},
	search_filters = {},
	sorting_methods = {},
}

i3.settings.hotbar_len = i3.settings.legacy_inventory and 8 or 9
i3.settings.inv_size   = 4 * i3.settings.hotbar_len

i3.files.common()
i3.files.api(http)
i3.files.compress()
i3.files.groups()
i3.files.callbacks(http, storage)

if i3.settings.progressive_mode then
	i3.files.progressive()
end

if i3.settings.debug_mode then
	lf("/tests/test_tabs.lua")()
	lf("/tests/test_operators.lua")()
	lf("/tests/test_compression.lua")()
	lf("/tests/test_custom_recipes.lua")()
end
