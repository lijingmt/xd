#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=20;
protected void create(){
	name=object_name(this_object());
	name_cn="镜沙洲";
	desc="细沙映出两轮新月，这是所有幻境行者共享的中立镜湖猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/mirror_lake.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/mirror_spider.pike",48,40,5,36,3);
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/drowned_mirror_demon.pike",ROOT "/gamelib/clone/npc/illusion_s1/drowned_mirror_demon.pike",ROOT "/gamelib/clone/npc/illusion_s1/drowned_mirror_demon.pike"}));
}
