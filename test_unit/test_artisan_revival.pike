#!/usr/bin/env pike
/** 百工复兴：旧档兼容、材料囊、熟练度、分类、批量与制造事务回归。 */

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

void cleanup_player_files(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_player(string userid,int level)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = "百工测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = level;
	player->packageLevel = 100;
	player->set_att_by_level();
	player->vice_skills = ([]);
	ARTISAND->initialize_player(player);
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
}

void test_runtime_compile()
{
	array(string) paths = ({
		"/gamelib/single/daemons/artisand.pike",
		"/gamelib/single/daemons/duanzaod.pike",
		"/gamelib/single/daemons/liandand.pike",
		"/gamelib/single/daemons/caifengd.pike",
		"/gamelib/single/daemons/zhijiad.pike",
		"/gamelib/cmds/artisan.pike",
		"/gamelib/cmds/artisan_master_craft.pike",
		"/gamelib/cmds/myskills.pike",
		"/gamelib/cmds/viceskill_learn.pike",
		"/gamelib/cmds/viceskill_pf_detail.pike",
		"/gamelib/cmds/viceskill_duanzao_confirm.pike",
		"/gamelib/cmds/viceskill_liandan_confirm.pike",
		"/gamelib/cmds/viceskill_caifeng_confirm.pike",
		"/gamelib/cmds/viceskill_zhijia_confirm.pike",
		"/gamelib/cmds/viceskill_dig.pike",
		"/gamelib/cmds/viceskill_gather.pike",
		"/gamelib/cmds/viceskill_add_baoshi.pike",
		"/gamelib/cmds/viceskill_add_moxian_caifeng.pike",
		"/gamelib/cmds/viceskill_add_moxian_zhijia.pike",
		"/gamelib/cmds/viceskill_duanzao_list.pike",
		"/gamelib/cmds/viceskill_duanzao_pf.pike",
		"/gamelib/cmds/viceskill_liandan_pf.pike",
		"/gamelib/cmds/viceskill_ronglian_confirm.pike",
		"/gamelib/cmds/viceskill_view.pike",
		"/gamelib/single/daemons/homed.pike",
		"/gamelib/single/daemons/roomLeveld.pike",
		"/gamelib/single/daemons/kuangd.pike",
		"/gamelib/single/daemons/caoyaod.pike",
		"/gamelib/clone/item/peifang/duanzao/p_lyuzhijiang",
		"/gamelib/clone/item/peifang/duanzao/p_lningchenlu",
		"/lowlib/mudlib/inherit/feature/readed.pike",
	});
	int failed = 0;
	string errors = "";
	foreach(paths,string path){
		mixed err = catch { compile_file(ROOT+path); };
		if(err){
			failed++;
			errors += path+": "+describe_error(err);
		}
	}
	check("百工守护、命令、采集和读配方入口全部编译",failed==0,errors);
}

void test_legacy_initialization()
{
	string userid = "__testunit_artisan_legacy__";
	object player = create_player(userid,80);
	player->vice_skills["duanzao"] = ({88,4,120});
	player->vice_skills["liandan"] = ({220,0,220});
	player["/liandan/attri_base"] = ([94:1,95:1]);
	player["/duanzao/weapon"] = 0;
	player["/liandan/attri_supply"] = 0;
	ARTISAND->initialize_player(player);
	check("旧熟练度原样保留且上层登录迁移仍可继续扩容",
		player->vice_skills["duanzao"][0]==88 &&
		player->vice_skills["duanzao"][1]==4 &&
		player->vice_skills["duanzao"][2]==120,
		"initialize_player 改写了旧熟练度");
	check("旧角色自动补齐高阶武器与炼丹补给分类",
		mappingp(player["/duanzao/weapon"]) &&
		mappingp(player["/liandan/attri_supply"]) &&
		player["/liandan/attri_supply"][94] &&
		player["/liandan/attri_supply"][95] &&
		!player["/liandan/attri_base"][94] &&
		!player["/liandan/attri_base"][95],
		"缺失分类未补齐或旧补给标记未迁移");
	destroy_player(player);
	cleanup_player_files(userid);
}

