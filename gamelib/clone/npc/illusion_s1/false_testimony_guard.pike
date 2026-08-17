#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="伪证雪卫";
	desc="它把逐徒令、逃亡录与冰墙刻痕重新排列，替冻宫守护一份精心拼出的假证词。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=58; _flushtime=15; setup_npc();
}
