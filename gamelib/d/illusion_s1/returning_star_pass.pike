#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;

string room_race="third";
protected int room_level=69;

protected void create()
{
	name=object_name(this_object());
	name_cn="归真星隘";
	desc="碎星在狭长山隘间重新排列，给完成长生劫的人留下继续精进之路。\n";
	dongtai_npc_start_level=69;
	exits["east"]=ROOT "/gamelib/d/illusion_s1/returning_moon_steps.pike";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/returning_heart_terrace.pike";
	configure_autofight_training_population(ROOT+
		"/gamelib/clone/npc/illusion_s1/returning_moon_wraith.pike",
		20,18,5,20,3);
}
