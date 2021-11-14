local make_fs = i3.files.gui()

local gmatch, match, split = i3.get("gmatch", "match", "split")
local S, err, fmt, reg_items = i3.get("S", "err", "fmt", "reg_items")
local sorter, sort_inventory = i3.get("sorter", "sort_inventory")
local sort, concat, copy, insert, remove = i3.get("sort", "concat", "copy", "insert", "remove")
local true_str, true_table, is_str, is_func, is_table, clean_name =
	i3.get("true_str", "true_table", "is_str", "is_func", "is_table", "clean_name")

function i3.register_craft_type(name, def)
	if not true_str(name) then
		return err "i3.register_craft_type: name missing"
	elseif not true_table(def) then
		return err "i3.register_craft_type: definition missing"
	elseif not is_str(def.description) then
		def.description = ""
	end

	i3.craft_types[name] = def
end

function i3.register_craft(def)
	local width, c = 0, 0

	if true_str(def.url) then
		if not i3.http then
			return err(fmt([[i3.register_craft(): Unable to reach %s.
				No HTTP support for this mod: add it to the `secure.http_mods` or
				`secure.trusted_mods` setting.]], def.url))
		end

		i3.http.fetch({url = def.url}, function(result)
			if result.succeeded then
				local t = core.parse_json(result.data)
				if is_table(t) then
					return i3.register_craft(t)
				end
			end
		end)

		return
	end

	if not true_table(def) then
		return err "i3.register_craft: craft definition missing"
	end

	if #def > 1 then
		for _, v in pairs(def) do
			i3.register_craft(v)
		end
		return
	end

	if def.result then
		def.output = def.result -- Backward compatibility
		def.result = nil
	end

	if not true_str(def.output) then
		return err "i3.register_craft: output missing"
	end

	if not is_table(def.items) then
		def.items = {}
	end

	if def.grid then
		if not is_table(def.grid) then
			def.grid = {}
		end

		if not is_table(def.key) then
			def.key = {}
		end

		local cp = copy(def.grid)
		sort(cp, function(a, b)
			return #a > #b
		end)

		width = #cp[1]

		for i = 1, #def.grid do
			while #def.grid[i] < width do
				def.grid[i] = def.grid[i] .. " "
			end
		end

		for symbol in gmatch(concat(def.grid), ".") do
			c = c + 1
			def.items[c] = def.key[symbol]
		end
	else
		local items, len = def.items, #def.items
		def.items = {}

		for i = 1, len do
			local rlen = #split(items[i], ",")

			if rlen > width then
				width = rlen
			end
		end

		for i = 1, len do
			while #split(items[i], ",") < width do
				items[i] = fmt("%s,", items[i])
			end
		end

		for name in gmatch(concat(items, ","), "[%s%w_:]+") do
			c = c + 1
			def.items[c] = clean_name(name)
		end
	end

	local item = match(def.output, "%S+")
	i3.recipes_cache[item] = i3.recipes_cache[item] or {}

	def.custom = true
	def.width = width

	insert(i3.recipes_cache[item], def)
end

function i3.add_recipe_filter(name, f)
	if not true_str(name) then
		return err "i3.add_recipe_filter: name missing"
	elseif not is_func(f) then
		return err "i3.add_recipe_filter: function missing"
	end

	i3.recipe_filters[name] = f
end

function i3.set_recipe_filter(name, f)
	if not is_str(name) then
		return err "i3.set_recipe_filter: name missing"
	elseif not is_func(f) then
		return err "i3.set_recipe_filter: function missing"
	end

	i3.recipe_filters = {[name] = f}
end

function i3.add_search_filter(name, f)
	if not true_str(name) then
		return err "i3.add_search_filter: name missing"
	elseif not is_func(f) then
		return err "i3.add_search_filter: function missing"
	end

	i3.search_filters[name] = f
end

function i3.get_recipes(item)
	return {
		recipes = i3.recipes_cache[item],
		usages = i3.usages_cache[item]
	}
end

