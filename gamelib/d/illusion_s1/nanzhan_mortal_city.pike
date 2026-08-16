#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=8;
protected void create(){
	name=object_name(this_object());
	name_cn="南瞻尘城";
	desc="名榜、利市与姻缘灯挤在同一条长街上。人们忙着为短暂一生争取更多，却很少有人停下来问生死究竟是什么。\n";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/moon_gate.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/nanzhan_life_death_temple.pike";
}
string query_links(){ return "[阅读月诏残响:illusion_realm witness]\n"; }
