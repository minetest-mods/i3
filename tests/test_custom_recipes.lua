local mt = ItemStack("default:wood")
mt:get_meta():set_string("description", "test wood")
mt:get_meta():set_string("color", "green")

local mt2 = ItemStack("dye:red")
mt2:get_meta():set_string("description", "test red")
mt2:get_meta():set_string("color", "#ff0")

local mt3 = ItemStack("default:pick_diamond")
mt3:get_meta():set_string("description", "Worn Pick")
mt3:get_meta():set_string("color", "yellow")
mt3:set_wear(10000)

minetest.register_craft({
	output = mt:to_string(),
	type = "shapeless",
	recipe = {
		"default:wood",
		mt2:to_string(),
	},
})

minetest.register_craft({
	output = mt3:to_string(),
	type = "shapeless",
	recipe = {
		"default:pick_mese",
		"default:diamond",
	},
})

i3.register_craft {
	url = "https://raw.githubusercontent.com/minetest-mods/i3/main/tests/test_online_recipe.json"
}

i3.register_craft({
	result = "default:ladder_wood 2",
	items = {"default:copper_ingot 7, default:tin_ingot, default:steel_ingot 2"},
})

i3.register_craft {
	result = "default:tree",
	items = {
		"default:wood",
		"",
		"default:wood"
	},
}

i3.register_craft {
	result = "default:cobble 16",
	items = {
		"default:stone, default:stone",
		"default:stone,              , default:stone",
		", default:stone, default:stone",
	}
}

i3.register_craft({
	grid = {
		"X",
		"#",
		"X",
		"X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X",
		"#X",
		"X",
		"X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})


i3.register_craft({
	grid = {
		"X#",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X#X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X#XX",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X#XX",
		"X#X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X#XX",
		"X#X",
		"#",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X##XX",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X##X#X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X##X#X",
		"",
		"X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"X  X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass 2",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#X",
		"X  X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"#X#X#",
		"X  X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"#X#X#",
		"X  X##",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})


i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"#X#X#",
		"X  X##",
		" ## ",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"#X#X#",
		"X  X##X",
		" ## ",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"#X#X#",
		"X  X##X#",
		" ## ",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"#X#X#",
		"X  X##X#X",
		" ## ",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})

i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"#X#X#",
		"X  X##X#X",
		" ## ",
		"#X#X#",
		"#X#X#",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})
