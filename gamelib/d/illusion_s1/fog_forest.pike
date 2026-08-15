#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=18;
protected void create(){
	name=object_name(this_object());
	name_cn="雾语林";
	desc="林雾会随击杀方向流动，独行者与队伍看到的是同一片真实树林。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/silver_path.pike";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/mirror_lake.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/fog_wolf.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/fog_wolf.pike"}));
}
