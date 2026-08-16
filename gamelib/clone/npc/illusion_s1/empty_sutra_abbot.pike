#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="西牛空经尊者";
	desc="他的经卷没有文字，门下弟子也没有旧名；所谓忘我，是把求道者先变成听话的空页。\n";
	set_raceId("third"); set_profeId("humanlike");
	_npcLevel=27; _boss=1; _flushtime=45; setup_npc();
}
