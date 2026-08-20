#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit GAMELIB_NPC;

protected void create()
{
	name=object_name(this_object());
	name_cn="混沌兽王";
	desc="它由力量、灵识与身法失衡后凝成，三张面孔不断争夺同一具躯体。\n";
	set_raceId("third");
	set_profeId("humanlike");
	picture="wuxiang_logo";
	_npcLevel=100;
	_boss=2;
	_flushtime=3600;
	set_base_str(650);
	set_base_dex(650);
	set_base_think(650);
	set_base_life(2000000);
	this_object()->query_life_max();
	set_base_baoji(10);
	set_base_hitte(100);
	set_base_dodge(12);
	setup_npc();
	set_heart_beat(1);
}

string query_words()
{
	string s=::query_words();
	s += "混沌兽王咆哮道：偏执一象者，终将为万象所吞。\n";
	return s;
}

string query_links(void|int count)
{
	return ::query_links(count);
}

void fight_die()
{
	::fight_die();
}
