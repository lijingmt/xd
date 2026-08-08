#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit GAMELIB_NPC;

protected void create(){
	name=object_name(this_object());
	desc="一位手持玉简的仙官，专司试炼武勋兑换事务。\n";
	set_raceId("third");
	set_profeId("humanlike");
	sex="male";
	gender="男";
	picture="3";
	_npcLevel=120;
	name_cn="试炼仙官";
	setup_npc();
}

string query_words(){
	string s = "";
	object me = this_player();
	if(!me) return ::query_words();
	s += ::query_words();
	s += name_cn+"说道：归墟境与万象林的硬 Boss 倒下后会掉落试炼武勋。\n";
	s += "队伍需 4 人以上才能挑战；伤害极高，必须有镇越拉住仇恨、灵医持续治疗。\n";
	s += "武勋可换：\n";
	s += "  10 武勋 → 金币×10000\n";
	s += "  30 武勋 → 90级蓝色装备\n";
	s += "  50 武勋 → 【特】化神丹×5\n";
	s += "  80 武勋 → 110级紫色装备\n";
	s += "  100 武勋 → 金币×5000（可购买灵兽饲料）\n";
	s += "  200 武勋 → 110级金色装备\n";
	s += "  500 武勋 → 太极/无相隐藏书随机 1 本\n";
	s += TASKD->query_words(me,this_object());
	return s;
}

string query_npc_links(void|int count){
	return ::query_npc_links(count)+
		"[兑换金币:shilian_duihuan 1 lingshi]\n"+
		"[兑换90级蓝装:shilian_duihuan 1 blue90]\n"+
		"[兑换化神丹:shilian_duihuan 1 dan]\n"+
		"[兑换110级紫装:shilian_duihuan 1 purple110]\n"+
		"[兑换饲料金币:shilian_duihuan 1 feed]\n"+
		"[兑换110级金装:shilian_duihuan 1 gold110]\n"+
		"[兑换隐藏书:shilian_duihuan 1 hidden]\n";
}
