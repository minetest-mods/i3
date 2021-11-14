local S, ES, fmt, msg, slz, dslz = i3.get("S", "ES", "fmt", "msg", "slz", "dslz")
local play_sound, create_inventory = i3.get("play_sound", "create_inventory")

local function get_content_inv(name)
	return core.get_inventory {
		type = "detached",
		name = fmt("i3_bag_content_%s", name)
	}
end

local function get_content(content)
	local t = {}

	for i, v in pairs(content) do
		local stack = ItemStack(v.name)

		if v.meta then
			local m = stack:get_meta()
			m:from_table(v.meta)
		end

		if v.wear then
			stack:set_wear(v.wear)
		end

		t[i] = stack
	end

	return t
end

local function safe_format(stack)
	local meta = stack:get_meta():to_table()
	local wear = stack:get_wear()
	local has_meta = next(meta.fields)

	local info = {}
	info.name = fmt("%s %u", stack:get_name(), stack:get_count())

	if has_meta then
		info.meta = meta
	end

	if wear > 0 then
		info.wear = wear
	end

	return info
end

local function init_bags(player)
	local name = player:get_player_name()
	local data = i3.data[name]

	local bag = create_inventory(fmt("i3_bag_%s", name), {
		allow_put = function(inv, _, _, stack)
			local empty = inv:is_empty"main"
			local item_group = core.get_item_group(stack:get_name(), "bag")

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
			data.bag_item = safe_format(stack)
			data.bag_size = core.get_item_group(stack:get_name(), "bag")

			local meta = stack:get_meta()
			local content = dslz(meta:get_string"content")

			if content then
				local inv = get_content_inv(name)
				inv:set_list("main", get_content(content))
			end

			i3.set_fs(player)
		end,

		on_take = function()
			data.bag_item = nil
			data.bag_size = nil

			local content = get_content_inv(name)
			content:set_list("main", {})

			i3.set_fs(player)
		end,
	}, name)

	bag:set_size("main", 1)

	if data.bag_item then
		bag:set_list("main", get_content{data.bag_item})
	end

	local function save_content(inv)
		local bagstack = bag:get_stack("main", 1)
		local meta = bagstack:get_meta()

		if inv:is_empty("main") then
			meta:set_string("description", "")
			meta:set_string("content", "")
		else
			local list = inv:get_list"main"
			local t = {}

			for i = 1, #list do
				local stack = list[i]

				if not stack:is_empty() then
					t[i] = safe_format(stack)
				end
			end

			local function count_items()
				local c = 0

				for _ in pairs(t) do
					c = c + 1
				end

				return c
			end

			local percent = fmt("%.1f", (count_items() * 100) / (data.bag_size * 4))

			meta:set_string("description", "")
			meta:set_string("description", ES("@1 (@2% full)", bagstack:get_description(), percent))
			meta:set_string("content", slz(t))
		end

		bag:set_stack("main", 1, bagstack)
		data.bag_item = safe_format(bagstack)

		i3.set_fs(player)
	end

	local bag_content = create_inventory(fmt("i3_bag_content_%s", name), {
		on_move = save_content,
		on_put = save_content,
		on_take = save_content,
	}, name)

	bag_content:set_size("main", 4*4)

	if data.bag_item then
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
