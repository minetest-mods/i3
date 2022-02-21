![logo](https://user-images.githubusercontent.com/7883281/145490041-d91d6bd6-a654-438d-b208-4d5736845ab7.png)

[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/tterb/atomic-design-ui/blob/master/LICENSEs) [![GitHub Release](https://img.shields.io/github/release/minetest-mods/i3.svg?style=flat)]() ![workflow](https://github.com/minetest-mods/i3/actions/workflows/luacheck.yml/badge.svg) [![ContentDB](https://content.minetest.net/packages/jp/i3/shields/downloads/)](https://content.minetest.net/packages/jp/i3/) [![PayPal](https://img.shields.io/badge/paypal-donate-yellow.svg)](https://www.paypal.me/jpg84240)

#### **`i3`** is a next-generation inventory for Minetest.

This mod features a modern, powerful inventory menu with a good user experience.
**`i3`** provides a rich [**API**](https://github.com/minetest-mods/i3/blob/master/API.md) for mod developers who want to extend it.

This mod requires **Minetest 5.4+**

#### List of features:
   - Crafting Guide (survival mode only)
   - Progressive Mode¹
   - Quick Crafting
   - 3D Player Model Real-Time Preview
   - Isometric Map Preview
   - Inventory Sorting (+ options: compression, reverse mode, automation, etc.)
   - Item List Compression (**`moreblocks`** is supported)
   - Item Bookmarks
   - Waypoints
   - Bags
   - Home

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
The `i3`  inventory is 9 slots wide by default, such as Minecraft.

Report bugs on the [**Bug Tracker**](https://github.com/minetest-mods/i3/issues).

**Video review on YouTube:** https://www.youtube.com/watch?v=Xd14BCdEZ3o

![Preview](https://content.minetest.net/uploads/3abf3755de.png)
