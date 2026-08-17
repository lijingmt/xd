#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="雾誓残影";
	desc="它把一句誓言拆成真假两半，引诱同行者只记得对自己有利的部分。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=18; _flushtime=15; setup_npc();
}
