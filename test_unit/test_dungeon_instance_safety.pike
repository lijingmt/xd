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
		"/gamelib/cmds/fb_fly.pike",
		"/gamelib/cmds/qge74hye.pike",
		"/gamelib/cmds/fb_entry.pike",
		"/gamelib/cmds/fb_leave.pike",
		"/gamelib/d/fb_runtime/ingress.pike",
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

void test_worker_ingress_affinity_and_direct_entry()
{
	test_start("幻境按队伍汇聚唯一 Worker 且单进程入口保持直达");
	object map_daemon=(object)(ROOT+
		"/gamelib/single/daemons/map_workerd.pike");
	object command_ob=(object)(ROOT+"/gamelib/cmds/fb_entry.pike");
	object player=create_player(
		"__testunit_fb_worker_ingress__",70,"human","jianxian");
	object start_room=(object)(ROOT+
		"/gamelib/d/xiqicheng/tiechuangxiang");
	object|zero original_player=this_player();
	string team_id="";
	string error_desc="";
	int valid=0;
	mixed err=catch {
		string fb_id_a="__testunit_team_a__/lingranzhiyan_h";
		string fb_id_b="__testunit_team_b__/lingranzhiyan_h";
		string ingress_affinity=map_daemon->query_affinity_key(
			"/gamelib/d/fb_runtime/ingress.pike",fb_id_a);
		string clone_affinity=map_daemon->query_affinity_key(
			"/gamelib/d/xinnian_fb/lingranzhiyan_h#42",fb_id_a);
		string other_affinity=map_daemon->query_affinity_key(
			"/gamelib/d/xinnian_fb/lingranzhiyan_h#7",fb_id_b);
		player->move(start_room);
		team_id=TERMD->term_create(player->query_name());
		set_this_player(player);
		command_ob->main("lingranzhiyan_h 0 0");
		valid=ingress_affinity==clone_affinity &&
			ingress_affinity!=other_affinity &&
			has_prefix(ingress_affinity,"fb_runtime:") &&
			environment(player) &&
			FBD->is_fb_room_path(file_name(environment(player))) &&
			(string)player->fb_id==team_id+"/lingranzhiyan_h" &&
			FBD->query_fb_memebers(player->fb_id,player->query_name());
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc=describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("Worker亲和或旧模式直达失败: "+error_desc);
	if(player && player->fb_id)
		FBD->detach_fb_member(player);
	if(team_id!="" && TERMD->query_termId(team_id))
		TERMD->destory_term(team_id,player->query_name());
	destroy_player(player);
}

void test_safe_dungeon_fly_catalog()
{
	test_start("幻境按钮只飞公共入口且费用完全由服务端计算");
	object command_ob = (object)(ROOT+"/gamelib/cmds/fb_fly.pike");
	string map_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/map_display.pike");
	object player = create_player(
		"__testunit_fb_safe_fly__",86,"human","jianxian");
	object start_room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero original_player = this_player();
	mapping entry = FBD->query_safe_fb_entrance("bawangmoku");
	array(mapping(string:string)) catalog = FBD->query_safe_fb_catalog();
	string current_path = "";
	string error_desc = "";
	int fee = MAPD->query_player_fly_fee(player);
	int before;
	int valid = 0;
	mixed err = catch {
		player->move(start_room);
		player->set_account(fee+5000);
		before = player->query_account();
		set_this_player(player);
		command_ob->main("../bwmk/mowangchaoxue");
		int rejected_uncharged = player->query_account()==before &&
			environment(player)==start_room;
		command_ob->main("bawangmoku");
		if(environment(player))
			current_path = (file_name(environment(player))/"#")[0];
		valid = sizeof(entry)>0 && sizeof(catalog)>=1 &&
			rejected_uncharged && player->query_account()==before-fee &&
			has_suffix(current_path,"/gamelib/d/bawangbao/zhuzunge") &&
			!FBD->is_fb_room_path(current_path) && !player->fb_id &&
			map_source &&
			search(map_source,
				"fee = MAPD->query_player_fly_fee(me)")!=-1;
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
		test_fail("安全直达验证失败: "+error_desc);
	destroy_player(player);
}

void test_flight_fee_progression()
{
	test_start("飞行金币按等级平滑增长且70级会员折扣明确");
	object player=create_player(
		"__testunit_flight_fee__",1,"human","jianxian");
	array(int) levels=({0,9,10,19,20,49,50,69,70,99,100,149,
		150,199,200,999});
	array(int) fees=({100,100,1000,1000,2000,2000,5000,5000,
		20000,20000,50000,50000,100000,100000,200000,200000});
	array(int) vip70=({20000,15000,10000,7500,5000,5000,5000,5000,
		5000});
	int valid=1;
	string error_desc="";
	mixed err=catch {
		for(int index=0;index<sizeof(levels);index++){
			player->level=levels[index];
			player->set_vip_flag(0);
			if(MAPD->query_player_fly_fee(player)!=fees[index])
				valid=0;
		}
		player->level=70;
		for(int vip=0;vip<=8;vip++){
			player->set_vip_flag(vip);
			if(MAPD->query_player_fly_fee(player)!=vip70[vip])
				valid=0;
		}
	};
	if(err)
		error_desc=describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("等级边界、70级费用或VIP折扣错误: "+error_desc);
	destroy_player(player);
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

void test_fixed_year_beast_levels_after_high_level_entry()
{
	test_start("高等级玩家进入前先登记成员，前两层年兽保持固定10/30级");
	object player=create_player(
		"__testunit_fixed_year_beast__",180,"human","jianxian");
	object|zero original_player=this_player();
	array(string) rooms=({"lingranzhiyan_h","hunfeizhijing_h"});
	array(int) expected=({10,30});
	array(string) fb_ids=({});
	string error_desc="";
	int valid=1;
	mixed err=catch {
		set_this_player(player);
		for(int i=0;i<sizeof(rooms);i++){
			string team_id="__testunit_fixed_year_beast_"+i+"__";
			string fb_id=team_id+"/"+rooms[i];
			player->fb_id=fb_id;
			FBD->add_fb_members(fb_id,player->query_name());
			fb_ids+=({fb_id});
			object room=FBD->query_fb_room(rooms[i],0,team_id,0);
			array(object) npcs=room ? filter(all_inventory(room),
				lambda(object ob){ return ob && ob->is("npc"); }) : ({});
			if(!room || sizeof(npcs)!=1 || npcs[0]->query_level()!=expected[i])
				valid=0;
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc=describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("固定年兽等级被动态缩放: "+error_desc);
	foreach(fb_ids,string fb_id)
		FBD->delete_fb_members(fb_id,player->query_name());
	FBD->flush_fb_map();
	destroy_player(player);
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

void test_fbd_cleanup_survives_missing_member_state()
{
	test_start("副本成员表缺失时清理链不中断且空实例可回收");
	program daemon_program = (program)(ROOT+
		"/gamelib/single/daemons/fbd.pike");
	object daemon = daemon_program();
	object|zero room = 0;
	string error_desc = "";
	int valid = 0;
	int created = 0;
	string daemon_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/fbd.pike");
	mixed err = catch {
		room = daemon->query_fb_room("lingranzhiyan_h",0,
			"__testunit_missing_members__",0);
		created = room ? 1 : 0;
		// query_fb_room deliberately creates no fb_members entry here.
		daemon->flush_fb_map();
		valid = created && daemon_source &&
			search(daemon->check_fb(),
				"__testunit_missing_members__/lingranzhiyan_h")==-1 &&
			search(daemon_source,
				"catch { flush_one_fb_map(fb_id); }")!=-1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("缺失成员表仍会终止清理: "+error_desc);
	if(daemon)
		destruct(daemon);
}

int main()
{
	werror("\n========== 副本实例与脱困安全测试 ==========\n");
	test_runtime_compile_and_reverse_index();
	test_worker_ingress_affinity_and_direct_entry();
	test_team_instance_identity();
	test_fixed_year_beast_levels_after_high_level_entry();
	test_map_filter_and_legacy_redirect();
	test_safe_dungeon_fly_catalog();
	test_flight_fee_progression();
	test_emergency_leave_and_move_cleanup();
	test_summons_do_not_block_autofight();
	test_relogin_and_ui_safety_wiring();
	test_fbd_cleanup_survives_missing_member_state();
	werror("副本安全：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
