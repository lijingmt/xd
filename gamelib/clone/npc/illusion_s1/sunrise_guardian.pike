#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="东胜朝生君";
	desc="他守护只燃一日的扶桑火，考验来者能否在必胜与救人之间主动放下捷径。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=62; _boss=1; _flushtime=50; setup_npc();
}
