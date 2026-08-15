#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="S1归真月主";
	desc="它不是终点，而是幻境人物带着所得返回真实世界前的最后证明。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=69; _boss=2; _flushtime=60; setup_npc();
}
