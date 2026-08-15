#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="渊花异兽";
	desc="花瓣般的甲片覆盖着它的脊背。\n";
	set_raceId("monst"); set_profeId("humanlike");
	_npcLevel=58; _flushtime=20; setup_npc();
}
