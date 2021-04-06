minetest.register_craft({
	output = minetest.itemstring_with_palette("default:wood", 3),
	type = "shapeless",
	recipe = {
		"default:wood",
		"dye:red",
	},
})

i3.register_craft({
	result = "default:ladder_wood",
	items = {"default:copper_ingot 7, default:tin_ingot, default:steel_ingot 2"},
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
