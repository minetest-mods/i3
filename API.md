# API :screwdriver:

### Table of Contents
1. [**Tabs**](https://github.com/minetest-mods/i3/blob/main/API.md#tabs)
2. [**Recipes**](https://github.com/minetest-mods/i3/blob/main/API.md#recipes)
3. [**Minitabs**](https://github.com/minetest-mods/i3/blob/main/API.md#minitabs)
4. [**Recipe filters**](https://github.com/minetest-mods/i3/blob/main/API.md#recipe-filters)
5. [**Search filters**](https://github.com/minetest-mods/i3/blob/main/API.md#search-filters)
6. [**Sorting methods**](https://github.com/minetest-mods/i3/blob/main/API.md#sorting-methods)
7. [**Item list compression**](https://github.com/minetest-mods/i3/blob/main/API.md#item-list-compression)
8. [**Waypoints**](https://github.com/minetest-mods/i3/blob/main/API.md#waypoints)
9. [**Miscellaneous**](https://github.com/minetest-mods/i3/blob/main/API.md#miscellaneous)

---

### Tabs

#### `i3.new_tab(name, def)`

- `name` is the tab name.
- `def` is the tab definition.

Custom tabs can be added to the `i3` inventory as follow (example):

```Lua
i3.new_tab("stuff", {
	description = "Stuff",
	image = "image.png", -- Optional, add an image next to the tab description
	slots = true -- Optional, whether the inventory slots are shown or not. Disabled by default.

	--
	-- The functions below are all optional
	--

	-- Determine if the tab is visible by a player, return false to hide the tab
	access = function(player, data)
		local name = player:get_player_name()
		return name == "singleplayer"
	end,

	-- Build the formspec
	formspec = function(player, data, fs)
		fs("label", 3, 1, "Just a test")
		fs"label[3,2;Lorem Ipsum]"
		-- No need to return anything
	end,

	-- Events handling happens here
	fields = function(player, data, fields)
		if fields.mybutton then
			-- Do things
		end

		-- To prevent a formspec update, return false.
		-- Otherwise: no need to return anything, it's automatic.
	end,
})
```

- `player` is an `ObjectRef` to the user.
- `data` are the user data.
- `fs` is the formspec table which is callable with a metamethod. Every call adds a new entry.

#### `i3.set_fs(player)`

Update the current formspec.

#### `i3.remove_tab(tabname)`

Delete a tab by name.

#### `i3.get_current_tab(player)`

Return the current player tab. `player` is an `ObjectRef` to the user.

#### `i3.set_tab(player[, tabname])`

Set the current tab by name. `player` is an `ObjectRef` to the user.
`tabname` can be omitted to get an empty tab.

#### `i3.override_tab(tabname, def)`

Override a tab by name. `def` is the tab definition like seen in `i3.set_tab`

#### `i3.tabs`

A list of registered tabs.

---

### Recipes

Custom recipes are nonconventional crafts outside the main crafting grid.
They can be registered in-game dynamically and have a size beyond 3x3 items.

**Note:** the registration format differs from the default registration format in everything.
The width is automatically calculated depending where you place the commas.

Examples:

#### Registering a custom crafting type

```Lua
i3.register_craft_type("digging", {
	description = "Digging",
	icon = "default_tool_steelpick.png",
})
```

#### Registering a custom crafting recipe

```Lua
i3.register_craft {
	type   = "digging",
	result = "default:cobble 2",
	items  = {"default:stone"},
}
```

```Lua
i3.register_craft {
	result = "default:cobble 16",
	items = {
		"default:stone, default:stone, default:stone",
		"default:stone,              , default:stone",
		"default:stone, default:stone, default:stone",
	}
}
```

Recipes can be registered in a Minecraft-like way:

```Lua
i3.register_craft {
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
}
```

Multiple recipes can also be registered at once:

```Lua
i3.register_craft {
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
}
```

Recipes can be registered from a given URL containing a JSON file (HTTP support is required¹):

```Lua
i3.register_craft {
	url = "https://raw.githubusercontent.com/minetest-mods/i3/main/tests/test_online_recipe.json"
}
```

---

### Minitabs

Manage the tabs on the right panel of the inventory.
Allow to make a sensible list sorted by specific groups of items.

#### `i3.new_minitab(name, def)`

Add a new minitab (limited to 6).

- `name` is the tab name.
- `def` is the definition table.

Example:

```Lua
i3.new_minitab("test", {
	description = "Test",

	-- Whether this tab is visible or not. Optional.
	access = function(player, data)
		return player:get_player_name() == "singleplayer"
	end,

	-- Whether a specific item is shown in the list or not.
	sorter = function(item, data)
		return item:find"wood"
	end
})

```

- `player` is an `ObjectRef` to the user.
- `data` are the user data.
- `item` is an item name string.

#### `i3.remove_minitab(name)`

Remove a minitab by name.

- `name` is the name of the tab to remove.

#### `i3.minitabs`

A list of registered minitabs.

---

### Recipe filters

Recipe filters can be used to filter the recipes shown to players. Progressive
mode is implemented as a recipe filter.

#### `i3.add_recipe_filter(name, function(recipes, player))`

Add a recipe filter with the given `name`. The filter function returns the
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

Remove all recipe filters and add a new one.

#### `i3.recipe_filters`

A map of recipe filters, indexed by name.

---

### Search filters

Search filters are used to perform specific searches from the search field.
The filters can be cumulated to perform a specific search.
They are used like so: `<optional_name> +<filter name>=<value1>,<value2>,<...>`

Example usages:

- `+groups=cracky,crumbly` -> search for groups `cracky` and `crumbly` in all items.
- `wood +groups=flammable` -> search for group `flammable` amongst items which contain
  `wood` in their names.

Notes:
- If `optional_name` is omitted, the search filter will apply to all items, without pre-filtering.
- The `+groups` filter is currently implemented by default.

#### `i3.add_search_filter(name, function(item, values))`

Add a search filter.
The search function must return a boolean value (whether the given item should be listed or not).

- `name` is the filter name.
- `values` is a table of all possible values.

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

#### `i3.search_filters`

A map of search filters, indexed by name.

---

### Sorting methods

Sorting methods are used to filter the player's main inventory.

#### `i3.add_sorting_method(name, def)`

Add a player inventory sorting method.

- `name` is the method name.
- `def` is the method definition.

Example:

```Lua
i3.add_sorting_method("test", {
	description = "Cool sorting method",
	func = function(list, data)
		-- `list`: inventory list
		-- `data`: player data

		table.sort(list)

		-- A list must be returned
		return list
	end,
})

```

#### `i3.sorting_methods`

A table containing all sorting methods.

---

### Item list compression

`i3` can reduce the item list size by compressing a group of items.

#### `i3.compress(item, def)`

Add a new group of items to compress.

- `item` is the item which represent the group of compressed items.
- `def` is a table specifying the substring replace patterns to be used.

Example:

```Lua
i3.compress("default:diamondblock", {
	replace = "diamond",
	by = {"bronze", "copper", "gold", "steel", "tin"}
})

```

#### `i3.compress_groups`

A map of all compressed item groups, indexed by stereotypes.

---

### Waypoints

`i3` allows you to manage the waypoints of a specific player.

#### `i3.add_waypoint(player_name, def)`

Add a waypoint to specific player.

- `player_name` is the player name.
- `def` is the waypoint definition table.

Example:

```Lua
i3.add_waypoint("Test", {
	player = "singleplayer",
	pos = {x = 0, y = 2, z = 0},
	color = 0xffff00,
--	image = "heart.png" (optional)
})
```

#### `i3.remove_waypoint(player_name, waypoint_name)`

Remove a waypoint for specific player.

- `player_name` is the player name.
- `waypoint_name` is the waypoint name.

Example:

```Lua
i3.remove_waypoint("singleplayer", "Test")
```

#### `i3.get_waypoints(player_name)`

Return a table of all waypoints of a specific player.

- `player_name` is the player name.

---

### Miscellaneous

#### `i3.hud_notif(name, msg[, img])`

Show a Steam-like HUD notification on the bottom-left corner of the screen.

- `name` is the player name.
- `msg` is the HUD message to show.
- `img` (optional) is the HUD image to show (preferably 16x16 px).

#### `i3.get_recipes(item)`

Return a table of recipes and usages of `item`.

#### `i3.export_url`

If set, the mod will export all the cached recipes and usages in a JSON format
to the given URL (HTTP support is required¹).

#### `groups = {bag = <1-4>}`

The `bag` group in the item definition allows to extend the player inventory size
given a number between 1 and 4.

---

**[1]** Add `i3` to the `secure.http_mods` or `secure.trusted_mods` setting in `minetest.conf`.
