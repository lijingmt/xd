#!/usr/bin/env pike
/** 金玉露批量消费、即时升级、上限和扣物守恒回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){ results["passed"]++; werror("[金玉露] ✓ %s\n",name); }
	else{ results["failed"]++; werror("[金玉露] ✗ %s: %s\n",name,detail); }
}

int main()
{
	object player=clone(GAMELIB_USER);
	object command=(object)(ROOT+"/gamelib/cmds/skill_eat_teyao.pike");
	object skill=(object)(ROOT+"/gamelib/single/skills/lingzhen");
	object medicine=clone(ROOT+"/gamelib/clone/item/teyao/jinyulu");
	int required=(int)skill->performs_shuliandu[1];
	player->set_name("__testunit_jinyulu_batch__");
	player->name_cn="金玉露测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("yushi");
	player->setup_player("human","yushi");
	player->level=200;
	player->set_att_by_level();
	player->skills["lingzhen"]=({1,required*9/10});
	medicine->amount=10;
	medicine->move(player);
	check("金玉露说明与历史实际20%效果保持一致",
		(int)medicine->query_effect_value()==20 &&
		search((string)medicine->query_desc(),"20%")!=-1,
		(string)medicine->query_desc());
	mapping first=command->consume_skill_medicine(
		player,"jinyulu","lingzhen",5);
	check("批量使用在达到100%时直接升级并继续累计下一级",
		(int)first["ok"] && (int)first["used"]==5 &&
		(int)first["levels"]==1 &&
		(int)player->skills["lingzhen"][0]==2 &&
		(int)player->skills["lingzhen"][1]>0,
		sprintf("result=%O skill=%O",first,player->skills["lingzhen"]));
	check("一次批量只扣实际使用瓶数",
		command->query_bottles_to_next_level(player,"lingzhen")>0 &&
		(int)medicine->amount==5,
		sprintf("remaining=%d",(int)medicine->amount));
	player->skills["lingzhen"]=({(int)player->query_skill_up("lingzhen"),0});
	mapping capped=command->consume_skill_medicine(
		player,"jinyulu","lingzhen",5);
	check("技能达到当前上限时一瓶也不扣",
		!(int)capped["ok"] && (int)medicine->amount==5,
		sprintf("result=%O remaining=%d",capped,(int)medicine->amount));
	player->skills["lingzhen"]=({1,required});
	mapping legacy_full=command->consume_skill_medicine(
		player,"jinyulu","lingzhen",1);
	check("旧档已卡在100%时直接升级且不额外扣一瓶",
		(int)legacy_full["ok"] && (int)legacy_full["used"]==0 &&
		(int)legacy_full["levels"]==1 &&
		(int)player->skills["lingzhen"][0]==2 &&
		(int)medicine->amount==5,
		sprintf("result=%O skill=%O remaining=%d",legacy_full,
			player->skills["lingzhen"],(int)medicine->amount));
	mixed err=catch{ compile_file(ROOT+"/gamelib/cmds/skill_eat_teyao.pike"); };
	check("批量金玉露命令可由真实Pike运行时编译",!err,
		err ? describe_error(err) : "");
	foreach(all_inventory(player),object item)
		if(item) destruct(item);
	destruct(player);
	werror("金玉露批量测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
