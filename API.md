## API

### Custom tabs

#### `i3.new_tab(def)`

Custom tabs can be added to the `i3` inventory as follow (example):

```Lua
i3.new_tab {
	name = "stuff",
	description = "Stuff",
	image = "image.png", -- Optional, adds an image next to the tab description

	-- Determine if the tab is visible by a player, `false` or `nil` hide the tab
	access = function(player, data)
		local name = player:get_player_name()
		if name == "singleplayer" then
			return false
		end
	end,

	formspec = function(player, data, fs)
		fs("label[3,1;This is just a test]")
	end,

	fields = function(player, data, fields)
		i3.set_fs(player)
	end,

	-- Determine if the recipe panels must be hidden or not (must return a boolean)
	hide_panels = function(player, data)
		local name = player:get_player_name()
		return core.is_creative_enabled(name)
	end,
}
```

- `player` is an `ObjectRef` to the user.
- `data` are the user data.
- `fs` is the formspec table which is callable with a metamethod. Each call adds a new entry.
- `i3.set_fs(player)` must be called to update the formspec.

##### `i3.delete_tab(name)`

Deletes a tab by name.

##### `i3.get_tabs()`

Returns the list of registered tabs.

---

### Custom recipes

Custom recipes are nonconventional crafts outside the main crafting grid.
They can be registered in-game dynamically and have a size beyond 3x3 items.

**Note:** the registration format differs from the default registration format in everything.
The width is automatically calculated depending where you place the commas. Look at the examples attentively.

#### Registering a custom crafting type (example)

```Lua
i3.register_craft_type("digging", {
	description = "Digging",
	icon = "default_tool_steelpick.png",
})
```

#### Registering a custom crafting recipe (examples)

```Lua
i3.register_craft({
	type   = "digging",
	result = "default:cobble 2",
	items  = {"default:stone"},
})
```

```Lua
i3.register_craft({
	result = "default:cobble 16",
	items = {
		"default:stone, default:stone, default:stone",
		"default:stone,              , default:stone",
		"default:stone, default:stone, default:stone",
	}
})
```

Recipes can be registered in a Minecraft-like way:

```Lua
i3.register_craft({
	grid = {
		"X  #",
		" ## ",
		"X#X#",
		"X  X",
	},
	key = {
		['#'] = "default:wood",
		['X'] = "default:glass",
	},
	result = "default:mese 3",
})
```

Multiples recipes can also be registered:

```Lua
i3.register_craft({
	{
		result = "default:mese",
		items = {
			"default:mese_crystal, default:mese_crystal",
			"default:mese_crystal, default:mese_crystal",
		}
	},

	big = {
		result = "default:mese 4",
		items = {
			"default:mese_crystal, default:mese_crystal",
			"default:mese_crystal, default:mese_crystal",
			"default:mese_crystal, default:mese_crystal",
			"default:mese_crystal, default:mese_crystal",
		}
	},
})
```

Recipes can be registered from a given URL containing a JSON file (HTTP support is required¹):

```Lua
i3.register_craft({
	url = "https://raw.githubusercontent.com/minetest-mods/i3/main/test_online_recipe.json"
})
```

---

### Recipe filters

Recipe filters can be used to filter the recipes shown to players. Progressive
mode is implemented as a recipe filter.

#### `i3.add_recipe_filter(name, function(recipes, player))`

Adds a recipe filter with the given `name`. The filter function returns the
recipes to be displayed, given the available recipes and an `ObjectRef` to the
user. Each recipe is a table of the form returned by
`minetest.get_craft_recipe`.

Example function to hide recipes for items from a mod called "secretstuff":

```lua
i3.add_recipe_filter("Hide secretstuff", function(recipes)
	local filtered = {}
	for _, recipe in ipairs(recipes) do
		if recipe.output:sub(1,12) ~= "secretstuff:" then
			filtered[#filtered + 1] = recipe
		end
	end

	return filtered
end)
```

#### `i3.set_recipe_filter(name, function(recipe, player))`

Removes all recipe filters and adds a new one.

#### `i3.remove_recipe_filter(name)`

Removes the recipe filter with the given `name`.

#### `i3.get_recipe_filters()`

Returns a map of recipe filters, indexed by name.

---

### Search filters

Search filters are used to perform specific searches inside the search field.
They can be used like so: `<optional_name> +<filter name>=<value1>,<value2>,<...>`

Examples:

- `+groups=cracky,crumbly`: search for groups `cracky` and `crumbly` in all items.
- `sand +groups=falling_node`: search for group `falling_node` for items which contain `sand` in their names.

Notes:
- If `optional_name` is omitted, the search filter will apply to all items, without pre-filtering.
- Filters can be combined.
- The `groups` and `type` filters are currently implemented by default.

#### `i3.add_search_filter(name, function(item, values))`

Adds a search filter with the given `name`.
The search function must return a boolean value (whether the given item should be listed or not).

Example function sorting items by drawtype:

```lua
i3.add_search_filter("type", function(item, drawtype)
	if drawtype == "node" then
		return reg_nodes[item]
	elseif drawtype == "item" then
		return reg_craftitems[item]
	elseif drawtype == "tool" then
		return reg_tools[item]
	end
end)
```

#### `i3.remove_search_filter(name)`

Removes the search filter with the given `name`.

#### `i3.get_search_filters()`

Returns a map of search filters, indexed by name.

---

### Miscellaneous

#### `i3.group_stereotypes`

This is the table indexing the item groups by stereotypes.
You can add a stereotype like so:

```Lua
i3.group_stereotypes.radioactive = "mod:item"
```

#### `i3.export_url`

If set, the mod will export all the cached recipes and usages in a JSON format
to the given URL (HTTP support is required¹).

---

**¹** Add `i3` to the `secure.http_mods` or `secure.trusted_mods` setting in `minetest.conf`.
