#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="忘日冰魇";
	desc="它吞下不老者被抽走的昨日，以熟悉却叫不出名字的声音在风雪中徘徊。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=48; _flushtime=15; setup_npc();
}
