#!/usr/bin/env pike
/**
 * 副本实例、地图飞行、紧急脱离与方士召唤物挂机边界测试。
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
	werror("\n[副本安全 %d] %s\n",test_results["total"],name);
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

object create_player(string name,int level,string race_id,string profession)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "副本安全测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession);
	player->setup_player(race_id,profession);
	player->level = level;
	player->set_att_by_level();
	player->flush_life();
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

void test_runtime_compile_and_reverse_index()
{
	test_start("核心命令编译且 fb.csv 反向索引识别基础与克隆路径");
	array(string) paths = ({
		"/gamelib/single/daemons/fbd.pike",
		"/gamelib/single/daemons/mapd.pike",
		"/gamelib/cmds/map_display.pike",
		"/gamelib/cmds/qge74hye.pike",
		"/gamelib/cmds/fb_entry.pike",
		"/gamelib/cmds/fb_leave.pike",
		"/gamelib/single/daemons/autofightd.pike",
		"/lowlib/wapmud2/inherit/feature/fight.pike",
	});
	object daemon = (object)(ROOT+"/gamelib/single/daemons/fbd.pike");
	object|zero cloned_room = 0;
	string error_desc = "";
	int failed = 0;
	mixed err = catch {
		foreach(paths,string path){
			program compiled = (program)(ROOT+path);
			if(!compiled)
				failed++;
		}
		cloned_room = clone(ROOT+"/gamelib/d/bwmk/mowangchaoxue");
		if(daemon->query_fb_name_by_room_path("bwmk/mowangchaoxue")!=
		   "bawangmoku" ||
		   daemon->query_fb_name_by_room_path(file_name(cloned_room))!=
		   "bawangmoku" ||
		   daemon->query_fb_leave_room("bawangmoku")!=
		   "bawangbao/zhuzunge")
			failed++;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && failed==0)
		test_pass();
	else
		test_fail("编译或反向索引错误: "+error_desc);
	if(cloned_room){
		foreach(all_inventory(cloned_room),object item)
			destruct(item);
		destruct(cloned_room);
	}
}

void test_team_instance_identity()
{
	test_start("同队入口共享同一 BOSS 实例且不同队严格隔离");
	object daemon = (object)(ROOT+"/gamelib/single/daemons/fbd.pike");
	object|zero first = 0;
	object|zero teammate = 0;
	object|zero other_team = 0;
	object base_room = (object)(ROOT+
		"/gamelib/d/xinnian_fb/lingranzhiyan_h");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		first = daemon->query_fb_room("lingranzhiyan_h",0,
			"__testunit_fb_team_a__",0);
		teammate = daemon->query_fb_room("lingranzhiyan_h",0,
			"__testunit_fb_team_a__",0);
		other_team = daemon->query_fb_room("lingranzhiyan_h",0,
			"__testunit_fb_team_b__",0);
		daemon->add_fb_members("__testunit_fb_team_a__/lingranzhiyan_h",
			"__testunit_fb_member_a__");
		daemon->add_fb_members("__testunit_fb_team_b__/lingranzhiyan_h",
			"__testunit_fb_member_b__");
		valid = first && teammate && other_team &&
			first==teammate && first!=other_team && first!=base_room;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("队伍实例身份错误: "+error_desc);
	if(first)
		daemon->delete_fb_members("__testunit_fb_team_a__/lingranzhiyan_h",
			"__testunit_fb_member_a__");
	if(other_team)
		daemon->delete_fb_members("__testunit_fb_team_b__/lingranzhiyan_h",
			"__testunit_fb_member_b__");
}

void test_map_filter_and_legacy_redirect()
{
	test_start("地图不暴露副本内部房间且旧直飞链接改送入口");
	object map_daemon = (object)(ROOT+
		"/gamelib/single/daemons/mapd.pike");
	object map_command = (object)(ROOT+"/gamelib/cmds/map_display.pike");
	object command_ob = (object)(ROOT+"/gamelib/cmds/qge74hye.pike");
	object player = create_player(
		"__testunit_fb_legacy_fly__",70,"human","jianxian");
	object start_room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero original_player = this_player();
	string sub_maps = "";
	string catalog = "";
	string current_path = "";
	string error_desc = "";
	int money_before = 0;
	int valid = 0;
	mixed err = catch {
		player->move(start_room);
		player->set_account(5000);
		set_this_player(player);
		sub_maps = map_daemon->get_sub_map_list("bwmk");
		catalog = map_daemon->get_all_kinds_map();
		money_before = player->query_account();
		map_command->main("bwmk 1000");
		command_ob->main("bwmk/mowangchaoxue");
		if(environment(player))
			current_path = (file_name(environment(player))/"#")[0];
		valid = sub_maps=="" &&
			search(catalog,"map_display bwmk")==-1 &&
			player->query_account()==money_before &&
			has_suffix(current_path,"/gamelib/d/bawangbao/zhuzunge") &&
			!FBD->is_fb_room_path(current_path);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("地图过滤或旧链接改送失败: "+error_desc);
	destroy_player(player);
}

void test_emergency_leave_and_move_cleanup()
{
	test_start("无出口 BOSS 房可无参数脱离且所有离开路径清理成员状态");
	object command_ob = (object)(ROOT+"/gamelib/cmds/fb_leave.pike");
	object player = create_player(
		"__testunit_fb_emergency_leave__",70,"human","jianxian");
	object boss_room = clone(ROOT+"/gamelib/d/bwmk/mowangchaoxue");
	object first_room = clone(ROOT+
		"/gamelib/d/xinnian_fb/lingranzhiyan_h");
	object safe_room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero original_player = this_player();
	string error_desc = "";
	int inferred_leave = 0;
	int generic_cleanup = 0;
	mixed err = catch {
		foreach(all_inventory(boss_room),object item)
			destruct(item);
		player->fb_id = "__testunit_fb_escape__/bawangmoku";
		FBD->add_fb_members(player->fb_id,player->query_name());
		player->move(boss_room);
		set_this_player(player);
		command_ob->main(0);
		inferred_leave = environment(player) &&
			has_suffix((file_name(environment(player))/"#")[0],
				"/gamelib/d/bawangbao/zhuzunge") &&
			!player->fb_id;

		player->fb_id = "__testunit_fb_move__/lingranzhiyan_h";
		FBD->add_fb_members(player->fb_id,player->query_name());
		player->move(first_room);
		player->move(safe_room);
		generic_cleanup = !player->fb_id &&
			!FBD->query_fb_memebers(
				"__testunit_fb_move__/lingranzhiyan_h",
				player->query_name());
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(!err && inferred_leave && generic_cleanup)
		test_pass();
	else
		test_fail(sprintf("脱离=%d 通用清理=%d: %s",
			inferred_leave,generic_cleanup,error_desc));
	if(boss_room)
		destruct(boss_room);
	if(first_room)
		destruct(first_room);
	destroy_player(player);
}

void test_summons_do_not_block_autofight()
{
	test_start("方士三灵不计入可见怪且不阻断挂机换图");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object player = create_player(
		"__testunit_fb_autofight_viewer__",72,"third","fangshi");
	object owner = create_player(
		"__testunit_fb_autofight_owner__",72,"third","fangshi");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	array(object) summons = ({ });
	mapping snapshot = ([]);
	string error_desc = "";
	int visible = -1;
	int route_requested = 0;
	int valid = 0;
	mixed err = catch {
		foreach(all_inventory(room),object old_item)
			destruct(old_item);
		player->move(room);
		owner->move(room);
		//进房会触发正常野怪刷新；测试要构造“只剩三灵”的现场。
		foreach(all_inventory(room),object spawned)
			if(spawned!=player && spawned!=owner)
				destruct(spawned);
		foreach(({"huling","heling","guiling"}),string summon_name){
			object summon = clone(ROOT+
				"/gamelib/clone/npc/summon/"+summon_name);
			summon->set_master(owner->query_name());
			summon->move(room);
			summons += ({summon});
		}
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		visible = daemon->query_visible_monster_count(player);
		snapshot = daemon->query_target_snapshot(player);
		route_requested =
			daemon->should_route_to_training_area(player,snapshot);
		valid = visible==0 && (int)snapshot["visible"]==0 &&
			!snapshot["target"] && route_requested==1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf("可见=%d 快照=%d 换图=%d: %s",
			visible,(int)snapshot["visible"],route_requested,error_desc));
	foreach(summons,object summon)
		if(summon)
			destruct(summon);
	if(room)
		destruct(room);
	destroy_player(player);
	destroy_player(owner);
}

void test_relogin_and_ui_safety_wiring()
{
	test_start("重登脱困、全局安全通道与逃跑无出口兜底完整接线");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string fight_source = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike");
	int valid = init_source && user_source && fight_source &&
		search(init_source,"query_fb_name_by_room_path(me->last_pos)")!=-1 &&
		search(user_source,"紧急离开幻境:fb_leave")!=-1 &&
		search(fight_source,"this_object()->command(\"fb_leave\")")!=-1;
	if(valid)
		test_pass();
	else
		test_fail("重登、UI 或逃跑脱困接线缺失");
}

int main()
{
	werror("\n========== 副本实例与脱困安全测试 ==========\n");
	test_runtime_compile_and_reverse_index();
	test_team_instance_identity();
	test_map_filter_and_legacy_redirect();
	test_emergency_leave_and_move_cleanup();
	test_summons_do_not_block_autofight();
	test_relogin_and_ui_safety_wiring();
	werror("副本安全：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
