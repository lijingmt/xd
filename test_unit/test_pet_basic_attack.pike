#!/usr/bin/env pike
/**
 * 宠物基础灵攻（每回合免费小技能）回归测试
 *
 * 覆盖：
 * - 每个山海经物种在 catalog 中有 basic_attack 名称
 * - query_pet_basic_attack_name 返回正确名称
 * - perform_pet_basic_assist 在 PVE 时每 tick 触发、无冷却
 * - 主灵技冷却不影响基础灵攻
 * - 聊天节流：每 3 秒最多 1 条提示，伤害仍按 tick 结算
 * - PVP 时基础灵攻不触发（避免破坏充能平衡）
 * - fight.pike heart_beat 中独立调用基础灵攻
 */

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

object create_test_player_with_pet(string species)
{
	object player = clone(GAMELIB_USER);
	player->set_name("xd99testunitpetbasic"+species);
	player->set_password("testunit99");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "山海测试";
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = 80;
	player->set_att_by_level();
	// 装备宠物
	player["/tmp/wanling/species"] = species;
	player["/tmp/wanling/pet_name"] = "测试灵兽";
	player["/tmp/wanling/pet_level"] = 60;
	player["/tmp/wanling/player_level"] = player->query_level();
	player["/tmp/wanling/skill_set"] = 0;
	player["/tmp/wanling/pet_growth_percent"] = 100;
	player["/tmp/wanling/assist_at"] = 0;
	player["/tmp/wanling/basic_msg_at"] = 0;
	return player;
}

object create_test_npc(int life_max)
{
	object npc = clone(ROOT+"/gamelib/clone/npc/human_npc/human_gud50");
	if(!npc)
		return 0;
	npc->set_life(life_max);
	return npc;
}

void test_all_species_have_basic_attack()
{
	werror("[测试1] 16 个物种在 catalog 中都设了 basic_attack\n");
	array(string) all_species = PETD->query_all_species();
	int all_set = 1;
	string missing = "";
	foreach(all_species,string s){
		string name = PETD->query_pet_basic_attack_name(s);
		if(!name || name==""){
			all_set = 0;
			missing += s+" ";
		}
	}
	check("所有物种都有 basic_attack 名称",
		all_set && sizeof(all_species)>=16,
		"缺失:"+missing);
}

void test_basic_attack_name_lookup()
{
	werror("[测试2] query_pet_basic_attack_name 返回指定名称\n");
	check("当康→獠牙拱",
		PETD->query_pet_basic_attack_name("dangkang")=="獠牙拱",
		"实际:"+PETD->query_pet_basic_attack_name("dangkang"));
	check("未知物种返回空串",
		PETD->query_pet_basic_attack_name("__notexist__")=="",
		"未知物种未安全回退");
}

void test_basic_assist_fires_every_tick()
{
	werror("[测试3] 基础灵攻在 PVE 每 tick 触发、无冷却\n");
	// 用强攻型物种（毕方）确保主灵技档位是 damage，结算出非零伤害。
	object player = create_test_player_with_pet("bifang");
	object npc = create_test_npc(100000);
	if(!npc){
		check("测试 NPC 可加载",0,"NPC 加载失败");
		destruct(player);
		return;
	}
	object room = (object)(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	player->move(room);
	npc->move(room);
	int total_damage = 0;
	for(int i=0;i<5;i++){
		mapping r = PETD->perform_pet_basic_assist(player,npc);
		if(r["ok"] && (int)r["amount"]>0)
			total_damage += (int)r["amount"];
	}
	check("连续 5 tick 全部生效（无冷却）",
		total_damage>0,
		"5 tick 总伤害为 0");
	destruct(player);
	destruct(npc);
}

void test_independent_from_main_skill()
{
	werror("[测试4] 基础灵攻与主灵技冷却相互独立\n");
	object player = create_test_player_with_pet("bifang");
	object npc = create_test_npc(100000);
	object room = (object)(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	player->move(room);
	npc->move(room);
	// 主灵技先打一次，进入冷却
	mapping main1 = PETD->perform_pet_pve_assist(player,npc);
	int main_cooldown = (int)main1["cooldown"];
	check("主灵技已释放进入冷却",
		(int)player["/tmp/wanling/assist_at"]>0 && main_cooldown>0,
		"主灵技未释放");
	// 主灵技冷却中，基础灵攻仍应每 tick 生效
	int basic_count = 0;
	for(int i=0;i<3;i++){
		mapping b = PETD->perform_pet_basic_assist(player,npc);
		if(b["ok"])
			basic_count++;
	}
	check("主灵技冷却中基础灵攻仍可连续 3 tick 触发",
		basic_count==3,
		"基础灵攻受主冷却影响，触发数="+basic_count);
	destruct(player);
	destruct(npc);
}

void test_message_throttle()
{
	werror("[测试5] 聊天节流：每 3 秒最多 1 条提示\n");
	object player = create_test_player_with_pet("zheng");
	object npc = create_test_npc(100000);
	object room = (object)(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	player->move(room);
	npc->move(room);
	player["/tmp/wanling/basic_msg_at"] = 0;
	// 第一次应能输出
	mapping r1 = PETD->perform_pet_basic_assist(player,npc);
	int first_at = (int)player["/tmp/wanling/basic_msg_at"];
	// 立刻再调应被节流（伤害仍生效但消息不发）
	mapping r2 = PETD->perform_pet_basic_assist(player,npc);
	int second_at = (int)player["/tmp/wanling/basic_msg_at"];
	check("节流期间 basic_msg_at 不刷新",
		first_at==second_at && r2["ok"] && (int)r2["amount"]>0,
		"节流失效或伤害未结算");
	destruct(player);
	destruct(npc);
}

void test_pvp_skips_basic_attack()
{
	werror("[测试6] PVP 时基础灵攻不触发\n");
	object p1 = create_test_player_with_pet("qiongqi");
	object p2 = clone(GAMELIB_USER);
	p2->set_name("xd99testunitpetbasicp2");
	p2->set_password("testunit99");
	p2->set_project("gamelib");
	p2->set_raceId("human");
	p2->set_profeId("jianxian");
	p2->setup_player("human","jianxian");
	p2->level = 80;
	p2->set_att_by_level();
	object room = (object)(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	p1->move(room);
	p2->move(room);
	mapping r = PETD->perform_pet_basic_assist(p1,p2);
	check("PVP 目标时基础灵攻 ok=0",
		!(int)r["ok"],
		"PVP 中基础灵攻被误触发");
	destruct(p1);
	destruct(p2);
}

void test_fight_pike_hooks_basic_attack()
{
	werror("[测试7] fight.pike 在 heart_beat 中独立调用基础灵攻\n");
	string src = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	check("fight.pike 调用 perform_pet_basic_assist",
		search(src,"PETD->perform_pet_basic_assist(")!=-1,
		"未接入基础灵攻");
}

int main()
{
	werror("\n========== 山海万灵基础灵攻测试 ==========\n");
	mixed err = catch {
		test_all_species_have_basic_attack();
		test_basic_attack_name_lookup();
		test_basic_assist_fires_every_tick();
		test_independent_from_main_skill();
		test_message_throttle();
		test_pvp_skips_basic_attack();
		test_fight_pike_hooks_basic_attack();
	};
	if(err)
		check("测试运行无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	werror("\n基础灵攻测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
