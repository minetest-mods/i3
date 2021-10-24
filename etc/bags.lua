local set_fs = i3.files.api()
local S, fmt, msg, spawn_item = i3.need("S", "fmt", "msg", "spawn_item")

local function init_backpack(player)
	local name = player:get_player_name()
	local data = i3.data[name]
	local inv = player:get_inventory()

	inv:set_size("main", data.bag_size and i3.BAG_SIZES[data.bag_size] or i3.INV_SIZE)

	data.bag = core.create_detached_inventory(fmt("%s_backpack", name), {
		allow_put = function(_inv, listname, _, stack)
			local empty = _inv:get_stack(listname, 1):is_empty()
			local item_group = minetest.get_item_group(stack:get_name(), "bag")

			if empty and item_group > 0 and item_group <= #i3.BAG_SIZES then
				return 1
			end

			msg(name, S"This is not a backpack")

			return 0
		end,

		on_put = function(_, _, _, stack)
			local stackname = stack:get_name()
			data.bag_item = stackname
			data.bag_size = minetest.get_item_group(stackname, "bag")

			inv:set_size("main", i3.BAG_SIZES[data.bag_size])
			set_fs(player)
		end,

		on_take = function()
			for i = i3.INV_SIZE + 1, i3.BAG_SIZES[data.bag_size] do
				local stack = inv:get_stack("main", i)

				if not stack:is_empty() then
					spawn_item(player, stack)
				end
			end

			data.bag_item = nil
			data.bag_size = nil

			inv:set_size("main", i3.INV_SIZE)
			set_fs(player)
		end,
	})

	data.bag:set_size("main", 1)

	if data.bag_item then
		data.bag:set_stack("main", 1, data.bag_item)
	end
end

local bag_recipes = {
	small = {
		rcp = {
			{"", "farming:string", ""},
			{"group:wool", "group:wool", "group:wool"},
			{"group:wool", "group:wool", "group:wool"},
		},
		size = 1,
	},
	medium = {
		rcp = {
			{"farming:string", "i3:bag_small", "farming:string"},
			{"farming:string", "i3:bag_small", "farming:string"},
		},
		size = 2,
	},
	large = {
		rcp = {
			{"farming:string", "i3:bag_medium", "farming:string"},
			{"farming:string", "i3:bag_medium", "farming:string"},
		},
		size = 3,
	},
}

for size, item in pairs(bag_recipes) do
	local bagname = fmt("i3:bag_%s", size)

	core.register_craftitem(bagname, {
		description = fmt("%s Backpack", size:gsub("^%l", string.upper)),
		inventory_image = fmt("i3_bag_%s.png", size),
		stack_max = 1,
		groups = {bag = item.size}
	})

	core.register_craft {output = bagname, recipe = item.rcp}
	core.register_craft {type = "fuel", recipe = bagname, burntime = 3}
end

return init_backpack
