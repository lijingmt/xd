#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="沉月镜妖";
	desc="它从镜湖最甜美的假梦中爬出，试图让每个追问真相的人留在倒影里。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=38; _flushtime=15; setup_npc();
}
