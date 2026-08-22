#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=10;
protected void create(){
	name=object_name(this_object());
	name_cn="云松谷";
	desc="云气压低松梢，这是所有幻境行者共享的中立雾林猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/fog_forest.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/fog_wolf.pike",48,40,5,36,3);
}
