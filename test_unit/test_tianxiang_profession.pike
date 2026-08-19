#!/usr/bin/env pike
/** 天象从建角、技能书、星痕战斗到共享系统的运行时测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[天象全链路 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

object create_player(string name,string profession,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "天象测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId(profession);
	player->setup_player("third",profession);
	player->level = level;
	player->set_att_by_level();
	player->set_base_life(100000);
	player->flush_life();
	player->set_life(player->query_life_max());
	player->set_mofa(player->query_mofa_max());
	player->set_base_hitte(100000);
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	if(player->query_in_combat())
		player->_clean_fight();
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void set_active_vip(object player,int level)
{
	player->set_vip_flag(level);
	player->set_vip_end_time(level>0 ? time()+3600 : 0);
}

void test_creation_growth_and_identity()
{
	test_start("中立独立建角、初始技能、身份与1/30/80/120级成长");
	object level_one = create_player("__testunit_tianxiang_one__","tianxiang",1);
	object level_thirty = create_player("__testunit_tianxiang_thirty__","tianxiang",30);
	object level_eighty = create_player("__testunit_tianxiang_eighty__","tianxiang",80);
	object level_one_twenty = create_player("__testunit_tianxiang_120__","tianxiang",120);
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string top_source = Stdio.read_file(ROOT+"/gamelib/cmds/look_top.pike");
	string base_source = Stdio.read_file(ROOT+"/lowlib/system/inherit/base.pike");
	int valid = level_one && level_thirty && level_eighty && level_one_twenty &&
		init_source && top_source && base_source &&
		search(init_source,"[天象:choice_profe third/tianxiang]")!=-1 &&
		search(init_source,"\"fangshi\",\"zhenyue\",\"tianxiang\",\"lingyi\"")!=-1 &&
		search(init_source,"me->skills[\"xingmang\"]=({1,0});")!=-1 &&
		level_one->query_raceId()=="third" &&
		level_one->query_profeId()=="tianxiang" &&
		level_one->query_profe_cn("tianxiang")=="天象" &&
		level_one->query_str()==7 && level_one->query_dex()==5 &&
		level_one->query_think()==13 &&
		level_thirty->query_str()==7+(int)(29*0.8) &&
		level_thirty->query_dex()==5+(int)(29*0.8) &&
		level_thirty->query_think()==13+(int)(29*2.8) &&
		level_eighty->query_think()==13+(int)(79*2.8) &&
		level_one_twenty->query_think()==13+(int)(119*2.8) &&
		search(top_source,"【象】")!=-1 &&
		search(base_source,"无名天象")!=-1;
	if(valid)
		test_pass();
	else
		test_fail("建角接线、身份或等级成长不正确");
	destroy_player(level_one);
	destroy_player(level_thirty);
	destroy_player(level_eighty);
	destroy_player(level_one_twenty);
}

void test_catalog_and_real_learning()
{
	test_start("十六本成长书、十五项技能与真实读书限制完整");
	array(string) books = ({"xingmang","guantian1","hanchen","liuxing",
		"xingbi","guantian2","xingsuo","yaoguang","tianxuan",
		"guantian3","xingyu","guantian4","yueyin","xingluo",
		"guantian5","jiuxinglianzhu"});
	array(string) skills = ({"xingmang","guantian","hanchen","liuxing",
		"xingbi","xingsuo","yaoguang","tianxuan","xingyu","yueyin",
		"xingluo","jiuxinglianzhu","xinghezhuiluo","zhoutianjingzhi",
		"wanxiangxingbi"});
	object player = create_player("__testunit_tianxiang_books__","tianxiang",100);
	object outsider = create_player("__testunit_tianxiang_wrong__","fangshi",100);
	object low_player = create_player("__testunit_tianxiang_low__","tianxiang",4);
	object|zero original_player = this_player();
	string csv = Stdio.read_file(ROOT+"/gamelib/data/can_buy_book_list.csv");
	int catalog = 0;
	int failed = 0;
	string error_desc = "";
	foreach(books,string book_name){
		if(csv && search(csv,"book,"+"book/"+book_name+",")!=-1)
			catalog++;
		object|zero book = 0;
		mixed err = catch { book = clone(ROOT+"/gamelib/clone/item/book/"+book_name); };
		if(err || !book || book->profe_read_limit!="天象"){
			failed++;
			if(err) error_desc += describe_error(err);
		}
		if(book) destruct(book);
	}
	foreach(skills,string skill_name){
		object|zero skill = 0;
		mixed err = catch { skill = (object)(ROOT+"/gamelib/single/skills/"+skill_name); };
		if(err || !skill || search(skill->skill_type,"tianxiang")==-1 ||
		   skill->query_skill_level_max()!=5){
			failed++;
			if(err) error_desc += describe_error(err);
		}
	}
	mixed read_err = catch {
		object wrong_book = clone(ROOT+"/gamelib/clone/item/book/hanchen");
		set_this_player(outsider);
		if(wrong_book->read()!=3 || wrong_book->read_flag!=1)
			failed++;
		destruct(wrong_book);
		object low_book = clone(ROOT+"/gamelib/clone/item/book/hanchen");
		set_this_player(low_player);
		if(low_book->read()!=4 || low_book->read_flag!=1)
			failed++;
		destruct(low_book);
		object active_book = clone(ROOT+"/gamelib/clone/item/book/hanchen");
		set_this_player(player);
		if(active_book->read()!=1 || !player->skills["hanchen"])
			failed++;
		object duplicate = clone(ROOT+"/gamelib/clone/item/book/hanchen");
		if(duplicate->read()!=2 || duplicate->read_flag!=1)
			failed++;
		destruct(duplicate);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(read_err){ failed++; error_desc += describe_error(read_err); }
	if(catalog==16 && failed==0)
		test_pass();
	else
		test_fail(sprintf("目录=%d/16 失败=%d: %s",catalog,failed,error_desc));
	destroy_player(player);
	destroy_player(outsider);
	destroy_player(low_player);
}

void test_passive_book_cold_registry()
{
	test_start("观天被动书无需预热注册表即可真实学习并写入智力");
	object player = create_player("__testunit_tianxiang_passive__","tianxiang",2);
	object book = clone(ROOT+"/gamelib/clone/item/book/guantian1");
	object|zero original_player = this_player();
	int result = 0;
	string error_desc = "";
	mixed err = catch {
		set_this_player(player);
		result = book->read();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err) error_desc = describe_error(err);
	if(!err && result==1 && player->skills["guantian"] &&
	   player->query_base_think()==10)
		test_pass();
	else
		test_fail(sprintf("读取=%d 智力=%d: %s",result,
			player->query_base_think(),error_desc));
	if(book) destruct(book);
	destroy_player(player);
}

void test_star_mark_state_boundaries()
{
	test_start("星痕服务端封顶、消费、过期、移动与脱战清理");
	object player = create_player("__testunit_tianxiang_marks__","tianxiang",80);
	object outsider = create_player("__testunit_tianxiang_marks_wrong__","fangshi",80);
	object room_one = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object room_two = clone(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	int failed = 0;
	player->move(room_one);
	if(outsider->add_tianxiang_star_marks(3)!=0)
		failed++;
	if(player->add_tianxiang_star_marks(2)!=2 ||
	   player->add_tianxiang_star_marks(9)!=3 ||
	   player->consume_tianxiang_star_marks()!=3 ||
	   player->query_tianxiang_star_marks()!=0)
		failed++;
	player->add_tianxiang_star_marks(2);
	player["/tmp/tianxiang_star_expire"] = time()-1;
	if(player->query_tianxiang_star_marks()!=0)
		failed++;
	player->add_tianxiang_star_marks(2);
	player->move(room_two);
	if(player->query_tianxiang_star_marks()!=0)
		failed++;
	player->add_tianxiang_star_marks(2);
	player->_clean_fight();
	if(player->query_tianxiang_star_marks()!=0)
		failed++;
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("星痕状态边界失败=%d",failed));
	destroy_player(player);
	destroy_player(outsider);
	if(room_one) destruct(room_one);
	if(room_two) destruct(room_two);
}

void test_real_star_rotation_and_unlearned_gate()
{
	test_start("三种真实法术积蓄三星、星落引爆且未学技能不可伪造");
	object caster = create_player("__testunit_tianxiang_rotation__","tianxiang",80);
	object target = create_player("__testunit_tianxiang_target__","fangshi",80);
	// 本用例验证星痕生成/消费与星落实效，不验证闪避随机。生成技已有
	// 合法未命中重试，但星落命中即消费全部星痕，无法无损重试；固定
	// 靶人闪避可避免把一次合法随机闪避误报为职业逻辑回归。
	target->set_base_dodge(-1000000);
	object room = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	array(string) generators = ({"xingmang","hanchen","liuxing"});
	int failed = 0;
	int marks_after_generators = -1;
	int target_life_before_burst = -1;
	int target_life_after_burst = -1;
	int caster_mofa_before_burst = -1;
	int caster_mofa_after_burst = -1;
	int marks_after_burst = -1;
	int burst_cooldown = -1;
	int unlearned_life_before = -1;
	int unlearned_life_after = -1;
	int unlearned_mofa_before = -1;
	int unlearned_mofa_after = -1;
	string error_desc = "";
	mixed err = catch {
		caster->move(room);
		target->move(room);
		caster->skills["xingmang"] = ({1,0});
		caster->skills["hanchen"] = ({1,0});
		caster->skills["liuxing"] = ({1,0});
		caster->skills["xingluo"] = ({1,0});
		caster->_fight(target);
		foreach(generators,string skill_name){
			int marks_before = caster->query_tianxiang_star_marks();
			// 命中判定是战斗公式的一部分；允许真实未命中后重试，避免
			// 单测把合法闪避随机误判成星痕逻辑回归。
			for(int attempt=0;attempt<20 &&
			    caster->query_tianxiang_star_marks()==marks_before;attempt++){
				caster->timeCold = 0;
				caster->f_skills[skill_name] = 0;
				caster->perform(skill_name,1);
			}
			if(caster->query_tianxiang_star_marks()!=marks_before+1)
				failed++;
		}
		marks_after_generators = caster->query_tianxiang_star_marks();
		if(marks_after_generators!=3)
			failed++;
		int life_before = target->get_cur_life();
		int mofa_before = caster->get_cur_mofa();
		target_life_before_burst = life_before;
		caster_mofa_before_burst = mofa_before;
		// 战斗命中率依法封顶99%，固定低闪避仍有1%合法未命中。
		// 星落未命中也会消耗星痕，测试重试前补回三星，避免随机数
		// 把星痕消费与爆发伤害回归误报为失败。
		for(int attempt=0;attempt<20 &&
		    target->get_cur_life()>=life_before;attempt++){
			if(caster->query_tianxiang_star_marks()<3)
				caster->add_tianxiang_star_marks(
					3-caster->query_tianxiang_star_marks());
			caster->timeCold = 0;
			caster->f_skills["xingluo"] = 0;
			caster->perform("xingluo",1);
		}
		target_life_after_burst = target->get_cur_life();
		caster_mofa_after_burst = caster->get_cur_mofa();
		marks_after_burst = caster->query_tianxiang_star_marks();
		burst_cooldown = caster->f_skills["xingluo"];
		if(target->get_cur_life()>=life_before ||
		   caster->get_cur_mofa()>=mofa_before ||
		   caster->query_tianxiang_star_marks()!=0 ||
		   caster->f_skills["xingluo"]!=19 ||
		   caster->query_tianxiang_star_bonus_percent(0,3)!=30 ||
		   caster->query_tianxiang_star_bonus_percent(target,3)!=24 ||
		   caster->query_tianxiang_star_bonus_percent(target,99)!=24)
			failed++;
		m_delete(caster->skills,"hanchen");
		caster->timeCold = 0;
		caster->f_skills["hanchen"] = 0;
		life_before = target->get_cur_life();
		mofa_before = caster->get_cur_mofa();
		unlearned_life_before = life_before;
		unlearned_mofa_before = mofa_before;
		caster->perform("hanchen",1);
		unlearned_life_after = target->get_cur_life();
		unlearned_mofa_after = caster->get_cur_mofa();
		if(target->get_cur_life()!=life_before ||
		   caster->get_cur_mofa()!=mofa_before)
			failed++;
	};
	if(err){ failed++; error_desc = describe_error(err); }
	if(!err && failed==0)
		test_pass();
	else
		test_fail(sprintf("真实星痕循环失败=%d marks=%d/%d "
			"life=%d/%d mofa=%d/%d cold=%d unlearned=%d/%d,%d/%d: %s",
			failed,marks_after_generators,marks_after_burst,
			target_life_before_burst,target_life_after_burst,
			caster_mofa_before_burst,caster_mofa_after_burst,
			burst_cooldown,unlearned_life_before,unlearned_life_after,
			unlearned_mofa_before,unlearned_mofa_after,error_desc));
	destroy_player(caster);
	destroy_player(target);
	if(room) destruct(room);
}

void test_shield_curse_and_hidden_balance()
{
	test_start("星壁智力成长、星锁控制与三本隐藏技能边界真实生效");
	object caster = create_player("__testunit_tianxiang_utility__","tianxiang",80);
	object target = create_player("__testunit_tianxiang_utility_target__","fangshi",80);
	object room = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	array(string) hidden = ({"xinghezhuiluo","zhoutianjingzhi","wanxiangxingbi"});
	int failed = 0;
	string csv = Stdio.read_file(ROOT+"/gamelib/data/can_buy_book_list.csv");
	string error_desc = "";
	mixed err = catch {
		caster->move(room);
		target->move(room);
		caster->_fight(target);
		caster->skills["xingbi"] = ({1,0});
		caster->perform("xingbi",1);
		if(caster->query_buff("buff",0)!="absorb" ||
		   caster->query_buff("buff",1)!=180+caster->query_think()*3 ||
		   caster->query_buff("buff",2)!=12)
			failed++;
		caster->clean_buff("buff");
		caster->skills["xingsuo"] = ({1,0});
		// 星锁保留真实命中判定；有限重试只消除单测随机闪避，
		// 不改变技能伤害、命中率或线上冷却。
		for(int attempt=0;attempt<20 &&
		    target->query_debuff("curse",0)!="all_mofa_defend";attempt++){
			caster->timeCold = 0;
			caster->f_skills["xingsuo"] = 0;
			caster->perform("xingsuo",1);
		}
		if(target->query_debuff("curse",0)!="all_mofa_defend" ||
		   target->query_debuff("curse",1)!=12 ||
		   target->query_debuff("curse",2)!=8)
			failed++;
		foreach(hidden,string skill_name){
			object skill = (object)(ROOT+"/gamelib/single/skills/"+skill_name);
			object book = clone(ROOT+"/gamelib/clone/item/book/"+skill_name);
			if(!skill || !book || skill->skill_rare!="mythic" ||
			   skill->query_s_delayTime(1)<50 ||
			   skill->query_performs_cast(1)<300 ||
			   book->level_limit!=80 || book->profe_read_limit!="天象" ||
			   search(csv,"book/"+skill_name)!=-1)
				failed++;
			if(book) destruct(book);
		}
	};
	if(err){ failed++; error_desc = describe_error(err); }
	if(!err && failed==0)
		test_pass();
	else
		test_fail(sprintf("护盾、诅咒或隐藏技能失败=%d: %s",failed,error_desc));
	destroy_player(caster);
	destroy_player(target);
	if(room) destruct(room);
}

void test_teacher_tasks_equipment_and_medicine()
{
	test_start("导师、任务、成长、装备、药品与职业商店共享链路完整");
	object player = create_player("__testunit_tianxiang_shared__","tianxiang",80);
	object teacher = clone(ROOT+"/gamelib/clone/npc/tianxiang_teacher.pike");
	object medicine = clone(ROOT+"/gamelib/clone/item/food/xiaohuandan");
	object equipment = clone(ROOT+"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object|zero original_player = this_player();
	string links = "";
	string tasks = Stdio.read_file(ROOT+"/gamelib/data/task/task_list.csv");
	int failed = 0;
	set_this_player(player);
	links = teacher->query_npc_links();
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(!teacher || teacher->query_raceId()!="third" ||
	   teacher->query_profeId()!="tianxiang" ||
	   search(links,"[学习天象技能:buy_items book tianxiang]")==-1 ||
	   !tasks || search(tasks,"【特殊】初观星轨")==-1 ||
	   search(tasks,"【象】三星同辉")==-1 ||
	   !TASKD->is_growth_task_profession("tianxiang") ||
	   search(TASKD->query_growth_task_title("tianxiang",80),"天象")==-1 ||
	   !medicine->profe_limit["tianxiang"] ||
	   search(equipment->query_item_profeLimit(),"tianxiang")==-1)
		failed++;
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("共享系统失败=%d",failed));
	if(teacher) destruct(teacher);
	if(medicine) destruct(medicine);
	if(equipment) destruct(equipment);
	destroy_player(player);
}

void test_autofight_vip_and_pvp_boundaries()
{
	test_start("普通智能选法术、会员策略仅PVE且不改变战斗数值");
	object player = create_player("__testunit_tianxiang_auto__","tianxiang",80);
	object pvp = create_player("__testunit_tianxiang_auto_pvp__","fangshi",80);
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	array(string) free_names = ({});
	array(string) pve_names = ({});
	array(string) pvp_names = ({});
	object autofight_daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string recommended = "";
	int think_before = player->query_think();
	int life_before = player->query_life_max();
	string error_desc = "";
	mixed err = catch {
		player->skills["xingmang"] = ({1,0});
		player->skills["hanchen"] = ({1,0});
		player->skills["xingluo"] = ({1,0});
		recommended = autofight_daemon->query_recommended_auto_skill(player);
		player->move(room);
		pvp->move(room);
		npc->move(room);
		player->_fight(npc);
		player->add_tianxiang_star_marks(2);
		free_names = PROFESSIONVIPD->query_tianxiang_context_candidates(player);
		set_active_vip(player,3);
		PROFESSIONVIPD->initialize_player(player);
		PROFESSIONVIPD->set_auto_enabled(player,1);
		PROFESSIONVIPD->set_strategy(player,"burst");
		pve_names = PROFESSIONVIPD->query_tianxiang_context_candidates(player);
		player->_clean_fight();
		player->_fight(pvp);
		pvp_names = PROFESSIONVIPD->query_tianxiang_context_candidates(player);
	};
	if(err) error_desc = describe_error(err);
	if(!err && recommended=="xingluo" && sizeof(free_names)==0 &&
	   search(pve_names,"xingluo")!=-1 && sizeof(pvp_names)==0 &&
	   player->query_think()==think_before &&
	   player->query_life_max()==life_before &&
	   PROFESSIONVIPD->query_style_info("tianxiang","wanxiang")["cost"]==200)
		test_pass();
	else
		test_fail(sprintf("推荐=%s PVE=%O PVP=%O: %s",
			recommended,pve_names,pvp_names,error_desc));
	destroy_player(player);
	destroy_player(pvp);
	if(npc) destruct(npc);
	if(room) destruct(room);
}

void test_assets_ui_and_deployment()
{
	test_start("原创图标、男女头像、双镜像、Vue状态与部署复制完整");
	array(string) names = ({"tianxiang_logo.png","tianxiang_male.png",
		"tianxiang_female.png","tianxiang_male.gif","tianxiang_female.gif"});
	string male = Stdio.read_file(ROOT+"/images/tianxiang_male.png");
	string female = Stdio.read_file(ROOT+"/images/tianxiang_female.png");
	string logo = Stdio.read_file(ROOT+"/images/tianxiang_logo.png");
	string vue = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string css = Stdio.read_file(ROOT+"/vue_source/css/app.css");
	string api = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	string deploy = Stdio.read_file(ROOT+"/restart-docker.sh");
	int failed = 0;
	foreach(names,string name){
		string image_one = Stdio.read_file(ROOT+"/images/"+name);
		string image_two = Stdio.read_file(ROOT+"/web/images/"+name);
		if(!image_one || !image_two || sizeof(image_one)<100 || image_one!=image_two ||
		   search(deploy,"\""+name+"\"")==-1)
			failed++;
	}
	if(!male || !female || !logo || male==female || male==logo || female==logo ||
	   !vue || search(vue,"【象】") == -1 ||
	   !css || search(css,"profession-style-tianxiang-3") == -1 ||
	   !api || search(api,"result[\"star_marks\"]") == -1)
		failed++;
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("资产/UI/部署失败=%d",failed));
}

int main(int argc,array(string) argv)
{
	werror("\n╔════════════════════════════════════════════════╗\n");
	werror("║             天象职业全链路测试                ║\n");
	werror("╚════════════════════════════════════════════════╝\n");
	test_creation_growth_and_identity();
	test_catalog_and_real_learning();
	test_passive_book_cold_registry();
	test_star_mark_state_boundaries();
	test_real_star_rotation_and_unlearned_gate();
	test_shield_curse_and_hidden_balance();
	test_teacher_tasks_equipment_and_medicine();
	test_autofight_vip_and_pvp_boundaries();
	test_assets_ui_and_deployment();
	werror("\n天象测试：%d通过，%d失败\n",
		test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
