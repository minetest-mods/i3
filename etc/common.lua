local modpath = core.get_modpath "i3"
local item_compression = core.settings:get_bool("i3_item_compression", true)
local reg_items, translate = core.registered_items, core.get_translated_string

local fmt, find, gmatch, match, sub, split, lower =
	string.format, string.find, string.gmatch, string.match,
	string.sub, string.split, string.lower

local function reset_compression(data)
	data.alt_items = nil
	data.expand = ""
end

local function search(data)
	reset_compression(data)

	local filter = data.filter
	local opt = "^(.-)%+([%w_]+)=([%w_,]+)"
	local search_filter = next(i3.search_filters) and match(filter, opt)
	local filters = {}

	if search_filter then
		search_filter = search_filter:trim()

		for filter_name, values in gmatch(filter, sub(opt, 6)) do
			if i3.search_filters[filter_name] then
				values = split(values, ",")
				filters[filter_name] = values
			end
		end
	end

	local filtered_list, c = {}, 0

	for i = 1, #data.items_raw do
		local item = data.items_raw[i]
		local def = core.registered_items[item]
		local desc = lower(translate(data.lang_code, def and def.description)) or ""
		local search_in = fmt("%s %s", item, desc)
		local temp, j, to_add = {}, 1

		if search_filter then
			for filter_name, values in pairs(filters) do
				if values then
					local func = i3.search_filters[filter_name]
					to_add = (j > 1 and temp[item] or j == 1) and
						func(item, values) and (search_filter == "" or
						find(search_in, search_filter, 1, true))

					if to_add then
						temp[item] = true
					end

					j = j + 1
				end
			end
		else
			local ok = true

			for keyword in gmatch(filter, "%S+") do
				if not find(search_in, keyword, 1, true) then
					ok = nil
					break
				end
			end

			if ok then
				to_add = true
			end
		end

		if to_add then
			c = c + 1
			filtered_list[c] = item
		end
	end

	data.items = filtered_list
end

local function table_merge(t1, t2, hash)
	t1 = t1 or {}
	t2 = t2 or {}

	if hash then
		for k, v in pairs(t2) do
			t1[k] = v
		end
	else
		local c = #t1

		for i = 1, #t2 do
			c = c + 1
			t1[c] = t2[i]
		end
	end

	return t1
end

local function is_group(item)
	return sub(item, 1, 6) == "group:"
end

local function extract_groups(str)
	if sub(str, 1, 6) == "group:" then
		return split(sub(str, 7), ",")
	end
end

local function item_has_groups(item_groups, groups)
	for i = 1, #groups do
		local group = groups[i]
		if (item_groups[group] or 0) == 0 then return end
	end

	return true
end

local function show_item(def)
	return def and def.groups.not_in_creative_inventory ~= 1 and
		def.description and def.description ~= ""
end

local function groups_to_items(groups, get_all)
	if not get_all and #groups == 1 then
		local group = groups[1]
		local stereotype = i3.group_stereotypes[group]
		local def = reg_items[stereotype]

		if show_item(def) then
			return stereotype
		end
	end

	local names = {}

	for name, def in pairs(reg_items) do
		if show_item(def) and item_has_groups(def.groups, groups) then
			if get_all then
				names[#names + 1] = name
			else
				return name
			end
		end
	end

	return get_all and names or ""
end

local function apply_recipe_filters(recipes, player)
	for _, filter in pairs(i3.recipe_filters) do
		recipes = filter(recipes, player)
	end

	return recipes
end

local function compression_active(data)
	return item_compression and not next(i3.recipe_filters) and data.filter == ""
end

local function compressible(item, data)
	return compression_active(data) and i3.compress_groups[item]
end

local function is_str(x)
	return type(x) == "string"
end

local function true_str(str)
	return is_str(str) and str ~= ""
end

local function is_fav(favs, query_item)
	local fav, i
	for j = 1, #favs do
		if favs[j] == query_item then
			fav = true
			i = j
			break
		end
	end

	return fav, i
end

return {
	init = {
		is_str,
		show_item,
		reset_compression,
	},

	progressive = {
		search,
		table_merge,
		is_group,
		extract_groups,
		item_has_groups,
		apply_recipe_filters,
	},

	gui = {
		groups_to_items,
		compression_active,
		compressible,
		true_str,
		is_fav,
	},
}
