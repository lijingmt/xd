#!/usr/bin/env pike
/** Zhaoming balanced AOE attack and team heal skill regression. */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

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

void cleanup_player_files(string name)
{
	string path;
	if(!name || search(name,"testunit")<0)
		return;
	path=DATA_ROOT+"u/"+name[sizeof(name)-2..]+"/"+name+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_zhaoming_player(string name)
{
	object player;
	cleanup_player_files(name);
	player=clone(GAMELIB_USER);
	player->set_name(name);
	player->set_account_owner("zhaomingtestacct");
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn="照命群攻群奶测试";
	player->set_raceId("third");
	player->set_profeId("zhaoming");
	player->setup_player("third","zhaoming");
	player->level=120;
	player->packageLevel=20;
	return player;
}

void destroy_player(object|zero player)
{
	string name="";
	if(!player)
		return;
	name=(string)player->query_name();
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	cleanup_player_files(name);
}

void test_skill_definitions()
{
	object aoe=clone(ROOT+"/gamelib/single/skills/suijingqianying");
	check("碎镜千影挂接通用群攻通道并按阶段扩大目标数",
		(string)aoe->s_skill_type=="balanced_aoe" &&
		(int)aoe->lingyi_aoe_power_percent==100 &&
		aoe->query_balanced_aoe_target_limit(1)==2 &&
		aoe->query_balanced_aoe_target_limit(3)==6 &&
		aoe->query_balanced_aoe_target_limit(5)==10 &&
		aoe->query_balanced_aoe_target_limit(9)==10 &&
		search(aoe->skill_type,"zhaoming")!=-1 &&
		(string)aoe->name_cn=="【命】碎镜千影",
		"群攻技能类型、倍率或目标上限不正确");
	check("碎镜千影五阶伤害与法力消耗齐全",
		aoe->query_performs_mofa_attack_low(1)==45 &&
		aoe->query_performs_mofa_attack_high(5)==702 &&
		aoe->query_performs_cast(5)==62,
		"群攻五阶数值缺失");
	// 技能克隆已进入 skillsd 注册表，destruct 会让注册表悬挂并
	// 崩掉后续职业测试的技能查询；留给测试进程结束统一回收。
	object heal=clone(ROOT+"/gamelib/single/skills/minghuotongran");
	check("命火同燃挂接同房同队群体治疗通道",
		(string)heal->s_skill_type=="balanced_team_heal" &&
		search(heal->skill_type,"zhaoming")!=-1 &&
		(string)heal->name_cn=="【命】命火同燃",
		"群疗技能类型不正确");
	check("命火同燃五阶治疗量齐全",
		heal->query_performs_mofa_attack_low(1)==80 &&
		heal->query_performs_mofa_attack_high(5)==880,
		"群疗五阶数值缺失");
}

void test_gate_and_grant_wiring()
{
	string fight=Stdio.read_file(
		ROOT+"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
	string init=Stdio.read_file(ROOT+"/gamelib/d/init") || "";
	string cmd=Stdio.read_file(
		ROOT+"/gamelib/cmds/illusion_hidden.pike") || "";
	check("中立通用技能门禁放行照命",
		search(fight,"profe!=\"zhaoming\"")!=-1,
		"balanced门禁未包含zhaoming");
	check("建角与四十九难入口均接照命新技能",
		search(init,"suijingqianying")!=-1 &&
		search(init,"minghuotongran")!=-1 &&
		search(cmd,"ensure_base_skills")!=-1,
		"新技能未接入建角或对账补发入口");
}

void test_grant_reconciliation()
{
	object player=create_zhaoming_player("__testunit_zhaomingbal__");
	int granted=ILLUSION_HIDDEN_PROFESSIOND->ensure_base_skills(player);
	check("存量照命首次对账补齐三本大成传承",
		granted==3 &&
		sizeof(player->skills["zhaomingjue"])==2 &&
		sizeof(player->skills["suijingqianying"])==2 &&
		sizeof(player->skills["minghuotongran"])==2,
		sprintf("granted=%d skills=%O",granted,player->skills));
	int again=ILLUSION_HIDDEN_PROFESSIOND->ensure_base_skills(player);
	check("对账补发幂等且不重复入档",
		again==0 && sizeof(player->skills["suijingqianying"])==2,
		sprintf("again=%d",again));
	destroy_player(player);
	object other=clone(GAMELIB_USER);
	other->set_name("__testunit_zhaomingoth__");
	other->set_profeId("jianxian");
	int foreign=ILLUSION_HIDDEN_PROFESSIOND->ensure_base_skills(other);
	check("非照命职业不会被补发照命传承",
		foreign==0 &&
		!(mappingp(other->skills) && other->skills["suijingqianying"]),
		sprintf("foreign=%d",foreign));
	destruct(other);
}

void test_entry_compiles()
{
	array(string) failures=({});
	foreach(({
		"/gamelib/single/skills/suijingqianying",
		"/gamelib/single/skills/minghuotongran",
		"/gamelib/single/daemons/illusion_hidden_professiond.pike",
		"/gamelib/cmds/illusion_hidden.pike",
	}),string path){
		mixed err=catch{ compile_file(ROOT+path); };
		if(err)
			failures+=({path+":"+describe_error(err)});
	}
	check("照命群攻群奶全部入口可编译",!sizeof(failures),failures*" | ");
}

int main()
{
	werror("\n========== 照命群攻群奶测试 ==========\n");
	test_skill_definitions();
	test_gate_and_grant_wiring();
	test_grant_reconciliation();
	test_entry_compiles();
	werror("照命群攻群奶测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
