#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位无相无相、衣袍上绣着三才太极图的中立修士，专传补位万金油之道。\n";
	set_raceId("third");
	set_profeId("wuxiang");
	sex="male";
	gender="男";
	picture="wuxiang_male";
	_npcLevel=80;
	name_cn="无相先生";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me)
		return ::query_words();
	s += ::query_words();
	if(me->query_profeId()=="wuxiang"){
		s += name_cn+"说道：无相心法让最高属性的一半继续贡献其他属性。\n";
		s += "技能单看都不抢专精风头，价值在「同时拥有」的灵活度。\n";
	}
	else
		s += name_cn+"说道：无相之道，只传已通晓十职业精髓者。\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);
	if(me->query_profeId()=="wuxiang")
		return ::query_npc_links(count)+
			"[学习无相技能:buy_items book wuxiang]\n";
	return ::query_npc_links(count);
}
