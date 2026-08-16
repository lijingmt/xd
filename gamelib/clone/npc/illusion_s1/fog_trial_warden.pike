#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="雾誓守关者";
	desc="它以最渴望的圆满诱使旅人留下，唯有不再等待昨日批准的人能走出迷雾。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=27; _boss=1; _flushtime=45; setup_npc();
}
