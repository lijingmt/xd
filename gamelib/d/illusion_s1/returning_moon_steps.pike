#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;

string room_race="third";
protected int room_level=69;

protected void create()
{
	name=object_name(this_object());
	name_cn="归真月阶";
	desc="八十一章后的月光凝成石阶，归真月魇会映照来者当前境界。\n";
	dongtai_npc_start_level=69;
	exits["east"]=ROOT "/gamelib/d/illusion_s1/moon_gate.pike";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/returning_star_pass.pike";
	configure_autofight_training_population(ROOT+
		"/gamelib/clone/npc/illusion_s1/returning_moon_wraith.pike",
		20,18,5,20,3);
}
