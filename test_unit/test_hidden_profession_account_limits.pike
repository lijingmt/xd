#!/usr/bin/env pike
/** 同一注册账号的无相/太极隐藏职业创建数量上限回归。 */

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

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_account_root(string account_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(account_id);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->name_cn = "隐藏职业限量测试";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level = 200;
	player->set_att_by_level();
	player->save_with_result();
	return player;
}

mapping(string:mixed) create_and_finish(string account_id,string race_id,
	string profession_id,array(string) created_ids)
{
	mapping result = ACCOUNT_CHARACTERD->create_character(account_id,
		race_id,profession_id);
	if(!(int)result["ok"] || !mappingp(result["character"]))
		return result;
	string character_id = (string)result["character"]["id"];
	object player = clone(GAMELIB_USER);
	player->set_name(character_id);
	player->set_project("gamelib");
	if(!player->restore()){
		destruct(player);
		return (["ok":0,"message":"新人物物理档案无法恢复"]);
	}
	player->name_cn = "限量测试"+profession_id;
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->level = 200;
	player->set_att_by_level();
	int saved = player->save_with_result();
	destruct(player);
	if(!saved)
		return (["ok":0,"message":"新人物职业存档失败"]);
	created_ids += ({character_id});
	result["created_ids"] = created_ids;
	return result;
}

int main()
{
	string account_id = "xd99testunithiddenlimit";
	array(string) created_ids = ({});
	object|zero root = 0;
	object original_player = this_player();
	werror("\n========== 隐藏职业账号数量上限测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		root = create_account_root(account_id);
		array(array(string)) required = ({
			({"human","yushi"}),({"human","zhuxian"}),
			({"monst","kuangyao"}),({"monst","wuyao"}),
			({"monst","yinggui"}),({"third","fangshi"}),
			({"third","zhenyue"}),({"third","tianxiang"}),
			({"third","lingyi"}),
		});
		int prerequisites_ok = 1;
		foreach(required,array(string) pair){
			mapping made = create_and_finish(account_id,pair[0],pair[1],
				created_ids);
			prerequisites_ok = prerequisites_ok && (int)made["ok"];
			if(arrayp(made["created_ids"]))
				created_ids = (array(string))made["created_ids"];
		}
		mapping unlocked = ACCOUNT_CHARACTERD->query_account_characters(
			account_id);
		check("十个基础职业达到200级后无相与太极解锁前置成立",
			prerequisites_ok &&
			ACCOUNT_CHARACTERD->query_wuxiang_unlocked_from_summary(unlocked),
			"测试账号没有完整建立十职业前置");

		array(string) wuxiang_ids = ({});
		int three_wuxiang = 1;
		for(int index=0;index<3;index++){
			mapping made = create_and_finish(account_id,"third","wuxiang",
				created_ids);
			three_wuxiang = three_wuxiang && (int)made["ok"];
			if(arrayp(made["created_ids"])){
				created_ids = (array(string))made["created_ids"];
				wuxiang_ids += ({created_ids[-1]});
			}
		}
		mapping fourth_wuxiang = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","wuxiang");
		mapping wuxiang_selection = ACCOUNT_CHARACTERD->
			query_profession_selection_permission(account_id,"wuxiang");
		check("同一注册账号允许三个无相并拒绝第四个及旧入口绕过",
			three_wuxiang && !fourth_wuxiang["ok"] &&
			search((string)fourth_wuxiang["message"],"最多创建3个")!=-1 &&
			!wuxiang_selection["allowed"] &&
			(int)wuxiang_selection["count"]==3,
			"无相上限未在账号锁或choice_profe共用校验中生效");

		int two_taiji = 1;
		for(int index=0;index<2;index++){
			mapping made = create_and_finish(account_id,"third","taiji",
				created_ids);
			two_taiji = two_taiji && (int)made["ok"];
			if(arrayp(made["created_ids"]))
				created_ids = (array(string))made["created_ids"];
		}
		mapping third_taiji = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","taiji");
		mapping taiji_selection = ACCOUNT_CHARACTERD->
			query_profession_selection_permission(account_id,"taiji");
		check("当前太极职业承载无极限量：允许两个并拒绝第三个",
			two_taiji && !third_taiji["ok"] &&
			search((string)third_taiji["message"],"最多创建2个")!=-1 &&
			!taiji_selection["allowed"] &&
			(int)taiji_selection["count"]==2 &&
			ACCOUNT_CHARACTERD->query_profession_account_limit("taiji")==2,
			"taiji/无极上限未按两个执行");

		mapping ordinary = ACCOUNT_CHARACTERD->
			query_profession_limit_from_summary(unlocked,"fangshi");
		mapping existing_wuxiang = ACCOUNT_CHARACTERD->
			query_profession_selection_permission(wuxiang_ids[0],"wuxiang");
		check("普通职业不受新增限制且当前待初始化人物不会重复计数",
			ordinary["allowed"] && !ordinary["limited"] &&
			existing_wuxiang["allowed"] &&
			(int)existing_wuxiang["count"]==2,
			"普通职业被误限或排除当前人物的边界错误");
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("隐藏职业上限测试没有运行异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(root)
		destruct(root);
	array(string) all_ids = ACCOUNT_CHARACTERD->query_character_ids(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	foreach(all_ids,string character_id)
		cleanup_player(character_id);
	cleanup_player(account_id);
	werror("隐藏职业账号上限：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
