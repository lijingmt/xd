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
	array(int) outgoing=({100,100,100,100,100,100,100,100});
	array(int) incoming=({10,100,200,400,800,1600,3200,6400});
	array(int) drop=({100,200,400,800,1600,3200,6400,12800});
	array(int) afk=({24,16,14,12,10,8,6,4});
	array(int) exp_percent=({100,200,400,800,1600,3200,6400,12800});
	array(int) rare_drop=({100,200,400,800,1600,3200,6400,12800});
	array(int) required_kills=({0,20000,50000,100000,180000,280000,
		400000,600000});
	array(int) required_bosses=({0,50,120,250,450,700,1000,1500});
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
				(int)catalog[tier]["kills"]==required_kills[tier] &&
				(int)catalog[tier]["bosses"]==required_bosses[tier] &&
				(int)catalog[tier]["outgoing_percent"]==outgoing[tier] &&
				(int)catalog[tier]["incoming_percent"]==incoming[tier] &&
				(int)catalog[tier]["set_drop_percent"]==drop[tier] &&
				(int)catalog[tier]["afk_cap_hours"]==afk[tier] &&
				(int)catalog[tier]["exp_percent"]==exp_percent[tier] &&
				(int)catalog[tier]["rare_drop_percent"]==
					rare_drop[tier] &&
				(tier==0 || (incoming[tier]>incoming[tier-1] &&
				 drop[tier]>drop[tier-1] && afk[tier]<afk[tier-1] &&
				 exp_percent[tier]>exp_percent[tier-1] &&
				 rare_drop[tier]>rare_drop[tier-1]));
		check("七阶累计163万击杀和4070首领且风险收益严格单调",catalog_ok,
			sprintf("catalog=%O",catalog));

		object unlock_player=create_player(
			"__testunit_personal_difficulty_unlock__","human","jianxian");
		players+=({unlock_player});
		difficulty->set_scope_for_test(unlock_player,"eternal");
		unlock_player["/plus/personal_difficulty/progress"]=([]);
		mapping empty_progress=difficulty->query_unlock_progress(unlock_player);
		unlock_player["/plus/personal_difficulty/progress"]=(
			["kills":19999,"bosses":49]);
		npc->_npcLevel=250;
		npc->_boss=1;
		difficulty->record_npc_kill(unlock_player,npc);
		mapping completed_progress=difficulty->query_unlock_progress(
			unlock_player);
		mapping claimed=difficulty->claim_next_tier(unlock_player);
		difficulty->record_npc_kill(unlock_player,npc);
		mapping blocked_progress=difficulty->query_unlock_progress(unlock_player);
		unlock_player["/plus/personal_difficulty/current"]=1;
		unlock_player["/plus/personal_difficulty/progress"]=(
			["kills":49999,"bosses":119]);
		difficulty->record_npc_kill(unlock_player,npc);
		mapping next_progress=difficulty->query_unlock_progress(unlock_player);
		check("长期门槛逐级结算且未切到最高难度不会偷跑下一阶",
			(int)empty_progress["kills_required"]==20000 &&
			(int)empty_progress["bosses_required"]==50 &&
			(int)completed_progress["complete"] && (int)claimed["ok"] &&
			(int)blocked_progress["kills"]==0 &&
			(int)blocked_progress["bosses"]==0 &&
			(int)next_progress["complete"] &&
			(int)next_progress["kills"]==50000 &&
			(int)next_progress["bosses"]==120,
			sprintf("empty=%O completed=%O claimed=%O blocked=%O next=%O",
				empty_progress,completed_progress,claimed,blocked_progress,
				next_progress));

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
		mapping difficulty_chapters=([]);
		for(int chapter=1;chapter<=18;chapter++){
			claims["S1-C"+(string)chapter]=time();
			difficulty_chapters["S1-C"+(string)chapter]=0;
		}
		scope_player["/plus/illusion_realm/S1"]=(
			["content_id":"S1","claims":claims]);
		mapping legacy_mastery=difficulty->query_unlock_progress(scope_player);
		((mapping)scope_player["/plus/illusion_realm/S1"])
			["difficulty_chapters"]=difficulty_chapters;
		mapping first_mastery=difficulty->query_unlock_progress(scope_player);
		mapping first_claim=difficulty->claim_next_tier(scope_player);
		mapping no_chain=difficulty->query_unlock_progress(scope_player);
		scope_player["/plus/personal_difficulty/scopes/S1/current"]=1;
		for(int chapter=10;chapter<=18;chapter++)
			difficulty_chapters["S1-C"+(string)chapter]=1;
		mapping second_mastery=difficulty->query_unlock_progress(scope_player);
		scope_player["/plus/personal_difficulty/scopes/S1/current"]=0;
		mapping lower_block=difficulty->claim_next_tier(scope_player);
		scope_player["/plus/personal_difficulty/scopes/S1/current"]=1;
		mapping second_claim=difficulty->claim_next_tier(scope_player);
		check("永恒与S1存档隔离且每档必须在当前最高难度完成九个新章回",
			s1_level==6 && eternal_level==2 &&
			(string)before_chapters["scope"]=="S1" &&
			(int)legacy_mastery["complete"] &&
			(int)legacy_mastery["mastery_chapters"]==9 &&
			(int)first_mastery["complete"] &&
			(int)first_mastery["mastery_chapters"]==18 &&
			(int)first_claim["ok"] && !(int)no_chain["complete"] &&
			(int)no_chain["mastery_chapters"]==0 &&
			(int)second_mastery["complete"] &&
			!(int)lower_block["ok"] && (int)second_claim["ok"],
			sprintf("s1=%d eternal=%d legacy=%O first=%O claim=%O no_chain=%O second=%O lower=%O second_claim=%O",
				s1_level,eternal_level,legacy_mastery,first_mastery,
				first_claim,no_chain,second_mastery,lower_block,second_claim));

		object combat_switch_player=create_player(
			"__testunit_personal_difficulty_combat_switch__",
			"human","jianxian");
		players+=({combat_switch_player});
		difficulty->set_scope_for_test(combat_switch_player,"eternal");
		combat_switch_player["/plus/personal_difficulty/unlocked"]=1;
		combat_switch_player["/plus/personal_difficulty/current"]=0;
		object safe_room=(object)(ROOT+
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		object combat_npc=clone(ROOT+
			"/gamelib/clone/npc/mihuandao/9youdangelang.pike");
		combat_switch_player->move(safe_room);
		combat_npc->move(safe_room);
		int fight_started=combat_switch_player->_fight(combat_npc);
		mapping combat_switch=difficulty->switch_tier(combat_switch_player,1);
		check("真实交战状态通过公开接口拒绝切换个人难度",
			fight_started && combat_switch_player->query_in_combat() &&
			!(int)combat_switch["ok"] &&
			search((string)combat_switch["message"],"战斗中")!=-1,
			sprintf("started=%d in_combat=%d result=%O",fight_started,
				combat_switch_player->query_in_combat(),combat_switch));
		combat_switch_player->_clean_fight();
		combat_npc->_clean_fight();
		destruct(combat_npc);

		int professions_ok=1;
		foreach(professions;int index;mapping profession){
			object player=create_player(sprintf(
				"__testunit_personal_difficulty_%02d__",index),
				(string)profession["race"],(string)profession["id"]);
			players+=({player});
			difficulty->set_scope_for_test(player,"eternal");
			player["/plus/personal_difficulty/unlocked"]=7;
			player["/plus/personal_difficulty/scopes/S1/unlocked"]=7;
			for(int tier=0;tier<8;tier++){
				player["/plus/personal_difficulty/current"]=tier;
				professions_ok=professions_ok &&
					difficulty->scale_pve_damage(player,npc,10000)==
						10000*outgoing[tier]/100 &&
					difficulty->scale_pve_damage(npc,player,10000)==
						10000*incoming[tier]/100 &&
					difficulty->scale_pve_damage(player,pvp_target,10000)==
						10000 && difficulty->query_afk_cap_hours(player)==afk[tier];
				difficulty->set_scope_for_test(player,"S1");
				player["/plus/personal_difficulty/scopes/S1/current"]=tier;
				professions_ok=professions_ok &&
					difficulty->scale_pve_damage(player,npc,10000)==
						10000*outgoing[tier]/100 &&
					difficulty->scale_pve_damage(npc,player,10000)==
						10000*incoming[tier]/100 &&
					difficulty->scale_pve_damage(player,pvp_target,10000)==
						10000 && difficulty->query_afk_cap_hours(player)==afk[tier];
				difficulty->set_scope_for_test(player,"eternal");
			}
		}
		check("十二职业在永恒与S1逐档PVE、挂机一致且PVP公式完全不变",
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
		string level_source=Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/level.pike") || "";
		string items_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/itemsd.pike") || "";
		string npc_source=Stdio.read_file(ROOT+
			"/gamelib/inherit/npc.pike") || "";
		check("打怪经验与稀有掉率真实接入难度回报曲线",
			search(level_source,"query_exp_percent")!=-1 &&
			search(items_source,"rare_drop_percent")!=-1 &&
			search(npc_source,"query_rare_drop_percent_for_level")!=-1 &&
			search(npc_source,"query_rare_drop_percent(first)")!=-1,
			"经验或稀有掉率未挂在统一入口，高难度无回报");
		check("难度不进入地图与RPC路由，所有档位仍在同房间见面",
			search(worker,"personal_difficulty")==-1 &&
			search(rpc,"personal_difficulty")==-1,
			"Worker路由不应读取个人难度");
		string difficulty_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/personal_difficultyd.pike") || "";
		check("账号世界归属读取异常不会中断战斗掉落或挂机主链",
			search(difficulty_source,"realm_err=catch")!=-1 &&
			search(difficulty_source,"!mappingp(realm)")!=-1 &&
			search(difficulty_source,"DIFFICULTY_SCOPE_UNAVAILABLE")!=-1 &&
			search(difficulty_source,
				"string scope=DIFFICULTY_SCOPE_UNAVAILABLE")!=-1 &&
			search(difficulty_source,
				"(string)realm[\"realm_type\"]==\"eternal\"")!=-1 &&
			search(difficulty_source,
				"(string)realm[\"illusion_state\"]==\"active\"")!=-1 &&
			search(difficulty_source,
				"player[DIFFICULTY_SCOPE_CACHE]=scope")!=-1,
			"个人难度异常作用域缺少中性隔离或可能误写永恒进度");
		object unavailable=create_player(
			"__testunit_personal_difficulty_scope_unavailable__",
			"human","jianxian");
		unavailable["/tmp/personal_difficulty_scope"]="__unavailable";
		unavailable["/tmp/personal_difficulty_scope_retry_at"]=time();
		mapping unavailable_status=PERSONAL_DIFFICULTYD->query_status(unavailable);
		mapping unavailable_claim=PERSONAL_DIFFICULTYD->claim_next_tier(unavailable);
		mapping unavailable_switch=PERSONAL_DIFFICULTYD->switch_tier(unavailable,0);
		check("世界归属暂不可用时难度页只读拒绝且不制造伪作用域进度",
			(string)unavailable_status["scope"]=="__unavailable" &&
			(string)unavailable_status["progress"]["mode"]=="unavailable" &&
			!(int)unavailable_claim["ok"] &&
			!(int)unavailable_switch["ok"] &&
			!mappingp(unavailable[
				"/plus/personal_difficulty/scopes/__unavailable/progress"]),
			sprintf("status=%O claim=%O switch=%O",unavailable_status,
				unavailable_claim,unavailable_switch));
		cleanup_player(unavailable);
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
