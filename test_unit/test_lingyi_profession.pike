#!/usr/bin/env pike
/** 灵医从建角、治疗、净化、药契到共享系统的运行时全链路测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[灵医全链路 %d] %s\n",test_results["total"],name);
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
	player->name_cn = "灵医测试人物";
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

void reset_cast(object player,string skill_name)
{
	player->timeCold = 0;
	player->f_skills[skill_name] = 0;
	player->set_mofa(player->query_mofa_max());
}

void test_creation_growth_and_identity()
{
	test_start("中立建角、初始技能、身份与1/30/80/120级成长");
	object one = create_player("__testunit_lingyi_one__","lingyi",1);
	object thirty = create_player("__testunit_lingyi_thirty__","lingyi",30);
	object eighty = create_player("__testunit_lingyi_eighty__","lingyi",80);
	object one_twenty = create_player("__testunit_lingyi_120__","lingyi",120);
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string top_source = Stdio.read_file(ROOT+"/gamelib/cmds/look_top.pike");
	string base_source = Stdio.read_file(ROOT+"/lowlib/system/inherit/base.pike");
	int valid = one && thirty && eighty && one_twenty && init_source &&
		user_source && top_source && base_source &&
		search(init_source,"[灵医:choice_profe third/lingyi]")!=-1 &&
		search(init_source,"me->skills[\"lingzhen\"]=({1,0});")!=-1 &&
		one->query_raceId()=="third" && one->query_profeId()=="lingyi" &&
		one->query_profe_cn("lingyi")=="灵医" &&
		one->query_str()==6 && one->query_dex()==6 && one->query_think()==14 &&
		thirty->query_str()==6+(int)(29*0.7) &&
		thirty->query_dex()==6+(int)(29*0.7) &&
		thirty->query_think()==14+(int)(29*2.5) &&
		eighty->query_think()==14+(int)(79*2.5) &&
		one_twenty->query_think()==14+(int)(119*2.5) &&
		search(user_source,"【医】")!=-1 &&
		search(top_source,"【医】")!=-1 &&
		search(base_source,"无名灵医")!=-1;
	if(valid)
		test_pass();
	else
		test_fail("建角接线、职业身份或等级成长不正确");
	destroy_player(one); destroy_player(thirty);
	destroy_player(eighty); destroy_player(one_twenty);
}

void test_catalog_skills_and_real_learning()
{
	test_start("十六本可购成长书、十七项技能与真实读书限制");
	array(string) skills = ({"lingzhen","yaoli","huichun","muxi",
		"qingxin","huxin","lingyu","huayu","yaowutianluo","yulu",
		"baicaojue","ganlin","xuming","cixinpudu","huimingtianlu",
		"wanmuxinchun","liuhehuichun"});
	object healer = create_player("__testunit_lingyi_books__","lingyi",100);
	object outsider = create_player("__testunit_lingyi_book_wrong__","fangshi",100);
	object low = create_player("__testunit_lingyi_book_low__","lingyi",4);
	object|zero original_player = this_player();
	string csv = Stdio.read_file(ROOT+"/gamelib/data/can_buy_book_list.csv");
	int catalog = 0;
	int failed = 0;
	string error_desc = "";
	foreach(csv/"\n",string line){
		array(string) parts = line/",";
		if(sizeof(parts)<4 || parts[3]!="lingyi")
			continue;
		object|zero book = 0;
		mixed book_err = catch {
			book = clone(ROOT+"/gamelib/clone/item/"+parts[1]);
		};
		catalog++;
		if(book_err || !book || book->profe_read_limit!="灵医")
			failed++;
		if(book)
			destruct(book);
	}
	foreach(skills,string skill_name){
		object|zero skill = 0;
		mixed skill_err = catch {
			skill = (object)(ROOT+"/gamelib/single/skills/"+skill_name);
		};
		if(skill_err || !skill || search(skill->skill_type,"lingyi")==-1 ||
		   skill->query_skill_level_max()!=5)
			failed++;
	}
	mixed read_err = catch {
		object passive = clone(ROOT+"/gamelib/clone/item/book/yaoli1");
		set_this_player(healer);
		if(passive->read()!=1 || !healer->skills["yaoli"] ||
		   healer->query_base_think()!=8)
			failed++;
		object active = clone(ROOT+"/gamelib/clone/item/book/huichun");
		if(active->read()!=1 || !healer->skills["huichun"])
			failed++;
		object wrong = clone(ROOT+"/gamelib/clone/item/book/qingxin");
		set_this_player(outsider);
		if(wrong->read()!=3)
			failed++;
		object too_low = clone(ROOT+"/gamelib/clone/item/book/huichun");
		set_this_player(low);
		if(too_low->read()!=4)
			failed++;
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(read_err){
		failed++;
		error_desc = describe_error(read_err);
	}
	if(catalog==16 && failed==0)
		test_pass();
	else
		test_fail(sprintf("目录=%d/16 失败=%d: %s",catalog,failed,error_desc));
	destroy_player(healer); destroy_player(outsider); destroy_player(low);
}

void test_solo_support_and_resource_boundaries()
{
	test_start("未组队自疗、有效收益才扣仙力冷却与等级授权");
	object healer = create_player("__testunit_lingyi_solo__","lingyi",80);
	object low = create_player("__testunit_lingyi_solo_low__","lingyi",4);
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		healer->skills["huichun"] = ({1,0});
		healer->set_life(healer->query_life_max()/2);
		int before_life = healer->get_cur_life();
		int before_mofa = healer->get_cur_mofa();
		if(healer->perform_support("huichun")!=1 ||
		   healer->get_cur_life()<=before_life ||
		   healer->get_cur_mofa()>=before_mofa || healer->timeCold!=2 ||
		   healer->query_lingyi_medicine_pacts()!=1)
			failed++;
		reset_cast(healer,"huichun");
		healer->set_life(healer->query_life_max());
		before_mofa = healer->get_cur_mofa();
		if(healer->perform_support("huichun")!=0 ||
		   healer->get_cur_mofa()!=before_mofa || healer->timeCold!=0)
			failed++;
		healer->skills["huichun"] = ({});
		healer->set_life(healer->query_life_max()/2);
		before_mofa = healer->get_cur_mofa();
		if(healer->perform_support("huichun")!=0 ||
		   healer->get_cur_mofa()!=before_mofa || healer->timeCold!=0)
			failed++;
		healer->skills["huichun"] = ({1,0});
		healer->set_life(0);
		before_mofa = healer->get_cur_mofa();
		if(healer->perform_support("huichun")!=0 ||
		   healer->get_cur_mofa()!=before_mofa || healer->timeCold!=0)
			failed++;
		low->skills["huichun"] = ({1,0});
		low->set_life(low->query_life_max()/2);
		before_mofa = low->get_cur_mofa();
		if(low->perform_support("huichun")!=0 ||
		   low->get_cur_mofa()!=before_mofa)
			failed++;
	};
	if(err){
		failed++;
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	}
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("自疗或资源边界失败=%d: %s",failed,error_desc));
	destroy_player(healer); destroy_player(low);
}

void test_smart_team_targeting_and_isolation()
{
	test_start("单体优先最低生命比例且隔离外人、异房与死亡队友");
	object healer = create_player("__testunit_lingyi_team__","lingyi",80);
	object member = create_player("__testunit_lingyi_member__","fangshi",80);
	object other_room_member = create_player("__testunit_lingyi_other_room__","zhenyue",80);
	object dead_member = create_player("__testunit_lingyi_dead__","tianxiang",80);
	object outsider = create_player("__testunit_lingyi_outsider__","fangshi",80);
	object room = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object other_room = clone(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		healer->set_term("__testunit_lingyi_team_id__");
		member->set_term("__testunit_lingyi_team_id__");
		other_room_member->set_term("__testunit_lingyi_team_id__");
		dead_member->set_term("__testunit_lingyi_team_id__");
		outsider->set_term("__testunit_lingyi_other_team__");
		healer->move(room); member->move(room); dead_member->move(room);
		outsider->move(room); other_room_member->move(other_room);
		healer->skills["huichun"] = ({1,0});
		healer->set_life(healer->query_life_max()*60/100);
		member->set_life(member->query_life_max()*30/100);
		other_room_member->set_life(other_room_member->query_life_max()/10);
		dead_member->set_life(0);
		outsider->set_life(outsider->query_life_max()/10);
		int healer_before = healer->get_cur_life();
		int member_before = member->get_cur_life();
		int other_before = other_room_member->get_cur_life();
		int outsider_before = outsider->get_cur_life();
		if(healer->perform_support("huichun")!=1 ||
		   member->get_cur_life()<=member_before ||
		   healer->get_cur_life()!=healer_before ||
		   other_room_member->get_cur_life()!=other_before ||
		   outsider->get_cur_life()!=outsider_before ||
		   dead_member->get_cur_life()!=0)
			failed++;
	};
	if(err){ failed++; error_desc = describe_error(err); }
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("智能目标或隔离失败=%d: %s",failed,error_desc));
	destroy_player(healer); destroy_player(member);
	destroy_player(other_room_member); destroy_player(dead_member);
	destroy_player(outsider);
	if(room) destruct(room);
	if(other_room) destruct(other_room);
}

void test_group_heal_cleanse_priority()
{
	test_start("群疗仅覆盖同队存活目标且按DOT到诅咒顺序逐项净化");
	object healer = create_player("__testunit_lingyi_group__","lingyi",100);
	object member = create_player("__testunit_lingyi_group_member__","fangshi",100);
	object outsider = create_player("__testunit_lingyi_group_outsider__","fangshi",100);
	object room = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		healer->set_term("__testunit_lingyi_group_id__");
		member->set_term("__testunit_lingyi_group_id__");
		outsider->set_term("__testunit_lingyi_group_other__");
		healer->move(room); member->move(room); outsider->move(room);
		healer->skills["ganlin"] = ({1,0});
		healer->set_life(healer->query_life_max()/2);
		member->set_life(member->query_life_max()/2);
		outsider->set_life(outsider->query_life_max()/2);
		member->set_debuff("dot",0,"test_dot");
		member->set_debuff("dot",1,10);
		member->set_debuff("dot",2,10);
		member->set_debuff("curse",0,"attack");
		member->set_debuff("curse",1,10);
		member->set_debuff("curse",2,10);
		int healer_before = healer->get_cur_life();
		int member_before = member->get_cur_life();
		int outsider_before = outsider->get_cur_life();
		if(healer->perform_support("ganlin")!=1 ||
		   healer->get_cur_life()<=healer_before ||
		   member->get_cur_life()<=member_before ||
		   outsider->get_cur_life()!=outsider_before ||
		   member->query_debuff("dot",0)!="none" ||
		   member->query_debuff("curse",0)!="attack")
			failed++;
		reset_cast(healer,"ganlin");
		if(healer->perform_support("ganlin")!=1 ||
		   member->query_debuff("curse",0)!="none")
			failed++;
	};
	if(err){ failed++; error_desc = describe_error(err); }
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("群疗净化失败=%d: %s",failed,error_desc));
	destroy_player(healer); destroy_player(member); destroy_player(outsider);
	if(room) destruct(room);
}

void test_caps_antiheal_and_pact_boost()
{
	test_start("治疗上限、90%抗疗封顶与三层药契增幅/消费均由服务端结算");
	object healer = create_player("__testunit_lingyi_caps__","lingyi",100);
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		healer->skills["huichun"] = ({1,0});
		healer->skills["xuming"] = ({1,0});
		healer->set_base_think(1000000);
		healer->set_life(1);
		healer->set_debuff("curse",0,"life");
		healer->set_debuff("curse",1,1000);
		healer->set_debuff("curse",2,10);
		int before = healer->get_cur_life();
		if(healer->perform_support("huichun")!=1)
			failed++;
		int healed = healer->get_cur_life()-before;
		if(healed<=0 || healed>healer->query_life_max()*25/1000)
			failed++;
		healer->clean_debuff("curse");
		healer->set_base_think(0);
		reset_cast(healer,"xuming");
		healer->clean_lingyi_medicine_pacts();
		if(healer->add_lingyi_medicine_pacts(99)!=3)
			failed++;
		int expected = (520+healer->query_think()*4)*145/100;
		healer->set_life(1);
		before = healer->get_cur_life();
		if(healer->perform_support("xuming")!=1 ||
		   healer->get_cur_life()-before!=expected ||
		   healer->query_lingyi_medicine_pacts()!=0)
			failed++;
	};
	if(err){ failed++; error_desc = describe_error(err); }
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("治疗上限或药契结算失败=%d: %s",failed,error_desc));
	destroy_player(healer);
}

void test_pact_lifecycle_cleanup()
{
	test_start("药契封顶、过期、换房、换队、脱战与非灵医隔离");
	object healer = create_player("__testunit_lingyi_pacts__","lingyi",80);
	object outsider = create_player("__testunit_lingyi_pacts_wrong__","fangshi",80);
	object room_one = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object room_two = clone(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	int failed = 0;
	if(outsider->add_lingyi_medicine_pacts(3)!=0)
		failed++;
	if(healer->add_lingyi_medicine_pacts(2)!=2 ||
	   healer->add_lingyi_medicine_pacts(9)!=3 ||
	   healer->consume_lingyi_medicine_pacts()!=3 ||
	   healer->query_lingyi_medicine_pacts()!=0)
		failed++;
	healer->add_lingyi_medicine_pacts(2);
	healer["/tmp/lingyi_medicine_pact_expire"] = time()-1;
	if(healer->query_lingyi_medicine_pacts()!=0)
		failed++;
	healer->move(room_one);
	healer->add_lingyi_medicine_pacts(2);
	healer->move(room_two);
	if(healer->query_lingyi_medicine_pacts()!=0)
		failed++;
	healer->add_lingyi_medicine_pacts(2);
	healer->set_term("__testunit_lingyi_new_team__");
	if(healer->query_lingyi_medicine_pacts()!=0)
		failed++;
	healer->add_lingyi_medicine_pacts(2);
	healer->_clean_fight();
	if(healer->query_lingyi_medicine_pacts()!=0)
		failed++;
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("药契生命周期失败=%d",failed));
	destroy_player(healer); destroy_player(outsider);
	if(room_one) destruct(room_one);
	if(room_two) destruct(room_two);
}

void test_hidden_tasks_teacher_equipment_and_medicine()
{
	test_start("四本隐藏治疗、任务链、导师、专属装备与恢复品完整");
	array(string) hidden = ({"cixinpudu","huimingtianlu","wanmuxinchun",
		"liuhehuichun"});
	string pool = Stdio.read_file(ROOT+"/gamelib/single/daemons/itemsd.pike");
	string tasks = Stdio.read_file(ROOT+"/gamelib/data/task/task_list.csv");
	object teacher = clone(ROOT+"/gamelib/clone/npc/lingyi_teacher.pike");
	object reward = clone(ROOT+"/gamelib/clone/item/taskaward/lingyiyaonang");
	object medicine = clone(ROOT+"/gamelib/clone/item/food/xiaohuandan");
	int failed = 0;
	string error_desc = "";
	foreach(hidden,string name){
		object|zero book = 0;
		object|zero skill = 0;
		mixed err = catch {
			book = clone(ROOT+"/gamelib/clone/item/book/"+name);
			skill = (object)(ROOT+"/gamelib/single/skills/"+name);
		};
		if(err || !book || !skill || book->profe_read_limit!="灵医" ||
		   book->level_limit!=80 || skill->skill_rare!="mythic" ||
		   skill->query_lingyi_life_cap_percent()>40 ||
		   !pool || search(pool,"\"book/"+name+"\"")==-1)
			failed++;
		if(book) destruct(book);
	}
	if(!pool || search(pool,"hidden_skill_drop_rate = 31") == -1 ||
	   !tasks || search(tasks,"379,n,【特殊】初辨药息") == -1 ||
	   search(tasks,"383,n,【医】万木回春") == -1 ||
	   search(tasks,"book/baicaojue:1") == -1 ||
	   !teacher || teacher->query_profeId()!="lingyi" ||
	   teacher->picture!="lingyi_female" ||
	   !reward || search(reward->query_item_profeLimit(),"lingyi")==-1 ||
	   !medicine || !medicine->profe_limit ||
	   medicine->profe_limit["lingyi"]!="灵医")
		failed++;
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("隐藏/共享系统失败=%d: %s",failed,error_desc));
	if(teacher) destruct(teacher);
	if(reward) destruct(reward);
	if(medicine) destruct(medicine);
}

void test_combat_and_mythic_healing_runtime()
{
	test_start("战斗内治疗与四本隐藏神技真实结算且隔离外人");
	object healer = create_player("__testunit_lingyi_mythic__","lingyi",100);
	object member = create_player("__testunit_lingyi_mythic_member__","fangshi",100);
	object outsider = create_player("__testunit_lingyi_mythic_outsider__","fangshi",100);
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		healer->set_term("__testunit_lingyi_mythic_team__");
		member->set_term("__testunit_lingyi_mythic_team__");
		outsider->set_term("__testunit_lingyi_mythic_other__");
		healer->move(room); member->move(room); outsider->move(room); npc->move(room);
		healer->skills["huichun"] = ({1,0});
		healer->skills["cixinpudu"] = ({1,0});
		healer->skills["huimingtianlu"] = ({1,0});
		healer->skills["wanmuxinchun"] = ({1,0});
		healer->skills["liuhehuichun"] = ({1,0});
		healer->_fight(npc);

		healer->set_life(healer->query_life_max()*60/100);
		member->set_life(member->query_life_max()*30/100);
		int member_before = member->get_cur_life();
		healer->perform("huichun",1);
		if(member->get_cur_life()<=member_before ||
		   healer->f_skills["huichun"]!=7)
			failed++;

		reset_cast(healer,"cixinpudu");
		healer->set_life(1); member->set_life(1); outsider->set_life(1);
		int outsider_before = outsider->get_cur_life();
		healer->perform("cixinpudu",1);
		if(healer->get_cur_life()<=1 || member->get_cur_life()<=1 ||
		   outsider->get_cur_life()!=outsider_before ||
		   healer->f_skills["cixinpudu"]!=91)
			failed++;

		reset_cast(healer,"wanmuxinchun");
		healer->set_life(1); member->set_life(1);
		member->set_debuff("dot",0,"test_dot");
		member->set_debuff("dot",1,10);
		member->set_debuff("dot",2,10);
		healer->perform("wanmuxinchun",1);
		if(member->get_cur_life()<=1 ||
		   member->query_debuff("dot",0)!="none" ||
		   healer->f_skills["wanmuxinchun"]!=121)
			failed++;

		reset_cast(healer,"huimingtianlu");
		healer->set_life(1); member->set_life(member->query_life_max());
		healer->clean_lingyi_medicine_pacts();
		healer->add_lingyi_medicine_pacts(3);
		healer->perform("huimingtianlu",1);
		if(healer->get_cur_life()<=1 ||
		   healer->query_lingyi_medicine_pacts()!=0 ||
		   healer->f_skills["huimingtianlu"]!=61)
			failed++;

		reset_cast(healer,"liuhehuichun");
		healer->set_life(1); member->set_life(1); outsider->set_life(1);
		member->set_debuff("curse",0,"life");
		member->set_debuff("curse",1,20);
		member->set_debuff("curse",2,10);
		healer->add_lingyi_medicine_pacts(3);
		outsider_before = outsider->get_cur_life();
		healer->perform("liuhehuichun",1);
		if(healer->get_cur_life()<=1 || member->get_cur_life()<=1 ||
		   outsider->get_cur_life()!=outsider_before ||
		   member->query_debuff("curse",0)!="none" ||
		   healer->query_lingyi_medicine_pacts()!=0 ||
		   healer->f_skills["liuhehuichun"]!=151)
			failed++;
	};
	if(err){ failed++; error_desc = describe_error(err); }
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("战斗治疗或隐藏治疗失败=%d: %s",failed,error_desc));
	destroy_player(healer); destroy_player(member); destroy_player(outsider);
	if(npc) destruct(npc);
	if(room) destruct(room);
}

void test_autofight_vip_and_pvp_fairness()
{
	test_start("助手仅自动化已学技能、仅PVE生效且不改变治疗数值");
	object healer = create_player("__testunit_lingyi_auto__","lingyi",100);
	object pvp = create_player("__testunit_lingyi_auto_pvp__","fangshi",100);
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object daemon = (object)(ROOT+"/gamelib/single/daemons/autofightd.pike");
	int failed = 0;
	string free_context = "";
	string ready_context = "";
	string ready_skill = "";
	string pvp_context = "";
	string error_desc = "";
	mixed err = catch {
		healer->skills["huichun"] = ({1,0});
		healer->set_life(healer->query_life_max()/2);
		int think_before = healer->query_think();
		int life_max_before = healer->query_life_max();
		healer->move(room); pvp->move(room); npc->move(room);
		healer->_fight(npc);
		free_context = daemon->query_ready_lingyi_context_skill(healer);
		if(sizeof(PROFESSIONVIPD->query_lingyi_context_candidates(healer))!=0 ||
		   free_context!="")
			failed++;
		set_active_vip(healer,3);
		PROFESSIONVIPD->initialize_player(healer);
		PROFESSIONVIPD->set_auto_enabled(healer,1);
		ready_context = daemon->query_ready_lingyi_context_skill(healer);
		ready_skill = daemon->query_ready_auto_skill(healer);
		if(search(PROFESSIONVIPD->query_lingyi_context_candidates(healer),
		   "huichun")==-1 || ready_context!="huichun" ||
		   ready_skill!="huichun" || healer->query_think()!=think_before ||
		   healer->query_life_max()!=life_max_before)
			failed++;
		healer->_clean_fight();
		healer->_fight(pvp);
		pvp_context = daemon->query_ready_lingyi_context_skill(healer);
		if(sizeof(PROFESSIONVIPD->query_lingyi_context_candidates(healer))!=0 ||
		   pvp_context!="")
			failed++;
	};
	if(err){ failed++; error_desc = describe_error(err); }
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("助手PVE/PVP公平性失败=%d free=%s ready=%s/%s "
			"pvp=%s: %s",failed,free_context,ready_context,ready_skill,
			pvp_context,error_desc));
	destroy_player(healer); destroy_player(pvp);
	if(npc) destruct(npc);
	if(room) destruct(room);
}

void test_room_aoe_and_battle_report()
{
	test_start("药雾天罗可定制玩家阵营且永久保护队友好友与路人");
	object healer = create_player("__testunit_lingyi_aoe__","lingyi",100);
	object member = create_player("__testunit_lingyi_aoe_member__","fangshi",100);
	object engaged = create_player("__testunit_lingyi_aoe_enemy__","fangshi",100);
	object same_faction = create_player(
		"__testunit_lingyi_aoe_same__","fangshi",100);
	object friend_player = create_player(
		"__testunit_lingyi_aoe_friend__","fangshi",100);
	object bystander = create_player("__testunit_lingyi_aoe_bystander__","fangshi",100);
	object npc_one = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object npc_two = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object task_npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(WAP_ROOM);
	object other_room = clone(WAP_ROOM);
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		engaged->set_raceId("human");
		friend_player->set_raceId("human");
		healer->qqlist_insert(friend_player->query_name(),"");
		healer->set_term("__testunit_lingyi_aoe_team__");
		member->set_term("__testunit_lingyi_aoe_team__");
		engaged->set_term("__testunit_lingyi_aoe_enemy_team__");
		same_faction->set_term("__testunit_lingyi_aoe_same_team__");
		friend_player->set_term("__testunit_lingyi_aoe_friend_team__");
		bystander->set_term("__testunit_lingyi_aoe_bystander_team__");
		healer->move(room); member->move(room); engaged->move(room);
		same_faction->move(room); friend_player->move(room);
		bystander->move(room); npc_one->move(room); npc_two->move(room);
		task_npc->move(room); task_npc->_tasknpc = 1;
		healer->skills["yaowutianluo"] = ({1,0});
		healer->set_base_hitte(100000);
		npc_one->set_life(1);
		// 第二只怪只验证群攻覆盖，避免普通低级怪被高等级测试人物秒杀后
		// 测试代码自身读取已析构对象。
		npc_two->set_base_life(10000000);
		npc_two->flush_life();
		npc_two->set_life(npc_two->query_life_max());
		int member_before = member->get_cur_life();
		int bystander_before = bystander->get_cur_life();
		int engaged_before = engaged->get_cur_life();
		int same_faction_before = same_faction->get_cur_life();
		int friend_before = friend_player->get_cur_life();
		int npc_two_before = npc_two->get_cur_life();
		int task_npc_before = task_npc->get_cur_life();
		int mofa_before = healer->get_cur_mofa();
		healer->_fight(npc_one);
		engaged->_fight(healer);
		healer->_fight(engaged);
		same_faction->_fight(healer);
		healer->_fight(same_faction);
		friend_player->_fight(healer);
		healer->_fight(friend_player);
		healer->perform("yaowutianluo",1);
		mapping(string:mixed) report =
			healer->query_recent_aoe_battle_report();
		int defeated = 0;
		int saw_engaged = 0;
		int saw_same_faction = 0;
		int saw_friend = 0;
		foreach((array(mapping))report["targets"],mapping target){
			if(target["defeated"])
				defeated++;
			if(target["name"]==engaged->query_name())
				saw_engaged = 1;
			if(target["name"]==same_faction->query_name())
				saw_same_faction = 1;
			if(target["name"]==friend_player->query_name())
				saw_friend = 1;
		}
		int engaged_damage = engaged_before-engaged->get_cur_life();
		if(member->get_cur_life()!=member_before ||
		   bystander->get_cur_life()!=bystander_before ||
		   same_faction->get_cur_life()!=same_faction_before ||
		   friend_player->get_cur_life()!=friend_before ||
		   engaged_damage<=0 ||
		   engaged_damage>engaged->query_life_max()*8/100 ||
		   npc_two->get_cur_life()>=npc_two_before ||
		   task_npc->get_cur_life()!=task_npc_before ||
		   !report || report["skill"]!="yaowutianluo" ||
		   sizeof((array)report["targets"])<3 || defeated<1 ||
		   !saw_engaged || saw_same_faction || saw_friend ||
		   healer->get_cur_mofa()>=mofa_before ||
		   healer->f_skills["yaowutianluo"]!=15)
			failed++;

		// 切换为允许中立、禁止仙阵营后，下一次施放应立即
		// 改变玩家目标；好友和队友仍不可被配置绕过。
		PROFESSIONVIPD->set_lingyi_aoe_target_enabled(healer,"human",0);
		PROFESSIONVIPD->set_lingyi_aoe_target_enabled(healer,"third",1);
		int engaged_after_first = engaged->get_cur_life();
		int same_after_first = same_faction->get_cur_life();
		int friend_after_first = friend_player->get_cur_life();
		int member_after_first = member->get_cur_life();
		int npc_two_after_first = npc_two->get_cur_life();
		healer->timeCold = 0;
		healer->f_skills["yaowutianluo"] = 0;
		healer->set_mofa(healer->query_mofa_max());
		healer->perform("yaowutianluo",1);
		mapping(string:mixed) custom_report =
			healer->query_recent_aoe_battle_report();
		int custom_saw_human = 0;
		int custom_saw_third = 0;
		foreach((array(mapping))custom_report["targets"],mapping target){
			if(target["name"]==engaged->query_name())
				custom_saw_human = 1;
			if(target["name"]==same_faction->query_name())
				custom_saw_third = 1;
		}
		if(engaged->get_cur_life()!=engaged_after_first ||
		   same_faction->get_cur_life()>=same_after_first ||
		   friend_player->get_cur_life()!=friend_after_first ||
		   member->get_cur_life()!=member_after_first ||
		   npc_two->get_cur_life()>=npc_two_after_first ||
		   custom_saw_human || !custom_saw_third)
			failed++;
		healer->move(other_room);
		if(sizeof(healer->query_recent_aoe_battle_report())!=0)
			failed++;
	};
	if(err){
		failed++;
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	}
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("群攻或战果快照失败=%d: %s",failed,error_desc));
	destroy_player(healer); destroy_player(member); destroy_player(engaged);
	destroy_player(same_faction); destroy_player(friend_player);
	destroy_player(bystander);
	if(npc_one) destruct(npc_one);
	if(npc_two) destruct(npc_two);
	if(task_npc) destruct(task_npc);
	if(room) destruct(room);
	if(other_room) destruct(other_room);
}

void test_mastery_auto_revive_boundaries()
{
	test_start("五门满段解锁每日复苏且次数、重登日界、城战与职业边界安全");
	array(string) mastery = ({"lingzhen","huichun","muxi","qingxin",
		"huxin","lingyu","huayu","yaowutianluo","yulu","baicaojue",
		"ganlin","xuming"});
	object healer = create_player("__testunit_lingyi_revive__","lingyi",120);
	object outsider = create_player("__testunit_lingyi_revive_wrong__","fangshi",120);
	object killer = create_player("__testunit_lingyi_revive_killer__","fangshi",120);
	object monster = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(WAP_ROOM);
	object city = clone(WAP_ROOM);
	int failed = 0;
	string error_desc = "";
	mixed err = catch {
		city->set_room_type("city");
		healer->move(room); killer->move(room); outsider->move(room);
		monster->move(room);
		for(int i=0;i<4;i++)
			healer->skills[mastery[i]] = ({5,0});
		if(healer->query_lingyi_mastered_skill_count()!=4 ||
		   healer->query_lingyi_auto_revive_max()!=0)
			failed++;
		healer->skills[mastery[4]] = ({5,0});
		outsider->skills[mastery[0]] = ({5,0});
		if(healer->query_lingyi_mastered_skill_count()!=5 ||
		   healer->query_lingyi_auto_revive_max()!=1 ||
		   healer->query_lingyi_auto_revive_remaining()!=1 ||
		   outsider->query_lingyi_auto_revive_max()!=0)
			failed++;
		// _fight()只建立仇恨；真实杀戮命令会把双方标成1。显式设置后才是
		// 百炼复苏允许消耗次数的PVP死亡，而不是不耗次数的切磋。
		healer->kill_flag = 1;
		killer->kill_flag = 1;
		healer->_fight(killer);
		killer->_fight(healer);
		healer->set_life(0);
		object before_room = environment(healer);
		healer->fight_die();
		if(environment(healer)!=before_room || healer->get_cur_life()!=
		   healer->query_life_max()*25/100 || healer->get_cur_mofa()!=
		   healer->query_mofa_max()*20/100 ||
		   healer->query_lingyi_auto_revive_used()!=1 ||
		   healer->query_lingyi_auto_revive_remaining()!=0 ||
		   healer->query_in_combat() || killer->if_in_targets(healer))
			failed++;
		if(healer->try_lingyi_auto_revive(killer)!=0)
			failed++;
		// 模拟跨自然日：只读查询应把旧日已用次数视为0，且不需重登。
		healer["/plus/lingyi/revive_day_key"] = 0;
		healer["/plus/lingyi/revive_used"] = 99;
		if(healer->query_lingyi_auto_revive_used()!=0 ||
		   healer->query_lingyi_auto_revive_remaining()!=1)
			failed++;
		// 普通怪击杀同样属于真实死亡；异常的跨房击杀者不能消耗次数。
		healer->set_life(0);
		monster->move(city);
		if(healer->try_lingyi_auto_revive(monster)!=0 ||
		   healer->query_lingyi_auto_revive_used()!=0)
			failed++;
		monster->move(room);
		healer->set_life(healer->query_life_max());
		healer->_fight(monster);
		monster->_fight(healer);
		healer->set_life(0);
		healer->fight_die();
		if(healer->get_cur_life()!=healer->query_life_max()*25/100 ||
		   healer->query_lingyi_auto_revive_used()!=1)
			failed++;
		// 后续阈值和禁用场景使用一个新的自然日快照。
		healer["/plus/lingyi/revive_day_key"] = 0;
		healer["/plus/lingyi/revive_used"] = 99;
		for(int i=5;i<8;i++)
			healer->skills[mastery[i]] = ({5,0});
		if(healer->query_lingyi_auto_revive_max()!=2)
			failed++;
		for(int i=8;i<12;i++)
			healer->skills[mastery[i]] = ({5,0});
		if(healer->query_lingyi_auto_revive_max()!=3)
			failed++;
		// 城战和自杀均不能偷用复苏次数。
		healer->move(city); killer->move(city);
		healer->set_life(0);
		int used_before = healer->query_lingyi_auto_revive_used();
		if(healer->try_lingyi_auto_revive(killer)!=0 ||
		   healer->query_lingyi_auto_revive_used()!=used_before)
			failed++;
		healer->move(room); killer->move(room);
		healer->set_life(0);
		healer->kill_flag = 0; killer->kill_flag = 0;
		if(healer->try_lingyi_auto_revive(killer)!=0)
			failed++;
		healer->kill_flag = 1; killer->kill_flag = 1;
		healer->set_life(0);
		healer->sucide = 1;
		if(healer->try_lingyi_auto_revive(killer)!=0)
			failed++;
		healer->sucide = 0;
	};
	if(err){
		failed++;
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	}
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("自动复苏边界失败=%d: %s",failed,error_desc));
	destroy_player(healer); destroy_player(outsider); destroy_player(killer);
	if(monster) destruct(monster);
	if(room) destruct(room);
	if(city) destruct(city);
}

void test_assets_ui_and_deployment()
{
	test_start("原创图标、男女头像、双镜像、Vue状态与容器复制完整");
	array(string) names = ({"lingyi_logo.png","lingyi_male.png",
		"lingyi_female.png","lingyi_male.gif","lingyi_female.gif"});
	string male = Stdio.read_file(ROOT+"/images/lingyi_male.png");
	string female = Stdio.read_file(ROOT+"/images/lingyi_female.png");
	string logo = Stdio.read_file(ROOT+"/images/lingyi_logo.png");
	string vue = Stdio.read_file(ROOT+"/vue_source/index.html");
	string css = Stdio.read_file(ROOT+"/vue_source/css/app.css");
	string api = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	string deploy = Stdio.read_file(ROOT+"/restart-docker.sh");
	int failed = 0;
	foreach(names,string name){
		string image_one = Stdio.read_file(ROOT+"/images/"+name);
		string image_two = Stdio.read_file(ROOT+"/web/images/"+name);
		if(!image_one || !image_two || sizeof(image_one)<100 ||
		   image_one!=image_two || search(deploy,"\""+name+"\"")==-1)
			failed++;
	}
	if(!male || !female || !logo || male==female || male==logo || female==logo ||
	   !vue || search(vue,"medicine_pacts") == -1 ||
	   search(vue,"battleAoeReport.targets") == -1 ||
	   search(vue,"lingyi_revive") == -1 ||
	   !css || search(css,"profession-style-lingyi-3") == -1 ||
	   search(css,"battle-aoe-target") == -1 ||
	   !api || search(api,"result[\"medicine_pacts\"]") == -1 ||
	   search(api,"result[\"lingyi_revive\"]") == -1 ||
	   search(api,"result[\"recent_aoe_report\"]") == -1 ||
	   !deploy || search(deploy,"\"cixinpudu\"") == -1 ||
	   search(deploy,"\"huimingtianlu\"") == -1 ||
	   search(deploy,"\"wanmuxinchun\"") == -1 ||
	   search(deploy,"\"liuhehuichun\"") == -1)
		failed++;
	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("资产/UI/部署失败=%d",failed));
}

int main(int argc,array(string) argv)
{
	werror("\n╔════════════════════════════════════════════════╗\n");
	werror("║             灵医职业全链路测试                ║\n");
	werror("╚════════════════════════════════════════════════╝\n");
	test_creation_growth_and_identity();
	test_catalog_skills_and_real_learning();
	test_solo_support_and_resource_boundaries();
	test_smart_team_targeting_and_isolation();
	test_group_heal_cleanse_priority();
	test_caps_antiheal_and_pact_boost();
	test_pact_lifecycle_cleanup();
	test_hidden_tasks_teacher_equipment_and_medicine();
	test_combat_and_mythic_healing_runtime();
	test_autofight_vip_and_pvp_fairness();
	test_room_aoe_and_battle_report();
	test_mastery_auto_revive_boundaries();
	test_assets_ui_and_deployment();
	werror("\n灵医测试：%d通过，%d失败\n",
		test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
