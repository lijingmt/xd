#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=65;
protected void create(){
	name=object_name(this_object());
	name_cn="无垢月宫";
	desc="十道装备虚影悬在殿中，只有完成历程并亲自领取的那一件才会成为真实。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/abyss_garden.pike";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/newmoon_altar.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/moon_general.pike"}));
}
