#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="月庭巡将";
	desc="月宫巡将守护着尚未凝实的套装虚影。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=65; _boss=1; _flushtime=45; setup_npc();
}
