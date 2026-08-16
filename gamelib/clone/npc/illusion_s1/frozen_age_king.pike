#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="北俱冻龄王";
	desc="他以影奴替不老者承受衰亡，坚信只要代价落在看不见的人身上，长生便算无罪。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=56; _boss=1; _flushtime=50; setup_npc();
}
