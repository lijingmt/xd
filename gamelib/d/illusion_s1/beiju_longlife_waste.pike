#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=50;
protected void create(){
	name=object_name(this_object());
	name_cn="北俱不老荒原";
	desc="荒原居民千年不老，也千年不曾真正欢笑。他们以每日一段昨日抵偿肉身衰老，久到忘记为何要活。\n";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/echo_ruins.pike";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/beiju_broken_oath.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/forgotten_day_ice_wraith.pike",ROOT "/gamelib/clone/npc/illusion_s1/forgotten_day_ice_wraith.pike",ROOT "/gamelib/clone/npc/illusion_s1/forgotten_day_ice_wraith.pike"}));
}
string query_links(){ return "[聆听千年不老者:illusion_realm witness]\n"; }