void test_progression_boundaries()
{
	string userid = "__testunit_artisan_progress__";
	object player = create_player(userid,20);
	player->vice_skills["duanzao"] = ({1,0,300});
	mapping first = ARTISAND->advance_proficiency(player,"duanzao",1);
	player->vice_skills["duanzao"] = ({4,0,300});
	mapping fourth = ARTISAND->advance_proficiency(player,"duanzao",1);
	player->vice_skills["duanzao"] = ({299,29,300});
	mapping capped = ARTISAND->advance_proficiency(player,"duanzao",50);
	int capped_level = (int)player->vice_skills["duanzao"][0];
	player->vice_skills["duanzao"] = ({50,9,300});
	mapping migrated = ARTISAND->advance_proficiency(player,"duanzao",1);
	check("1至4级熟练度需求不再出现零值",
		ARTISAND->query_progress_required(1)==1 &&
		ARTISAND->query_progress_required(4)==1 &&
		first["new_level"]==2 && fourth["new_level"]==5,
		"低级熟练度推进仍有零除或停滞");
	check("批量熟练度推进严格停在300上限",
		capped["new_level"]==300 &&
		capped_level==300,
		"批量推进越过技能上限");
	check("旧公式留下的较大进度会折算而不是被清零",
		migrated["new_level"]==51 && migrated["new_progress"]==4,
		"旧人物部分熟练度在首次制作时丢失");
	destroy_player(player);
	cleanup_player_files(userid);
}

string query_recipe_type(string skill_name,int recipe_id)
{
	if(skill_name=="duanzao")
		return DUANZAOD->query_recipe_type(recipe_id);
	if(skill_name=="liandan")
		return LIANDAND->query_recipe_type(recipe_id);
	if(skill_name=="caifeng")
		return CAIFENGD->query_recipe_type(recipe_id);
	if(skill_name=="zhijia")
		return ZHIJIAD->query_recipe_type(recipe_id);
	return "";
}

void test_complete_recipe_catalog()
{
	mapping(string:int) limits = ([
		"duanzao":140,"liandan":95,"caifeng":87,"zhijia":87,
	]);
	mapping(string:array(string)) allowed = ([
		"duanzao":({"m_weapon","s_weapon","d_weapon","armor","weapon"}),
		"liandan":({"normal","spec","attri_base","attri_vice",
			"attri_attack","attri_defend","attri_supply"}),
		"caifeng":({"head","cloth","waste","hand","thou","shoes"}),
		"zhijia":({"head","cloth","waste","hand","thou","shoes"}),
	]);
	int failed = 0;
	string reason = "";
	foreach(indices(limits),string skill_name){
		for(int recipe_id=1;recipe_id<=limits[skill_name];recipe_id++){
			string path = ARTISAND->query_recipe_item_path(skill_name,recipe_id);
			string type = query_recipe_type(skill_name,recipe_id);
			mapping materials = ARTISAND->query_recipe_materials(
				skill_name,recipe_id);
			int materials_valid = sizeof(materials)>0;
			foreach(values(materials),mixed one_material){
				if(!arrayp(one_material) || sizeof(one_material)<2 ||
				   (int)one_material[1]<=0)
					materials_valid = 0;
			}
			if(path=="" || !Stdio.exist(ITEM_PATH+path) ||
			   search(allowed[skill_name],type)==-1 ||
			   ARTISAND->query_recipe_item_level(skill_name,recipe_id)<=0 ||
			   ARTISAND->query_recipe_need_level(skill_name,recipe_id)<0 ||
			   !materials_valid){
				failed++;
				if(reason=="")
					reason = skill_name+"#"+(string)recipe_id+
						" type="+type+" path="+path;
			}
		}
	}
	check("四门手艺409张历史配方均有分类、产物和材料",
		failed==0,reason=="" ? "配方目录不完整" : reason);
}

