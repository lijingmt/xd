#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="空名月侍";
	desc="它替月主抹去众生名册上的牺牲者，只留下无人需要承担的空白称号。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=88; _flushtime=15; setup_npc();
}
