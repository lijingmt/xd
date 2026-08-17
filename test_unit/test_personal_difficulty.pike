#!/usr/bin/env pike
/** 永恒服/S1个人难度隔离、十二职业战斗与套装掉落回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[个人难度] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[个人难度] ✗ %s: %s\n",name,reason);
	}
}

object create_player(string userid,string race,string profession)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn="难度测试";
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level=250;
	player->set_att_by_level();
	return player;
}

void cleanup_player(object player)
{
	if(!player)
		return;
	string userid=(string)player->query_name();
	if(player->query_in_combat())
		player->_clean_fight();
	destruct(player);
	if(has_prefix(userid,"__testunit_personal_difficulty_")){
		string path=DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
		rm(path);
		rm(path+".bak");
		rm(path+".tmp");
	}
}

int main()
{
	array(mapping(string:string)) professions=({
		(["id":"jianxian","race":"human"]),
		(["id":"yushi","race":"human"]),
		(["id":"zhuxian","race":"human"]),
		(["id":"kuangyao","race":"monst"]),
		(["id":"wuyao","race":"monst"]),
		(["id":"yinggui","race":"monst"]),
		(["id":"fangshi","race":"third"]),
		(["id":"zhenyue","race":"third"]),
		(["id":"tianxiang","race":"third"]),
		(["id":"lingyi","race":"third"]),
		(["id":"wuxiang","race":"human"]),
		(["id":"taiji","race":"human"]),
	});
	array(int) outgoing=({100,95,90,85,80,75,70,65});
	array(int) incoming=({100,108,118,130,145,162,182,205});
	array(int) drop=({100,112,125,140,160,185,215,250});
	array(int) afk=({24,16,14,12,10,8,6,4});
	object difficulty=(object)(ROOT+
		"/gamelib/single/daemons/personal_difficultyd.pike");
	object npc=clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang.pike");
	object pvp_target=create_player(
		"__testunit_personal_difficulty_pvp__","human","jianxian");
	array(object) players=({pvp_target});
	mixed err=catch{
		array catalog=difficulty->query_catalog();
		int catalog_ok=sizeof(catalog)==8;
		for(int tier=0;tier<8;tier++)
			catalog_ok=catalog_ok &&
				(int)catalog[tier]["outgoing_percent"]==outgoing[tier] &&
				(int)catalog[tier]["incoming_percent"]==incoming[tier] &&
				(int)catalog[tier]["set_drop_percent"]==drop[tier] &&
				(int)catalog[tier]["afk_cap_hours"]==afk[tier] &&
				(tier==0 || (outgoing[tier]<outgoing[tier-1] &&
				 incoming[tier]>incoming[tier-1] &&
				 drop[tier]>drop[tier-1] && afk[tier]<afk[tier-1]));
		check("八档倍率、挂机上限与风险收益严格单调",catalog_ok,
			sprintf("catalog=%O",catalog));

		object scope_player=create_player(
			"__testunit_personal_difficulty_scope__","human","jianxian");
		players+=({scope_player});
		difficulty->set_scope_for_test(scope_player,"eternal");
		scope_player["/plus/personal_difficulty/unlocked"]=3;
		scope_player["/plus/personal_difficulty/current"]=2;
		difficulty->set_scope_for_test(scope_player,"S1");
		scope_player["/plus/personal_difficulty/scopes/S1/unlocked"]=7;
		scope_player["/plus/personal_difficulty/scopes/S1/current"]=6;
		int s1_level=difficulty->query_current_level(scope_player);
		difficulty->set_scope_for_test(scope_player,"eternal");
		int eternal_level=difficulty->query_current_level(scope_player);
		difficulty->set_scope_for_test(scope_player,"S1");
		mapping before_chapters=difficulty->query_unlock_progress(scope_player);
		scope_player["/plus/personal_difficulty/scopes/S1/unlocked"]=0;
		scope_player["/plus/personal_difficulty/scopes/S1/current"]=0;
		mapping claims=([]);
		for(int chapter=1;chapter<=9;chapter++)
			claims["S1-C"+(string)chapter]=time();
		scope_player["/plus/illusion_realm/S1"]=(
			["content_id":"S1","claims":claims]);
		mapping after_chapters=difficulty->query_unlock_progress(scope_player);
		check("永恒与S1难度存档互不泄漏且S1按九章解锁下一档",
			s1_level==6 && eternal_level==2 &&
			(string)before_chapters["scope"]=="S1" &&
			(int)after_chapters["complete"] &&
			(int)after_chapters["chapters"]==9 &&
			(int)after_chapters["chapters_required"]==9,
			sprintf("s1=%d eternal=%d before=%O after=%O",s1_level,
				eternal_level,before_chapters,after_chapters));

		int professions_ok=1;
		foreach(professions;int index;mapping profession){
			object player=create_player(sprintf(
				"__testunit_personal_difficulty_%02d__",index),
				(string)profession["race"],(string)profession["id"]);
			players+=({player});
			difficulty->set_scope_for_test(player,"eternal");
			player["/plus/personal_difficulty/unlocked"]=7;
			for(int tier=0;tier<8;tier++){
				player["/plus/personal_difficulty/current"]=tier;
				professions_ok=professions_ok &&
					difficulty->scale_pve_damage(player,npc,10000)==
						10000*outgoing[tier]/100 &&
					difficulty->scale_pve_damage(npc,player,10000)==
						10000*incoming[tier]/100 &&
					difficulty->scale_pve_damage(player,pvp_target,10000)==
						10000;
			}
		}
		check("十二职业逐档PVE输出承伤一致且PVP公式完全不变",
			professions_ok,"某职业或某难度的统一战斗边界不一致");

		int denominator=ITEMSD->query_newmoon_equipment_drop_denominator();
		array(int) hit_counts=allocate(8);
		for(int tier=0;tier<8;tier++)
			for(int roll=1;roll<=denominator;roll++)
				if(sizeof(ITEMSD->query_newmoon_collection_for_difficulty_roll(
				   300,roll,tier)))
					hit_counts[tier]++;
		int drop_ok=hit_counts[0]>0;
		for(int tier=1;tier<8;tier++)
			drop_ok=drop_ok && hit_counts[tier]>=hit_counts[tier-1];
		check("全随机区间实算套装命中数随难度提高且不倒挂",
			drop_ok,sprintf("denominator=%d hits=%O",denominator,hit_counts));

		string fight=Stdio.read_file(ROOT+
			"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
		string quick=Stdio.read_file(ROOT+
			"/lowlib/wapmud2/cmds/kill_quick.pike") || "";
		string worker=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/map_workerd.pike") || "";
		string rpc=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike") || "";
		check("普通战斗、技能、群攻和快速战斗均接入统一难度边界",
			sizeof(fight/"scale_pve_damage")-1>=5 &&
			sizeof(quick/"scale_pve_damage")-1==2,
			"存在绕过统一伤害边界的主要战斗路径");
		check("难度不进入地图与RPC路由，所有档位仍在同房间见面",
			search(worker,"personal_difficulty")==-1 &&
			search(rpc,"personal_difficulty")==-1,
			"Worker路由不应读取个人难度");
	};
	check("个人难度完整测试未发生运行异常",!err,
		err ? describe_error(err)+" "+describe_backtrace(err) : "");
	foreach(players,object player)
		cleanup_player(player);
	if(npc)
		destruct(npc);
	werror("个人难度测试：%d/%d通过\n",results["passed"],results["total"]);
	return results["failed"] ? 1 : 0;
}
