#!/usr/bin/env pike
/** 2026-08-06/07 Claude 提交严格审计回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void generate_hidden_token_probe(object httpd,string user,int worker,
	int count,mapping generated,object result_lock)
{
	for(int i=0;i<count;i++){
		string cmd = sprintf("_explorer inventory %d",worker*1000+i);
		string token = httpd->hide_command(user,cmd);
		object key = result_lock->lock();
		generated[token] = cmd;
		destruct(key);
	}
}

string audit_player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_audit_player_files(string userid)
{
	string path = audit_player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

void check(string name,int valid,string detail)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("[Claude审计] ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("[Claude审计] ✗ %s: %s\n",name,detail);
	}
}

void test_changed_files_compile()
{
	array(string) files = ({
		"/gamelib/clone/npc/shilian_xianguan.pike",
		"/gamelib/clone/npc/taiji_teacher.pike",
		"/gamelib/cmds/shilian_duihuan.pike",
		"/gamelib/cmds/auto_learn_confirm.pike",
		"/gamelib/cmds/chatroom_chat.pike",
		"/gamelib/cmds/boss_enter.pike",
		"/gamelib/cmds/buy_items.pike",
		"/gamelib/cmds/set_relife.pike",
		"/gamelib/cmds/gift_take.pike",
		"/gamelib/cmds/look.pike",
		"/gamelib/cmds/look_top.pike",
		"/gamelib/cmds/my_games.pike",
		"/gamelib/cmds/myskills.pike",
		"/gamelib/cmds/newbie_guide.pike",
		"/gamelib/cmds/profession_assistant.pike",
		"/gamelib/cmds/convert_equip_detail.pike",
		"/gamelib/cmds/taiji_fuyin.pike",
		"/gamelib/cmds/trial_center.pike",
		"/gamelib/inherit/npc.pike",
		"/gamelib/single/create_skill.pike",
		"/gamelib/clone/item/weapon/taijijian/taijijian",
		"/gamelib/clone/item/weapon/wuxiangjian/wuxiangjian",
		"/gamelib/single/daemons/account_characterd.pike",
		"/gamelib/single/daemons/autofightd.pike",
		"/gamelib/single/daemons/autolearnd.pike",
		"/gamelib/single/daemons/buyd.pike",
		"/gamelib/single/daemons/http_api_daemon.pike",
		"/gamelib/single/daemons/giftd.pike",
		"/gamelib/single/daemons/itemsd.pike",
		"/gamelib/single/daemons/newbied.pike",
		"/gamelib/single/daemons/taskd.pike",
		"/gamelib/single/daemons/timed_eventd.pike",
		"/gamelib/single/daemons/professionvipd.pike",
		"/gamelib/single/daemons/racechatd.pike",
		"/gamelib/single/daemons/summond.pike",
		"/gamelib/clone/user.pike",
		"/lowlib/mudlib/inherit/feature/attack.pike",
		"/lowlib/mudlib/inherit/feature/char.pike",
		"/lowlib/mudlib/inherit/feature/ghost.pike",
		"/lowlib/mudlib/inherit/feature/level.pike",
		"/lowlib/mudlib/inherit/npc.pike",
		"/lowlib/mudlib/inherit/user.pike",
		"/lowlib/system/cmds/set_filter.pike",
		"/lowlib/system/inherit/base.pike",
		"/lowlib/system/inherit/feature/cmds.pike",
		"/lowlib/wapmud2/cmds/_explorer.pike",
		"/lowlib/wapmud2/cmds/flushview.pike",
		"/lowlib/wapmud2/inherit/feature/fight.pike",
		"/lowlib/wapmud2/inherit/skill.pike",
		"/lowlib/wapmud2/cmds/leave.pike",
	});
	array(string) failures = ({});
	foreach(files,string file){
		mixed err = catch { compile_file(ROOT+file); };
		if(err)
			failures += ({file+": "+describe_error(err)});
	}
	foreach(({"wuxiang","taiji"}),string prefix){
		foreach(({"quan","jue","yi","dun","hou","jian","yan",
		   "jing","bi","huan","yu","ji","mie","guixu",
		   "hunyuan","wuji"}),string suffix){
			string file = "/gamelib/single/skills/"+prefix+suffix;
			mixed err = catch { compile_file(ROOT+file); };
			if(err)
				failures += ({file+": "+describe_error(err)});
		}
	}
	foreach(({"/gamelib/single/skills/wanxiangguiyi",
	   "/gamelib/single/skills/taijiguizhen"}),string file){
		mixed err = catch { compile_file(ROOT+file); };
		if(err)
			failures += ({file+": "+describe_error(err)});
	}
	check("审计修改的 Pike 入口均可由真实运行时编译",
		!sizeof(failures),failures*" | ");
}

void test_hidden_skill_contract_runtime()
{
	mapping(string:string) expected = ([
		"quan":"phy","yi":"balanced_self_heal",
		"dun":"balanced_shield","hou":"balanced_attr",
		"jian":"phy","yan":"balanced_aoe",
		"jing":"balanced_cleanse","bi":"balanced_team_guard",
		"huan":"balanced_summon","yu":"balanced_team_heal",
		"ji":"phy","guixu":"balanced_heart",
		"hunyuan":"balanced_combo","wuji":"balanced_wuji",
	]);
	array(string) routing_failures = ({});
	foreach(({"wuxiang","taiji"}),string prefix){
		foreach(sort(indices(expected)),string suffix){
			object skill = (object)(ROOT+"/gamelib/single/skills/"+
				prefix+suffix);
			if(!skill || skill->s_skill_type!=expected[suffix])
				routing_failures += ({prefix+suffix+"="+
					(skill ? skill->s_skill_type : "NULL")});
		}
	}
	check("无相/太极物理、回血、护盾、净化、群攻、召唤和神技均有真实路由",
		!sizeof(routing_failures),routing_failures*", ");

	object taiji = create_hidden_profession_player(
		"xd01testunittaijieffects","taiji");
	int attr_before = taiji->query_str();
	int attr_applied = taiji->apply_balanced_attr_percent(20,30);
	int attr_after = taiji->query_str();
	taiji["/tmp/balanced/attr_expires"] = time()-1;
	int attr_expired = taiji->query_str();
	int heart_before = taiji->query_taiji_heart_bonus("str");
	int heart_applied = taiji->apply_balanced_heart_boost(10,30);
	int heart_after = taiji->query_taiji_heart_bonus("str");
	check("全属性百分比和归墟心法强化均按秒级期限真实生效",
		attr_applied==1 && attr_after==attr_before*120/100 &&
		attr_expired==attr_before && heart_applied==1 &&
		heart_after>heart_before,
		sprintf("attr=%d/%d/%d heart=%d/%d",
			attr_before,attr_after,attr_expired,heart_before,heart_after));

	taiji->set_debuff("dot",0,"audit_dot");
	taiji->set_debuff("dot",1,10);
	taiji->set_debuff("dot",2,10);
	taiji->set_debuff("curse",0,"life");
	taiji->set_debuff("curse",1,50);
	taiji->set_debuff("curse",2,10);
	string first_clean = taiji->clean_one_balanced_debuff(taiji);
	string second_clean = taiji->clean_one_balanced_debuff(taiji);
	check("太极净严格先清持续伤害、再清治疗压制且每次仅一项",
		first_clean=="dot" && second_clean=="heal_suppression" &&
		taiji->query_debuff("dot",0)=="none" &&
		taiji->query_debuff("curse",0)=="none",
		"净化顺序或单次边界错误");
	destroy_player_with_inventory(taiji);
}

void test_hidden_support_perform_runtime()
{
	object caster = create_hidden_profession_player(
		"xd01testunittaijisupport","taiji");
	object member = create_hidden_profession_player(
		"xd01testunittaijimember","wuxiang");
	object outsider = create_hidden_profession_player(
		"xd01testunittaijioutsider","wuxiang");
	object enemy = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object enemy_two = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/taijijian/taijijian");
	object room = clone(WAP_ROOM);
	int failed = 0;
	string detail = "";
	mixed err = catch {
		caster->set_term("xd01testunittaijiteam");
		member->set_term("xd01testunittaijiteam");
		outsider->set_term("xd01testunittaijiother");
		caster->move(room); member->move(room); outsider->move(room);
		enemy->move(room); enemy_two->move(room);
		weapon->move(caster);
		if(!caster->wield(weapon) ||
		   caster->query_equip()["single_main_weapon"]!=weapon ||
		   weapon->query_speed_power()<=0){
			failed++;
			detail += "太极剑无法进入主手或攻击速度为零; ";
		}
		caster->set_mofa(caster->query_mofa_max());
		caster->skills["taijiyu"] = ({5,0});
		caster->skills["taijidun"] = ({5,0});
		caster->skills["taijibi"] = ({5,0});
		caster->skills["taijiyan"] = ({5,0});
		caster->_fight(enemy);
		member->set_life(1);
		caster->set_life(1);
		outsider->set_life(1);
		int enemy_before = enemy->get_cur_life();
		int outsider_before = outsider->get_cur_life();
		int mofa_before = caster->get_cur_mofa();
		caster->perform("taijiyu",1);
		if(caster->get_cur_life()<=1 || member->get_cur_life()<=1 ||
		   outsider->get_cur_life()!=outsider_before ||
		   enemy->get_cur_life()!=enemy_before ||
		   caster->get_cur_mofa()>=mofa_before ||
		   caster->f_skills["taijiyu"]!=5){
			failed++;
			detail += "群疗未隔离敌人/外人; ";
		}

		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		caster->perform("taijidun",1);
		if(caster->query_buff("buff",0)!="absorb" ||
		   (int)caster->query_buff("buff",1)!=1430 ||
		   (int)caster->query_buff("buff",2)!=10){
			failed++;
			detail += "个人盾未按面板生效; ";
		}

		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		caster->perform("taijibi",1);
		if(caster->query_buff("team_guard",0)!="absorb" ||
		   member->query_buff("team_guard",0)!="absorb" ||
		   outsider->query_buff("team_guard",0)!="none"){
			failed++;
			detail += "团队盾范围错误; ";
		}

		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		enemy->set_base_life(10000000);
		enemy->flush_life();
		enemy_two->set_base_life(10000000);
		enemy_two->flush_life();
		caster->flush_targets(enemy_two,1);
		enemy_two->_fight(caster);
		outsider_before = outsider->get_cur_life();
		caster->perform("taijiyan",1);
		mapping report = caster->query_recent_aoe_battle_report();
		if(!report || report["skill"]!="taijiyan" ||
		   sizeof((array)report["targets"])<2 ||
		   outsider->get_cur_life()!=outsider_before ||
		   caster->f_skills["taijiyan"]!=4){
			failed++;
			detail += sprintf(
				"群攻报告=%O targets=%d cold=%d outsider=%d/%d; ",
				report && report["skill"],
				report ? sizeof((array)report["targets"]) : -1,
				(int)caster->f_skills["taijiyan"],
				outsider->get_cur_life(),outsider_before);
		}
	};
	if(err){
		failed++;
		detail += describe_error(err);
	}
	check("太极群疗、个人盾、团队盾和群攻均通过真实 perform 结算",
		failed==0,detail);
	if(caster && caster->query_in_combat())
		caster->_clean_fight();
	destroy_player_with_inventory(caster);
	destroy_player_with_inventory(member);
	destroy_player_with_inventory(outsider);
	if(enemy) destruct(enemy);
	if(enemy_two) destruct(enemy_two);
	if(room) destruct(room);
}

// 无相焰的生产故障来自“候选目标只取已有仇恨表”：普通开战
// 仅有一只怪在表中，所以群攻实际只打一只。本测试故意不预先给
// 第二只怪建立仇恨，同时验证路人玩家和任务NPC不被误伤。
void test_wuxiang_room_aoe_runtime()
{
	object caster = create_hidden_profession_player(
		"xd01testunitwuxiangaoe","wuxiang");
	object teammate = create_hidden_profession_player(
		"xd01testunitwuxiangmate","taiji");
	object outsider = create_hidden_profession_player(
		"xd01testunitwuxiangout","taiji");
	object enemy = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object enemy_two = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object enemy_three = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object enemy_four = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object protected_npc = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object room = clone(WAP_ROOM);
	int failed = 0;
	string detail = "";
	mixed err = catch {
		caster->set_term("xd01testunitwuxiangteam");
		teammate->set_term("xd01testunitwuxiangteam");
		outsider->set_term("xd01testunitwuxiangother");
		caster->move(room);
		teammate->move(room);
		outsider->move(room);
		enemy->move(room);
		enemy_two->move(room);
		enemy_three->move(room);
		enemy_four->move(room);
		protected_npc->move(room);
		enemy->set_name("__testunit_wuxiang_aoe_primary__");
		enemy_two->set_name("__testunit_wuxiang_aoe_extra_two__");
		enemy_three->set_name("__testunit_wuxiang_aoe_extra_three__");
		enemy_four->set_name("__testunit_wuxiang_aoe_extra_four__");
		protected_npc->set_name("__testunit_wuxiang_aoe_protected__");
		protected_npc->_tasknpc = 1;
		enemy->set_base_life(10000000);
		enemy->flush_life();
		enemy_two->set_base_life(10000000);
		enemy_two->flush_life();
		enemy_three->set_base_life(10000000);
		enemy_three->flush_life();
		enemy_four->set_base_life(10000000);
		enemy_four->flush_life();
		protected_npc->set_base_life(10000000);
		protected_npc->flush_life();
		caster->skills["wuxiangyan"] = ({5,0});
		// 虽已学到5阶，但1级人物只能发挥1阶：服务端必须把覆盖上限压到2。
		caster->level = 1;
		caster->set_att_by_level();
		caster->set_mofa(caster->query_mofa_max());
		caster->_fight(enemy);
		int second_was_not_engaged = !caster->if_in_targets(enemy_two);
		int teammate_before = teammate->get_cur_life();
		int outsider_before = outsider->get_cur_life();
		int protected_before = protected_npc->get_cur_life();
		int mofa_before = caster->get_cur_mofa();
		caster->perform("wuxiangyan",1);
		mapping report = caster->query_recent_aoe_battle_report();
		int saw_primary = 0;
		int selected_extras = 0;
		int saw_protected = 0;
		foreach((array(mapping))report["targets"],mapping target){
			if(target["name"]=="__testunit_wuxiang_aoe_primary__")
				saw_primary = 1;
			else if(search(({"__testunit_wuxiang_aoe_extra_two__",
			   "__testunit_wuxiang_aoe_extra_three__",
			   "__testunit_wuxiang_aoe_extra_four__"}),
			   target["name"])!=-1)
				selected_extras++;
			else if(target["name"]=="__testunit_wuxiang_aoe_protected__")
				saw_protected = 1;
		}
		if(!second_was_not_engaged || !report ||
		   report["skill"]!="wuxiangyan" ||
		   sizeof((array)report["targets"])!=2 ||
		   !saw_primary || selected_extras!=1 || saw_protected ||
		   teammate->get_cur_life()!=teammate_before ||
		   outsider->get_cur_life()!=outsider_before ||
		   protected_npc->get_cur_life()!=protected_before ||
		   caster->get_cur_mofa()>=mofa_before ||
		   caster->f_skills["wuxiangyan"]!=7){
			failed++;
			detail += sprintf(
				"pre=%d report=%O targets=%d primary=%d extras=%d protected=%d mate=%d/%d out=%d/%d task=%d/%d mana=%d/%d cold=%d; ",
				second_was_not_engaged,report && report["skill"],
				report ? sizeof((array)report["targets"]) : -1,
				saw_primary,selected_extras,saw_protected,
				teammate->get_cur_life(),teammate_before,
				outsider->get_cur_life(),outsider_before,
				protected_npc->get_cur_life(),protected_before,
				caster->get_cur_mofa(),mofa_before,
				(int)caster->f_skills["wuxiangyan"]);
		}
	};
	if(err){
		failed++;
		detail += describe_error(err)+" "+describe_backtrace(err);
	}
	check("无相焰会扩展到同房普通怪且不误伤队友、路人与任务NPC",
		failed==0,detail);
	if(caster && caster->query_in_combat())
		caster->_clean_fight();
	destroy_player_with_inventory(caster);
	destroy_player_with_inventory(teammate);
	destroy_player_with_inventory(outsider);
	if(enemy) destruct(enemy);
	if(enemy_two) destruct(enemy_two);
	if(enemy_three) destruct(enemy_three);
	if(enemy_four) destruct(enemy_four);
	if(protected_npc) destruct(protected_npc);
	if(room) destruct(room);
}

void test_hidden_advanced_perform_runtime()
{
	object caster = create_hidden_profession_player(
		"xd01testunittaijiadvanced","taiji");
	object member = create_hidden_profession_player(
		"xd01testunittaijiadvancedmember","wuxiang");
	object outsider = create_hidden_profession_player(
		"xd01testunittaijiadvancedout","wuxiang");
	object ghost_member = create_hidden_profession_player(
		"xd01testunittaijiadvancedghost","wuxiang");
	object enemy = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/taijijian/taijijian");
	object room = clone(WAP_ROOM);
	int failed = 0;
	string detail = "";
	mixed err = catch {
		caster->set_term("xd01testunittaijiadvancedteam");
		member->set_term("xd01testunittaijiadvancedteam");
		ghost_member->set_term("xd01testunittaijiadvancedteam");
		outsider->set_term("xd01testunittaijiadvancedother");
		caster->move(room); member->move(room); outsider->move(room);
		ghost_member->move(room); enemy->move(room);
		weapon->move(caster);
		caster->wield(weapon);
		enemy->set_base_life(10000000);
		enemy->flush_life();
		caster->_fight(enemy);

		caster->skills["taijiguizhen"] = ({1,0});
		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		int attr_before = caster->query_str();
		caster->perform("taijiguizhen",1);
		if(caster->query_str()!=attr_before+attr_before*40/100 ||
		   caster->f_skills["taijiguizhen"]!=301){
			failed++;
			detail += "归真未产生40%属性或5分钟冷却; ";
		}
		caster["/tmp/balanced/attr_expires"] = time()-1;

		caster->skills["taijiguixu"] = ({1,0});
		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		caster->perform("taijiguixu",1);
		if(caster->query_balanced_heart_boost_percent()!=10 ||
		   caster->f_skills["taijiguixu"]!=91){
			failed++;
			detail += sprintf("归墟 boost=%d cold=%d; ",
				caster->query_balanced_heart_boost_percent(),
				(int)caster->f_skills["taijiguixu"]);
		}

		caster->skills["taijijing"] = ({1,0});
		caster->set_debuff("dot",0,"audit_dot");
		caster->set_debuff("dot",1,10);
		caster->set_debuff("dot",2,10);
		caster->set_debuff("curse",0,"life");
		caster->set_debuff("curse",1,50);
		caster->set_debuff("curse",2,10);
		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		caster->perform("taijijing",1);
		if(caster->query_debuff("dot",0)!="none" ||
		   caster->query_debuff("curse",0)!="life" ||
		   caster->f_skills["taijijing"]!=5){
			failed++;
			detail += "太极净未做到单次按优先级净化; ";
		}

		caster->skills["taijiwuji"] = ({1,0});
		caster->set_life(1); member->set_life(1); outsider->set_life(1);
		member->set_debuff("dot",0,"audit_dot");
		member->set_debuff("dot",1,10);
		member->set_debuff("dot",2,10);
		outsider->set_debuff("dot",0,"audit_outside_dot");
		outsider->set_debuff("dot",1,10);
		outsider->set_debuff("dot",2,10);
		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		caster->perform("taijiwuji",1);
		if(caster->get_cur_life()<=1 || member->get_cur_life()<=1 ||
		   member->query_debuff("dot",0)!="none" ||
		   outsider->get_cur_life()!=1 ||
		   outsider->query_debuff("dot",0)!="audit_outside_dot" ||
		   caster->f_skills["taijiwuji"]!=81){
			failed++;
			detail += sprintf(
				"无极 life=%d/%d/%d dot=%O/%O cold=%d; ",
				caster->get_cur_life(),member->get_cur_life(),
				outsider->get_cur_life(),member->query_debuff("dot",0),
				outsider->query_debuff("dot",0),
				(int)caster->f_skills["taijiwuji"]);
		}

		caster->skills["taijihuan"] = ({1,0});
		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		caster->perform("taijihuan",1);
		object summon = SUMMOND->get_player_summons(
			caster->query_name())["balanced_spirit"];
		int summon_valid = summon &&
			summon->query_summon_duration()==300 &&
			summon->query_summon_skill_level()==1 &&
			summon->query_summon_type()=="balanced_spirit" &&
			summon->query_base_str()==155 &&
			SUMMOND->query_combat_credit_owner(summon)==caster;
		if(summon){
			SUMMOND->remove_creature_record(caster->query_name(),
				"balanced_spirit");
			summon->heart_beat();
			summon_valid = summon_valid && summon &&
				SUMMOND->get_player_summons(caster->query_name())[
					"balanced_spirit"]==summon;
		}
		if(!summon_valid || caster->f_skills["taijihuan"]!=5){
			failed++;
			detail += "阴阳灵兽时长/缩放/心跳登记/击杀归属错误; ";
		}
		SUMMOND->dismiss_all(caster->query_name());

		caster->skills["taijihunyuan"] = ({1,0});
		caster->timeCold = 0;
		caster->set_mofa(caster->query_mofa_max());
		int enemy_before = enemy->get_cur_life();
		int mofa_before = caster->get_cur_mofa();
		caster->perform("taijihunyuan",1);
		if(enemy->get_cur_life()>=enemy_before ||
		   caster->get_cur_mofa()>=mofa_before ||
		   caster->f_skills["taijihunyuan"]!=76){
			failed++;
			detail += "混元双段物理结算未造成伤害或资源错误; ";
		}

		ghost_member->set_life(0);
		ghost_member->ghost();
		int revived = caster->try_taiji_team_revive(caster,ghost_member);
		if(!revived || ghost_member->is("ghost") ||
		   ghost_member->get_cur_life()!=ghost_member->query_life_max()/2 ||
		   caster->query_taiji_team_revive_remaining()<=0){
			failed++;
			detail += "复阴未真实解除鬼魂或成功后未记冷却; ";
		}
	};
	if(err){
		failed++;
		detail += describe_error(err)+" "+describe_backtrace(err);
	}
	check("太极终式、净化、召唤、混元和复阴均通过真实运行结算",
		failed==0,detail);
	SUMMOND->dismiss_all(caster ? caster->query_name() : "");
	if(caster && caster->query_in_combat())
		caster->_clean_fight();
	destroy_player_with_inventory(caster);
	destroy_player_with_inventory(member);
	destroy_player_with_inventory(outsider);
	destroy_player_with_inventory(ghost_member);
	if(enemy) destruct(enemy);
	if(room) destruct(room);
}

void destroy_player_with_inventory(object player)
{
	if(!player)
		return;
	SUMMOND->dismiss_all(player->query_name());
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

object create_hidden_profession_player(string name,string profession)
{
	object player = clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn = "Claude审计测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId(profession);
	player->setup_player("third",profession);
	player->level = 120;
	player->set_att_by_level();
	return player;
}

void test_hidden_profession_combat_formulas()
{
	object wuxiang = create_hidden_profession_player(
		"xd01testunitwuxiangformula","wuxiang");
	object taiji = create_hidden_profession_player(
		"xd01testunittaijiformula","taiji");
	int formulas_work =
		wuxiang->query_base_damage()>0 &&
		wuxiang->query_defend_power()>0 &&
		wuxiang->query_phy_dodge()>0.0 &&
		wuxiang->query_phy_hitte()>0.0 &&
		wuxiang->query_phy_baoji()>0.0 &&
		taiji->query_base_damage()>wuxiang->query_base_damage() &&
		taiji->query_defend_power()>wuxiang->query_defend_power();
	check("无相/太极已接入全部基础战斗公式且太极成长领先",
		formulas_work,
		sprintf("wx伤害=%d 防御=%d，tj伤害=%d 防御=%d",
			wuxiang->query_base_damage(),wuxiang->query_defend_power(),
			taiji->query_base_damage(),taiji->query_defend_power()));
	destroy_player_with_inventory(wuxiang);
	destroy_player_with_inventory(taiji);
}

void test_server_authoritative_reward_and_relife()
{
	object player = clone(GAMELIB_USER);
	player->set_name("xd01testunitrelifeauth");
	player->set_project("gamelib");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	check("复活点只接受明确提供设置链接的合法卧室",
		player->is_valid_relife_path(
			"/gamelib/d/congxianzhen/congxianzhenguangchang")==1 &&
		player->is_valid_relife_path(
			"/gamelib/d/congxianzhen/wanxianglin")==0 &&
		player->is_valid_relife_path("/gamelib/d/../../etc/passwd")==0,
		"Boss 房或路径穿越仍可作为复活点");
	destroy_player_with_inventory(player);

	string gift_cmd = Stdio.read_file(ROOT+"/gamelib/cmds/gift_take.pike");
	string gift_daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/giftd.pike");
	check("礼包数量由服务端剩余值决定，客户端数字不再参与发奖",
		gift_cmd && gift_daemon &&
		search(gift_cmd,"sscanf(arg")==-1 &&
		search(gift_cmd,"add_account(remaining)")!=-1 &&
		search(gift_cmd,"query_gift_remaining")!=-1 &&
		search(gift_daemon,"int query_gift_remaining")!=-1 &&
		GIFTD->query_gift_remaining(
			"__testunit_missing_gift_user__","money")==0,
		"仍信任 gift_take money 后的客户端数量");
	check("礼包物品只有确认进入背包后才核销",
		gift_cmd && search(gift_cmd,"if(!delivered)")!=-1 &&
		search(gift_cmd,"flush_gift_m(me->query_name(),gift_name,1)")>
		search(gift_cmd,"if(!delivered)"),
		"背包满或移动失败仍可能吃掉奖励");

	string convert = Stdio.read_file(ROOT+
		"/gamelib/cmds/convert_equip_detail.pike");
	check("装备炼化详情拒绝生产日志中的 NULL 参数",
		convert && search(convert,"!me || !arg ||")!=-1 &&
		search(convert,"sscanf(arg")>search(convert,"!me || !arg ||"),
		"NULL 参数仍先进入 sscanf");
	string buy_items = Stdio.read_file(ROOT+"/gamelib/cmds/buy_items.pike");
	string look_top = Stdio.read_file(ROOT+"/gamelib/cmds/look_top.pike");
	check("商店和排行榜畸形参数不会进入 sscanf 或负页索引",
		buy_items && look_top &&
		search(buy_items,"!me || !arg ||")!=-1 &&
		search(buy_items,"sscanf(arg")>search(buy_items,"!me || !arg ||") &&
		search(look_top,"sscanf(arg,\"%s %s\",act,value)!=2")!=-1 &&
		search(look_top,"page<1")!=-1,
		"冷门入口仍可由NULL或无效页码触发运行时异常");
}

void test_trial_reward_exchange_runtime()
{
	string userid = "xd01testunitshilian99";
	object original_player = this_player();
	object player;
	object wuxun;
	object command;
	int result = 0;
	int before = 0;
	int remaining = 0;
	mixed err;
	cleanup_audit_player_files(userid);
	err = catch {
		player = clone(GAMELIB_USER);
		player->set_name(userid);
		player->name_cn = "试炼兑换审计";
		player->set_project("gamelib");
		player->setup("testunit-only");
		player->set_raceId("human");
		player->set_profeId("jianxian");
		player->setup_player("human","jianxian");
		wuxun = clone(ROOT+
			"/gamelib/clone/item/other/shilianwuxun");
		wuxun->move(player);
		wuxun->amount = 10;
		before = player->query_account();
		command = (object)(ROOT+"/gamelib/cmds/shilian_duihuan.pike");
		set_this_player(player);
		result = command->main("1 lingshi");
		foreach(all_inventory(player),object item)
			if(item && item->query_name()=="shilianwuxun")
				remaining += (int)item->amount;
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	check("试炼武勋真实兑换按金币单位结算且成功后才扣除",
		!err && result==1 && player &&
		player->query_account()==before+1000000 && remaining==0,
		err ? describe_error(err) :
			sprintf("result=%d money=%d/%d remaining=%d",result,
				player ? player->query_account() : -1,before,remaining));

	string npc_source = Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	check("只有两个明确 Boss 发武勋且新堆叠先检查背包容量",
		npc_source && search(npc_source,"int wuxun_per_member = 0;")!=-1 &&
		search(npc_source,"else if(termer->if_over_load(wuxun_ob))")!=-1,
		"未知组队 Boss 仍会误发武勋，或满背包仍强行移动奖励");
	destroy_player_with_inventory(player);
	cleanup_audit_player_files(userid);
}

void test_jinaodao_monster_level_integrity()
{
	string room_dir = ROOT+"/gamelib/d/jinaodao";
	array(string) files = get_dir(room_dir) || ({});
	array(string) combat_prefixes = ({"shachong","youhun",
		"tianxianjiaocike","duwuhuoshe","huangshaxiyi","yeying"});
	int checked = 0;
	array(string) failures = ({});
	foreach(files,string file){
		string source = Stdio.read_file(room_dir+"/"+file);
		int room_level = 0;
		int expected = 0;
		if(!source || sscanf(source,"%*sprotected int room_level=%d;",room_level)<2)
			continue;
		if(room_level>=15 && room_level<=24)
			expected = 15;
		else if(room_level>=25 && room_level<=34)
			expected = 25;
		else if(room_level>=35 && room_level<=44)
			expected = 35;
		else if(room_level>=45 && room_level<=54)
			expected = 45;
		else if(room_level>=55 && room_level<=63)
			expected = 55;
		if(!expected)
			continue;
		foreach(source/"\n",string line){
			array(string) split = line/"/gamelib/clone/npc/jinaodao/";
			if(sizeof(split)!=2)
				continue;
			string npc_name = (split[1]/"\"")[0];
			int is_training_monster = 0;
			foreach(combat_prefixes,string prefix)
				if(has_prefix(npc_name,prefix)){
					is_training_monster = 1;
					break;
				}
			if(!is_training_monster)
				continue;
			string npc_source = Stdio.read_file(ROOT+
				"/gamelib/clone/npc/jinaodao/"+npc_name);
			checked++;
			if(!npc_source || search(npc_source,
				"_npcLevel="+expected+";")==-1)
				failures += ({file+" -> "+npc_name});
		}
	}
	check("金鳌岛 15-60 级房间引用的怪物文件存在且等级分桶正确",
		checked>=200 && !sizeof(failures),
		sprintf("checked=%d failures=%s",checked,failures*", "));
}

void test_timed_event_daily_entry_contract()
{
	string runtime = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_timed_event_mod/runtime.pike");
	int last_entry_guard = runtime ? search(runtime,
		"if((string)last_entry[event_id]==date)\n\t\treturn 1;") : -1;
	check("限时活动淘汰后不再算活跃会话，但仍保持每日一次资格",
		runtime && last_entry_guard!=-1 &&
		search(runtime,"忽略 last_entry 记录")==-1,
		"淘汰状态绕过了 last_entry 的每日资格锁");
}

void test_server_driven_autofight()
{
	string frontend = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string http = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	check("浏览器只同步服务端挂机画面，不再推进世界命令",
		frontend && search(frontend,"/api/autofight_view?")!=-1 &&
		search(frontend,"sendJsonCommand('flushview')")==-1 &&
		search(frontend,"this.applyBattleStatusData(data.refresh, true)")!=-1,
		"浏览器仍在执行 flushview 或画面缺少同刻战斗快照");
	check("隐藏标签页只暂停画面，恢复可见后立即同步",
		frontend && search(frontend,"visibilityState === 'hidden'")!=-1 &&
		search(frontend,"clearInterval(this.autofightInterval)")!=-1 &&
		search(frontend,"visibilityState === 'visible'")!=-1 &&
		search(frontend,"服务端全局调度器继续挂机")!=-1,
		"后台仍可能暂停真实挂机或前台恢复不同步");
	check("服务端使用单一调度器和公平有界队列推进原 flushview",
		daemon && http &&
		search(daemon,"run_server_autofight_tick")!=-1 &&
		search(daemon,"single_global_callout")!=-1 &&
		search(daemon,"cleanup_server_autofight_views")!=-1 &&
		search(daemon,"HTTP_APID->update_connection_time(userid)")!=-1 &&
		search(daemon,"enqueue_world_command(userid,\"\",\"flushview\"")!=-1 &&
		search(daemon,"execute_core_command")==-1 &&
		search(http,"case \"/api/autofight_view\"")!=-1 &&
		search(http,"query_server_autofight_tick_active(cached_player)")!=-1 &&
		search(http,"旧 flushview 请求")!=-1 &&
		search(http,"case \"/api/ping\"")!=-1 &&
		search(frontend,"/api/ping?txd=")!=-1,
		"挂机仍依赖每玩家计时器、绕过公平队列或缺少只读画面接口");

	object httpd = HTTP_APID;
	object player = clone(GAMELIB_USER);
	// 老账号可能包含大写字母；连接池与挂机键保留物理档案精确大小写。
	string userid = "xd01TestUnitAuditAFK";
	player->set_name(userid);
	player->set_password("testunit-afk");
	player->set_project("gamelib");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->move(ROOT+"/gamelib/d/kunlunshan/wuge");
	httpd->set_virtual_connection(userid,({0,time(),player}));
	check("HTTP虚拟连接池保留混合大小写账号的精确身份",
		httpd->has_virtual_connection(userid)==1 &&
		httpd->has_virtual_connection(lower_case(userid))==0 &&
		!httpd->get_player_from_connection(lower_case(userid),0) &&
		httpd->get_player_from_connection(userid,0)==player,
		"大小写变体发生串号或精确连接无法读取");
	AUTOFIGHTD->start_autofight(player);
	check("混合大小写账号开启挂机后注册服务端全局调度",
		AUTOFIGHTD->query_server_autofight_tick_active(player)==1,
		"服务端调度未激活");
	int before = AUTOFIGHTD->query_time_left(player);
	player["/tmp/autofight_last_charge"] = time()-31;
	int after = AUTOFIGHTD->charge_time(player);
	check("事件循环长停顿不一次性补扣超过30秒额度",
		after==before,
		sprintf("before=%d after=%d",before,after));
	AUTOFIGHTD->cancel_server_autofight_tick(player);
	player->set_autofight("enable");
	player["/tmp/autofight_no_target_ticks"] = 9;
	player["/tmp/autofight_previous_room"] = "stale/source/room";
	player["/tmp/autofight_resting"] = 1;
	player["/tmp/autofight_rest_started"] = time()-10;
	player["/tmp/autofight_last_charge"] = time()-20;
	int resume_before = AUTOFIGHTD->query_time_left(player);
	int resumed = AUTOFIGHTD->resume_worker_handoff(player);
	int resume_after = AUTOFIGHTD->query_time_left(player);
	check("跨Worker恢复挂机重新登记调度且不补扣运输耗时",
		resumed==1 &&
		AUTOFIGHTD->query_server_autofight_tick_active(player)==1 &&
		resume_after==resume_before &&
		(int)player["/tmp/autofight_last_charge"]>=time()-1 &&
		(int)player["/tmp/autofight_no_target_ticks"]==0 &&
		(string)player["/tmp/autofight_previous_room"]=="" &&
		(int)player["/tmp/autofight_resting"]==0 &&
		(int)player["/tmp/autofight_rest_started"]==0,
		"目标Worker未恢复调度、错误扣费或计费锚点未更新");
	AUTOFIGHTD->stop_autofight(player);
	check("关闭挂机立即注销服务端调度",
		AUTOFIGHTD->query_server_autofight_tick_active(player)==0,
		"关闭后调度仍活跃");
	httpd->remove_virtual_connection(userid);
	destruct(player);
}

void test_immutable_hidden_commands()
{
	object httpd = HTTP_APID;
	string user = "xd01testunittoken";
	string auth_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/auth.pike");
	string first = httpd->hide_command(user,"_explorer inventory 2");
	string second = httpd->hide_command(user,"look sword");
	check("隐藏命令使用独立随机令牌",
		has_prefix(first,"c_") && has_prefix(second,"c_") &&
		first!=second && sizeof(first)>40,
		"仍是可覆盖的数字下标");
	check("生成后续页面不会覆盖背包下一页",
		httpd->unhide_command(user,first)=="_explorer inventory 2" &&
		httpd->unhide_command(user,second)=="look sword",
		"令牌对应命令发生漂移");
	check("输入框后缀只拼到令牌自己的命令",
		httpd->unhide_command(user,first+" 7")==
		"_explorer inventory 2 7",
		"输入后缀解析错误");
	check("隐藏命令令牌绑定账号",
		httpd->unhide_command("xd01another",first)=="look",
		"其他账号可复用令牌");
	check("老JSP数字命令书签失效后安全恢复当前画面",
		httpd->unhide_command(user,"0")=="look" &&
		httpd->unhide_command(user,"17 old-input")=="look",
		"旧进程数字下标被当作明文命令执行");
	check("令牌回收按序号推进且按账号清理",
		auth_source &&
		search(auth_source,"mapping(int:string) hidden_command_order")!=-1 &&
		search(auth_source,"hidden_command_oldest_serial")!=-1 &&
		search(auth_source,"hidden_command_user_tokens[userid]")!=-1 &&
		search(auth_source,"foreach(indices(hidden_command_tokens)")==-1,
		"高频页面动作仍会全表扫描令牌缓存");
	mapping generated = ([]);
	object result_lock = Thread.Mutex();
	array(object) workers = ({});
	for(int worker=0;worker<8;worker++)
		workers += ({Thread.Thread(generate_hidden_token_probe,httpd,user,
			worker,16,generated,result_lock)});
	foreach(workers,object worker)
		worker->wait();
	int concurrent_valid = sizeof(generated)==128;
	foreach(indices(generated),string token)
		if(httpd->unhide_command(user,token)!=(string)generated[token])
			concurrent_valid = 0;
	check("背包翻页令牌并发生成后仍各自对应原命令",
		concurrent_valid,
		sprintf("期望128个独立令牌，实际%d",sizeof(generated)));
	httpd->clear_hidden_commands(user);
}

void test_other_runtime_regressions()
{
	object player = clone(GAMELIB_USER);
	object equipment = clone(ROOT+
		"/gamelib/clone/item/armor/38binglingtoushi/38binglingtoushi");
	player->set_name("xd01testunitdura");
	player->query_equip()["armor_head"] = equipment;
	equipment->item_cur_dura = 1;
	string warning = AUTOFIGHTD->maybe_durability_warning(player);
	check("挂机耐久预警读取真实公开字段和接口",
		warning!="" && search(warning,"耐久")!=-1,
		"低耐久装备没有产生提醒");
	destruct(equipment);
	destruct(player);

	object taiji = clone(GAMELIB_USER);
	taiji->set_profeId("taiji");
	taiji->set_str(100);
	taiji->set_dex(100);
	taiji->set_think(100);
	check("太极三项同步成长时心法仍生效",
		taiji->query_taiji_heart_bonus("str")==65 &&
		taiji->query_taiji_heart_bonus("dex")==65 &&
		taiji->query_taiji_heart_bonus("think")==65,
		"三项相等导致心法永久为零");
	destruct(taiji);

	string profession = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/professionvipd.pike");
	string fight = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	string death = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	check("灵医常驻战斗助手硬限制为 PVE",
		profession && search(profession,
		"!player->query_in_combat() ||\n\t   !is_pve_enemy(player)")!=-1,
		"PVP 仍可能被自动选招接管");
	check("DOT 延迟死亡允许已脱战零血 NPC 收尾且仍保护玩家",
		fight &&
		search(fight,"if(actor->is(\"npc\")){")!=-1 &&
		search(fight,"else if(!actor->query_in_combat())")!=-1 &&
		search(fight,"actor->fight_die();")!=-1,
		"NPC 脱战后仍可能跳过死亡，或玩家缺少重复死亡保护");
	check("挂机死亡次数在所有免死判定之后记录",
		death && search(death,"try_pet_owner_revive") <
		search(death,"record_afk_death"),
		"免死仍被计作真实挂机死亡");
}

void test_prelogin_command_guards()
{
	object original_player = this_player();
	object prelogin = clone(LOW_USER_OB);
	object look_cmd = (object)(ROOT+"/gamelib/cmds/look.pike");
	object leave_cmd = (object)(ROOT+"/lowlib/wapmud2/cmds/leave.pike");
	int look_result = -1;
	int leave_result = -1;
	mixed err = catch {
		set_this_player(prelogin);
		look_result = look_cmd->main(
			"html6 /main.jsp legacy-probe");
		leave_result = leave_cmd->main(
			"html6 /main.jsp legacy-probe");
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	check("登录阶段对象误入 look/leave 时安全拒绝而不抛异常",
		!err && look_result==0 && leave_result==0,
		err ? describe_error(err) : sprintf("look=%d leave=%d",
			look_result,leave_result));
	if(prelogin)
		destruct(prelogin);
}

void test_distributed_channel_chat_contract()
{
	string userid="__testunit_channel_chat";
	string message=userid+"|[频道测试:look]：跨Worker消息";
	check("普通频道消息可由目标Worker幂等投递且拒绝伪造阵营",
		RACECHATD->apply_distributed_chat_msg(
			"human","pub_channel",message)==1 &&
		RACECHATD->apply_distributed_chat_msg(
			"invalid","pub_channel",message)==0,
		"普通频道缺少跨Worker投递入口或未校验阵营");
}

int main()
{
	werror("\n========== Claude 两日提交审计回归 =========="
		"\n");
	mixed err = catch {
		test_changed_files_compile();
		test_server_driven_autofight();
		test_immutable_hidden_commands();
		test_hidden_profession_combat_formulas();
		test_hidden_skill_contract_runtime();
		test_hidden_support_perform_runtime();
		test_wuxiang_room_aoe_runtime();
		test_hidden_advanced_perform_runtime();
		test_server_authoritative_reward_and_relife();
		test_trial_reward_exchange_runtime();
		test_jinaodao_monster_level_integrity();
		test_timed_event_daily_entry_contract();
		test_other_runtime_regressions();
		test_prelogin_command_guards();
		test_distributed_channel_chat_contract();
	};
	if(err)
		check("审计回归测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	werror("Claude审计：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
