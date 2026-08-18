#!/usr/bin/env pike

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) result=(["total":0,"passed":0,"failed":0]);

void check(string name,int ok,string detail)
{
	result["total"]++;
	if(ok){ result["passed"]++; werror("  ✓ %s\n",name); }
	else{ result["failed"]++; werror("  ✗ %s: %s\n",name,detail); }
}

mapping summary(string id,string profession,int level,int completed,
	void|string illusion_id)
{
	return (["id":id,"profession_id":profession,"level":level,
		"realm_type":"illusion","illusion_state":"active",
		"illusion_id":illusion_id || "S1",
		"illusion_story_completion_version":completed ? 1 : 0,
		"illusion_story_completed_at":completed ? time() : 0,
		"illusion_story_completed_profession":completed ? profession : ""]);
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(object|zero player,string userid)
{
	if(player) destruct(player);
	string path=player_file(userid);
	rm(path); rm(path+".tmp"); rm(path+".bak"); rm(path+".bak.tmp");
}

void cleanup_ranking_prefix(string userid_prefix)
{
	if(search(userid_prefix,"testunit")<0)
		return;
	string directory=DATA_ROOT+"illusion_realm/rankings/S1";
	foreach(get_dir(directory) || ({}),string filename)
		if(has_prefix(filename,userid_prefix) &&
		   (has_suffix(filename,".json") || has_suffix(filename,".tmp")))
			rm(directory+"/"+filename);
}

int bootstrap_character(object player,string race_id,string profession_id)
{
	object login_room=(object)(ROOT+"/gamelib/d/init");
	object|zero original_player=this_player();
	int bootstrapped;
	mixed err=catch{
		set_this_player(player);
		bootstrapped=login_room->choice_profe(race_id+"/"+profession_id);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	return !err && bootstrapped &&
		(string)player->query_raceId()==race_id &&
		(string)player->query_profeId()==profession_id;
}

int main()
{
	werror("\n========== S1照命隐藏职业测试 ==========\n");
	array(string) professions=({"jianxian","yushi","zhuxian","kuangyao","wuyao"});
	array characters=({});
	for(int index=0;index<sizeof(professions);index++)
		characters+=({summary("hidden"+(string)index,professions[index],120,1)});
	mapping unlocked=ACCOUNT_CHARACTERD->query_s1_hidden_unlock_from_summary(([
		"ok":1,"characters":characters,
	]),"S1");
	check("五个不同S1职业完整通关且达到120级才解锁",
		(int)unlocked["unlocked"] && (int)unlocked["completed_count"]==5,
		sprintf("status=%O",unlocked));
	mapping duplicate=ACCOUNT_CHARACTERD->query_s1_hidden_unlock_from_summary(([
		"ok":1,"characters":characters+({summary("duplicate","jianxian",200,1)}),
	]),"S1");
	check("同职业重复人物不重复计数",
		(int)duplicate["completed_count"]==5,sprintf("status=%O",duplicate));
	array four=characters[..3]+({summary("under","wuyao",119,1)});
	mapping under=ACCOUNT_CHARACTERD->query_s1_hidden_unlock_from_summary(([
		"ok":1,"characters":four,
	]),"S1");
	check("通关但未达120级不能伪造第五职业",
		!(int)under["unlocked"] && (int)under["completed_count"]==4 &&
		sizeof((array)under["level_pending"])==1,sprintf("status=%O",under));
	array wrong_cycle=characters[..3]+({summary("s2","wuyao",120,1,"S2")});
	mapping cycle=ACCOUNT_CHARACTERD->query_s1_hidden_unlock_from_summary(([
		"ok":1,"characters":wrong_cycle,
	]),"S1");
	check("其他赛季完成记录不能混入S1资格",
		!(int)cycle["unlocked"] && (int)cycle["completed_count"]==4,
		sprintf("status=%O",cycle));
	mapping malformed=copy_value(characters[4]);
	malformed["illusion_story_completion_version"]=0;
	mapping malformed_gate=ACCOUNT_CHARACTERD->
		query_s1_hidden_unlock_from_summary(([
			"ok":1,"characters":characters[..3]+({malformed}),
		]),"S1");
	check("缺少服务端完成凭证版本的档案不能凑足第五职业",
		!(int)malformed_gate["unlocked"] &&
		(int)malformed_gate["completed_count"]==4,
		sprintf("status=%O",malformed_gate));
	mapping eternal_denied=ACCOUNT_CHARACTERD->create_character(
		"xd99missinghidden","third","zhaoming","","","","eternal","");
	check("照命不能在永恒服创建",
		!(int)eternal_denied["ok"] &&
		search((string)eternal_denied["message"],"幻境限定")!=-1,
		sprintf("result=%O",eternal_denied));

	// 使用真实账号索引、幻境栏位、独立人物档案与账号锁走完创建事务，
	// 避免只验证纯辅助函数而漏掉落盘摘要或锁内二次校验。
	string gate_account="xd99testunitzhgate";
	string gate_password="testunit88";
	array(object) gate_players=({});
	array(string) gate_ids=({gate_account});
	array(string) gate_profile_names=({
		"testunitZH1","testunitZH2","testunitZH3","testunitZH4",
		"testunitZH5","testunitZHH",
	});
	ACCOUNT_CHARACTERD->remove_test_account(gate_account);
	cleanup_player(0,gate_account);
	cleanup_ranking_prefix(gate_account);
	foreach(gate_profile_names,string profile_name)
		NAMESD->remove_test_profile_name(profile_name);
	object gate_root=clone(GAMELIB_USER);
	gate_players+=({gate_root});
	gate_root->set_name(gate_account); gate_root->set_password(gate_password);
	gate_root->set_project("gamelib"); gate_root->set_userip("testunit");
	gate_root->set_account_owner(gate_account);
	gate_root->name_cn="照命门槛账号"; gate_root->set_raceId("human");
	gate_root->set_profeId("jianxian");
	gate_root->setup_player("human","jianxian");
	int gate_root_saved=gate_root->save_with_result();
	mapping entitlement=ACCOUNT_CHARACTERD->grant_illusion_entitlement(
		gate_account,"test","e"*64,"S1");
	mapping slots_five=ACCOUNT_CHARACTERD->grant_illusion_character_expansion(
		gate_account,"S1","all","f"*64,500);
	mapping slot_six=ACCOUNT_CHARACTERD->grant_illusion_character_expansion(
		gate_account,"S1","one","1"*64,100);
	int real_gate_ok=gate_root_saved && (int)entitlement["ok"] &&
		(int)slots_five["ok"] &&
		(int)slot_six["ok"];
	check("真实根账号完成存档、S1资格及六个人物栏位初始化",
		real_gate_ok,
		sprintf("saved=%d entitlement=%O five=%O six=%O",
			gate_root_saved,entitlement,slots_five,slot_six));
	mapping four_denied=([]);
	foreach(professions;int profession_index;string profession){
		string race=search(({"kuangyao","wuyao","yinggui"}),profession)!=-1 ?
			"monst" : "human";
		mapping created=ACCOUNT_CHARACTERD->create_character(gate_account,
			race,profession,gate_profile_names[profession_index],"male",
			race=="monst" ? "m_male1" : "h_male1","illusion","S1");
		if(!(int)created["ok"] || !mappingp(created["character"])){
			real_gate_ok=0;
			break;
		}
		string child_id=(string)created["character"]["id"];
		gate_ids+=({child_id});
		object child=clone(GAMELIB_USER);
		gate_players+=({child});
		child->set_name(child_id); child->set_project("gamelib");
		if(!child->restore() ||
		   !bootstrap_character(child,race,profession))
			real_gate_ok=0;
		child->level=120;
		child->set_att_by_level();
		if(!child->save_with_result())
			real_gate_ok=0;
		if(profession_index==0){
			mapping premature=ACCOUNT_CHARACTERD->
				record_illusion_story_completion(child,"S1");
			check("未完成八十一章不能直接写入账号完成凭证",
				!(int)premature["ok"] &&
				search((string)premature["message"],"八十一章")!=-1,
				sprintf("result=%O",premature));
		}
		child["/tmp/zhaoming_story_completion_test_ready"]=1;
		mapping completion=ACCOUNT_CHARACTERD->
			record_illusion_story_completion(child,"S1");
		child->m_delete_foruser(
			"/tmp/zhaoming_story_completion_test_ready");
		if(!(int)completion["ok"])
			real_gate_ok=0;
		if(sizeof(gate_players)==5)
			four_denied=ACCOUNT_CHARACTERD->create_character(gate_account,
				"third","zhaoming","","","","illusion","S1");
	}
	check("真实账号只有四个完成职业时照命创建事务失败关闭",
		real_gate_ok && !(int)four_denied["ok"] &&
		search((string)four_denied["message"],"4/5")!=-1,
		sprintf("result=%O",four_denied));
	mapping real_summary=ACCOUNT_CHARACTERD->query_account_characters(
		gate_account,"S1");
	mapping forged_selection=ACCOUNT_CHARACTERD->
		query_profession_selection_permission(gate_ids[-1],"zhaoming");
	check("普通S1人物不能用旧职业命令改选照命",
		!(int)forged_selection["allowed"] &&
		search((string)forged_selection["message"],"专属栏位")!=-1,
		sprintf("result=%O",forged_selection));
	mapping hidden_created=ACCOUNT_CHARACTERD->create_character(gate_account,
		"third","zhaoming",gate_profile_names[-1],"male","h_male1",
		"illusion","S1");
	string hidden_id=(int)hidden_created["ok"] ?
		(string)hidden_created["character"]["id"] : "";
	if(hidden_id!="") gate_ids+=({hidden_id});
	check("第五个不同职业完成后可在真实账号事务创建唯一照命",
		real_gate_ok && (int)real_summary["zhaoming_unlocked"] &&
		(int)hidden_created["ok"] && hidden_id!="",
		sprintf("summary=%O create=%O",real_summary,hidden_created));
	mapping hidden_selection=hidden_id!="" ? ACCOUNT_CHARACTERD->
		query_profession_selection_permission(hidden_id,"zhaoming") : ([]);
	check("服务端批准的照命专属栏位可进入职业初始化",
		(int)hidden_selection["allowed"],
		sprintf("result=%O",hidden_selection));
	ACCOUNT_CHARACTERD->grant_illusion_character_expansion(
		gate_account,"S1","one","2"*64,100);
	mapping hidden_duplicate=ACCOUNT_CHARACTERD->create_character(gate_account,
		"third","zhaoming","","","","illusion","S1");
	check("同一账号同一期不能重复创建第二个照命",
		!(int)hidden_duplicate["ok"] &&
		search((string)hidden_duplicate["message"],"只能创建一个照命")!=-1,
		sprintf("result=%O",hidden_duplicate));
	foreach(gate_players,object one) if(one) destruct(one);
	ACCOUNT_CHARACTERD->remove_test_account(gate_account);
	foreach(gate_ids,string one_id) cleanup_player(0,one_id);
	cleanup_ranking_prefix(gate_account);
	foreach(gate_profile_names,string profile_name)
		NAMESD->remove_test_profile_name(profile_name);

	int hunt_count; int visit_count; int boss_count; int reward_count;
	for(int trial=1;trial<=49;trial++){
		mapping task=ILLUSION_HIDDEN_PROFESSIOND->
			query_trial_definition_for_test(trial);
		if((string)task["kind"]=="hunt") hunt_count++;
		if((string)task["kind"]=="visit") visit_count++;
		if((string)task["kind"]=="boss") boss_count++;
		if((int)task["reward_index"]>=0) reward_count++;
		check("第"+(string)trial+"难目标文件存在",
			(string)task["target_room"]!="" &&
			Stdio.file_size(ROOT+(string)task["target_room"])>0 &&
			((string)task["kind"]=="visit" ||
			 Stdio.file_size(ROOT+(string)task["target_path"])>0),
			sprintf("task=%O",task));
	}
	check("七卷任务严格包含35狩猎7探索7首领",
		hunt_count==35 && visit_count==7 && boss_count==7,
		sprintf("hunt=%d visit=%d boss=%d",hunt_count,visit_count,boss_count));
	check("十件奖励里程碑固定为5至45每五难加终章49",
		reward_count==10,"reward_count="+(string)reward_count);

	array(string) base_templates=ITEMSD->
		query_newmoon_base_templates_for_profession("zhaoming");
	check("照命八十一章底版恰好十件且不进入随机池",
		sizeof(base_templates)==10 &&
		ITEMSD->query_newmoon_equipment_template_count()==120,
		"templates="+(string)sizeof(base_templates)+" global="+
		(string)ITEMSD->query_newmoon_equipment_template_count());
	foreach(base_templates,string path){
		object item=clone(ITEM_PATH+path);
		check("照命底版模板职业与新月品质正确",
			item && (string)item->query_newmoon_resonance_profession()=="zhaoming" &&
			(string)item->query_newmoon_collection_id()=="newmoon",
			path);
		if(item) destruct(item);
	}

	string userid="__testunit_zhaoming_full__";
	object player=clone(GAMELIB_USER);
	player->set_name(userid); player->set_password("testunit88");
	player->set_project("gamelib"); player->set_userip("testunit");
	player->set_account_owner(userid); player->name_cn="照命测试者";
	player->set_raceId("third"); player->set_profeId("zhaoming");
	player->setup_player("third","zhaoming"); player->level=120;
	player->set_att_by_level(); player["/tmp/zhaoming_test_ready"]=1;
	player->save_with_result();
	int claims_ok=1;
	for(int trial=1;trial<=49;trial++){
		if(!ILLUSION_HIDDEN_PROFESSIOND->complete_current_target_for_test(player)){
			claims_ok=0; break;
		}
		mapping claimed=ILLUSION_HIDDEN_PROFESSIOND->claim(player);
		if(!(int)claimed["ok"]){ claims_ok=0; break; }
		mapping repeated=ILLUSION_HIDDEN_PROFESSIOND->claim(player);
		if((int)repeated["ok"]){ claims_ok=0; break; }
	}
	mapping finished=ILLUSION_HIDDEN_PROFESSIOND->query_progress(player);
	int set_count; int bound_count;
	array(object) top_set_items=({});
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_newmoon_resonance_profession) &&
		   (string)item->query_newmoon_resonance_profession()=="zhaoming" &&
		   (string)item->query_newmoon_collection_id()=="huanji"){
			set_count++;
			top_set_items+=({item});
			if((string)item->query_newmoon_account_bind_owner()==userid)
				bound_count++;
		}
	check("四十九难可严格顺序结算且重复领取失败关闭",
		claims_ok && (int)finished["completed"],sprintf("progress=%O",finished));
	check("四十九难只发十件寰极账号绑定照命套装",
		set_count==10 && bound_count==10,
		sprintf("set=%d bound=%d",set_count,bound_count));
	int equipped_ok=sizeof(top_set_items)==10;
	foreach(top_set_items,object item){
		int equipped=(string)item->query_item_kind()=="single_main_weapon" ?
			player->wield(item) : player->wear(item);
		if(!equipped) equipped_ok=0;
	}
	mapping active_set=NEWMOON_SET_SKILLD->query_active_set_skill(player);
	object|zero active_set_skill=NEWMOON_SET_SKILLD->
		query_active_skill_object(player,"newmoon_zhaoming");
	check("照命寰极十件套可真实穿戴并激活六阶五命同辉",
		equipped_ok && (string)active_set["skill"]=="newmoon_zhaoming" &&
		(int)active_set["rank"]==6 && active_set_skill &&
		active_set_skill->query_newmoon_set_skill(),
		sprintf("equipped=%d active=%O",equipped_ok,active_set));
	array(string) volume_skill_ids=({"minghenjian","wushengyin","kongjingzhao",
		"suijingyue","youqingxue","huanminghuo","rendingrenjian"});
	int learned=0;
	foreach(volume_skill_ids,string skill_id)
		if(player->skills[skill_id] && MUD_SKILLSD[skill_id]) learned++;
	check("七卷分别授予七个可加载的照命技能",learned==7,
		"learned="+(string)learned);
	check("照命初始属性和升级成长均可计算",
		player->query_str()>200 && player->query_dex()>200 &&
		player->query_think()>200,
		sprintf("str=%d dex=%d think=%d",player->query_str(),
			player->query_dex(),player->query_think()));
	check("照命五项核心战斗派生值不会落入未知职业零值",
		player->query_phy_dodge()>0.0 && player->query_phy_hitte()>0.0 &&
		player->query_phy_baoji()>0.0 && player->query_base_damage()>0 &&
		player->query_defend_power()>0,
		sprintf("dodge=%.2f hit=%.2f crit=%.2f damage=%d defend=%d",
			player->query_phy_dodge(),player->query_phy_hitte(),
			player->query_phy_baoji(),player->query_base_damage(),
			player->query_defend_power()));
	cleanup_player(player,userid);

	array(string) compile_files=({
		"/gamelib/single/daemons/account_characterd.pike",
		"/gamelib/single/daemons/seasonal_chard.pike",
		"/gamelib/single/daemons/illusion_hidden_professiond.pike",
		"/gamelib/cmds/illusion_hidden.pike","/gamelib/d/init",
		"/gamelib/cmds/myskills.pike","/gamelib/cmds/newbie_guide.pike",
		"/gamelib/single/daemons/newmoon_set_skilld.pike",
	});
	foreach(compile_files,string file){
		mixed err=catch{ compile_file(ROOT+file); };
		check("编译"+file,!err,err ? describe_error(err) : "");
	}
	werror("S1照命隐藏职业: %d/%d passed\n",result["passed"],result["total"]);
	return result["failed"] ? 1 : 0;
}
