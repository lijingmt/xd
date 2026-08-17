#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="第四影灯奴";
	desc="它没有自己的影子，只借祝无晷的灯火替伪造残方遮掩真正的书写次序。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=78; _flushtime=15; setup_npc();
}
