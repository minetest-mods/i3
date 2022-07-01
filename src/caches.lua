local replacements = {fuel = {}}
local http = ...

IMPORT("maxn", "copy", "insert", "sort", "match", "sub")
IMPORT("true_str", "is_table", "valid_item", "table_merge", "table_replace", "rcp_eq")
IMPORT("fmt", "reg_items", "reg_aliases", "reg_nodes", "is_cube", "get_cube", "ItemStack")
IMPORT("is_group", "extract_groups", "item_has_groups", "groups_to_items", "get_group_stereotype")

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

local function cache_groups(group, groups)
	i3.groups[group] = {}
	i3.groups[group].groups = groups
	i3.groups[group].items = groups_to_items(groups)

	if #groups == 1 then
		i3.groups[group].stereotype = get_group_stereotype(groups[1])
	end

	local items = i3.groups[group].items
	if #items <= 1 then return end

	local px, lim, c = 64, 10, 0
	local sprite = "[combine:WxH"

	for _, item in ipairs(items) do
		local def = reg_items[item]
		local tiles = def.tiles or def.tile_images
		local texture = true_str(def.inventory_image) and def.inventory_image --or tiles[1]

		if def.drawtype and is_cube(def.drawtype) then
			texture = get_cube(tiles)
		end

		if texture then
			texture = texture:gsub("%^", "\\^"):gsub(":", "\\:") .. fmt("\\^[resize\\:%ux%u", px, px)
			sprite = sprite .. fmt(":0,%u=%s", c * px, texture)
			c++
			if c == lim then break end
		end
	end

	if c > 1 then
		sprite = sprite:gsub("WxH", px .. "x" .. px * c)

		i3.groups[group].sprite = sprite
		i3.groups[group].count = c
	end
end

local function get_item_usages(item, recipe, added)
	if is_group(item) then
		local group = item:sub(7)
		local group_cache = i3.groups[group]
		local groups = group_cache and group_cache.groups or extract_groups(item)

		if not group_cache then
			cache_groups(group, groups)
		end

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
		output = groups_to_items(groups)
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

		if newname ~= "" and i3.recipes_cache[oldname] and reg_items[newname] and not hash[newname] then
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

local function init_cubes()
	for name, def in pairs(reg_nodes) do
		if def then
			local id = core.get_content_id(name)
			local tiles = def.tiles or def.tile_images

			if is_cube(def.drawtype) then
				i3.cubes[id] = get_cube(tiles)
			elseif sub(def.drawtype, 1, 9) == "plantlike" or sub(def.drawtype, 1, 8) == "firelike" then
				local texture = true_str(def.inventory_image) and def.inventory_image or tiles[1]

				if texture then
					i3.plants[id] = texture
				end
			end
		end
	end
end

return function()
	init_recipes()
	init_cubes()
end
