#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;

string room_race="third";
protected int room_level=69;

protected void create()
{
	name=object_name(this_object());
	name_cn="归真尘桥";
	desc="一座横跨月尘的长桥，桥上归真月魇以尘为形、以心为刃。\n";
	dongtai_npc_start_level=69;
	exits["west"]=ROOT "/gamelib/d/illusion_s1/returning_dawn_pavilion.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/returning_void_garden.pike";
	configure_autofight_training_population(ROOT+
		"/gamelib/clone/npc/illusion_s1/returning_moon_wraith.pike",
		20,18,5,20,3);
}
