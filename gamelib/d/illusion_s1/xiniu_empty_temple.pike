#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=27;
protected void create(){
	name=object_name(this_object());
	name_cn="西牛空经殿";
	desc="殿中长生经一字皆无，纸面却留着八十一处被刮去姓名的凹痕。月光照过时，它们像剑路一样重新相连。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/xiniu_scripture_market.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/empty_sutra_abbot.pike"}));
}
string query_links(){ return "[研读空白长生经:illusion_realm witness]\n"; }
