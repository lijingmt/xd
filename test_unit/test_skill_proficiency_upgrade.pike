#!/usr/bin/env pike
/** 技能熟练度本次达到100%时立即升级，不改变成长概率与上限。 */

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

int main()
{
	object player = clone(GAMELIB_USER);
	object skill = (object)(ROOT+"/gamelib/single/skills/lingzhen");
	int required = (int)skill->performs_shuliandu[1];
	int maximum = (int)skill->query_skill_level_max();
	player->set_name("__testunit_skill_proficiency_upgrade__");
	player->name_cn = "熟练度测试者";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("yushi");
	player->setup_player("human","yushi");
	player->skills["lingzhen"] = ({1,required-1});
	player->skills_level_check("lingzhen",2);
	check("本次熟练度从不足推到100%时直接升级",
		(int)player->skills["lingzhen"][0]==2 &&
		(int)player->skills["lingzhen"][1]==0,
		"仍需下一次施放或熟练度没有归零");
	player->skills["lingzhen"] = ({maximum,required-1});
	player->skills_level_check("lingzhen",2);
	check("即时升级不突破技能原有等级上限",
		(int)player->skills["lingzhen"][0]==maximum,
		"便利性修改突破了技能等级上限");
	if(player)
		destruct(player);
	werror("熟练度即时升级测试：%d通过/%d失败\n",
		results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
