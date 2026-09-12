#!/usr/bin/env pike
/** 建议7批D-5回归：帮贡商店 解锁→兑换→限购→账目守恒。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

object create_player(string userid,string race_id,string profession_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = "帮贡商店测试"+userid;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

int count_items(object player,string item_name)
{
	int count = 0;
	foreach(all_inventory(player),object item)
		if(item->query_name()==item_name)
			count += (int)(item->amount>0 ? item->amount : 1);
	return count;
}

int main()
{
	object original_player = this_player();
	object|zero member = 0;
	string error_desc = "";
	mixed err = catch {
		member = create_player("__testunit_shop_a__","human","jianxian");
		member->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		BANGPAI_EXTD->set_state_file_for_test(1);
		member->bangid = 15;
		set_this_player(member);

		// 1级帮派商店未解锁。
		mapping locked = BANGPAI_EXTD->buy_bang_shop_item(
			member,"cuilianshi",1);
		check("帮派等级不足3级时商店未开放",
			!(int)locked["ok"] &&
			search((string)locked["message"],"3级")!=-1,
			sprintf("result=%O",locked));

		// 升到3级并注入帮贡：捐献25万（250帮贡）+BOSS渠道340。
		member->set_account(250000);
		BANGPAI_EXTD->donate(member,250000);
		BANGPAI_EXTD->add_contribution(15,
			(string)member->query_name(),340,"boss");
		int contrib_start = BANGPAI_EXTD->query_contribution(member);
		check("注入后帮贡590且商店解锁",
			contrib_start==590 &&
			BANGPAI_EXTD->query_gang_shop_unlocked(15),
			"contrib="+contrib_start);

		// 正常兑换：淬炼石30帮贡/件×5。
		mapping buy = BANGPAI_EXTD->buy_bang_shop_item(
			member,"cuilianshi",5);
		check("兑换5颗淬炼石扣150帮贡且物品真实入包",
			(int)buy["ok"] && (int)buy["granted"]==5 &&
			count_items(member,"cuilianshi")==5 &&
			BANGPAI_EXTD->query_contribution(member)==
				contrib_start-150,
			sprintf("buy=%O have=%d contrib=%d",
				buy,count_items(member,"cuilianshi"),
				BANGPAI_EXTD->query_contribution(member)));

		// 限购：今日已兑5/10，再兑6件被拒且不扣帮贡。
		int before_over = BANGPAI_EXTD->query_contribution(member);
		mapping over = BANGPAI_EXTD->buy_bang_shop_item(
			member,"cuilianshi",6);
		check("超出每日限购被拒绝且帮贡不变",
			!(int)over["ok"] &&
			BANGPAI_EXTD->query_contribution(member)==before_over,
			sprintf("result=%O",over));

		// 守护符：120帮贡×2=240，余额250刚好够。
		mapping charm = BANGPAI_EXTD->buy_bang_shop_item(
			member,"tilianshouhufu",2);
		check("兑换2张提炼守护符扣240帮贡",
			(int)charm["ok"] &&
			count_items(member,"tilianshouhufu")==2 &&
			BANGPAI_EXTD->query_contribution(member)==
				before_over-240,
			sprintf("charm=%O count=%d contrib=%d",
				charm,count_items(member,"tilianshouhufu"),
				BANGPAI_EXTD->query_contribution(member)));

		// 余额不足：剩200帮贡，离火玉5件需300（限购允许）。
		mapping poor = BANGPAI_EXTD->buy_bang_shop_item(
			member,"lihuoyu",5);
		check("帮贡不足时兑换被拒绝",
			!(int)poor["ok"] &&
			search((string)poor["message"],"帮贡不足")!=-1,
			sprintf("result=%O",poor));

		// 未知商品。
		mapping unknown = BANGPAI_EXTD->buy_bang_shop_item(
			member,"nosuchitem",1);
		check("未知商品被拒绝",
			!(int)unknown["ok"],
			sprintf("result=%O",unknown));

		// 页面含限购进度与商品。
		string page = BANGPAI_EXTD->query_bang_shop_page(member);
		check("商店页展示商品与今日限购进度",
			search(page,"淬炼石")!=-1 &&
			search(page,"离火玉")!=-1 &&
			search(page,"提炼守护符")!=-1 &&
			search(page,"5/10")!=-1 &&
			search(page,"2/2")!=-1,
			"page="+page);

		BANGPAI_EXTD->set_state_file_for_test(0);
		rm(DATA_ROOT+"bangpai/ext_state.json.test");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("帮贡商店流程无异常",0,error_desc);
	else
		check("帮贡商店流程无异常",1,"");
	destroy_player(member);
	werror("[帮贡商店] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
