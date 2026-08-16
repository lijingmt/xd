#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=38;
protected void create(){
	name=object_name(this_object());
	name_cn="星仪石林";
	desc="石柱按旧星仪排列，这是所有幻境行者共享的中立折星猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/broken_observatory.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/ruin_guard.pike",20,18,5,20,3);
}
