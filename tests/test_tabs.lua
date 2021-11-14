i3.new_tab("test1", {
	description = "Test 1 Test 1",
	image = "i3_heart.png",

	formspec = function(player, data, fs)
		fs("label[3,1;Test 1]")
	end,
})

i3.new_tab("test2", {
	description = "Test 2",
	image = "i3_mesepick.png",

	formspec = function(player, data, fs)
		fs("label[3,1;Test 2]")
	end,
})

i3.new_tab("test3", {
	description = "Test 3",

	access = function(player, data)
		local name = player:get_player_name()
		if name == "singleplayer" then
			return true
		end
	end,

	formspec = function(player, data, fs)
		fs("label[3,1;Test 3]")
	end,

	fields = function(player, data, fields)
		i3.set_fs(player, "label[3,2;Test extra_fs]")
	end,
})

i3.override_tab("test2", {
	description = "Test override",
	image = "i3_mesepick.png",

	formspec = function(player, data, fs)
		fs("label[3,1;Override!]")
	end,
})
