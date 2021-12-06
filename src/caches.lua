local replacements = {fuel = {}}
local http = ...

IMPORT("maxn", "copy", "insert", "sort", "match", "sub")
IMPORT("is_group", "extract_groups", "item_has_groups", "groups_to_items")
IMPORT("fmt", "reg_items", "reg_aliases", "reg_nodes", "draw_cube", "ItemStack")
IMPORT("true_str", "true_table", "is_table", "valid_item", "table_merge", "table_replace", "rcp_eq")

local function get_burntime(item)
	return core.get_craft_result{method = "fuel", items = {item}}.time
end

local function cache_fuel(item)
	local burntime = get_burntime(item)
	if burntime > 0 then
		i3.fuel_cache[item] = {
			type = "fuel",
			items = {item},
			burntime = burntime,
			replacements = replacements.fuel[item],
		}
	end
end

local function get_item_usages(item, recipe, added)
	local groups = extract_groups(item)

	if groups then
		for name, def in pairs(reg_items) do
			if not added[name] and valid_item(def) and item_has_groups(def.groups, groups) then
				local usage = copy(recipe)
				table_replace(usage.items, item, name)

				i3.usages_cache[name] = i3.usages_cache[name] or {}
				insert(i3.usages_cache[name], 1, usage)

				added[name] = true
			end
		end
	elseif valid_item(reg_items[item]) then
		i3.usages_cache[item] = i3.usages_cache[item] or {}
		insert(i3.usages_cache[item], 1, recipe)
	end
end

local function get_usages(recipe)
	local added = {}

	for _, item in pairs(recipe.items) do
		item = reg_aliases[item] or item

		if not added[item] then
			get_item_usages(item, recipe, added)
			added[item] = true
		end
	end
end

local function cache_usages(item)
	local recipes = i3.recipes_cache[item] or {}

	for i = 1, #recipes do
		get_usages(recipes[i])
	end

	if i3.fuel_cache[item] then
		i3.usages_cache[item] = table_merge(i3.usages_cache[item] or {}, {i3.fuel_cache[item]})
	end
end

local function drop_table(name, drop)
	local count_sure = 0
	local drop_items = drop.items or {}
	local max_items = drop.max_items

	for i = 1, #drop_items do
		local di = drop_items[i]
		local valid_rarity = di.rarity and di.rarity > 1

		if di.rarity or not max_items or
				(max_items and not di.rarity and count_sure < max_items) then
			for j = 1, #di.items do
				local dstack = ItemStack(di.items[j])
				local dname  = dstack:get_name()
				local dcount = dstack:get_count()
				local empty  = dstack:is_empty()

				if not empty and (dname ~= name or (dname == name and dcount > 1)) then
					local rarity = valid_rarity and di.rarity

					i3.register_craft {
						type   = rarity and "digging_chance" or "digging",
						items  = {name},
						output = fmt("%s %u", dname, dcount),
						rarity = rarity,
						tools  = di.tools,
					}
				end
			end
		end

		if not di.rarity then
			count_sure++
		end
	end
end

local function cache_drops(name, drop)
	if true_str(drop) then
		local dstack = ItemStack(drop)
		local dname  = dstack:get_name()
		local empty  = dstack:is_empty()

		if not empty and dname ~= name then
			i3.register_craft {
				type = "digging",
				items = {name},
				output = drop,
			}
		end
	elseif is_table(drop) then
		drop_table(name, drop)
	end
end

