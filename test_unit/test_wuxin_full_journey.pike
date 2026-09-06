#!/usr/bin/env pike
/** 无心 0→400 级全路线集成测试：建角门槛→成长曲线→技能数值→
 * 400级解锁→套装发放→PVE/PVP伤害分层。 */

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
	string account_id = "xd01testunitwxj";
	werror("\n========== 无心0→400级全路线集成测试 ==========\n");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	mixed err = catch{
		object seed = clone(GAMELIB_USER);
		seed->set_name(account_id);
		seed->set_password("testunitwxj");
		seed->set_project("gamelib");
		seed->set_userip("testunit-wxj");
		seed->name_cn = "无心全路线测试";
		seed->set_raceId("human");
		seed->set_profeId("jianxian");
		seed->setup_player("human","jianxian");
		seed->save_with_result();
		destruct(seed);

		/* 0) 先建普通角色建立账号索引，并完成职业初始化
		 * （未初始化的人物会阻塞后续建角）。 */
		mapping idx = ACCOUNT_CHARACTERD->create_character(
			account_id,"human","jianxian",
			"无心甲"+time()%100,"male","h_male1");
		check("0a.测试账号索引就绪",(int)idx["ok"]==1,
			sprintf("%O",idx));
		if((int)idx["ok"]){
			string seed_cid =
				(string)idx["character"]["id"];
			object boot = clone(GAMELIB_USER);
		boot->set_name(seed_cid);
			boot->set_password("testunitwxj");
			boot->set_project("gamelib");
			boot->set_userip("testunit-wxj");
			boot->name_cn = "无心引路人";
			boot->set_raceId("human");
			boot->set_profeId("jianxian");
			boot->setup_player("human","jianxian");
			boot->save_with_result();
			destruct(boot);
		}

		/* 1) 建角：未解锁拒绝 */
		mapping blocked = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","wuxin","无心乙","male","wuxin_male");
		check("1.未解锁建角被拒",!(int)blocked["ok"] &&
			search((string)blocked["message"],"未解锁")!=-1,
			sprintf("%O",blocked));

		/* 2) 解锁+付费后建角成功 */
		ACCOUNT_CHARACTERD->record_wuxin_difficulty_maxed(account_id);
		ACCOUNT_CHARACTERD->record_wuxin_entitlement_for_test(account_id);
		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","wuxin",
			"无心路"+time()%100,"male","wuxin_male");
		check("2.解锁+付费后建角成功",(int)created["ok"]==1,
			sprintf("%O",created));

		/* 3) 成长曲线：1级/100级/300级/400级三系值 */
		object wuxin_char = clone(GAMELIB_USER);
		wuxin_char->set_name(account_id+"ctestwxj");
		wuxin_char->set_password("testunitwxj");
		wuxin_char->set_project("gamelib");
		wuxin_char->set_raceId("third");
		wuxin_char->set_profeId("wuxin");
		wuxin_char->set_account_owner(account_id);
		wuxin_char->setup_player("third","wuxin");
		/* 对称三系时总str = base(16+3.2×L) + 心法85% */
		int expected_total(int lv){
			int base = 16+(int)((lv-1)*3.2);
			return base+base*85/100;
		}
		int lv1 = wuxin_char->query_str();
		check("3a.1级总str≈29(base16+心法13)",
			lv1>=27 && lv1<=31,
			sprintf("str=%d",lv1));
		wuxin_char->level = 100;
		wuxin_char->set_att_by_level();
		int lv100 = wuxin_char->query_str();
		check("3b.100级总str符合曲线",
			lv100>=expected_total(100)-3 &&
			lv100<=expected_total(100)+3,
			sprintf("str=%d exp=%d",lv100,expected_total(100)));
		wuxin_char->level = 300;
		wuxin_char->set_att_by_level();
		int lv300 = wuxin_char->query_str();
		check("3c.300级总str符合曲线",
			lv300>=expected_total(300)-3 &&
			lv300<=expected_total(300)+3,
			sprintf("str=%d exp=%d",lv300,expected_total(300)));
		wuxin_char->level = 400;
		wuxin_char->set_att_by_level();
		int lv400_base = 16+(int)(399*3.2);
		int lv400 = wuxin_char->query_str();
		check("3d.400级总str符合曲线",
			lv400>=lv400_base+lv400_base*85/100-3 &&
			lv400<=lv400_base+lv400_base*85/100+3,
			sprintf("str=%d exp=%d",lv400,
				lv400_base+lv400_base*85/100));

		/* 4) 心法85%：对称三系时 bonus = highest×85% */
		int heart_bonus = wuxin_char->query_wuxin_heart_bonus("str");
		check("4.心法85%生效",
			heart_bonus>=(lv400_base*85)/100-2,
			sprintf("bonus=%d expected~%d",
				heart_bonus,(lv400_base*85)/100));

		/* 5) 技能：wuxinjue = wujijue ×2 */
		object wj = clone(ROOT+"/gamelib/single/skills/wujijue");
		object wx = clone(ROOT+"/gamelib/single/skills/wuxinjue");
		int wj_dmg = (int)wj->query_performs_mofa_attack_high(5);
		int wx_dmg = (int)wx->query_performs_mofa_attack_high(5);
		check("5.无心诀5阶=无极诀×2",
			wx_dmg>=wj_dmg*2-2,
			sprintf("wx=%d wj=%d",wx_dmg,wj_dmg));

		/* 6) 400级解锁：无心到300级触发账号flag */
		wuxin_char->level = 300;
		wuxin_char->query_if_levelup_trigger_for_test();
		check("6.300级触发400上限flag",
			ACCOUNT_CHARACTERD->
				query_account_level_cap_400(account_id)==1,
			"flag未设置");

		/* 7) 套装发放 */
		mapping suit = ITEMSD->award_xinyuan_suit_piece(
			wuxin_char,"single_main_weapon","integration");
		check("7.套装发放给无心成功",(int)suit["ok"]==1,
			sprintf("%O",suit));
		mapping suit_dup = ITEMSD->award_xinyuan_suit_piece(
			wuxin_char,"single_main_weapon","integration");
		check("7b.同槽重复发放被拒",
			(string)suit_dup["code"]=="already_owned",
			sprintf("%O",suit_dup));

		/* 8) PVE/PVP 分层：源码级双重确认 */
		string fight_src = Stdio.read_file(ROOT+
			"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
		int pvp_hooks = 0;
		int pos = 0;
		while((pos = search(fight_src,"query_wuxin_pvp_damage(",pos))!=-1){
			pvp_hooks++;
			pos += 10;
		}
		check("8.PVP减半钩子≥5处(1定义+4调用)",pvp_hooks>=5,
			sprintf("hooks=%d",pvp_hooks));

		destruct(wuxin_char);
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	werror("========== 无心全路线测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
