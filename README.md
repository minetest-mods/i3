# i3

[![ContentDB](https://content.minetest.net/packages/jp/i3/shields/title/)](https://content.minetest.net/packages/jp/i3/) [![ContentDB](https://content.minetest.net/packages/jp/i3/shields/downloads/)](https://content.minetest.net/packages/jp/i3/)

#### **`i3`** is a next-generation inventory for Minetest.

This mod features a modern, powerful inventory menu with a good user experience.
**`i3`** provides a rich [**API**](https://github.com/minetest-mods/i3/blob/master/API.md) for mod developers who want to extend it.

This mod requires **Minetest 5.4+**

#### List of features:
   - Crafting Guide (only in survival mode)
   - Progressive Mode¹
   - Quick Crafting
   - Backpacks
   - 3D Player Model Preview
   - Inventory Sorting (with optional compression)
   - Item Bookmarks
   - Waypoints
   - Item List Compression (**`moreblocks`** is supported)

**¹** *This mode is a Terraria-like system that shows recipes you can craft from items you ever had in your inventory.
To enable it: `i3_progressive_mode = true` in `minetest.conf`.*


#### This mod officially supports the following mods:
   - [**`3d_armor`**](https://content.minetest.net/packages/stu/3d_armor/)
   - [**`skinsdb`**](https://content.minetest.net/packages/bell07/skinsdb/)
   - [**`awards`**](https://content.minetest.net/packages/rubenwardy/awards/)

#### Recommendations

To use this mod in the best conditions:

   - Use LuaJIT
   - Use a HiDPI widescreen display
   - Use the default Freetype font style

#### Troubleshooting

If the inventory's font size is too big on certain setups (namely Windows 10/11 or 144 DPI display), you should lower the
value of the setting `display_density_factor` in your `minetest.conf`. Note that the change is applied after restart.

#### Notes

`i3` uses a larger inventory than the usual inventories in Minetest games.
Thus, most chests will be unadapted to this inventory size.
The `i3`  inventory is 9 slots wide by default (without backpack), such as Minecraft.

Report any bug on the [**Bug Tracker**](https://github.com/minetest-mods/i3/issues).

Love this mod? Donations are appreciated: https://www.paypal.me/jpg84240

Demo video (outdated): https://www.youtube.com/watch?v=25nCAaqeacU

![Preview](https://user-images.githubusercontent.com/7883281/123561657-10ba7780-d7aa-11eb-8bbe-dcec348bb28c.png)
