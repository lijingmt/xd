#!/usr/bin/env pike
/** 建议7批D-1/D-2回归：跨阵营帮派列表 + 帮派建设/帮贡账本。 */

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
	player->name_cn = "帮派建设测试";
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

int main()
{
	object original_player = this_player();
	object|zero player = 0;
	string error_desc = "";
	mixed err = catch {
		player = create_player("__testunit_gang_build__",
			"human","jianxian");
		player->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		set_this_player(player);

		// 隔离状态：测试专用 .test 状态文件，不碰真实帮派账本。
		BANGPAI_EXTD->set_state_file_for_test(1);
		player->bangid = 7;

		// 未捐献时：1级、无加成、0帮贡。
		check("新帮派从1级起步且无经验加成",
			BANGPAI_EXTD->query_gang_level(7)==1 &&
			BANGPAI_EXTD->query_gang_exp_bonus_percent(player)==0 &&
			BANGPAI_EXTD->query_contribution(player)==0,
			sprintf("level=%d bonus=%d contrib=%d",
				BANGPAI_EXTD->query_gang_level(7),
				BANGPAI_EXTD->query_gang_exp_bonus_percent(player),
				BANGPAI_EXTD->query_contribution(player)));

		// 拒绝路径：金额过小、银两不足。
		player->set_account(100000);
		mapping too_small = BANGPAI_EXTD->donate(player,500);
		check("低于最小捐献额被拒绝且不扣钱",
			!(int)too_small["ok"] && player->query_account()==100000,
			sprintf("ok=%d account=%d",
				(int)too_small["ok"],player->query_account()));
		player->set_account(0);
		mapping no_money = BANGPAI_EXTD->donate(player,5000);
		check("银两不足被拒绝",
			!(int)no_money["ok"],
			"穷人也成功捐献");

		// 正常捐献：银两→建设度+帮贡，守恒可对账。
		player->set_account(60000);
		mapping ok_donate = BANGPAI_EXTD->donate(player,60000);
		int contrib_after = BANGPAI_EXTD->query_contribution(player);
		check("捐献60000银两换60建设度与60帮贡且银两清零",
			(int)ok_donate["ok"] && player->query_account()==0 &&
			contrib_after==60 &&
			(int)BANGPAI_EXTD->query_gang_summary(player)["exp"]==60000,
			sprintf("ok=%d account=%d contrib=%d",
				(int)ok_donate["ok"],player->query_account(),
				contrib_after));
		check("60000建设度恰升2级并解锁2%打怪经验",
			BANGPAI_EXTD->query_gang_level(7)==2 &&
			BANGPAI_EXTD->query_gang_exp_bonus_percent(player)==2 &&
			BANGPAI_EXTD->query_gang_boss_attempts_daily(7)==1 &&
			!BANGPAI_EXTD->query_gang_shop_unlocked(7),
			"等级或解锁状态错误");

		// 大额捐献：累计560000跨过500000门槛 → 4级（商店3级已解锁）。
		player->set_account(500000);
		BANGPAI_EXTD->donate(player,500000);
		check("累计560000建设度达到4级且3级帮贡商店已解锁",
			BANGPAI_EXTD->query_gang_level(7)==4 &&
			BANGPAI_EXTD->query_gang_shop_unlocked(7),
			"等级="+BANGPAI_EXTD->query_gang_level(7));

		// 每日捐献帮贡已满500：第三笔只入建设度，不再涨帮贡。
		player->set_account(500000);
		mapping capped = BANGPAI_EXTD->donate(player,500000);
		check("每日捐献帮贡封顶500但建设度全额入账",
			(int)capped["ok"] &&
			(int)capped["gained_contrib"]==0 &&
			BANGPAI_EXTD->query_contribution(player)==500 &&
			(int)BANGPAI_EXTD->query_gang_summary(player)["exp"]==
				1060000,
			sprintf("gained=%d contrib=%d exp=%d",
				(int)capped["gained_contrib"],
				BANGPAI_EXTD->query_contribution(player),
				(int)BANGPAI_EXTD->query_gang_summary(player)["exp"]));

		// 非捐献渠道的帮贡不受日上限（帮派BOSS/幻境走add_contribution）。
		BANGPAI_EXTD->add_contribution(7,(string)player->query_name(),
			300,"boss");
		check("BOSS渠道帮贡不受捐献日上限",
			BANGPAI_EXTD->query_contribution(player)==800,
			"contrib="+BANGPAI_EXTD->query_contribution(player));

		// 顶级边界：注入满级建设度验证8%加成与满级提示。
		mapping summary_max;
		{
			int saved = 0;
			// 直接用公开接口无法一步到位，改用连续大额捐献到10级门槛。
			for(int i=0;i<30 && BANGPAI_EXTD->query_gang_level(7)<10;i++){
				player->set_account(10000000);
				BANGPAI_EXTD->donate(player,10000000);
			}
			saved = BANGPAI_EXTD->query_gang_level(7)==10;
			summary_max = BANGPAI_EXTD->query_gang_summary(player);
			check("建设度堆到10级满级：8%经验、BOSS每日2次、幻境解锁",
				saved &&
				BANGPAI_EXTD->query_gang_exp_bonus_percent(player)==8 &&
				(int)summary_max["next_cost"]==0 &&
				BANGPAI_EXTD->query_gang_boss_attempts_daily(7)==2 &&
				BANGPAI_EXTD->query_gang_illusion_unlocked(7),
				sprintf("level=%d bonus=%d next=%d",
					BANGPAI_EXTD->query_gang_level(7),
					BANGPAI_EXTD->query_gang_exp_bonus_percent(player),
					(int)summary_max["next_cost"]));
		}

		// 经验加成真实生效：同基础经验下8级帮比无帮多8%。
		{
			player->bangid = 7;
			int gang_bonus =
				BANGPAI_EXTD->query_gang_exp_bonus_percent(player);
			mapping reward_no = player->calculate_kill_exp_reward(
				1000,gang_bonus,2,1);
			player->bangid = 0;
			mapping reward_zero = player->calculate_kill_exp_reward(
				1000,0,2,1);
			check("帮派8%加成进入击杀经验计算口径",
				gang_bonus==8 &&
				(int)reward_no["buff_bonus"]>
					(int)reward_zero["buff_bonus"],
				sprintf("bonus=%d with=%d without=%d",
					gang_bonus,(int)reward_no["buff_bonus"],
					(int)reward_zero["buff_bonus"]));
		}

		// 无帮派玩家不受影响。
		{
			object loner = create_player("__testunit_gang_loner__",
				"monst","kuangyao");
			check("无帮派玩家经验加成为0",
				BANGPAI_EXTD->query_gang_exp_bonus_percent(loner)==0,
				"无帮玩家拿到了加成");
			mapping loner_donate = BANGPAI_EXTD->donate(loner,5000);
			check("无帮派玩家不能捐献",
				!(int)loner_donate["ok"],
				"无帮玩家捐献成功");
			destroy_player(loner);
		}

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
		check("帮派建设流程无异常",0,error_desc);
	else
		check("帮派建设流程无异常",1,"");
	destroy_player(player);
	werror("[帮派建设] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
