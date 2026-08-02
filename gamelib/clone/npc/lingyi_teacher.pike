#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位佩草木药囊、衣袂带青白灵光的中立医者，专门传授灵医济世之道。\n";
	set_raceId("third");
	set_profeId("lingyi");
	sex="female";
	gender="女";
	picture="lingyi_female";
	_npcLevel=80;
	name_cn="灵医药师";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me)
		return ::query_words();
	s += ::query_words();
	if(me->query_profeId()=="lingyi"){
		s += name_cn+"说道：回春等单体术会优先救治同房间同队中生命比例最低者。\n";
		s += "未组队时只治疗自己；有效治疗可凝成药契，最多三层，二十秒内有效。\n";
	}
	else
		s += name_cn+"说道：辨药济世之法，只传灵医门下。\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	object me = this_player();
	if(!me)
		return ::query_npc_links(count);
	if(me->query_profeId()=="lingyi")
		return ::query_npc_links(count)+
			"[学习灵医技能:buy_items book lingyi]\n";
	return ::query_npc_links(count);
}
