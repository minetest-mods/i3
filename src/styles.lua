local PNG = {
	blank = "i3_blank.png",
	bg = "i3_bg.png",
	bg_full = "i3_bg_full.png",
	bg_content = "i3_bg_content.png",
	bar = "i3_bar.png",
	hotbar = "i3_hotbar.png",
	search = "i3_search.png",
	heart = "i3_heart.png",
	heart_half = "i3_heart_half.png",
	heart_grey = "i3_heart_grey.png",
	prev = "i3_next.png^\\[transformFX",
	next = "i3_next.png",
	arrow = "i3_arrow.png",
	arrow_content = "i3_arrow_content.png",
	trash = "i3_trash.png",
	sort = "i3_sort.png",
	settings = "i3_settings.png",
	compress = "i3_compress.png",
	fire = "i3_fire.png",
	fire_anim = "i3_fire_anim.png",
	book = "i3_book.png",
	sign = "i3_sign.png",
	cancel = "i3_cancel.png",
	export = "i3_export.png",
	slot = "i3_slot.png",
	tab = "i3_tab.png",
	tab_small = "i3_tab_small.png",
	tab_top = "i3_tab.png^\\[transformFY",
	furnace_anim = "i3_furnace_anim.png",
	shapeless = "i3_shapeless.png",
	bag = "i3_bag.png",
	armor = "i3_armor.png",
	awards = "i3_award.png",
	skins = "i3_skin.png",
	waypoints = "i3_waypoint.png",
	add = "i3_add.png",
	refresh = "i3_refresh.png",
	visible = "i3_visible.png^\\[brighten",
	nonvisible = "i3_non_visible.png",
	exit = "i3_exit.png",
	home = "i3_home.png",
	flag = "i3_flag.png",
	edit = "i3_edit.png",
	no_result = "i3_no_result.png",
	find_more = "i3_find_more.png",

	cancel_hover = "i3_cancel.png^\\[brighten",
	search_hover = "i3_search.png^\\[brighten",
	export_hover = "i3_export.png^\\[brighten",
	trash_hover = "i3_trash.png^\\[brighten^\\[colorize:#f00:100",
	compress_hover = "i3_compress.png^\\[brighten",
	sort_hover = "i3_sort.png^\\[brighten",
	settings_hover = "i3_settings.png^\\[brighten",
	prev_hover = "i3_next_hover.png^\\[transformFX",
	next_hover = "i3_next_hover.png",
	tab_hover = "i3_tab_hover.png",
	tab_small_hover = "i3_tab_small_hover.png",
	tab_hover_top = "i3_tab_hover.png^\\[transformFY",
	bag_hover = "i3_bag_hover.png",
	armor_hover = "i3_armor_hover.png",
	awards_hover = "i3_award_hover.png",
	skins_hover = "i3_skin_hover.png",
	waypoints_hover = "i3_waypoint_hover.png",
	add_hover = "i3_add.png^\\[brighten",
	refresh_hover = "i3_refresh.png^\\[brighten",
	exit_hover = "i3_exit.png^\\[brighten",
	home_hover = "i3_home.png^\\[brighten",
	edit_hover = "i3_edit.png^\\[brighten",
}

local styles = string.format([[
	style_type[field;border=false;bgcolor=transparent]
	style_type[label,field;font_size=16]
	style_type[button;border=false;content_offset=0]
	style_type[image_button,item_image_button,checkbox,dropdown;border=false;sound=i3_click]
	style_type[item_image_button;bgimg_hovered=%s]

	style[;sound=]
	style[nofav;sound=i3_cannot]
	style[pagenum,no_item,no_rcp;font=bold;font_size=18]
	style[search;fgimg=%s;content_offset=0]
	style[exit;fgimg=%s;fgimg_hovered=%s;content_offset=0]
	style[cancel;fgimg=%s;fgimg_hovered=%s;content_offset=0]
	style[prev_page,prev_recipe,prev_usage,prev_sort,prev_skin;fgimg=%s;fgimg_hovered=%s]
	style[next_page,next_recipe,next_usage,next_sort,next_skin;fgimg=%s;fgimg_hovered=%s]
	style[waypoint_add;fgimg=%s;fgimg_hovered=%s;content_offset=0]
	style[bag_rename;fgimg=%s;fgimg_hovered=%s;content_offset=0]
	style[btn_bag,btn_armor,btn_skins;font=bold;font_size=18;content_offset=0;sound=i3_click]
	style[craft_rcp,craft_usg;noclip=true;font_size=16;sound=i3_craft;
	      bgimg=i3_btn9.png;bgimg_hovered=i3_btn9_hovered.png;
	      bgimg_pressed=i3_btn9_pressed.png;bgimg_middle=4,6]
	style[confirm_trash_yes,confirm_trash_no,set_home;noclip=true;font_size=16;
	      bgimg=i3_btn9.png;bgimg_hovered=i3_btn9_hovered.png;
	      bgimg_pressed=i3_btn9_pressed.png;bgimg_middle=4,6]
	style[confirm_trash_yes;sound=i3_trash]
]],
PNG.slot,
PNG.search_hover,
PNG.exit,     PNG.exit_hover,
PNG.cancel,   PNG.cancel_hover,
PNG.prev,     PNG.prev_hover,
PNG.next,     PNG.next_hover,
PNG.add,      PNG.add_hover,
PNG.edit,     PNG.edit_hover)

local fs_elements = {
	label = "label[%f,%f;%s]",
	box = "box[%f,%f;%f,%f;%s]",
	image = "image[%f,%f;%f,%f;%s]",
	tooltip = "tooltip[%f,%f;%f,%f;%s]",
	button = "button[%f,%f;%f,%f;%s;%s]",
	checkbox = "checkbox[%f,%f;%s;%s;%s]",
	item_image = "item_image[%f,%f;%f,%f;%s]",
	hypertext = "hypertext[%f,%f;%f,%f;%s;%s]",
	bg9 = "background9[%f,%f;%f,%f;%s;false;%u]",
	scrollbar = "scrollbar[%f,%f;%f,%f;%s;%s;%u]",
	model = "model[%f,%f;%f,%f;%s;%s;%s;%s;%s;%s;%s]",
	image_button = "image_button[%f,%f;%f,%f;%s;%s;%s]",
	animated_image = "animated_image[%f,%f;%f,%f;;%s;%u;%u]",
	item_image_button = "item_image_button[%f,%f;%f,%f;%s;%s;%s]",
}

local colors = {
	yellow = "#ffd866",
	black = "#2d2a2e",
	blue = "#7bf",
}

return PNG, styles, fs_elements, colors
