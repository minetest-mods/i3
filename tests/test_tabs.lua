local SWITCH

i3.new_tab("test1", {
	description = "Test 1 Test 1",
	image = "i3_heart.png",

	formspec = function(player, data, fs)
		fs("button", 3, 4, 3, 0.8, "test", "Click here")
		fs("label", 3, 1, "Just a test")
		

		if SWITCH then
			fs"label[3,2;Button clicked]"
		else
			fs"label[3,2;Lorem Ipsum]"
		end
	end,

	fields = function(player, data, fields)
		if fields.test then
			SWITCH = true
		end
	end
})

i3.new_tab("test2", {
	description = "Test 2",
	image = "i3_mesepick.png",
	slots = true,

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