void test_withdrawal_path_guard()
{
	string userid = "__testunit_artisan_path_guard__";
	object player = create_player(userid,20);
	player["/artisan/materials/evil"] = 1;
	player["/artisan/material_paths/evil"] =
		ROOT+"/gamelib/clone/item/liandan/shenlidan";
	mapping result = ARTISAND->withdraw_material(player,"evil",1);
	check("材料囊拒绝损坏存档中的非材料模板路径",
		!result["ok"] && (int)player["/artisan/materials/evil"]==1,
		(string)result["message"]);
	destroy_player(player);
	cleanup_player_files(userid);
}

void test_material_pouch()
{
	string userid = "__testunit_artisan_pouch__";
	object player = create_player(userid,20);
	object pouch_item = clone(ROOT+"/gamelib/clone/item/material/qingtong");
	object bag_item = clone(ROOT+"/gamelib/clone/item/material/qingtong");
	pouch_item->amount = 7;
	bag_item->amount = 3;
	bag_item->move(player);
	int stored = ARTISAND->store_material_object(player,pouch_item);
	ARTISAND->refresh_material_cache(player);
	check("材料囊与包袱材料合并计数且不复制",
		stored==7 && ARTISAND->query_material_count(player,"qingtong")==10 &&
		player->material_m["qingtong"]==10,
		"材料囊与物理背包计数不一致");
	check("新角色默认开启采集自动入囊",
		ARTISAND->query_auto_pouch(player)==1,
		"默认自动收纳没有开启");
	mapping deposited = ARTISAND->deposit_all_materials(player);
	mapping withdrawn = ARTISAND->withdraw_material(player,"qingtong",10);
	object|zero withdrawn_item = present("qingtong",player);
	check("包袱材料可一键收纳并以合法大堆叠完整取回",
		deposited["ok"] && withdrawn["ok"] && withdrawn_item &&
		(int)withdrawn_item->amount==10 &&
		(int)withdrawn_item->max_count==9999 &&
		ARTISAND->query_material_count(player,"qingtong")==10,
		(string)withdrawn["message"]);
	destroy_player(player);
	cleanup_player_files(userid);
}

void test_learning_runtime()
{
	string userid = "__testunit_artisan_learning__";
	object player = create_player(userid,20);
	object command = (object)(ROOT+"/gamelib/cmds/viceskill_learn.pike");
	object original_player = this_player();
	int account_after_valid;
	player->set_account(3000);
	set_this_player(player);
	command->main("duanzao 1");
	account_after_valid = player->query_account();
	command->main("not_a_skill 1");
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	check("基础手艺可真实学习且伪造技能名不会扣款",
		arrayp(player->vice_skills["duanzao"]) &&
		player->vice_skills["duanzao"][0]==1 &&
		account_after_valid==2000 && player->query_account()==2000 &&
		!player->vice_skills["not_a_skill"],
		"真实学习、扣款或技能白名单不正确");
	destroy_player(player);
	cleanup_player_files(userid);
}

