#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位披玄甲、持山纹巨盾的中立守山人，专门传授镇越守御之道。\n";
	set_raceId("third");
	set_profeId("zhenyue");
	sex="male";
	gender="男";
	picture="humanlike_male";
	_npcLevel=80;
	name_cn="镇越守山人";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me)
		return ::query_words();

	s += ::query_words();
	if(me->query_profeId()=="zhenyue"){
		s += name_cn+"说道：镇越不以无敌自居，而以稳住敌势、护住同伴为先。\n";
		s += "先以震吼夺取仇恨，再用山河壁为同队抵挡伤害；独行时护盾同样会保护自己。\n";
	}
	else
		s += name_cn+"说道：镇山守御之法，只传镇越门下。\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);
	if(me->query_profeId()=="zhenyue")
		return ::query_npc_links(count)+
			"[学习镇越技能:buy_items book zhenyue]\n";
	return ::query_npc_links(count);
}
