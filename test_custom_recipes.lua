local mt = ItemStack("default:wood")
mt:get_meta():set_string("description", "test wood")
mt:get_meta():set_string("color", "#000")

local mt2 = ItemStack("dye:red")
mt2:get_meta():set_string("description", "test red")
mt2:get_meta():set_string("color", "#ff0")

minetest.register_craft({
	output = mt:to_string(),
	type = "shapeless",
	recipe = {
		"default:wood",
		mt2:to_string(),
	},
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
		"X  #",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})
