#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=50;
protected void create(){
	name=object_name(this_object());
	name_cn="深月谷";
	desc="谷底承接最深的月色，这是所有幻境行者共享的中立深渊猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/abyss_garden.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/abyss_beast.pike",20,18,5,20,3);
}