void test_recipe_categories_and_master()
{
	string userid = "__testunit_artisan_master__";
	object player = create_player(userid,120);
	player->vice_skills["duanzao"] = ({210,0,300});
	player->vice_skills["caifeng"] = ({210,0,300});
	player["/duanzao/weapon"] = ([137:1]);
	player->vice_skills["liandan"] = ({220,0,300});
	player["/liandan/attri_supply"] = ([94:1]);
	player->save_with_result();
	mapping selected = ARTISAND->select_master_specialty(player,"duanzao");
	int account_after_first = player->query_account();
	mapping blocked_switch = ARTISAND->select_master_specialty(player,"caifeng");
	array(int) targets = ARTISAND->query_master_target_levels(player);
	mapping(string:int) needs = ARTISAND->query_required_materials(
		"duanzao",137,1,120);
	check("高级通用武器与炼丹补给配方可被识别",
		DUANZAOD->query_recipe_type(137)=="weapon" &&
		LIANDAND->query_recipe_type(94)=="attri_supply" &&
		ARTISAND->has_recipe(player,"duanzao",137) &&
		ARTISAND->has_recipe(player,"liandan",94),
		"历史缺失分类仍不能学习或制造");
	check("首次大师专精免费持久化并开放80至120级升阶",
		selected["ok"] && ARTISAND->query_master_specialty(player)=="duanzao" &&
		equal(targets,({80,100,120})) &&
		ARTISAND->query_master_material_multiplier(120)==3 &&
		sizeof(needs)>0,
		(string)selected["message"]);
	check("大师专精七日冷却阻止立即改换且不扣金币",
		!blocked_switch["ok"] &&
		ARTISAND->query_master_specialty(player)=="duanzao" &&
		player->query_account()==account_after_first,
		(string)blocked_switch["message"]);
	foreach(indices(needs),string item_name){
		player["/artisan/materials/"+item_name] = needs[item_name];
		player["/artisan/material_names/"+item_name] = item_name;
	}
	mapping high_made = ARTISAND->craft_equipment(player,"duanzao",137,1,120);
	array high_items = high_made["items"];
	object|zero high_item = arrayp(high_items) && sizeof(high_items) ?
		high_items[0] : 0;
	check("大师可真实制造120级装备且产物标记为百工来源",
		high_made["ok"] && high_item && environment(high_item)==player &&
		high_item->query_item_canLevel()==120 &&
		high_item->query_item_from()=="artisan",
		(string)high_made["message"]);
	destroy_player(player);
	cleanup_player_files(userid);
}

void test_equipment_batch_transaction()
{
	string userid = "__testunit_artisan_equip__";
	object player = create_player(userid,20);
	player->vice_skills["duanzao"] = ({1,0,300});
	player["/duanzao/d_weapon"] = ([1:1]);
	player["/artisan/materials/tongkuangshi"] = 10;
	player["/artisan/material_names/tongkuangshi"] = "铜矿石";
	object bag_material = clone(ROOT+
		"/gamelib/clone/item/material/tongkuangshi");
	bag_material->amount = 6;
	bag_material->move(player);
	player->save_with_result();
	mapping rejected = ARTISAND->craft_equipment(player,"duanzao",9999,1,0);
	int before_valid = ARTISAND->query_material_count(player,"tongkuangshi");
	mapping too_many = ARTISAND->craft_equipment(player,"duanzao",1,21,0);
	mapping made = ARTISAND->craft_equipment(player,"duanzao",1,2,0);
	array items = made["items"];
	int artisan_sources = 0;
	if(arrayp(items)){
		foreach(items,object item){
			if(item && item->query_item_from()=="artisan")
				artisan_sources++;
		}
	}
	check("伪造配方编号被拒绝且不扣材料",
		!rejected["ok"] && !too_many["ok"] && before_valid==16,
		"未学配方可以绕过列表直接制造");
	check("装备批量制造一次扣清材料并推进对应次数熟练度",
		made["ok"] && arrayp(items) && sizeof(items)==2 &&
		ARTISAND->query_material_count(player,"tongkuangshi")==0 &&
		player->vice_skills["duanzao"][0]==3 && artisan_sources==2,
		(string)made["message"]);
	destroy_player(player);
	cleanup_player_files(userid);
}

void test_medicine_batch_transaction()
{
	string userid = "__testunit_artisan_medicine__";
	object player = create_player(userid,20);
	player->vice_skills["liandan"] = ({1,0,300});
	player["/liandan/attri_base"] = ([1:1]);
	player["/artisan/materials/muhudie"] = 9;
	player["/artisan/material_names/muhudie"] = "木蝴蝶";
	player->save_with_result();
	mapping made = ARTISAND->craft_medicine(player,1,3);
	object|zero item = made["item"];
	check("炼丹批量上限提升后按颗扣料和推进熟练度",
		made["ok"] && item && environment(item)==player &&
		(int)item->amount==3 &&
		(int)item->max_count==100 &&
		ARTISAND->query_material_count(player,"muhudie")==0 &&
		player->vice_skills["liandan"][0]==4,
		(string)made["message"]);
	destroy_player(player);
	cleanup_player_files(userid);
}

