#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="断桥镇星使";
	desc="守桥首领会记录独行与同心两种完全不同的勇气。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=50; _boss=1; _flushtime=45; setup_npc();
}
