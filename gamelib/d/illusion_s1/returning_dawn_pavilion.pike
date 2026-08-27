#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;

string room_race="third";
protected int room_level=69;

protected void create()
{
	name=object_name(this_object());
	name_cn="归真晓亭";
	desc="晨光在亭檐凝成剑意，归真月魇的残影在此处化作磨砺心性的对手。\n";
	dongtai_npc_start_level=69;
	exits["west"]=ROOT "/gamelib/d/illusion_s1/returning_heart_terrace.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/returning_dust_bridge.pike";
	configure_autofight_training_population(ROOT+
		"/gamelib/clone/npc/illusion_s1/returning_moon_wraith.pike",
		20,18,5,20,3);
}
