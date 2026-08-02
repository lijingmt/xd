#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位携星盘、披深蓝长袍的中立观星者，专门传授天象法门。\n";
	set_raceId("third");
	set_profeId("tianxiang");
	sex="female";
	gender="女";
	picture="tianxiang_female";
	_npcLevel=80;
	name_cn="天象导师";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me)
		return ::query_words();
	s += ::query_words();
	if(me->query_profeId()=="tianxiang"){
		s += name_cn+"说道：不同攻击法术命中会凝聚星痕，最多三层，十五秒内有效。\n";
		s += "星落会消耗全部星痕换取受控爆发；换房、脱战、死亡或离线都会清空星痕。\n";
	}
	else
		s += name_cn+"说道：观星御法之术，只传天象门下。\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);
	if(me->query_profeId()=="tianxiang")
		return ::query_npc_links(count)+
			"[学习天象技能:buy_items book tianxiang]\n";
	return ::query_npc_links(count);
}
