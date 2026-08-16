#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=45;
protected void create(){
	name=object_name(this_object());
	name_cn="回声古城";
	desc="城墙会复述上一场战斗的余音，却不会复制任何一件已经归属玩家的装备。\n";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/broken_observatory.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/star_bridge.pike";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/beiju_longlife_waste.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/star_wraith.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/star_wraith.pike"}));
}
