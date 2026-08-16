#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="冻宫雪审使";
	desc="他负责把逐徒、盗方与叛宗写成唯一版本的历史，从不允许被审判者留下自己的证词。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=54; _boss=1; _flushtime=50; setup_npc();
}
