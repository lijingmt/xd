#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=69;
protected void create(){
	name=object_name(this_object());
	name_cn="隐月环坑";
	desc="第十道月痕藏在祭台背后。愿意探索的人，终会发现直线之外的答案。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/newmoon_altar.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/moon_general.pike"}));
}
string query_links(){ return "[勘察环坑星核:illusion_realm explore]\n"; }
