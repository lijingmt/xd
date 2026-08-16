#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=18;
protected void create(){
	name=object_name(this_object());
	name_cn="雾林半药营";
	desc="一堆不会被雾打湿的旧篝火留在林间，旁边摆着半只药碗与褪色红巾。没有香案的结义反而记得最久。\n";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/fog_forest.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/fog_trial_warden.pike"}));
}
string query_links(){ return "[重温半碗药之盟:illusion_realm witness]\n"; }
