#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=56;
protected void create(){
	name=object_name(this_object());
	name_cn="北俱冻龄宫";
	desc="冰墙封着历代不老者舍弃的名字，最早一批刻痕里既有月主，也有晏孤峤。风雪正在等待一场迟到多年的师徒重逢。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/beiju_broken_oath.pike";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/frozen_judgment_hall.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/frozen_age_king.pike"}));
}
string query_links(){ return "[读取冻龄名册:illusion_realm witness]\n"; }
