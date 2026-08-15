#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="逐光月灵";
	desc="一团会追逐脚步的微弱月光。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=8; _flushtime=20; setup_npc();
}
