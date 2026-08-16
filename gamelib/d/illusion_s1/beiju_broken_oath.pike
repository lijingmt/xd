#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=54;
protected void create(){
	name=object_name(this_object());
	name_cn="北俱断誓坡";
	desc="半条红巾冻在雪坡上。有人并非忘了兄弟才背盟，恰恰因为还记得另一个至亲，才在两份情义之间走错一步。\n";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/beiju_longlife_waste.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/beiju_frozen_palace.pike";
}
string query_links(){ return "[拾起红巾留别:illusion_realm witness]\n"; }
