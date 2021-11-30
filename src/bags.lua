local set_fs = i3.set_fs

IMPORT("get_bag_description", "ItemStack")
IMPORT("S", "ES", "fmt", "msg", "slz", "dslz")
IMPORT("get_group", "play_sound", "get_detached_inv", "create_inventory")

local function get_content(content)
	local t = {}

	for i, v in pairs(content) do
		t[i] = ItemStack(v)
	end

	return t
end

local function init_bags(player)
	local name = player:get_player_name()
	local data = i3.data[name]

	local bag = create_inventory(fmt("i3_bag_%s", name), {
		allow_put = function(inv, _, _, stack)
			local empty = inv:is_empty"main"
			local item_group = get_group(stack:get_name(), "bag")

			if empty and item_group > 0 and item_group <= 4 then
				return 1
			end

			if not empty then
				msg(name, S"There is already a bag")
			else
				msg(name, S"This is not a bag")
			end

			return 0, play_sound(name, "i3_cannot", 0.8)
		end,

		on_put = function(_, _, _, stack)
			data.bag = stack:to_string()

			local meta = stack:get_meta()
			local content = dslz(meta:get_string"content")

			if content then
				local inv = get_detached_inv("bag_content", name)
				inv:set_list("main", get_content(content))
			end

			set_fs(player)
		end,

		on_take = function()
			data.bag = nil
			data.bag_rename = nil

			local content = get_detached_inv("bag_content", name)
			content:set_list("main", {})

			set_fs(player)
		end,
	}, name)

	bag:set_size("main", 1)

	if data.bag then
		bag:set_list("main", get_content{data.bag})
	end

	local function save_content(inv)
		local bagstack = bag:get_stack("main", 1)
		local meta = bagstack:get_meta()
		local desc = get_bag_description(data, bagstack)

		if inv:is_empty"main" then
			meta:set_string("description", desc)
			meta:set_string("content", "")
		else
			local list = inv:get_list"main"
			local t, c = {}, 0

			for i = 1, #list do
				local stack = list[i]

				if not stack:is_empty() then
					c++
					t[i] = stack:to_string()
				end
			end

			local bag_size = get_group(bagstack:get_name(), "bag")
			local percent = fmt("%d", (c * 100) / (bag_size * 4))

			meta:set_string("description", ES("@1 (@2% full)", desc, percent))
			meta:set_string("content", slz(t))
		end

		bag:set_stack("main", 1, bagstack)
		data.bag = bagstack:to_string()

		set_fs(player)
	end

	local bag_content = create_inventory(fmt("i3_bag_content_%s", name), {
		on_move = save_content,
		on_put = save_content,
		on_take = save_content,

		allow_put = function(_, _, _, stack)
			local meta = stack:get_meta()
			local content = dslz(meta:get_string"content")

			if content then
				msg(name, "You cannot put a bag in another bag")
				return 0, play_sound(name, "i3_cannot", 0.8)
			end

			return stack:get_count()
		end,
	}, name)

	bag_content:set_size("main", 4*4)

	if data.bag then
		local meta = bag:get_stack("main", 1):get_meta()
		local content = dslz(meta:get_string"content")

		if content then
			bag_content:set_list("main", get_content(content))
		end
	end
end

local bag_recipes = {
	small = {
		rcp = {
			{"", "farming:string", ""},
			{"group:wool", "group:wool", "group:wool"},
			{"group:wool", "group:wool", "group:wool"},
		},
		size = 2,
	},
	medium = {
		rcp = {
			{"farming:string", "i3:bag_small", "farming:string"},
			{"farming:string", "i3:bag_small", "farming:string"},
		},
		size = 3,
	},
	large = {
		rcp = {
			{"farming:string", "i3:bag_medium", "farming:string"},
			{"farming:string", "i3:bag_medium", "farming:string"},
		},
		size = 4,
	},
}

for size, item in pairs(bag_recipes) do
	local bagname = fmt("i3:bag_%s", size)

	core.register_craftitem(bagname, {
		description = fmt("%s Backpack", size:gsub("^%l", string.upper)),
		inventory_image = fmt("i3_bag_%s.png", size),
		groups = {bag = item.size},
		stack_max = 1,
	})

	core.register_craft{output = bagname, recipe = item.rcp}
	core.register_craft{type = "fuel", recipe = bagname, burntime = 3}
end

return init_bags
