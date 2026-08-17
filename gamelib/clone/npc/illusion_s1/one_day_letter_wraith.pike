#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;
protected void create(){
	name=object_name(this_object()); name_cn="朝暮信魇";
	desc="它专门撕毁活不过一日者写下的约定，嘲笑短暂生命不配拥有完整的开端与结尾。\n";
	set_raceId("third"); set_profeId("humanlike"); set_npc_type("illusion_sidequest");
	_npcLevel=68; _flushtime=15; setup_npc();
}
