#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="无影司炉者";
	desc="一路提灯的祝无晷终于以司炉真身现世；所有援手与巧合，都是为了养成最后药引。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=68; _boss=2; _flushtime=60; setup_npc();
}
