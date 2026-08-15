#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="折星石卫";
	desc="石卫用残缺星盘判断来者的命途。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=38; _flushtime=20; setup_npc();
}
