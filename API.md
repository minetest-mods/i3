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
		
	end,
}
```

- `player` is an `ObjectRef` to the user.
- `data` are the user data.
- `fs` is the formspec table which is callable with a metamethod. Each call adds a new entry.

#### `i3.set_fs(player[, extra_formspec])`

Updates the current formspec. `extra_formspec` adds an additional formspec string.

#### `i3.remove_tab(tabname)`

Deletes a tab by name.

#### `i3.set_tab(player[, tabname])`

Sets the current tab by name. `player` is an `ObjectRef` to the user.
`tabname` can be omitted to get an empty tab.

#### `i3.override_tab(tabname, def)`

Overrides a tab by name. `def` is the tab definition like seen in `i3.set_tab`.

#### `i3.get_tabs()`

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
	url = "https://raw.githubusercontent.com/minetest-mods/i3/main/tests/test_online_recipe.json"
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
These filters are cumulative to perform a specific search.
They can be used like so: `<optional_name> +<filter name>=<value1>,<value2>,<...>`

Example usages:

- `+groups=cracky,crumbly`: search for groups `cracky` and `crumbly` in all items.
- `wood +groups=flammable`: search for group `flammable` amongst items which contain
  `wood` in their names.

Notes:
- If `optional_name` is omitted, the search filter will apply to all items, without pre-filtering.
- The `+groups` filter is currently implemented by default.

#### `i3.add_search_filter(name, function(item, values))`

Adds a search filter with the given `name`. `values` is a table of all possible values.
The search function must return a boolean value (whether the given item should be listed or not).

Example function sorting items by drawtype:

```lua
i3.add_search_filter("types", function(item, drawtypes)
	local t = {}

	for i, dt in ipairs(drawtypes) do
		t[i] = (dt == "node" and reg_nodes[item] and 1) or
		       (dt == "item" and reg_craftitems[item] and 1) or
		       (dt == "tool" and reg_tools[item] and 1) or nil
	end

	return #t > 0
end)
```

#### `i3.remove_search_filter(name)`

Removes the search filter with the given `name`.

#### `i3.get_search_filters()`

Returns a map of search filters, indexed by name.

---

### Miscellaneous

#### `i3.export_url`

If set, the mod will export all the cached recipes and usages in a JSON format
to the given URL (HTTP support is required¹).

---

**¹** Add `i3` to the `secure.http_mods` or `secure.trusted_mods` setting in `minetest.conf`.
