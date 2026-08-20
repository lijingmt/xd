#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_ROOM;

protected void create()
{
	name=object_name(this_object());
	name_cn="无相·混沌秘境";
	desc="三道互相吞噬的混沌气环悬在虚空中，力量、灵识与身法在这里不再各自为政。\n"
		"混沌兽王守在气环中央；只有在三系之间找到平衡，才能把万象重新归于一心。\n";
	set_room_type("fb");
	exits=([]);
	add_items(({ROOT+"/gamelib/clone/npc/wuxiang_hundun/hundunshouwang.pike"}));
}

int is_wuxiang_chaos_room(){ return 1; }

string query_links(void|int count)
{
	return "[安全离开混沌秘境:fb_leave wuxianghundun]\n";
}

string view_exits(){ return ""; }