local function cache_recipes(item)
	local recipes = core.get_all_craft_recipes(item)

	if replacements[item] then
		local _recipes = {}

		for k, v in ipairs(recipes or {}) do
			_recipes[#recipes + 1 - k] = v
		end

		local shift = 0
		local size_rpl = maxn(replacements[item])
		local size_rcp = #_recipes

		if size_rpl > size_rcp then
			shift = size_rcp - size_rpl
		end

		for k, v in pairs(replacements[item]) do
			k += shift

			if _recipes[k] then
				_recipes[k].replacements = v
			end
		end

		recipes = _recipes
	end

	if recipes then
		i3.recipes_cache[item] = table_merge(recipes, i3.recipes_cache[item] or {})
	end
end

--[[	As `core.get_craft_recipe` and `core.get_all_craft_recipes` do not
	return the fuel, replacements and toolrepair recipes, we have to
	override `core.register_craft` and do some reverse engineering.
	See engine's issues #4901, #5745 and #8920.	]]

local old_register_craft = core.register_craft
local rcp_num = {}

core.register_craft = function(def)
	old_register_craft(def)

	if def.type == "toolrepair" then
		i3.toolrepair = def.additional_wear * -100
	end

	local output = def.output or (true_str(def.recipe) and def.recipe) or nil
	if not output then return end
	output = {match(output, "%S+")}

	local groups

	if is_group(output[1]) then
		groups = extract_groups(output[1])
		output = groups_to_items(groups, true)
	end

	for i = 1, #output do
		local item = output[i]
		rcp_num[item] = (rcp_num[item] or 0) + 1

		if def.replacements then
			if def.type == "fuel" then
				replacements.fuel[item] = def.replacements
			else
				replacements[item] = replacements[item] or {}
				replacements[item][rcp_num[item]] = def.replacements
			end
		end
	end
end

local old_clear_craft = core.clear_craft

core.clear_craft = function(def)
	old_clear_craft(def)

	if true_str(def) then
		return -- TODO
	elseif is_table(def) then
		return -- TODO
	end
end

local function resolve_aliases(hash)
	for oldname, newname in pairs(reg_aliases) do
		cache_recipes(oldname)
		local recipes = i3.recipes_cache[oldname]

		if recipes then
			if not i3.recipes_cache[newname] then
				i3.recipes_cache[newname] = {}
			end

			local similar

			for i = 1, #i3.recipes_cache[oldname] do
				local rcp_old = i3.recipes_cache[oldname][i]

				for j = 1, #i3.recipes_cache[newname] do
					local rcp_new = copy(i3.recipes_cache[newname][j])
					      rcp_new.output = oldname

					if rcp_eq(rcp_old, rcp_new) then
						similar = true
						break
					end
				end

				if not similar then
					insert(i3.recipes_cache[newname], rcp_old)
				end
			end
		end

		if newname ~= "" and i3.recipes_cache[oldname] and not hash[newname] then
			insert(i3.init_items, newname)
		end
	end
end

local function init_recipes()
	local _select, _preselect = {}, {}

	for name, def in pairs(reg_items) do
		if name ~= "" and valid_item(def) then
			cache_drops(name, def.drop)
			cache_fuel(name)
			cache_recipes(name)

			_preselect[name] = true
		end
	end

	for name in pairs(_preselect) do
		cache_usages(name)

		insert(i3.init_items, name)
		_select[name] = true
	end

	resolve_aliases(_select)
	sort(i3.init_items)

	if http and true_str(i3.export_url) then
		local post_data = {
			recipes = i3.recipes_cache,
			usages  = i3.usages_cache,
		}

		http.fetch_async {
			url = i3.export_url,
			post_data = core.write_json(post_data),
		}
	end
end

local function get_cube(tiles)
	if not true_table(tiles) then
		return "i3_blank.png"
	end

	local t = copy(tiles)
	local texture

	for k, v in pairs(t) do
		if type(v) == "table" then
			t[k] = v.name
		end
	end

	-- Tiles: up, down, right, left, back, front
	-- Inventory cube: up, front, right
	if #t <= 2 then
		texture = draw_cube(t[1], t[1], t[1])
	elseif #t <= 5 then
		texture = draw_cube(t[1], t[3], t[3])
	else -- Full tileset
		texture = draw_cube(t[1], t[6], t[3])
	end

	return texture
end

local function init_cubes()
	for name, def in pairs(reg_nodes) do
		if def then
			local id = core.get_content_id(name)

			if def.drawtype == "normal" or def.drawtype == "liquid" or
					sub(def.drawtype, 1, 9) == "glasslike" or
					sub(def.drawtype, 1, 8) == "allfaces" then
				i3.cubes[id] = get_cube(def.tiles)
			elseif sub(def.drawtype, 1, 9) == "plantlike" or sub(def.drawtype, 1, 8) == "firelike" then
				i3.plants[id] = def.inventory_image .. "^\\[resize:16x16"
			end
		end
	end
end

return function()
	init_recipes()
	init_cubes()
end
