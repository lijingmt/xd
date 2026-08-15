#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=58;
protected void create(){
	name=object_name(this_object());
	name_cn="渊花庭";
	desc="深渊并不黑暗，月花在每次战斗结束后重新开放。\n";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/star_bridge.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/moon_palace.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/abyss_beast.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/abyss_beast.pike"}));
}
