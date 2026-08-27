#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;

string room_race="third";
protected int room_level=69;

protected void create()
{
	name=object_name(this_object());
	name_cn="归真虚园";
	desc="园中花木皆由虚空凝成，归真月魇在花影间映出修行者最初的模样。\n";
	dongtai_npc_start_level=69;
	exits["west"]=ROOT "/gamelib/d/illusion_s1/returning_dust_bridge.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/returning_moon_steps.pike";
	configure_autofight_training_population(ROOT+
		"/gamelib/clone/npc/illusion_s1/returning_moon_wraith.pike",
		20,18,5,20,3);
}
