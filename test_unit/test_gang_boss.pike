#!/usr/bin/env pike
/** 建议7批D-3回归：帮派BOSS 召唤→跨阵营助战→伤害排行→结算奖励。 */

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
	player->name_cn = "帮派BOSS测试"+userid;
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
	object|zero leader = 0;
	object|zero member = 0;
	object|zero outsider = 0;
	object|zero boss_npc = 0;
	string error_desc = "";
	mixed err = catch {
		leader = create_player("__testunit_boss_lead__","human","jianxian");
		member = create_player("__testunit_boss_mate__","monst","kuangyao");
		outsider = create_player("__testunit_boss_out__","human","jianxian");
		leader->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		member->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		outsider->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		BANGPAI_EXTD->set_state_file_for_test(1);
		BANGPAI_EXTD->set_bang_gate_for_test(1);
		leader->bangid = 9;
		member->bangid = 9;
		outsider->bangid = 8;
		set_this_player(leader);

		// 召唤：低等级帮派每日1次；BOSS落地演武场。
		mapping summon = BANGPAI_EXTD->summon_bang_boss(leader,200000000);
		boss_npc = BANGPAI_EXTD->query_bang_boss_npc(9);
		check("帮主召唤BOSS成功且BOSS在演武场中",
			(int)summon["ok"] && objectp(boss_npc) &&
			search(file_name(environment(boss_npc)),
				"/gamelib/d/bangpai/yanchang")!=-1,
			sprintf("ok=%d npc=%O env=%O",(int)summon["ok"],
				boss_npc,boss_npc ? environment(boss_npc) : 0));

		// 跨阵营成员与门外汉的攻击门禁。
		check("本帮成员（含跨阵营）可攻击BOSS，外人被拒",
			boss_npc->can_be_attacked(leader) &&
			boss_npc->can_be_attacked(member) &&
			!boss_npc->can_be_attacked(outsider),
			"帮派门禁判定错误");

		// 模拟战斗伤害：flush_targets 回调入实时账本。
		boss_npc->flush_targets(member,4000);
		boss_npc->flush_targets(leader,6000);
		boss_npc->flush_targets(outsider,99999);
		mapping damage = BANGPAI_EXTD->query_bang_boss_damage(9);
		check("伤害只记本帮成员且跨阵营成员照常入账",
			(int)damage["__testunit_boss_lead__"]==6000 &&
			(int)damage["__testunit_boss_mate__"]==4000 &&
			!damage["__testunit_boss_out__"],
			sprintf("damage=%O",damage));

		// 重复召唤被拒（每日1次）。
		mapping again = BANGPAI_EXTD->summon_bang_boss(leader,200000000);
		check("BOSS在场且当日次数已用完时拒绝再次召唤",
			!(int)again["ok"],
			"重复召唤成功="+sprintf("%O",again));

		// 击杀结算：排行奖励按档发放。
		int lead_contrib_before = BANGPAI_EXTD->query_contribution(leader);
		mapping gang_before = BANGPAI_EXTD->query_gang_summary(leader);
		mixed die_err = catch{ boss_npc->fight_die(); };
		check("BOSS死亡结算无异常",!die_err,
			die_err ? describe_error(die_err) : "");
		check("结算后BOSS退场且排行奖励按档发放",
			!BANGPAI_EXTD->query_bang_boss_npc(9) &&
			count_items(leader,"cuilianshi")==20 &&
			count_items(leader,"lihuoyu")==10 &&
			count_items(member,"cuilianshi")==10 &&
			count_items(member,"lihuoyu")==5 &&
			count_items(outsider,"cuilianshi")==0,
			sprintf("lead=%d/%d mate=%d/%d out=%d",
				count_items(leader,"cuilianshi"),
				count_items(leader,"lihuoyu"),
				count_items(member,"cuilianshi"),
				count_items(member,"lihuoyu"),
				count_items(outsider,"cuilianshi")));
		check("击杀结算发放帮贡与建设度",
			BANGPAI_EXTD->query_contribution(leader)-
				lead_contrib_before==200 &&
			(int)BANGPAI_EXTD->query_gang_summary(leader)["exp"]-
				(int)gang_before["exp"]==50000,
			sprintf("contrib+%d exp+%d",
				BANGPAI_EXTD->query_contribution(leader)-
					lead_contrib_before,
				(int)BANGPAI_EXTD->query_gang_summary(leader)["exp"]-
					(int)gang_before["exp"]));
		boss_npc = 0;

		// 当日次数耗尽后不能再召唤。
		mapping exhausted = BANGPAI_EXTD->summon_bang_boss(leader,
			200000000);
		check("当日次数耗尽后召唤被拒绝",
			!(int)exhausted["ok"] &&
			search((string)exhausted["message"],"次数已用完")!=-1,
			sprintf("result=%O",exhausted));

		// 超时路径：另一帮派召唤后30分钟无人击杀→参与奖减半。
		object|zero other_leader =
			create_player("__testunit_boss2_lead__","monst","kuangyao");
		other_leader->bangid = 11;
		set_this_player(other_leader);
		mapping summon2 = BANGPAI_EXTD->summon_bang_boss(other_leader,
			200000000);
		object|zero boss2 = BANGPAI_EXTD->query_bang_boss_npc(11);
		check("第二个帮派可独立召唤自己的BOSS",
			(int)summon2["ok"] && objectp(boss2) &&
			boss2->query_bangpai_boss_bangid()==11 &&
			!boss2->can_be_attacked(leader),
			"跨帮BOSS隔离失败");
		boss2->flush_targets(other_leader,50000);
		BANGPAI_EXTD->bangpai_boss_tick_for_test(11,time()+2000);
		check("超时退场只发减半参与奖且无离火玉",
			!BANGPAI_EXTD->query_bang_boss_npc(11) &&
			count_items(other_leader,"cuilianshi")<=3 &&
			count_items(other_leader,"lihuoyu")==0,
			sprintf("stones=%d jades=%d",
				count_items(other_leader,"cuilianshi"),
				count_items(other_leader,"lihuoyu")));
		destroy_player(other_leader);

		// 页面与入口。
		set_this_player(leader);
		string page = BANGPAI_EXTD->query_bang_boss_page(leader);
		check("BOSS页面展示上场击杀结果与伤害榜首",
			search(page,"上场结果：击杀")!=-1 &&
			search(page,"__testunit_boss_lead__")!=-1,
			"页面="+page);
		string my_bang_source = Stdio.read_file(
			ROOT+"/gamelib/cmds/my_bang.pike");
		check("我的帮派页提供帮派BOSS入口",
			my_bang_source &&
			search(my_bang_source,"[帮派BOSS:bang_boss]")!=-1,
			"my_bang缺少BOSS入口");

		BANGPAI_EXTD->set_state_file_for_test(0);
		BANGPAI_EXTD->set_bang_gate_for_test(0);
		rm(DATA_ROOT+"bangpai/ext_state.json.test");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("帮派BOSS流程无异常",0,error_desc);
	else
		check("帮派BOSS流程无异常",1,"");
	if(boss_npc)
		catch{ boss_npc->bangpai_boss_remove(); };
	destroy_player(leader);
	destroy_player(member);
	destroy_player(outsider);
	werror("[帮派BOSS] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
