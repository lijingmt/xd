#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位气息内敛、衣袍上绣着阴阳太极图的中立修士，专传生死轮转之道。\n";
	set_raceId("third");
	set_profeId("taiji");
	sex="female";
	gender="女";
	picture="taiji_female";
	_npcLevel=200;
	name_cn="太极仙子";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me)
		return ::query_words();
	s += ::query_words();
	if(me->query_profeId()=="taiji"){
		s += name_cn+"说道：太极心法让最高属性的 65% 继续贡献其他属性；\n";
		s += "生生不息让你在致命边缘逆转，复阴能拉回同房同队的鬼魂队友。\n";
	}
	else
		s += name_cn+"说道：太极之道，只传已通晓十职业与无相精髓者。\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);
	if(me->query_profeId()=="taiji")
		return ::query_npc_links(count)+
			"[学习太极技能:buy_items book taiji]\n[复活队友:taiji_fuyin]\n";
	return ::query_npc_links(count);
}
