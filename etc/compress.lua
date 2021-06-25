local fmt, insert = string.format, table.insert

local wood_types = {
	"acacia_wood", "aspen_wood", "junglewood", "pine_wood",
}

local material_tools = {
	"bronze", "diamond", "mese", "stone", "wood",
}

local material_stairs = {
	"acacia_wood", "aspen_wood", "brick", "bronzeblock", "cobble", "copperblock",
	"desert_cobble", "desert_sandstone", "desert_sandstone_block", "desert_sandstone_brick",
	"desert_stone", "desert_stone_block", "desert_stonebrick",
	"glass", "goldblock", "ice", "junglewood", "mossycobble", "obsidian",
	"obsidian_block", "obsidian_glass", "obsidianbrick", "pine_wood",
	"sandstone", "sandstone_block", "sandstonebrick",
	"silver_sandstone", "silver_sandstone_block", "silver_sandstone_brick",
	"snowblock", "steelblock", "stone", "stone_block", "stonebrick",
	"straw", "tinblock",
}

local colors = {
	"black", "blue", "brown", "cyan", "dark_green", "dark_grey", "green",
	"grey", "magenta", "orange", "pink", "red", "violet", "yellow",
}

local to_compress = {
	["bucket:bucket_empty"] = {
		replace = "empty",
		by = {"lava", "river_water", "water"}
	},

	["default:wood"] = {
		replace = "wood",
		by = wood_types,
	},

	["default:sapling"] = {
		replace = "sapling",
		by = {
			"acacia_bush_sapling",
			"acacia_sapling",
			"aspen_sapling",
			"blueberry_bush_sapling",
			"bush_sapling",
			"emergent_jungle_sapling",
			"junglesapling",
			"pine_bush_sapling",
			"pine_sapling"
		}
	},

	["default:gold_lump"] = {
		replace = "gold",
		by = {"clay", "coal", "copper", "iron", "tin"}
	},

	["default:leaves"] = {
		replace = "leaves",
		by = {
			"acacia_bush_leaves",
			"acacia_leaves",
			"aspen_leaves",
			"blueberry_bush_leaves",
			"blueberry_bush_leaves_with_berries",
			"bush_leaves",
			"jungleleaves",
		},
	},

	["default:stone_with_diamond"] = {
		replace = "diamond",
		by = {"coal", "copper", "gold", "iron", "mese", "tin"},
	},

	["default:fence_wood"] = {
		replace = "wood",
		by = wood_types,
	},

	["default:fence_rail_wood"] = {
		replace = "wood",
		by = wood_types,
	},

	["default:mese_post_light"] = {
		replace = "mese_post_light",
		by = {
			"mese_post_light_acacia",
			"mese_post_light_aspen_wood",
			"mese_post_light_junglewood",
			"mese_post_light_pine_wood",
		}
	},

	["doors:gate_wood_closed"] = {
		replace = "wood",
		by = wood_types,
	},

	["doors:door_wood"] = {
		replace = "wood",
		by = {"glass", "obsidian_glass", "steel"}
	},

	["flowers:geranium"] = {
		replace = "geranium",
		by = {
			"chrysanthemum_green",
			"dandelion_white",
			"dandelion_yellow",
			"rose",
			"tulip",
			"tulip_black",
			"viola",
		}
	},

	["wool:white"] = {
		replace = "white",
		by = colors
	},

	["dye:white"] = {
		replace = "white",
		by = colors
	},

	["default:axe_steel"] = {
		replace = "steel",
		by = material_tools
	},

	["default:pick_steel"] = {
		replace = "steel",
		by = material_tools
	},

	["default:shovel_steel"] = {
		replace = "steel",
		by = material_tools
	},

	["default:sword_steel"] = {
		replace = "steel",
		by = material_tools
	},

	["stairs:slab_wood"] = {
		replace = "wood",
		by = material_stairs
	},

	["stairs:stair_wood"] = {
		replace = "wood",
		by = material_stairs
	},

	["stairs:stair_inner_wood"] = {
		replace = "wood",
		by = material_stairs
	},

	["stairs:stair_outer_wood"] = {
		replace = "wood",
		by = material_stairs
	},
}

local compressed = {}

for k, v in pairs(to_compress) do
	compressed[k] = compressed[k] or {}

	for _, str in ipairs(v.by) do		
		local a, b = k:match("(.*):(.*)")
		local it = fmt("%s:%s", a, b:gsub(v.replace, str))
		insert(compressed[k], it)
	end
end

local _compressed = {}

for _, v in pairs(compressed) do
for _, v2 in ipairs(v) do
	_compressed[v2] = true
end
end

return compressed, _compressed
