#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位仙风道骨的方士，精通召唤之术，可以传授你方士的技能。\n";
	set_raceId("third");
	set_profeId("fangshi");
	sex="male";
	gender="男";
	picture="humanlike_male";
	_npcLevel=80;
	name_cn="方士传人";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me) return ::query_words();

	s += ::query_words();
	if(me->query_profeId() == "fangshi"){
		s += name_cn + "说道：方士之道，在于召唤灵兽助战。\n";
		s += "虎灵主攻击，鹤灵主治疗，龟灵主防御。\n";
		s += "三灵合一，则可发挥最大威力！\n";
	}
	else{
		s += name_cn + "说道：只有方士才能学习召唤之术。\n";
	}
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);

	if(me->query_profeId() == "fangshi")
		return ::query_npc_links(count) +
			"[学习方士技能:buy_items book fangshi]\n";
	return ::query_npc_links(count);
}
