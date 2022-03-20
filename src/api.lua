local http = ...
local make_fs, get_inventory_fs = i3.files.gui()

IMPORT("gmatch", "split")
IMPORT("S", "err", "fmt", "reg_items")
IMPORT("sorter", "sort_inventory")
IMPORT("sort", "concat", "copy", "insert", "remove")
IMPORT("true_str", "true_table", "is_str", "is_func", "is_table", "clean_name")

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

	if http and true_str(def.url) then
		http.fetch({url = def.url}, function(result)
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

	if not true_str(def.output) and not def.url then
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
		sort(cp, function(a, b) return #a > #b end)

		width = #cp[1]

		for i = 1, #def.grid do
			while #def.grid[i] < width do
				def.grid[i] = def.grid[i] .. " "
			end
		end

		for symbol in gmatch(concat(def.grid), ".") do
			c++
			def.items[c] = def.key[symbol]
		end
	else
		local items = copy(def.items)
		local lines = {}
		def.items = {}

		for i = 1, #items do
			lines[i] = split(items[i], ",", true)

			if #lines[i] > width then
				width = #lines[i]
			end
		end

		for i = 1, #items do
			while #lines[i] < width do
				insert(lines[i], items[i])
			end
		end

		for _, line in ipairs(lines) do
			for _, v in ipairs(line) do
				c++
				def.items[c] = clean_name(v)
			end
		end
	end

	local item = ItemStack(def.output):get_name()
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
	item = core.registered_aliases[item] or item
	local recipes = i3.recipes_cache[item]
	local usages = i3.usages_cache[item]

	return {recipes = recipes, usages = usages}
end

function i3.set_fs(player)
	if not player or player.is_fake_player then return end
	local name = player:get_player_name()
	local data = i3.data[name]
	if not data then return end

	if data.auto_sorting then
		sort_inventory(player, data)
	end

	for i, tab in ipairs(i3.tabs) do
		if data.tab == i and tab.access and not tab.access(player, data) then
			data.tab = 1
			break
		end
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

i3.new_tab("inventory", {
	description = S"Inventory",
	formspec = get_inventory_fs,
	fields = i3.files.fields(),
})

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

	for i, tab in ipairs(i3.tabs) do
		if tab.name == tabname then
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

function i3.hud_notif(name, msg, img)
	if not true_str(name) then
		return err "i3.hud_notif: player name missing"
	elseif not true_str(msg) then
		return err "i3.hud_notif: message missing"
	end

	local data = i3.data[name]

	if not data then
		return err "i3.hud_notif: no player data initialized"
	end

	data.show_hud = true
	data.hud_msg = msg

	if img then
		data.hud_img = fmt("%s^[resize:16x16", img)
	end
end

function i3.add_sorting_method(name, def)
	if not true_str(name) then
		return err "i3.add_sorting_method: name missing"
	elseif not true_table(def) then
		return err "i3.add_sorting_method: definition missing"
	elseif not is_func(def.func) then
		return err "i3.add_sorting_method: function missing"
	end

	def.name = name
	insert(i3.sorting_methods, def)
end

i3.add_sorting_method("alphabetical", {
	description = S"Sort items by name (A-Z)",
	func = function(list, data)
		sorter(list, data.reverse_sorting, 1)
		return list
	end
})

i3.add_sorting_method("numerical", {
	description = S"Sort items by number of items per stack",
	func = function(list, data)
		sorter(list, data.reverse_sorting, 2)
		return list
	end,
})
