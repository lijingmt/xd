#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
int query_illusion_combat_mechanic(){ return 1; }
protected void create(){
	name=object_name(this_object()); name_cn="雾纹月狼";
	desc="背脊上的雾纹会在扑击前亮起。\n";
	set_raceId("monst"); set_profeId("humanlike");
	_npcLevel=10; _flushtime=20; setup_npc();
}
