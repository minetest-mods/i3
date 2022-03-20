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

i3.new_tab("test_creative", {
	description = "Test creative",

	access = function(player, data)
		local name = player:get_player_name()
		return core.is_creative_enabled(name)
	end,

	formspec = function(player, data, fs)
		fs("label[3,1;Creative enabled]")
	end,

	fields = i3.set_fs,
})

