#!/usr/bin/env pike
/**
 * 方士严格审计补全测试：
 * - 守护进程召唤鉴权与真实技能等级
 * - 跨阵营队友保护与主人失去房间后的清理
 * - 九职业高级技能书独立轮换及服务端购买授权
 * - 装备描述、开放说明与治疗技能配置
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[方士补全审计 %d] %s\n",test_results["total"],name);
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

object create_player(string name,string race_id,
	string profession_id,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "方士补全审计人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->level = level;
	player->set_att_by_level();
	if(profession_id=="fangshi")
		player->skills["lingdanshu"] = ({1,0});
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	SUMMOND->dismiss_all(player->query_name());
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_summon_daemon_authorization()
{
	test_start("SUMMOND拒绝跨职业与未学技能调用并忽略伪造等级");
	string fangshi_name = "__testunit_audit_summon_fangshi__";
	string yushi_name = "__testunit_audit_summon_yushi__";
	object fangshi = create_player(
		fangshi_name,"third","fangshi",60);
	object yushi = create_player(
		yushi_name,"human","yushi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero no_skill = 0;
	object|zero wrong_profession = 0;
	object|zero tiger = 0;
	int tiger_created = 0;
	int no_all = -1;
	int all_count = -1;
	string error_desc = "";

	mixed err = catch {
		fangshi->move(room);
		yushi->move(room);
		yushi->skills["huling"] = ({5,0});
		no_skill = SUMMOND->summon_creature(
			fangshi_name,"huling",600,999);
		no_all = SUMMOND->summon_all_spirits(
			fangshi_name,600,999);
		wrong_profession = SUMMOND->summon_creature(
			yushi_name,"huling",600,999);
		fangshi->skills["huling"] = ({10,0});
		tiger = SUMMOND->summon_creature(
			fangshi_name,"huling",600,999);
		if(tiger)
			tiger_created = 1;
		SUMMOND->dismiss_all(fangshi_name);
		fangshi->skills["sanlingheyi"] = ({3,0});
		all_count = SUMMOND->summon_all_spirits(
			fangshi_name,600,999);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && !no_skill && no_all==0 && !wrong_profession &&
	   tiger_created &&
	   SUMMOND->query_authorized_skill_level(fangshi,"huling")==5 &&
	   all_count==3 &&
	   SUMMOND->get_current_summon_count(fangshi_name)==3)
		test_pass();
	else
		test_fail("召唤鉴权、等级封顶或三灵内部授权失败: "+error_desc);

	destroy_player(fangshi);
	destroy_player(yushi);
	if(room)
		destruct(room);
}

void test_summon_team_protection_and_orphan_cleanup()
{
	test_start("跨阵营同队成员不能误伤灵兽且主人无房间立即清理");
	string owner_name = "__testunit_audit_summon_owner__";
	object owner = create_player(
		owner_name,"third","fangshi",30);
	object teammate = create_player(
		"__testunit_audit_summon_teammate__","human","yushi",30);
	object outsider = create_player(
		"__testunit_audit_summon_outsider__","human","yushi",30);
	object orphan_owner = clone(GAMELIB_USER);
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero tiger = clone(ROOT+
		"/gamelib/clone/npc/summon/huling");
	int teammate_blocked = 0;
	int outsider_allowed = 0;
	int cleaned = 0;
	string error_desc = "";

	mixed err = catch {
		owner->set_term("__testunit_audit_cross_race_team__");
		teammate->set_term("__testunit_audit_cross_race_team__");
		outsider->set_term("__testunit_audit_other_team__");
		teammate->move(room);
		outsider->move(room);
		if(tiger){
			tiger->set_master(owner_name);
			tiger->set_summon_duration(600);
			tiger->move(room);
			teammate_blocked = !tiger->can_be_attacked(teammate);
			outsider_allowed = tiger->can_be_attacked(outsider);
			tiger->cleanup_if_master_unavailable(orphan_owner);
			cleaned = !tiger &&
				SUMMOND->get_current_summon_count(owner_name)==0;
			tiger = 0;
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && teammate_blocked && outsider_allowed && cleaned)
		test_pass();
	else
		test_fail(sprintf(
			"队伍保护或孤儿召唤清理失败 team=%d outsider=%d cleaned=%d: %s",
			teammate_blocked,outsider_allowed,cleaned,error_desc));

	destroy_player(owner);
	destroy_player(teammate);
	destroy_player(outsider);
	if(orphan_owner)
		destruct(orphan_owner);
}

void test_profession_balanced_high_books()
{
	test_start("九职业各自轮换两种高级书且只能购买本职业目录");
	array(string) professions = ({
		"jianxian","yushi","zhuxian",
		"kuangyao","wuyao","yinggui","fangshi","zhenyue","tianxiang",
	});
	array(string) races = ({
		"human","human","human",
		"monst","monst","monst","third","third","third",
	});
	array(object) players = ({});
	array(array(string)) selected = ({});
	int failed = 0;
	string error_desc = "";

	mixed err = catch {
		for(int i=0;i<sizeof(professions);i++){
			object player = create_player(
				"__testunit_audit_book_"+professions[i]+"__",
				races[i],professions[i],100);
			array(string) names =
				BUYD->query_book_names_for_profe(professions[i]);
			players += ({player});
			selected += ({names});
			if(sizeof(names)!=2)
				failed++;
			foreach(names,string name){
				if(!BUYD->can_buy_high_level_book(player,name) ||
				   BUYD->query_high_level_book_price(name)<=0 ||
				   search(BUYD->get_book_for_profe(professions[i]),
					name)==-1)
					failed++;
			}
		}
		for(int i=0;i<sizeof(professions);i++){
			int other = i+1;
			if(other>=sizeof(professions))
				other = 0;
			if(sizeof(selected[other]) &&
			   BUYD->can_buy_high_level_book(
				players[i],selected[other][0]))
				failed++;
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"高级书职业轮换或授权失败 failed=%d: %s",
			failed,error_desc));

	foreach(players,object player)
		destroy_player(player);
}

void test_ui_and_config_regressions()
{
	test_start("装备描述显示方士、开放命令无伪解锁、秘传治疗使用减疗类型");
	object player = create_player(
		"__testunit_audit_ui_fangshi__","third","fangshi",80);
	object item = clone(ROOT+
		"/gamelib/clone/item/weapon/5shanmuchangzhang/5shanmuchangzhang");
	object unlock_command =
		(object)(ROOT+"/gamelib/cmds/unlock_fangshi.pike");
	object heal_skill =
		(object)(ROOT+"/gamelib/single/skills/lingzhi_mystic");
	object|zero original_player = this_player();
	string content = "";
	string open_info = "";
	string unlock_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/unlock_fangshi.pike");
	string confirm_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/yushi_buy_hlbook_confirm.pike");
	string error_desc = "";

	mixed err = catch {
		set_this_player(player);
		content = item->query_content();
		open_info = unlock_command->query_fangshi_open_info();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err &&
	   search(content,"方士")!=-1 &&
	   search(open_info,"已经全服免费开放")!=-1 &&
	   search(open_info,"不需要额外解锁")!=-1 &&
	   search(open_info,"confirm")==-1 &&
	   search(unlock_source,"SEASONALD->unlock_fangshi")==-1 &&
	   search(unlock_source,"me->save()")==-1 &&
	   heal_skill->s_curse_type=="life" &&
	   search(confirm_source,"query_high_level_book_price")!=-1 &&
	   search(confirm_source,"can_buy_high_level_book")!=-1)
		test_pass();
	else
		test_fail("显示、开放状态或服务端配置回归: "+error_desc);

	if(item)
		destruct(item);
	destroy_player(player);
}

void print_summary()
{
	werror("\n========================================\n");
	werror("方士补全审计测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_summon_daemon_authorization();
	test_summon_team_protection_and_orphan_cleanup();
	test_profession_balanced_high_books();
	test_ui_and_config_regressions();
	print_summary();
	return test_results["failed"];
}
