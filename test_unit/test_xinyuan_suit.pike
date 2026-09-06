#!/usr/bin/env pike
/** 心渊套装（无心专属隐藏套装）回归：10件齐、无心限定、
 * 发放仅限无心、同槽防刷、boss/活动钩子接线。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

int main()
{
	werror("\n========== 心渊套装测试 ==========\n");
	mixed err = catch{
		/* 10件全部存在且标记心渊套装 */
		int pieces = 0;
		int suit_marked = 0;
		foreach(({"jian","guan","pao","ku","shou","xue","wan","jie",
			"lian","zhuo"}),string suffix){
			string path = ROOT+"/gamelib/clone/item/wuxinsuit/xinyuan"+
				suffix;
			string src = Stdio.read_file(path) || "";
			if(src!="")
				pieces++;
			if(search(src,"is_xinyuan_suit_piece")!=-1)
				suit_marked++;
		}
		check("心渊套装10件齐",pieces==10,
			sprintf("pieces=%d",pieces));
		check("10件全部标记心渊套装",suit_marked==10,
			sprintf("count=%d",suit_marked));

		/* 槽位路径反查覆盖10槽 */
		int slots = 0;
		foreach(({"single_main_weapon","armor_head","armor_cloth",
			"armor_thou","armor_hand","armor_shoes","armor_waste",
			"jewelry_ring","jewelry_neck","jewelry_bangle"}),
			string slot){
			if(ITEMSD->query_xinyuan_suit_piece_path(slot)!="")
				slots++;
		}
		check("槽位反查覆盖全部10槽",slots==10,
			sprintf("slots=%d",slots));

		/* 每件自带无心限定+禁交易（独立文件继承正确基类） */
		int wuxin_limited = 0;
		int no_trade = 0;
		int level300 = 0;
		foreach(({"jian","guan","pao","ku","shou","xue","wan","jie",
			"lian","zhuo"}),string suffix){
			string src = Stdio.read_file(ROOT+
				"/gamelib/clone/item/wuxinsuit/xinyuan"+suffix) || "";
			if(search(src,"set_item_profeLimit(\"wuxin\")")!=-1)
				wuxin_limited++;
			if(search(src,"set_item_canDrop(0)")!=-1 &&
			   search(src,"set_item_canTrade(0)")!=-1 &&
			   search(src,"set_item_canSend(0)")!=-1)
				no_trade++;
			if(search(src,"set_item_canLevel(300)")!=-1)
				level300++;
		}
		check("10件全部限定无心职业",wuxin_limited==10,
			sprintf("count=%d",wuxin_limited));
		check("10件全部禁丢弃/交易/赠送",no_trade==10,
			sprintf("count=%d",no_trade));
		check("10件全部要求300级",level300==10,
			sprintf("count=%d",level300));

		/* 发放钩子：boss + 活动 */
		string npc_src = Stdio.read_file(ROOT+
			"/gamelib/inherit/npc.pike") || "";
		check("boss掉落钩子存在",
			search(npc_src,"award_xinyuan_suit_piece")!=-1,
			"boss钩子缺失");
		string rt_src = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_timed_event_mod/runtime.pike") || "";
		check("活动奖励钩子存在",
			search(rt_src,"xinyuan_suit_drop")!=-1 &&
			search(rt_src,"award_xinyuan_suit_piece")!=-1,
			"活动钩子缺失");

		/* 发放对象克隆验证：属性与槽位 */
		object piece = clone(ROOT+
			"/gamelib/clone/item/wuxinsuit/xinyuanjian");
		check("心渊剑克隆并可读属性",
			objectp(piece) &&
			(string)piece->query_xinyuan_suit_slot()=="single_main_weapon",
			"克隆或槽位失败");
		if(piece)
			check("心渊剑三系附加=1500",
				(int)piece->query_str_add()==1500 &&
				(int)piece->query_dex_add()==1500 &&
				(int)piece->query_think_add()==1500,
				sprintf("str=%d",(int)piece->query_str_add()));
		object robe = clone(ROOT+
			"/gamelib/clone/item/wuxinsuit/xinyuanpao");
		if(robe)
			check("心渊袍防御=1200",
				(int)robe->query_equip_defend()==1200,
				sprintf("def=%d",(int)robe->query_equip_defend()));
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	werror("========== 心渊套装测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
