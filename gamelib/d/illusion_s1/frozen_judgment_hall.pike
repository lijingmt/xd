#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=54;
protected void create(){
	name=object_name(this_object());
	name_cn="冻宫雪审殿";
	desc="被篡改的逐徒旧案刻满天幕。只有把绝笔、宗印、冰墙名册与镜湖残图同时带到这里，真相才不会再由胜者单独书写。\n";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/beiju_frozen_palace.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/frost_inquisitor.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/false_testimony_guard.pike",ROOT "/gamelib/clone/npc/illusion_s1/false_testimony_guard.pike",ROOT "/gamelib/clone/npc/illusion_s1/false_testimony_guard.pike"}));
}
