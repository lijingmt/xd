#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=62;
protected void create(){
	name=object_name(this_object());
	name_cn="东胜扶桑坛";
	desc="朝生火照出寻星、破阵、同心三条命途。没有一条路能独自回答长生，所有选择却能在这里照见彼此。\n";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/dongsheng_morning_port.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/sunrise_guardian.pike"}));
}
string query_links(){ return "[让三途照心:illusion_realm witness]\n"; }