void test_wiring_and_safety_guards()
{
	string learn_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/viceskill_learn.pike");
	string thread_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string dig_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/viceskill_dig.pike");
	string gather_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/viceskill_gather.pike");
	string kuang_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/kuangd.pike");
	string caoyao_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/caoyaod.pike");
	array(string) rooms = ROOMLEVELD->query_rooms(10,20);
	array(string) rooms_again = ROOMLEVELD->query_rooms(10,20);
	check("基础手艺取消二选二限制且非法技能不会扣款",
		learn_source &&
		search(learn_source,"sizeof(me->vice_skills) >= 2")==-1 &&
		search(learn_source,"is_valid_skill(skill_name)")!=-1,
		"学习入口仍保留两技能硬限制或缺少白名单");
	check("百工写命令保持主线程核心串行",
		thread_source && search(thread_source,
			"\"viceskill_\", \"artisan\"")!=-1,
		"百工写操作可能进入并行只读线程");
	check("手动采矿采药均接入自动材料囊与统一熟练度",
		dig_source && gather_source &&
		search(dig_source,"store_gathered_material(me,get_ob)")!=-1 &&
		search(gather_source,"store_gathered_material(me,get_ob)")!=-1 &&
		search(dig_source,"advance_proficiency(me,\"caikuang\",1)")!=-1 &&
		search(gather_source,"advance_proficiency(me,\"caiyao\",1)")!=-1,
		"采集链存在未接入的新旧分叉");
	check("房间等级目录返回排序副本且worker资源只刷新归属房间",
		sizeof(rooms)>0 && equal(rooms,rooms_again) &&
		kuang_source && caoyao_source &&
		search(kuang_source,"local_affinity_assignments_ready")!=-1 &&
		search(caoyao_source,"local_affinity_assignments_ready")!=-1 &&
		search(kuang_source,"local_worker_owns_room")!=-1 &&
		search(caoyao_source,"local_worker_owns_room")!=-1 &&
		search(kuang_source,"stable_room_slot")!=-1 &&
		search(caoyao_source,"stable_room_slot")!=-1 &&
		search(kuang_source,"reconciled_sources=%d")!=-1 &&
		search(caoyao_source,"reconciled_sources=%d")!=-1 &&
		search(kuang_source,"if(spawned || missing)")!=-1 &&
		search(caoyao_source,"if(spawned || missing)")!=-1 &&
		search(caoyao_source,"reconcile_all_worker_caoyao")!=-1 &&
		search(caoyao_source,"if(refresh_worker_generation())")!=-1 &&
		search(caoyao_source,"call_out(flush_caoyao,FLUSH_TIME)")!=-1,
		"资源可能在assignment前刷新、跨owner加载房间或每个worker重复全量生成");
}

int main()
{
	werror("\n========== 百工复兴测试 ==========\n");
	mixed err = catch {
		test_runtime_compile();
		test_legacy_initialization();
		test_progression_boundaries();
		test_material_pouch();
		test_learning_runtime();
		test_complete_recipe_catalog();
		test_withdrawal_path_guard();
		test_recipe_categories_and_master();
		test_equipment_batch_transaction();
		test_medicine_batch_transaction();
		test_wiring_and_safety_guards();
	};
	if(err){
		test_results["failed"]++;
		werror("  ✗ 百工测试异常: %s\n%s\n",describe_error(err),
			describe_backtrace(err));
	}
	werror("百工复兴测试完成: %d/%d 通过，%d 失败\n",
		test_results["passed"],test_results["total"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
