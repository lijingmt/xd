#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=40;
protected void create(){
	name=object_name(this_object());
	name_cn="古城广场";
	desc="残旗围住空旷广场，这是所有幻境行者共享的中立古城猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/echo_ruins.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/star_wraith.pike",48,40,5,36,3);
}
