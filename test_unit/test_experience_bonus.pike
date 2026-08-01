#!/usr/bin/env pike
/** 打怪经验药品、活动、捐赠和界面加成的统一叠加回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	werror("\n[经验加成 %d] %s\n",results["total"],name);
	if(valid){
		results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

object create_test_player()
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name("__testunit_exp_bonus__");
	player->name_cn = "经验加成测试人物";
	player->level = 1;
	player->exp = 0;
	player->current_exp = 0;
	player->all_fee = 0;
	player->is_http_api_user = 0;
	return player;
}

void test_donation_tiers(object player)
{
	int valid =
		player->query_donation_exp_multiplier_for_fee(0)==1 &&
		player->query_donation_exp_multiplier_for_fee(199)==1 &&
		player->query_donation_exp_multiplier_for_fee(200)==2 &&
		player->query_donation_exp_multiplier_for_fee(400)==3 &&
		player->query_donation_exp_multiplier_for_fee(600)==4 &&
		player->query_donation_exp_multiplier_for_fee(800)==5 &&
		player->query_donation_exp_multiplier_for_fee(1000)==6 &&
		player->query_donation_exp_multiplier_for_fee(1200)==8 &&
		player->query_donation_exp_multiplier_for_fee(1400)==10 &&
		player->query_donation_exp_multiplier_for_fee(1600)==20 &&
		player->query_donation_exp_multiplier_for_fee(3200)==30 &&
		player->query_donation_exp_multiplier_for_fee(6400)==40 &&
		player->query_donation_exp_multiplier_for_fee(12800)==50 &&
		player->query_donation_exp_multiplier_for_fee(999999)==50;
	check("所有捐赠档位返回标称总倍数",valid,
		"捐赠临界值或最高50倍封顶错误");
}

void test_final_total_multiplier(object player)
{
	mapping reward = player->calculate_kill_exp_reward(100,50,2,2);
	int valid = reward["base_exp"]==100 &&
		reward["buff_bonus"]==50 &&
		reward["event_bonus"]==150 &&
		reward["donation_bonus"]==300 &&
		reward["donation_multiplier"]==2 &&
		reward["stacked_exp"]==600;
	check("捐赠2倍作用于药品和活动后的300点总经验",valid,
		"100基础+50%药品+2倍活动+2倍捐赠应为600");
}

void test_multiplier_semantics_and_edges(object player)
{
	mapping double_event = player->calculate_kill_exp_reward(100,0,2,1);
	mapping invalid = player->calculate_kill_exp_reward(100,-50,0,0);
	mapping zero = player->calculate_kill_exp_reward(0,100,2,50);
	mapping capped = player->calculate_kill_exp_reward(10,0,1,999);
	int valid = double_event["stacked_exp"]==200 &&
		double_event["event_bonus"]==100 &&
		invalid["stacked_exp"]==100 && zero["stacked_exp"]==0 &&
		capped["donation_multiplier"]==50 &&
		capped["stacked_exp"]==500;
	check("双倍语义、零经验、负加成和50倍上限安全",valid,
		"边界输入可能产生负数、额外一份基础经验或突破50倍");
}

void test_real_award_path(object player)
{
	player->all_fee = 200;
	int before_exp = player->exp;
	int before_current = player->current_exp;
	mapping reward = player->add_kill_exp_with_bonus(100,50,2);
	int valid = reward["donation_multiplier"]==2 &&
		reward["stacked_exp"]==600 && reward["actual_exp"]==600 &&
		reward["interface_bonus"]==0 &&
		player->exp-before_exp==600 &&
		player->current_exp-before_current==600;
	check("真实发放入口按统一链路一次性入账",valid,
		"实际经验入账与纯计算结果不一致或发生重复加成");
}

void test_single_team_wiring()
{
	string source = Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike") || "";
	int first_call = search(source,"grant_kill_experience(termer,exp_gain)");
	int second_call = search(source,"grant_kill_experience(first,exp_gain)");
	int valid = first_call!=-1 && second_call!=-1 &&
		search(source,"extra_dh")==-1 &&
		search(source,"GAME_AREA==\"xd01\"")==-1;
	check("组队和单人共用统一经验入口且所有逻辑区一致",valid,
		"仍残留基础经验叠加旧公式或按物理区区别计算");
}

int main()
{
	object player = create_test_player();
	werror("\n========== 打怪经验加成测试 ==========\n");
	if(!player){
		check("测试人物可创建",0,"GAMELIB_USER 创建失败");
		return 1;
	}
	test_donation_tiers(player);
	test_final_total_multiplier(player);
	test_multiplier_semantics_and_edges(player);
	test_real_award_path(player);
	test_single_team_wiring();
	destruct(player);
	werror("\n经验加成：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
