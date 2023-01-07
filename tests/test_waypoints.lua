core.after(5, function()
	i3.add_waypoint("Test", {
		player = "singleplayer",
		pos = {x = 0, y = 2, z = 0},
		color = 0xffff00,
	--	image = "heart.png",
	})

	core.after(5, function()
		i3.remove_waypoint("singleplayer", "Test")
	end)
end)
