#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="沉月镜主";
	desc="它把每个人最舍不得放弃的结局织成牢笼，再让被困者误以为那就是幸福。\n";
	set_raceId("monst"); set_profeId("humanlike");
	_npcLevel=46; _boss=1; _flushtime=45; setup_npc();
}
