#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=69;
protected void create(){
	name=object_name(this_object());
	name_cn="长生月炉";
	desc="炉中没有仙丹，只有万千姓名被揉成火光。一路提灯的祝无晷也在此等待摘下面具，让所有巧合显出人为安排的痕迹。\n";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/newmoon_altar.pike";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/true_name_hall.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/eclipse_priest.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/fourth_shadow_lamp_servant.pike",ROOT "/gamelib/clone/npc/illusion_s1/fourth_shadow_lamp_servant.pike",ROOT "/gamelib/clone/npc/illusion_s1/fourth_shadow_lamp_servant.pike"}));
}
string query_links(){ return "[查看长生月炉真相:illusion_realm witness]\n"; }
