#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=38;
protected void create(){
	name=object_name(this_object());
	name_cn="折星台";
	desc="损坏的星仪仍在推演三条命途：寻星、破阵、同心。第二十三章前必须作出选择。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/mirror_lake.pike";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/echo_ruins.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/ruin_guard.pike"}));
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/unpriced_sutra_puppet.pike",ROOT "/gamelib/clone/npc/illusion_s1/unpriced_sutra_puppet.pike",ROOT "/gamelib/clone/npc/illusion_s1/unpriced_sutra_puppet.pike"}));
}
