#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=8;
protected void create(){
	name=object_name(this_object());
	name_cn="银痕小径";
	desc="细碎月辉落在石径上，脚下的银痕会记住每一位真正来过的旅人。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/moon_gate.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/fog_forest.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/moon_wisp.pike"}));
}
