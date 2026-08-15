#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="古城星魇";
	desc="一段被古城反复记住的战斗残影。\n";
	set_raceId("monst"); set_profeId("humanlike");
	_npcLevel=45; _flushtime=20; setup_npc();
}
