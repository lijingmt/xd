#!/usr/bin/env pike
/**
 * 普通/VIP分级封顶与九霄界境终局地图回归测试。
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
	werror("\n[千级地图 %d] %s\n",test_results["total"],name);
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

object create_player(string player_name,int player_level,string race_id)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(player_name);
	player->name_cn = "千级地图测试角色";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId("fangshi");
	player->setup_player(race_id,"fangshi");
	player->level = player_level;
	player->set_att_by_level();
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

void test_level_cap_runtime()
{
	test_start("普通120级、VIP1-8每级加20级且过期保级停经验");
	object|zero player = 0;
	string error_desc = "";
	int granted = -1;
	int valid = 0;
	mapping(int:int) expected_limits = ([
		0:120,
		1:140,
		2:160,
		3:180,
		4:300,
		5:300,
		6:300,
		7:300,
		8:300,
	]);
	mixed err = catch {
		player = create_player(
			"__testunit_vip_level_cap__",119,"third");
		player->current_exp = player->query_need_exp();
		player->query_if_levelup();
		valid = NORMAL_MAX_LEVEL==120 &&
			VIP_LEVEL_LIMIT_STEP==20 &&
			VIP_MAX_LEVEL==8 && MAX_LEVEL==1000 &&
			MUD_ROOMD->query_max_level()==1000 &&
			ENDGAME_MAP_MIN_LEVEL==990 &&
			player->query_level()==120 &&
			player->query_levelFlag()==1;
		granted = player->add_exp_with_bonus(1000);
		player->query_if_levelup();
		valid = valid && granted==0 && player->query_level()==120 &&
			player->current_exp==0 &&
			player->query_levelFlag()==0;

		for(int vip_level=0;vip_level<=VIP_MAX_LEVEL;vip_level++){
			player->set_vip_flag(vip_level);
			player->set_vip_end_time(vip_level>0 ? time()+3600 : 0);
			int level_limit = VIPD->query_player_level_limit(player);
			valid = valid && level_limit==expected_limits[vip_level] &&
				VIPD->query_vip_level_limit(vip_level)==
				expected_limits[vip_level];
			if(vip_level>0){
				player->level = level_limit-1;
				player->current_exp = player->query_need_exp();
				player->query_if_levelup();
				valid = valid && player->query_level()==level_limit &&
					player->query_levelFlag()==1;
				granted = player->add_exp_with_bonus(1000);
				player->query_if_levelup();
				valid = valid && granted==0 &&
					player->query_level()==level_limit &&
					player->current_exp==0;
			}
		}

		player->level = 180;
		player->set_vip_flag(3);
		player->set_vip_end_time(time()-10);
		granted = player->add_exp_with_bonus(1000);
		player->query_if_levelup();
		valid = valid && granted==0 && player->query_level()==180 &&
			player->query_vip_flag()==0 &&
			VIPD->query_player_level_limit(player)==120;

		player->level = 1001;
		player->query_if_levelup();
		valid = valid && player->query_level()<=1000 &&
			search(VIPD->get_level_limit_des(player),"重新开通后")!=-1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf(
			"封顶异常: granted=%d level=%d current=%d vip=%d limit=%d %s",
			granted,player ? player->query_level() : 0,
			player ? player->current_exp : -1,
			player ? player->query_vip_flag() : -1,
			player ? VIPD->query_player_level_limit(player) : -1,
			error_desc));
	destroy_player(player);
}

void test_vip_guidance_runtime()
{
	test_start("等级状态、会员购买和玉石不足入口完整接线");
	object|zero player = 0;
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player = create_player(
			"__testunit_vip_guidance__",120,"third");
		string desc = VIPD->get_level_limit_des(player);
		string actions = VIPD->get_level_limit_action_links(player);
		mapping normal_status = HTTP_APID->query_player_state(player);
		player->set_vip_flag(2);
		player->set_vip_end_time(time()+3600);
		player->level = 150;
		mapping vip_status = HTTP_APID->query_player_state(player);
		string app_list = Stdio.read_file(ROOT+
			"/gamelib/cmds/vip_service_app_list.pike") || "";
		string app_confirm = Stdio.read_file(ROOT+
			"/gamelib/cmds/vip_service_app_confirm.pike") || "";
		string upgrade_confirm = Stdio.read_file(ROOT+
			"/gamelib/cmds/vip_service_upgrade_confirm.pike") || "";
		string renderer = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/html_renderer.pike") || "";
		string vue = Stdio.read_file(ROOT+"/vue_source/index.html") || "";
		valid = search(desc,"普通玩家上限120级")!=-1 &&
			search(desc,"每提高一级有效VIP")!=-1 &&
			search(actions,"vip_service_app_list")!=-1 &&
			search(actions,"add_szx_fee")!=-1 &&
			normal_status["level_limit"]==120 &&
			normal_status["level_can_progress"]==0 &&
			normal_status["level_breakthrough_state"]=="blocked" &&
			vip_status["vip_level"]==2 &&
			vip_status["level_limit"]==160 &&
			vip_status["level_can_progress"]==1 &&
			vip_status["level_breakthrough_state"]=="active" &&
			search(app_list,"query_vip_level_limit(i)")!=-1 &&
			search(app_confirm,"level>VIP_MAX_LEVEL")!=-1 &&
			search(app_confirm,"捐赠获取仙玉")!=-1 &&
			search(upgrade_confirm,"vip_cost_map[level]")!=-1 &&
			search(renderer,"level_breakthrough_label")!=-1 &&
			search(vue,"level-cap-badge")!=-1 &&
			search(vue,"vip_service_list")!=-1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("会员引导或安全校验缺失: "+error_desc);
	destroy_player(player);
}

void test_map_and_npc_runtime()
{
	test_start("五张九霄地图、循环出口和五类999级怪物均可加载");
	array(string) rooms = ({
		"jiuxiaojiejing/jiuxiaotianmen",
		"jiuxiaojiejing/xinghedu",
		"jiuxiaojiejing/wuxiangyuntai",
		"jiuxiaojiejing/tianleijie",
		"jiuxiaojiejing/wanxiangguixu",
	});
	array(string) npcs = ({
		"999xingheling",
		"999yuntianjiang",
		"999leijieshou",
		"999xuwujuling",
		"999guixushenwei",
	});
	mapping(string:array(string)) expected_exits = ([
		"jiuxiaotianmen":({"xinghedu","wuxiangyuntai"}),
		"xinghedu":({"jiuxiaotianmen","tianleijie"}),
		"wuxiangyuntai":({"jiuxiaotianmen","wanxiangguixu"}),
		"tianleijie":({"xinghedu","wanxiangguixu"}),
		"wanxiangguixu":({"wuxiangyuntai","tianleijie"}),
	]);
	string catalog = Stdio.read_file(DATA_ROOT+"room_level.log");
	string error_desc = "";
	int failed = 0;
	if(!catalog)
		catalog = "";
	for(int i=0;i<sizeof(rooms);i++){
		mixed err = catch {
			object room = (object)(ROOT+"/gamelib/d/"+rooms[i]);
			array(string) path_parts = rooms[i]/"/";
			string room_id = path_parts[sizeof(path_parts)-1];
			array(string) exits = values(room->exits);
			int npc_count = 0;
			foreach(all_inventory(room),object item){
				if(item->is("npc"))
					npc_count++;
			}
			if(!room || room->query_name_cn()=="" || npc_count<3 ||
			   search(catalog,"jiuxiaojiejing/"+room_id)==-1)
				failed++;
			foreach(expected_exits[room_id],string neighbor){
				int found = 0;
				foreach(exits,string destination){
					if(has_suffix(destination,"/jiuxiaojiejing/"+neighbor))
						found = 1;
				}
				if(!found)
					failed++;
			}
		};
		if(err){
			failed++;
			error_desc += rooms[i]+": "+describe_error(err);
		}
	}
	for(int i=0;i<sizeof(npcs);i++){
		object|zero npc = 0;
		mixed err = catch {
			npc = new(ROOT+
				"/gamelib/clone/npc/jiuxiaojiejing/"+npcs[i]);
			if(!npc || npc->query_level()!=999 ||
			   npc->query_raceId()!="third")
				failed++;
		};
		if(err){
			failed++;
			error_desc += npcs[i]+": "+describe_error(err);
		}
		if(npc)
			destruct(npc);
	}
	if(failed==0)
		test_pass();
	else
		test_fail("地图、出口、刷新或目录失败="+failed+": "+
			error_desc);
}

void test_endgame_dynamic_level_runtime()
{
	test_start("终局动态怪精确匹配999级并在1000级封顶");
	object|zero player = 0;
	object|zero npc_999 = 0;
	object|zero npc_1000 = 0;
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player = create_player(
			"__testunit_endgame_dynamic__",999,"third");
		set_this_player(player);
		npc_999 = MUD_ROOMD->get_npc_level(
			"/gamelib/clone/npc/jiuxiaojiejing/999leijieshou",999);
		player->level = 1000;
		player->set_att_by_level();
		npc_1000 = MUD_ROOMD->get_npc_level(
			"/gamelib/clone/npc/jiuxiaojiejing/999leijieshou",1000);
		valid = npc_999 && npc_999->query_level()==999 &&
			npc_1000 && npc_1000->query_level()==1000;
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
		test_fail(sprintf("动态等级错误: %d/%d %s",
			npc_999 ? npc_999->query_level() : 0,
			npc_1000 ? npc_1000->query_level() : 0,error_desc));
	if(npc_999)
		destruct(npc_999);
	if(npc_1000)
		destruct(npc_1000);
	destroy_player(player);
}

void test_entry_and_autofight_route_runtime()
{
	test_start("990级入口门槛、三阵营直飞和挂机路线一致");
	object|zero low_player = 0;
	object|zero high_player = 0;
	object|zero original_player = this_player();
	object start_room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object command_ob = (object)(ROOT+"/gamelib/cmds/qge74hye.pike");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	array(string) races = ({"human","monst","third"});
	string error_desc = "";
	int failed = 0;
	mixed err = catch {
		low_player = create_player(
			"__testunit_endgame_gate_low__",989,"third");
		low_player->move(start_room);
		set_this_player(low_player);
		command_ob->main("jiuxiaojiejing/jiuxiaotianmen");
		if(environment(low_player)!=start_room)
			failed++;

		for(int i=0;i<sizeof(races);i++){
			high_player = create_player(
				"__testunit_endgame_route_"+races[i]+"__",
				999,races[i]);
			mapping route = daemon->query_training_route(high_player);
			mapping window = daemon->query_target_level_window(high_player);
			if(route["path"]!="jiuxiaojiejing/jiuxiaotianmen" ||
			   route["level"]!=999 || route["max"]!=1000 ||
			   window["minimum"]!=995 || window["maximum"]!=999)
				failed++;
			destroy_player(high_player);
			high_player = 0;
		}

		high_player = create_player(
			"__testunit_endgame_gate_high__",990,"third");
		high_player->move(start_room);
		set_this_player(high_player);
		command_ob->main("jiuxiaojiejing/jiuxiaotianmen");
		if(!environment(high_player) ||
		   !has_suffix((file_name(environment(high_player))/"#")[0],
			"/gamelib/d/jiuxiaojiejing/jiuxiaotianmen"))
			failed++;
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(!err && failed==0)
		test_pass();
	else
		test_fail("入口或挂机路线失败="+failed+": "+error_desc);
	destroy_player(low_player);
	destroy_player(high_player);
}

void test_frontend_map_catalog_runtime()
{
	test_start("前端地图显示九霄界境且低等级不会误扣传送费");
	object|zero low_player = 0;
	object|zero high_player = 0;
	object|zero original_player = this_player();
	object map_daemon = (object)(ROOT+
		"/gamelib/single/daemons/mapd.pike");
	object map_command = (object)(ROOT+
		"/gamelib/cmds/map_display.pike");
	string low_catalog = "";
	string high_catalog = "";
	string sub_maps = "";
	string error_desc = "";
	int money_before = 0;
	int valid = 0;
	mixed err = catch {
		low_player = create_player(
			"__testunit_endgame_map_low__",989,"third");
		low_player->set_account(20000000);
		set_this_player(low_player);
		low_catalog = map_daemon->get_all_kinds_map();
		money_before = low_player->query_account();
		map_command->main("jiuxiaojiejing 10000000");
		valid = search(low_catalog,"九霄界境（990级开放）")!=-1 &&
			search(low_catalog,"map_display jiuxiaojiejing")==-1 &&
			low_player->query_account()==money_before;

		high_player = create_player(
			"__testunit_endgame_map_high__",990,"third");
		set_this_player(high_player);
		high_catalog = map_daemon->get_all_kinds_map();
		sub_maps = map_daemon->get_sub_map_list("jiuxiaojiejing");
		valid = valid &&
			search(high_catalog,"飞到 九霄界境")!=-1 &&
			search(high_catalog,"map_display jiuxiaojiejing")!=-1 &&
			search(sub_maps,
				"qge74hye jiuxiaojiejing/jiuxiaotianmen")!=-1 &&
			search(sub_maps,"飞到：万象归墟")!=-1;
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
		test_fail("地图分类、等级门槛或扣费保护失败: "+error_desc);
	destroy_player(low_player);
	destroy_player(high_player);
}

int main()
{
	werror("\n========== 千级封顶与九霄界境测试 ==========\n");
	test_level_cap_runtime();
	test_vip_guidance_runtime();
	test_map_and_npc_runtime();
	test_endgame_dynamic_level_runtime();
	test_entry_and_autofight_route_runtime();
	test_frontend_map_catalog_runtime();
	werror("千级地图：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
