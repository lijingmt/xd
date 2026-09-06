#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位超然物外的中立隐士，无极之上，仍有无心。渡尽八难，方见本心。\n";
	set_raceId("third");
	set_profeId("wuji");
	sex="female";
	gender="女";
	picture="wuji_female";
	_npcLevel=200;
	name_cn="无极尊者";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me)
		return ::query_words();
	s += ::query_words();
	if(me->query_profeId()=="wuji")
		s += name_cn+"说道：无极之上，仍有无心。渡尽八难，方见本心。\n";
	else
		s += name_cn+"说道：无极之道，不传外人。\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);
	if(me->query_profeId()=="wuji")
		return ::query_npc_links(count)+
			"[学习无极技能:buy_items book wuji]\n";
	return ::query_npc_links(count);
}
