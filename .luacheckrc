allow_defined_top = true

ignore = {
	"631", -- Line is too long.
	"get_debug_grid",
}

read_globals = {
	"minetest",
	"armor",
	"skins",
	"awards",
	"hb",
	"vector",
	"string",
	"table",
	"ItemStack",
	"VoxelArea",
	"VoxelManip",
}

globals = {
	"i3",
	"core",
	"sfinv",
	"unified_inventory",
}

exclude_files = {
	"tests/test_compression.lua",
	"tests/test_custom_recipes.lua",
	"tests/test_operators.lua",
	"tests/test_tabs.lua",
	"tests/test_waypoints.lua",

	".install",
	".luarocks",
}
