#!/usr/bin/env pike
/** 镇越从建角、技能书、坦克机制到隐藏掉落的运行时测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void test_start(string name){ test_results["total"]++; werror("\n[镇越全链路 %d] %s\n",test_results["total"],name); }
void test_pass(){ test_results["passed"]++; werror("  ✓ 通过\n"); }
void test_fail(string reason){ test_results["failed"]++; werror("  ✗ 失败: %s\n",reason); }

object create_player(string name,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "镇越测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("zhenyue");
	player->setup_player("third","zhenyue");
	player->level = level;
	player->set_att_by_level();
	player->set_mofa(player->query_mofa_max());
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_creation_and_growth()
{
	test_start("中立建角、身份、初始技能与等级成长");
	object level_one = create_player("__testunit_zhenyue_one__",1);
	object level_thirty = create_player("__testunit_zhenyue_thirty__",30);
	object level_eighty = create_player("__testunit_zhenyue_eighty__",80);
	object level_one_twenty = create_player(
		"__testunit_zhenyue_one_twenty__",120);
	string source = Stdio.read_file(ROOT+"/gamelib/d/init");
	if(level_one && level_thirty && level_eighty && level_one_twenty &&
	   source &&
	   search(source,"[镇越:choice_profe third/zhenyue]")!=-1 &&
	   search(source,"valid_professions")!=-1 &&
	   search(source,"if(me->skills[\"yueji\"]==0)")!=-1 &&
	   search(source,"me->skills[\"yueji\"]=({1,0});")!=-1 &&
	   search(source,"me->query_profeId()==\"zhenyue\" && !me->skills[\"yueji\"]")!=-1 &&
	   search(source,"string race = (string)(me->query_raceId() || \"\")")!=-1 &&
	   search(source,"else if(race==\"third\")")!=-1 &&
	   level_one->query_raceId()=="third" &&
	   level_one->query_profe_cn("zhenyue")=="镇越" &&
	   level_one->query_str()==14 && level_one->query_dex()==3 &&
	   level_one->query_think()==5 &&
	   level_thirty->query_str()==92 &&
	   level_thirty->query_dex()==20 &&
	   level_thirty->query_think()==28 &&
	   level_eighty->query_str()==14+(int)(79*2.7) &&
	   level_eighty->query_dex()==3+(int)(79*0.6) &&
	   level_one_twenty->query_str()==14+(int)(119*2.7) &&
	   level_one_twenty->query_think()==5+(int)(119*0.8) &&
	   level_thirty->query_defend_power()>level_thirty->query_str()*3)
		test_pass();
	else
		test_fail("建角接线、身份或1/30级属性不正确");
	destroy_player(level_one);
	destroy_player(level_thirty);
	destroy_player(level_eighty);
	destroy_player(level_one_twenty);
}

void test_passive_book_lazy_learning()
{
	test_start("被动技能书无需预热技能注册表即可真实学习");
	object player = create_player("__testunit_zhenyue_lazy_book__",10);
	object book = clone(ROOT+"/gamelib/clone/item/book/shanyin1");
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
	if(err)
		error_desc = describe_error(err);
	if(!err && result==1 && player->skills["shanyin"] &&
	   player->query_base_defend()==20)
		test_pass();
	else
		test_fail(sprintf("读取结果=%d: %s",result,error_desc));
	if(book)
		destruct(book);
	destroy_player(player);
}

void test_skill_catalog_and_real_learning()
{
	test_start("十六本成长书、十五项技能与真实读书限制");
	object player = create_player("__testunit_zhenyue_books__",100);
	object outsider = clone(GAMELIB_USER);
	object|zero book = 0;
	object|zero original_player = this_player();
	string csv = Stdio.read_file(ROOT+"/gamelib/data/can_buy_book_list.csv");
	int catalog = 0;
	int failed = 0;
	string error_desc = "";

	outsider->set_name("__testunit_zhenyue_book_outsider__");
	outsider->name_cn = "外职业";
	outsider->set_project("gamelib");
	outsider->setup("testunit-only");
	outsider->set_raceId("human");
	outsider->set_profeId("jianxian");
	outsider->setup_player("human","jianxian");
	outsider->level = 100;
	outsider->set_att_by_level();

	mixed err = catch {
		foreach(csv/"\n",string line){
			array(string) parts = line/",";
			if(sizeof(parts)<4 || parts[3]!="zhenyue")
				continue;
			object catalog_book = clone(ROOT+"/gamelib/clone/item/"+parts[1]);
			object skill = catalog_book ?
				(object)(ROOT+"/gamelib/single/skills/"+catalog_book->skill_bname) : 0;
			catalog++;
			if(!catalog_book || !skill || search(skill->skill_type,"zhenyue")==-1)
				failed++;
			if(catalog_book)
				destruct(catalog_book);
		}
		book = clone(ROOT+"/gamelib/clone/item/book/shanyin1");
		set_this_player(player);
		if(!book || book->read()!=1 || !player->skills["shanyin"] ||
		   player->query_base_defend()!=20)
			failed++;
		book = clone(ROOT+"/gamelib/clone/item/book/shanhebi");
		if(!book || book->read()!=1 || !player->skills["shanhebi"])
			failed++;
		book = clone(ROOT+"/gamelib/clone/item/book/dizhenhou");
		set_this_player(outsider);
		if(!book || book->read()!=3)
			failed++;
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(!err && catalog==16 && failed==0)
		test_pass();
	else
		test_fail(sprintf("目录=%d 失败=%d: %s",catalog,failed,error_desc));
	if(book)
		destruct(book);
	destroy_player(player);
	if(outsider)
		destruct(outsider);
}

void test_team_guard_edges()
{
	test_start("山河壁仅保护自己与同房间存活队友且不覆盖其他Buff");
	object tank = create_player("__testunit_zhenyue_guard__",80);
	object teammate = create_player("__testunit_zhenyue_member__",80);
	object dead_member = create_player("__testunit_zhenyue_dead__",80);
	object outsider = create_player("__testunit_zhenyue_outsider__",80);
	object room = (object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object other_room = (object)(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	int applied = 0;
	int tank_guard_before_move = 0;
	int first_damage = -1;
	int second_damage = -1;
	string error_desc = "";

	mixed err = catch {
		tank->set_term("__testunit_zhenyue_team__");
		teammate->set_term("__testunit_zhenyue_team__");
		dead_member->set_term("__testunit_zhenyue_team__");
		outsider->set_term("__testunit_zhenyue_other__");
		tank->move(room); teammate->move(room); dead_member->move(room); outsider->move(room);
		dead_member->set_life(0);
		teammate->set_buff("buff2",0,"all_mofa_attack");
		teammate->set_buff("buff2",1,77);
		teammate->set_buff("buff2",2,10);
		applied = tank->apply_team_guard_to_group(tank,500,12);
		tank_guard_before_move = tank->query_buff("team_guard",1);
		first_damage = teammate->absorb_team_guard_damage(300);
		second_damage = teammate->absorb_team_guard_damage(350);
		tank->move(other_room);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && applied==2 &&
	   tank_guard_before_move==500 &&
	   teammate->query_buff("buff2",0)=="all_mofa_attack" &&
	   dead_member->query_buff("team_guard",0)=="none" &&
	   outsider->query_buff("team_guard",0)=="none" &&
	   first_damage==0 && second_damage==150 &&
	   teammate->query_buff("team_guard",0)=="none" &&
	   tank->query_buff("team_guard",0)=="none")
		test_pass();
	else
		test_fail(sprintf("applied=%d damage=%d/%d: %s",applied,first_damage,second_damage,error_desc));
	destroy_player(tank); destroy_player(teammate); destroy_player(dead_member); destroy_player(outsider);
}

void test_all_skill_stages_and_passive_growth()
{
	test_start("十五项技能五阶成长、类型与山印高阶读书完整");
	array(string) skills = ({
		"yueji","shanyin","zhenyan","hengshanji","dizhenhou",
		"shanhebi","juyuepo","xuantiedun","yuefanzhen",
		"zhenyuezhenshen","wanshanbugu","zhenhunhou",
		"wanshanchaogong","buzhouzhenji","tiandichengbi"
	});
	array(string) supported_types = ({"phy","buff","taunt","team_guard"});
	object player = create_player("__testunit_zhenyue_all_stages__",200);
	object|zero original_player = this_player();
	int failed = 0;
	string failure = "";
	foreach(skills,string skill_name){
		object skill = (object)(ROOT+
			"/gamelib/single/skills/"+skill_name);
		int previous_attack = 0;
		int previous_cast = 0;
		int previous_limit = 0;
		if(!skill || skill->query_skill_level_max()!=5 ||
		   search(skill->skill_type,"zhenyue")==-1 ||
		   search(supported_types,skill->s_skill_type)==-1){
			failed++;
			failure += " "+skill_name+"(基础契约)";
			continue;
		}
		for(int stage=1;stage<=5;stage++){
			int attack = skill->query_performs_attack(stage);
			int cast = skill->query_performs_cast(stage);
			int limit = skill->query_performs_level_limit(stage);
			int delay = skill->query_s_delayTime(stage);
			if(attack<=previous_attack || limit<=previous_limit ||
			   delay<0 || (skill->s_type=="zhudong" &&
			   (cast<=previous_cast || delay<=0))){
				failed++;
				failure += sprintf(" %s(阶%d)",skill_name,stage);
				break;
			}
			previous_attack = attack;
			previous_cast = cast;
			previous_limit = limit;
		}
	}
	string error_desc = "";
	mixed err = catch {
		set_this_player(player);
		for(int stage=1;stage<=5;stage++){
			object book = clone(ROOT+
				"/gamelib/clone/item/book/shanyin"+stage);
			if(!book || book->read()!=1)
				failed++;
			if(book)
				destruct(book);
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(!err && failed==0 && player->skills["shanyin"] &&
	   player->skills["shanyin"][0]==5 && player->query_base_defend()==300)
		test_pass();
	else
		test_fail(sprintf("技能阶位失败=%d:%s %s",
			failed,failure,error_desc));
	destroy_player(player);
}

void test_team_guard_recast_and_team_change()
{
	test_start("山河壁弱护盾不覆盖强护盾且离队立即清理");
	object player = create_player("__testunit_zhenyue_guard_recast__",80);
	int first = player->apply_team_guard(800,12);
	int weaker = player->apply_team_guard(500,20);
	int stronger = player->apply_team_guard(1000,10);
	int guard_before_team_change = player->query_buff("team_guard",1);
	player->set_term("__testunit_guard_old_team__");
	player->set_term("__testunit_guard_new_team__");
	if(first==1 && weaker==0 && stronger==1 &&
	   guard_before_team_change==1000 &&
	   player->query_buff("team_guard",0)=="none")
		test_pass();
	else
		test_fail("重复施放强弱优先级或队伍变更清理失败");
	destroy_player(player);
}

void test_threat_and_balance_contract()
{
	test_start("震吼仇恨置顶、跨房拒绝与伤害仇恨倍率");
	object tank = create_player("__testunit_zhenyue_taunt__",80);
	object teammate = create_player("__testunit_zhenyue_hate_member__",80);
	object enemy = create_player("__testunit_zhenyue_hate_enemy__",80);
	object room = (object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object other_room = (object)(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	int forced;
	int rejected;
	int stale_ignored;
	tank->move(room); teammate->move(room); enemy->move(room);
	enemy->flush_targets(teammate,1000);
	forced = enemy->force_target(tank,50);
	teammate->move(other_room);
	enemy->flush_targets(teammate,100000);
	stale_ignored = enemy->query_max_threat();
	teammate->move(room);
	tank->move(other_room);
	rejected = enemy->force_target(tank,9999);
	if(forced==1050 && stale_ignored==1050 && enemy->first_target==tank && rejected==0 &&
	   MUD_SKILLSD["hengshanji"]->query_hate_multiplier()==400 &&
	   MUD_SKILLSD["buzhouzhenji"]->query_hate_multiplier()==600 &&
	   MUD_SKILLSD["shanhebi"]->s_skill_type=="team_guard" &&
	   MUD_SKILLSD["dizhenhou"]->s_skill_type=="taunt")
		test_pass();
	else
		test_fail(sprintf("forced=%d stale=%d rejected=%d",forced,stale_ignored,rejected));
	destroy_player(tank); destroy_player(teammate); destroy_player(enemy);
}

void test_hidden_equipment_tasks_and_teacher()
{
	test_start("三本隐藏传承、装备药品、导师与每级任务完整接线");
	array(string) hidden = ({"wanshanchaogong","buzhouzhenji","tiandichengbi"});
	object player = create_player("__testunit_zhenyue_shared__",80);
	object teacher = clone(ROOT+"/gamelib/clone/npc/zhenyue_teacher.pike");
	object medicine = clone(ROOT+"/gamelib/clone/item/food/xiaohuandan");
	object equipment = clone(ROOT+"/gamelib/clone/item/armor/2caoxie/2caoxie");
	object|zero original_player = this_player();
	string csv = Stdio.read_file(ROOT+"/gamelib/data/can_buy_book_list.csv");
	string links = "";
	int failed = 0;
	foreach(hidden,string name){
		object skill = (object)(ROOT+"/gamelib/single/skills/"+name);
		object book = clone(ROOT+"/gamelib/clone/item/book/"+name);
		if(!skill || !book || skill->skill_rare!="mythic" ||
		   book->level_limit!=80 || book->profe_read_limit!="镇越" ||
		   search(csv,"book/"+name)!=-1)
			failed++;
		if(book)
			destruct(book);
	}
	set_this_player(player);
	links = teacher->query_npc_links();
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(ITEMSD->query_hidden_skill_book_count()!=37 ||
	   ITEMSD->query_hidden_skill_drop_rate()!=37 ||
	   ITEMSD->can_drop_hidden_skill_book(70,30)!=1 ||
	   ITEMSD->can_drop_hidden_skill_book(70,37)!=1 ||
	   ITEMSD->can_drop_hidden_skill_book(70,38)!=0 ||
	   search(equipment->query_item_profeLimit(),"zhenyue")==-1 ||
	   !medicine->profe_limit["zhenyue"] ||
	   !TASKD->is_growth_task_profession("zhenyue") ||
	   search(TASKD->query_growth_task_title("zhenyue",80),"镇山守望")==-1 ||
	   search(links,"[学习镇越技能:buy_items book zhenyue]")==-1)
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

void test_original_assets_and_avatar_choices()
{
	test_start("原创职业图标、男女头像、建角展示与容器部署完整接线");
	object player = create_player("__testunit_zhenyue_avatar__",1);
	object human_square = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object monst_square = (object)(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	string logo = Stdio.read_file(ROOT+"/images/zhenyue_logo.png");
	string male = Stdio.read_file(ROOT+"/images/zhenyue_male.gif");
	string female = Stdio.read_file(ROOT+"/images/zhenyue_female.gif");
	string web_logo = Stdio.read_file(ROOT+"/web/images/zhenyue_logo.png");
	string web_male = Stdio.read_file(ROOT+"/web/images/zhenyue_male.gif");
	string web_female = Stdio.read_file(ROOT+"/web/images/zhenyue_female.gif");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string deploy_source = Stdio.read_file(ROOT+"/restart-docker.sh");
	array(string) male_choices = ({});
	array(string) female_choices = ({});
	player->sex = "male";
	male_choices = human_square->query_pic_choices(player);
	player->sex = "female";
	female_choices = monst_square->query_pic_choices(player);
	if(logo && male && female && sizeof(logo)>1000 &&
	   sizeof(male)>1000 && sizeof(female)>1000 &&
	   logo==web_logo && male==web_male && female==web_female &&
	   male!=female &&
	   search(male_choices,"zhenyue_male")!=-1 &&
	   search(female_choices,"zhenyue_female")!=-1 &&
	   init_source && search(init_source,"images/zhenyue_logo.png")!=-1 &&
	   deploy_source && search(deploy_source,"\"zhenyue_logo.png\"")!=-1 &&
	   search(deploy_source,"\"zhenyue_male.gif\"")!=-1 &&
	   search(deploy_source,"\"zhenyue_female.gif\"")!=-1)
		test_pass();
	else
		test_fail("图片缺失、男女头像重复、选择入口或容器复制未接线");
	destroy_player(player);
}

void test_profession_quest_chain_and_reward()
{
	test_start("20级专属奖励与53级四段守御传承按前置解锁");
	object player = create_player("__testunit_zhenyue_quests__",53);
	object teacher = clone(ROOT+"/gamelib/clone/npc/zhenyue_teacher.pike");
	object wrong_teacher = clone(ROOT+
		"/gamelib/clone/npc/fangshi_teacher.pike");
	object reward = clone(ROOT+
		"/gamelib/clone/item/taskaward/zhenyuehuxin");
	object|zero original_player = this_player();
	string task_list = "";
	int accepted = 0;
	int wrong_npc = 0;
	int completed = 0;
	int skipped = 0;
	int continued = 0;
	int guide_failed = 0;
	string human_square = Stdio.read_file(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	string monst_square = Stdio.read_file(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	for(int taskid=369;taskid<=373;taskid++){
		if(!TASKD->queryTaskHasGuide(taskid))
			guide_failed++;
	}
	set_this_player(player);
	task_list = TASKD->query_npc_taskList(player,teacher);
	wrong_npc = TASKD->get_task(player,369,wrong_teacher);
	accepted = TASKD->get_task(player,369,teacher);
	player["/taskd/kill"][369]["清云兽"] = 3;
	player["/taskd/kill"][369]["灵龟"] = 3;
	player["/taskd/kill"][369]["雷鸟"] = 3;
	completed = TASKD->isComplete(player,369);
	skipped = TASKD->get_task(player,371,teacher);
	player["/taskd/done"] = ([370:1]);
	continued = TASKD->get_task(player,371,teacher);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(search(task_list,"初镇山门")!=-1 &&
	   search(task_list,"背山试阵")!=-1 &&
	   search(task_list,"冥关承压")==-1 &&
	   TASKD->queryTaskProfe(369)=="镇越" &&
	   TASKD->queryTaskProfe(373)=="镇越" &&
	   wrong_npc==7 && accepted==1 && completed==1 &&
	   skipped==7 && continued==1 &&
	   guide_failed==0 && human_square && monst_square &&
	   search(human_square,"zhenyue_teacher")!=-1 &&
	   search(monst_square,"zhenyue_teacher")!=-1 &&
	   reward && reward->query_item_canLevel()==20 &&
	   search(reward->query_item_profeLimit(),"zhenyue")!=-1 &&
	   reward->query_item_canTrade()==0 &&
	   reward->query_item_canSend()==0 &&
	   reward->query_item_canStorage()==1)
		test_pass();
	else
		test_fail(sprintf("错误导师=%d 接取=%d 完成=%d 跳过=%d 延续=%d 引导失败=%d",
			wrong_npc,accepted,completed,skipped,continued,guide_failed));
	if(reward) destruct(reward);
	if(teacher) destruct(teacher);
	if(wrong_teacher) destruct(wrong_teacher);
	destroy_player(player);
}

void test_skill_ui_and_perform_authorization()
{
	test_start("重启后已学技能可见且未学技能不能伪造施放");
	object player = create_player("__testunit_zhenyue_skill_ui__",80);
	object enemy = create_player("__testunit_zhenyue_skill_target__",80);
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	string skill_view = "";
	int mana_before;
	int life_before;
	int cooldown_before;
	string toolbar_view = "";
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		player->move(room);
		enemy->move(room);
		player->skills["yueji"] = ({1,0});
		skill_view = player->view_skills();
		player->toolbar_key = ({(["yueji":1]),(["none":0]),
			(["none":0]),(["none":0]),(["none":0]),(["none":0])});
		toolbar_view = player->query_toolbar_cn();
		player->skills_enable = "yueji";
		player->_fight(enemy);
		if(player->skills_enable!="yueji")
			failed++;
		mana_before = player->get_cur_mofa();
		life_before = enemy->get_cur_life();
		cooldown_before = player->f_skills["buzhouzhenji"];
		player->perform("buzhouzhenji");
		if(player->get_cur_mofa()!=mana_before ||
		   enemy->get_cur_life()!=life_before ||
		   player->f_skills["buzhouzhenji"]!=cooldown_before)
			failed++;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && failed==0 && search(skill_view,"岳击")!=-1 &&
	   search(toolbar_view,"岳击")!=-1)
		test_pass();
	else
		test_fail(sprintf("技能页或施法授权失败=%d: %s",failed,error_desc));
	destroy_player(player);
	destroy_player(enemy);
}

void test_all_active_skill_runtime_contracts()
{
	test_start("十四项主动技能逐项消耗、冷却与实效运行验证");
	array(string) active_skills = ({
		"yueji","zhenyan","hengshanji","dizhenhou","shanhebi",
		"juyuepo","xuantiedun","yuefanzhen","zhenyuezhenshen",
		"wanshanbugu","zhenhunhou","wanshanchaogong",
		"buzhouzhenji","tiandichengbi"
	});
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int failed = 0;
	string failure = "";
	foreach(active_skills,string skill_name){
		object player = create_player(
			"__testunit_zhenyue_active_"+skill_name+"__",200);
		object target = create_player(
			"__testunit_zhenyue_target_"+skill_name+"__",200);
		object weapon = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		object skill = (object)(ROOT+
			"/gamelib/single/skills/"+skill_name);
		int mana_before = 0;
		int cooldown_after = 0;
		string effect_type = "";
		string error_desc = "";
		mixed err = catch {
			player->move(room);
			target->move(room);
			weapon->move(player);
			player->wield(weapon);
			player->skills[skill_name] = ({1,0});
			player->set_mofa(player->query_mofa_max());
			player->_fight(target);
			target->_fight(player);
			mana_before = player->get_cur_mofa();
			player->perform(skill_name,1);
			cooldown_after = player->f_skills[skill_name];
			effect_type = (string)skill->s_skill_type;
		};
		if(err)
			error_desc = describe_error(err);
		int effect_ok = 0;
		if(!err && skill){
			if(effect_type=="phy")
				effect_ok = cooldown_after>1;
			else if(effect_type=="taunt")
				effect_ok = target->first_target==player;
			else if(effect_type=="team_guard")
				effect_ok =
					player->query_buff("team_guard",0)=="absorb" &&
					player->query_buff("team_guard",1)>0;
			else if(effect_type=="buff")
				effect_ok =
					player->query_buff("buff",0)==skill->s_curse_type &&
					player->query_buff("buff",1)>0;
		}
		if(err || !skill ||
		   search(skill->skill_type,"zhenyue")==-1 ||
		   player->get_cur_mofa()>=mana_before || cooldown_after<=1 ||
		   !effect_ok){
			failed++;
			failure += sprintf(
				" %s(type=%s mana=%d/%d cold=%d effect=%d err=%s)",
				skill_name,effect_type,mana_before,
				player ? player->get_cur_mofa() : -1,
				cooldown_after,effect_ok,error_desc);
		}
		if(player && player->query_in_combat())
			player->_clean_fight();
		if(target && target->query_in_combat())
			target->_clean_fight();
		destroy_player(player);
		destroy_player(target);
	}
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("逐技能运行失败=%d:%s",failed,failure));
}

void test_aoe_target_cleanup()
{
	test_start("AOE目标列表清除死亡与跨地图对象且当前目标同步");
	object tank = create_player("__testunit_zhenyue_aoe__",80);
	object valid = create_player("__testunit_zhenyue_aoe_valid__",80);
	object stale = create_player("__testunit_zhenyue_aoe_stale__",80);
	object dead = create_player("__testunit_zhenyue_aoe_dead__",80);
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object other_room = (object)(ROOT+
		"/gamelib/d/jinaodao/yuhuacunguangchang");
	tank->move(room); valid->move(room); stale->move(room); dead->move(room);
	tank->flush_targets(valid,50);
	tank->flush_targets(stale,100);
	tank->flush_targets(dead,200);
	stale->move(other_room);
	dead->set_life(0);
	array(object) targets = tank->get_all_targets();
	if(sizeof(targets)==1 && targets[0]==valid && tank->first_target==valid){
		tank->clean_targets(valid);
		if(!tank->first_target)
			test_pass();
		else
			test_fail("移除当前目标后 first_target 未清理");
	}
	else
		test_fail("死亡或跨地图目标仍残留在 AOE 列表");
	destroy_player(tank); destroy_player(valid);
	destroy_player(stale); destroy_player(dead);
}

void test_neutral_social_and_faction_boundaries()
{
	test_start("中立镇越可跨阵营组队交流但不能伪装转换阵营");
	object tank = create_player("__testunit_zhenyue_social__",20);
	object human = create_player("__testunit_zhenyue_human__",20);
	object monst = create_player("__testunit_zhenyue_monst__",20);
	human->set_raceId("human");
	human->set_profeId("jianxian");
	monst->set_raceId("monst");
	monst->set_profeId("kuangyao");
	if(tank->can_use_room_race("human") &&
	   tank->can_use_room_race("monst") &&
	   tank->can_use_room_race("third") &&
	   !tank->can_change_faction() &&
	   tank->can_socialize_with(human) &&
	   tank->can_socialize_with(monst) &&
	   human->can_socialize_with(tank) &&
	   monst->can_socialize_with(tank) &&
	   !human->can_socialize_with(monst))
		test_pass();
	else
		test_fail("跨阵营设施、双向社交或阵营转换边界错误");
	destroy_player(tank); destroy_player(human); destroy_player(monst);
}

void test_purchase_boundary_and_identity_surfaces()
{
	test_start("购买类型/路径边界与镇越身份展示安全");
	object player = create_player("__testunit_zhenyue_purchase__",80);
	object|zero original_player = this_player();
	string forged = "";
	string missing = "";
	string traversal = "";
	string source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string top_source = Stdio.read_file(ROOT+"/gamelib/cmds/look_top.pike");
	string base_source = Stdio.read_file(ROOT+"/lowlib/system/inherit/base.pike");
	string newbie_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/newbied.pike");
	string buy_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/buy_items.pike");
	string error_desc = "";
	mixed err = catch {
		set_this_player(player);
		forged = BUYD->buy_items("book/yueji","food");
		missing = BUYD->item_view("book/not-a-real-zhenyue-book",1,1);
		traversal = BUYD->item_view("../user/test",1,1);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(!err && search(forged,"类别不匹配")!=-1 &&
	   search(missing,"暂时不可用")!=-1 &&
	   search(traversal,"资料无效")!=-1 &&
	   source && search(source,"【越】")!=-1 &&
	   top_source && search(top_source,"【越】")!=-1 &&
	   base_source && search(base_source,"无名镇越")!=-1 &&
	   newbie_source && search(newbie_source,"震吼稳住仇恨")!=-1 &&
	   buy_source && search(buy_source,"else if(type == \"zhenyue\")")!=-1 &&
	   search(buy_source,"[镇越:buy_items ")!=-1)
		test_pass();
	else
		test_fail("购买边界或镇越身份文案缺失: "+error_desc);
	destroy_player(player);
}

void test_physical_damage_and_broken_weapon_boundary()
{
	test_start("镇越物理实战伤害与零耐久武器边界");
	object normal = create_player("__testunit_zhenyue_damage_normal__",120);
	object broken = create_player("__testunit_zhenyue_damage_broken__",120);
	object normal_target = create_player(
		"__testunit_zhenyue_damage_target_a__",1);
	object broken_target = create_player(
		"__testunit_zhenyue_damage_target_b__",1);
	object normal_weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object broken_weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int normal_damage = 0;
	int broken_damage = 0;
	int normal_weapon_attack = 0;
	int broken_weapon_attack = 0;
	string error_desc = "";
	mixed err = catch {
		normal->set_str(30000);
		broken->set_str(30000);
		normal->set_base_hitte(100000);
		broken->set_base_hitte(100000);
		normal_target->set_base_dodge(-1000000);
		broken_target->set_base_dodge(-1000000);
		normal_target->set_base_life(1000000000);
		broken_target->set_base_life(1000000000);
		normal_target->flush_life();
		broken_target->flush_life();
		normal->move(room);
		broken->move(room);
		normal_target->move(room);
		broken_target->move(room);
		normal_weapon->set_attack_power(300000);
		normal_weapon->set_attack_power_limit(300000);
		broken_weapon->set_attack_power(300000);
		broken_weapon->set_attack_power_limit(300000);
		normal_weapon->item_cur_dura = 200;
		broken_weapon->item_cur_dura = 200;
		normal_weapon->move(normal);
		broken_weapon->move(broken);
		normal->wield(normal_weapon);
		broken->wield(broken_weapon);
		broken_weapon->item_cur_dura = 0;
		normal_weapon_attack = normal->query_equip_add("base_attack_main");
		broken_weapon_attack = broken->query_equip_add("base_attack_main");
		normal->skills["yueji"] = ({1,0});
		broken->skills["yueji"] = ({1,0});
		normal->_fight(normal_target);
		broken->_fight(broken_target);
		for(int attempt=0;attempt<10 && normal_damage==0;attempt++){
			normal->timeCold = 0;
			normal->f_skills["yueji"] = 0;
			normal->set_mofa(normal->query_mofa_max());
			int life_before = normal_target->get_cur_life();
			normal->perform("yueji",1);
			normal_damage = life_before-normal_target->get_cur_life();
		}
		for(int attempt=0;attempt<10 && broken_damage==0;attempt++){
			broken->timeCold = 0;
			broken->f_skills["yueji"] = 0;
			broken->set_mofa(broken->query_mofa_max());
			int life_before = broken_target->get_cur_life();
			broken->perform("yueji",1);
			broken_damage = life_before-broken_target->get_cur_life();
		}
	};
	if(err)
		error_desc = describe_error(err)+" "+describe_backtrace(err);
	if(!err && normal->query_base_damage()==broken->query_base_damage() &&
	   normal_weapon_attack==300000 && broken_weapon_attack==0 &&
	   normal_damage>200000 && broken_damage>0 && broken_damage<50000 &&
	   normal_damage>broken_damage*10)
		test_pass();
	else
		test_fail(sprintf("base=%d/%d equip=%d/%d damage=%d/%d %s",
			normal ? normal->query_base_damage() : -1,
			broken ? broken->query_base_damage() : -1,
			normal_weapon_attack,broken_weapon_attack,
			normal_damage,broken_damage,error_desc));
	if(normal && normal->query_in_combat())
		normal->_clean_fight();
	if(broken && broken->query_in_combat())
		broken->_clean_fight();
	if(normal_target && normal_target->query_in_combat())
		normal_target->_clean_fight();
	if(broken_target && broken_target->query_in_combat())
		broken_target->_clean_fight();
	destroy_player(normal);
	destroy_player(broken);
	destroy_player(normal_target);
	destroy_player(broken_target);
}

int main(int argc,array(string) argv)
{
	werror("\n╔════════════════════════════════════════════════╗\n");
	werror("║             镇越职业全链路测试                ║\n");
	werror("╚════════════════════════════════════════════════╝\n");
	test_creation_and_growth();
	test_passive_book_lazy_learning();
	test_skill_catalog_and_real_learning();
	test_all_skill_stages_and_passive_growth();
	test_team_guard_edges();
	test_team_guard_recast_and_team_change();
	test_threat_and_balance_contract();
	test_hidden_equipment_tasks_and_teacher();
	test_original_assets_and_avatar_choices();
	test_profession_quest_chain_and_reward();
	test_skill_ui_and_perform_authorization();
	test_all_active_skill_runtime_contracts();
	test_aoe_target_cleanup();
	test_neutral_social_and_faction_boundaries();
	test_purchase_boundary_and_identity_surfaces();
	test_physical_damage_and_broken_weapon_boundary();
	werror("\n镇越测试：%d通过，%d失败\n",test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
