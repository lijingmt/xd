#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;

string room_race="third";
protected int room_level=69;

protected void create()
{
	name=object_name(this_object());
	name_cn="归真问心台";
	desc="石台不再追问长生，只把每一次战斗映成修行者自己的答案。\n";
	dongtai_npc_start_level=69;
	exits["east"]=ROOT "/gamelib/d/illusion_s1/returning_star_pass.pike";
	configure_autofight_training_population(ROOT+
		"/gamelib/clone/npc/illusion_s1/returning_moon_wraith.pike",
		20,18,5,20,3);
}
