#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="南瞻司寿使";
	desc="黑金官袍由无数人的寿数丝线织成，他把每次夺寿都说成公平交易。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=9; _boss=1; _flushtime=45; setup_npc();
}
