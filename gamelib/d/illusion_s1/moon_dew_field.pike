#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=1;
protected void create(){
	name=object_name(this_object());
	name_cn="月露原";
	desc="月露沿草叶铺开，这是所有幻境行者共享的中立初猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/silver_path.pike";
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/moon_wisp.pike",48,40,5,36,3);
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/nameless_ink_wraith.pike",ROOT "/gamelib/clone/npc/illusion_s1/nameless_ink_wraith.pike",ROOT "/gamelib/clone/npc/illusion_s1/nameless_ink_wraith.pike"}));
}
