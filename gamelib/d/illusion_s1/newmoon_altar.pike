#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=69;
protected void create(){
	name=object_name(this_object());
	name_cn="新月归真台";
	desc="S1终章的月轮在此闭合。三条命途会以不同方式证明你真正走完了这段旅程。\n";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/moon_palace.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/hidden_crater.pike";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/moon_immortality_furnace.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/newmoon_lord.pike"}));
}
string query_links(){ return "[合印归真:illusion_realm explore]\n"; }
