#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=18;
protected void create(){
	name=object_name(this_object());
	name_cn="南瞻生死祠";
	desc="没有署名的绝笔铺满残破供桌。每封信都承认怕死，也都写着一件比多活几日更舍不得忘记的事。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/nanzhan_mortal_city.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/life_collector.pike"}));
}
string query_links(){ return "[阅读凡人绝笔:illusion_realm witness]\n"; }
