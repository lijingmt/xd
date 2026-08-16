#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="镜丝月蛛";
	desc="它把湖面的倒影织成锋利蛛网。\n";
	set_raceId("monst"); set_profeId("humanlike");
	_npcLevel=20; _flushtime=20; setup_npc();
}
