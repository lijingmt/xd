#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="无价经傀";
	desc="它奉命给每段修行标上价码，唯独无法理解不肯出售的那一页经文。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=28; _flushtime=15; setup_npc();
}
