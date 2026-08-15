#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=28;
protected void create(){
	name=object_name(this_object());
	name_cn="倒月镜湖";
	desc="湖中倒月比天上的新月更圆，镜蛛沿着倒影编织出错误的道路。\n";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/fog_forest.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/broken_observatory.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/mirror_spider.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/mirror_spider.pike"}));
}
string query_links(){ return "[观察倒月:illusion_realm explore]\n"; }
