#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=8;
protected void create(){
	name=object_name(this_object());
	name_cn="星辉坡";
	desc="低坡收拢了散落星辉，这是所有幻境行者共享的中立初猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/silver_path.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/moon_wisp.pike",20,18,5,20,3);
}