function i3.set_fs(player)
	if not player or player.is_fake_player then return end
	local name = player:get_player_name()
	local data = i3.data[name]
	if not data then return end

	if data.auto_sorting then
		sort_inventory(player, data)
	end

	local fs = make_fs(player, data)
	player:set_inventory_formspec(fs)
end

function i3.new_tab(name, def)
	if not true_str(name) then
		return err "i3.new_tab: tab name missing"
	elseif not true_table(def) then
		return err "i3.new_tab: tab definition missing"
	elseif not true_str(def.description) then
		return err "i3.new_tab: description missing"
	elseif #i3.tabs == 6 then
		return err(fmt("i3.new_tab: cannot add '%s' tab. Limit reached (6).", def.name))
	end

	def.name = name
	insert(i3.tabs, def)
end

function i3.remove_tab(name)
	if not true_str(name) then
		return err "i3.remove_tab: tab name missing"
	end

	for i, def in ipairs(i3.tabs) do
		if name == def.name then
			remove(i3.tabs, i)
			break
		end
	end
end

function i3.get_current_tab(player)
	local name = player:get_player_name()
	local data = i3.data[name]

	return data.tab
end

function i3.set_tab(player, tabname)
	local name = player:get_player_name()
	local data = i3.data[name]

	if not tabname or tabname == "" then
		data.tab = 0
		return
	end

	for i, def in ipairs(i3.tabs) do
		if def.name == tabname then
			data.tab = i
			return
		end
	end

	err(fmt("i3.set_tab: tab name '%s' does not exist", tabname))
end

function i3.override_tab(name, newdef)
	if not true_str(name) then
		return err "i3.override_tab: tab name missing"
	elseif not true_table(newdef) then
		return err "i3.override_tab: tab definition missing"
	elseif not true_str(newdef.description) then
		return err "i3.override_tab: description missing"
	end

	newdef.name = name

	for i, def in ipairs(i3.tabs) do
		if def.name == name then
			i3.tabs[i] = newdef
			break
		end
	end
end

i3.register_craft_type("digging", {
	description = S"Digging",
	icon = "i3_steelpick.png",
})

i3.register_craft_type("digging_chance", {
	description = S"Digging (by chance)",
	icon = "i3_mesepick.png",
})

i3.add_search_filter("groups", function(item, groups)
	local def = reg_items[item]
	local has_groups = true

	for _, group in ipairs(groups) do
		if not def.groups[group] then
			has_groups = nil
			break
		end
	end

	return has_groups
end)

function i3.compress(item, def)
	if not true_str(item) then
		return err "i3.compress: item name missing"
	elseif not true_table(def) then
		return err "i3.compress: replace definition missing"
	elseif not true_str(def.replace) then
		return err "i3.compress: replace string missing"
	elseif not is_table(def.by) then
		return err "i3.compress: replace substrings missing"
	elseif i3.compressed[item] then
		return err(fmt("i3.compress: item '%s' is already compressed", item))
	end

	local t = {}
	i3.compress_groups[item] = i3.compress_groups[item] or {}

	for _, str in ipairs(def.by) do
		local it = item:gsub(def.replace, str)

		insert(t, it)
		insert(i3.compress_groups[item], it)

		i3.compressed[it] = true
	end
end

function i3.add_sorting_method(def)
	if not true_table(def) then
		return err "i3.add_sorting_method: definition missing"
	elseif not true_str(def.name) then
		return err "i3.add_sorting_method: name missing"
	elseif not is_func(def.func) then
		return err "i3.add_sorting_method: function missing"
	end

	insert(i3.sorting_methods, def)
end

i3.add_sorting_method {
	name = "alphabetical",
	description = S"Sort items by name (A-Z)",
	func = function(list, data)
		sorter(list, data.reverse_sorting, 1)
		return list
	end
}

i3.add_sorting_method {
	name = "numerical",
	description = S"Sort items by number of items per stack",
	func = function(list, data)
		sorter(list, data.reverse_sorting, 2)
		return list
	end,
}
