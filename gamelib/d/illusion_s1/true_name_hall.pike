#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=69;
protected void create(){
	name=object_name(this_object());
	name_cn="归真名殿";
	desc="八十一章见过的姓名化作星点悬在殿中。把它们逐一念回，众生才不再只是长生方上的一味材料。\n";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/moon_immortality_furnace.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/fourth_shadow_lamp_servant.pike",ROOT "/gamelib/clone/npc/illusion_s1/fourth_shadow_lamp_servant.pike",ROOT "/gamelib/clone/npc/illusion_s1/fourth_shadow_lamp_servant.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/nameless_moon_attendant.pike",ROOT "/gamelib/clone/npc/illusion_s1/nameless_moon_attendant.pike",ROOT "/gamelib/clone/npc/illusion_s1/nameless_moon_attendant.pike"}));
}
string query_links(){ return "[归还众生真名:illusion_realm witness]\n"; }
