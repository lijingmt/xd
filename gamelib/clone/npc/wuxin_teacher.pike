#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位超然物外的中立隐士，无心即本心。技能对怪物双倍，心法八五，四百之境由你开启。\n";
	set_raceId("third");
	set_profeId("wuxin");
	sex="female";
	gender="女";
	picture="wuxin_female";
	_npcLevel=300;
	name_cn="无心圣者";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me)
		return ::query_words();
	s += ::query_words();
	if(me->query_profeId()=="wuxin")
		s += name_cn+"说道：无心即本心。技能对怪物双倍，心法八五，四百之境由你开启。\n";
	else
		s += name_cn+"说道：无心之道，不传外人。\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);
	if(me->query_profeId()=="wuxin")
		return ::query_npc_links(count)+
			"[学习无心技能:buy_items book wuxin]\n";
	return ::query_npc_links(count);
}
