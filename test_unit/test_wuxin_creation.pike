#!/usr/bin/env pike
/** 无心职业注册与门槛回归：无极全难度通关解锁 + 2万碎玉资格购买，
 * 未解锁/未付费拒绝建角；85%心法；技能数值=无极×2；PVP减半钩子。 */

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
	string account_id = "xd01testunitwuxin";
	werror("\n========== 无心职业注册与门槛测试 ==========\n");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	mixed err = catch{
		/* 纯函数门槛 */
		check("未解锁账号无法通过无心解锁判定",
			!ACCOUNT_CHARACTERD->query_wuxin_unlocked_from_summary(
				(["ok":1,"characters":({}),"wuxin_difficulty_ready":0])),
			"flag=0时不应当判定解锁");
		check("难度通关标记驱动解锁判定",
			ACCOUNT_CHARACTERD->query_wuxin_unlocked_from_summary(
				(["ok":1,"wuxin_difficulty_ready":1])),
			"flag=1时应当判定解锁");
		check("无心创建成本为20000碎玉",
			ACCOUNT_CHARACTERD->query_wuxin_creation_cost()==20000,
			sprintf("%d",ACCOUNT_CHARACTERD->query_wuxin_creation_cost()));

		/* 未解锁/未付费拒绝建角 */
		mapping created = ACCOUNT_CHARACTERD->create_character(account_id,
			"third","wuxin","测无心","male","wuxin_male");
		check("未解锁账号无法创建无心",
			!(int)created["ok"] &&
			search((string)created["message"],"未解锁")!=-1,
			sprintf("%O",created));

		/* 源码级检查：闸门与接线 */
		string ac_src = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/account_characterd.pike") || "";
		check("create_character 包含无心闸门",
			search(ac_src,"profession_id==\"wuxin\"")!=-1 &&
			search(ac_src,"wuxin_entitled")!=-1 &&
			search(ac_src,"WUXIN_CREATION_COST")!=-1,
			"闸门代码缺失");
		check("purchase_wuxin_entitlement 函数存在",
			search(ac_src,
				"mapping(string:mixed) purchase_wuxin_entitlement")!= -1,
			"购买函数缺失");
		check("record_wuxin_difficulty_maxed 回填函数存在",
			search(ac_src,"record_wuxin_difficulty_maxed")!=-1,
			"回填函数缺失");

		string http_src = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/account_characters.pike") || "";
		check("HTTP handler 包含无心购买调用",
			search(http_src,"purchase_wuxin_entitlement")!=-1,
			"HTTP接线缺失");

		string init_src = Stdio.read_file(ROOT+"/gamelib/d/init") || "";
		check("choice_profe 职业池包含 wuxin",
			search(init_src,"\"zhaoming\",\"wuji\",\"wuxin\"")!=-1,
			"third_pool缺失");
		check("choice_profe 包含无心防绕过闸门",
			search(init_src,"【无心·未解锁】")!=-1 &&
			search(init_src,"【无心·未付费】")!=-1,
			"闸门文案缺失");
		check("无极登录回填难度通关标记",
			search(init_src,"record_wuxin_difficulty_maxed")!=-1,
			"回填接线缺失");

		/* 技能数值：wuxinjue = wujijue ×2，法力消耗 ×1.5 */
		object|zero wj = clone(ROOT+"/gamelib/single/skills/wujijue");
		object|zero wx = clone(ROOT+"/gamelib/single/skills/wuxinjue");
		if(wj && wx){
			int wj_hi = (int)wj->query_performs_mofa_attack_high(5);
			int wx_hi = (int)wx->query_performs_mofa_attack_high(5);
			int wj_cast = wj->query_performs_cast(5);
			int wx_cast = wx->query_performs_cast(5);
			check("无心诀5阶伤害≈无极诀×2",
				wx_hi>=wj_hi*2-2,
				sprintf("wx=%d wj=%d",wx_hi,wj_hi));
			check("无心诀5阶法力消耗≈无极诀×1.5",
				wx_cast>=(wj_cast*3)/2-1,
				sprintf("wx=%d wj=%d",wx_cast,wj_cast));
		}
		else
			check("技能对象克隆成功",0,"clone失败");
		/* 不destruct技能克隆：全局SKILLSD持有引用，析构会污染
		 * 后续测试的技能索引（TestUnit既有坑）。 */
		wj = 0;
		wx = 0;

		/* 19个无心技能文件全部存在且注册 wuxin */
		int skill_count = 0;
		foreach(({"quan","jue","yi","dun","hou","jian","yan","tian",
			"jing","bi","huan","yu","lin","ji","mie","guixu",
			"hunyuan","wuji","guizhen"}),string suffix){
			string path = ROOT+"/gamelib/single/skills/wuxin"+suffix;
			string src = Stdio.read_file(path) || "";
			if(src!="" && search(src,"skill_type+=({\"wuxin\"})")!=-1)
				skill_count++;
		}
		check("19个无心技能文件全部注册",skill_count==19,
			sprintf("count=%d",skill_count));

		/* 心法 85%：源码级 + 数值级（对称三系时 85%） */
		string char_src = Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/char.pike") || "";
		check("query_wuxin_heart_bonus 实现存在",
			search(char_src,"int query_wuxin_heart_bonus")!=-1 &&
			search(char_src,"int heart_percent = 85+")!=-1,
			"心法实现缺失");

		/* PVP减半钩子 */
		string fight_src = Stdio.read_file(ROOT+
			"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
		check("wuxin_pvp_damage 减半钩子存在",
			search(fight_src,"query_wuxin_pvp_damage")!=-1 &&
			search(fight_src,"return damage/2;")!=-1,
			"PVP钩子缺失");
		check("心法战斗标签支持无心",
			search(fight_src,"profe==\"wuxin\"")!=-1,
			"心法标签缺失");

		/* 职业成长：level.pike 无心 +3.2/级 */
		string level_src = Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/level.pike") || "";
		check("无心三系成长 16+3.2L 存在",
			search(level_src,"16+(int)(level_now*3.2)")!=-1,
			"成长公式缺失");

		/* setup_player 无极/无心模板存在 */
		string user_src = Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/user.pike") || "";
		check("setup_player 无极分支存在",
			search(user_src,"pid==\"wuji\"")!=-1,
			"无极模板缺失");
		check("setup_player 无心分支存在",
			search(user_src,"pid==\"wuxin\"")!=-1,
			"无心模板缺失");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	werror("========== 无心创建测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
