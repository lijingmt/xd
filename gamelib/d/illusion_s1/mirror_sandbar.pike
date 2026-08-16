#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=28;
protected void create(){
	name=object_name(this_object());
	name_cn="镜沙洲";
	desc="细沙映出两轮新月，这是所有幻境行者共享的中立镜湖猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/mirror_lake.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/mirror_spider.pike",20,18,5,20,3);
}
