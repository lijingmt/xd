#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=18;
protected void create(){
	name=object_name(this_object());
	name_cn="月影林";
	desc="树冠筛下斑驳月影，这是所有幻境行者共享的中立雾林猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/fog_forest.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/fog_wolf.pike",20,18,5,20,3);
}
