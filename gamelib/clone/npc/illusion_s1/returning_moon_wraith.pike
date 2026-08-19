#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

int query_illusion_combat_mechanic(){ return 1; }

protected void create()
{
	name=object_name(this_object());
	name_cn="归真月魇";
	desc="它由月主散去后未归位的执念凝成，会映照修行者当下的境界。\n";
	set_raceId("monst");
	set_profeId("humanlike");
	_npcLevel=69;
	_flushtime=20;
	setup_npc();
}
