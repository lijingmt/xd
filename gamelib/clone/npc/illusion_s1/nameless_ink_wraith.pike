#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="无名墨魇";
	desc="它由被刮去的姓名与烧剩的残墨凝成，死守着不肯归还的凡人名册。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=8; _flushtime=15; setup_npc();
}
