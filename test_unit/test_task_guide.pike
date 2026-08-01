#!/usr/bin/env pike
/**
 * 任务引导真实测试：
 * - 9级方士每级历练可一键飞往有效练级房间
 * - 方士普通任务按下一个未完成目标引导
 * - 冥府、蛟龙任务只到副本外入口
 * - 无任务或伪造参数不能控制目的地
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
	werror("\n[任务引导 %d] %s\n",test_results["total"],name);
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

object create_player(string name,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "任务引导测试方士";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = level;
	player->set_att_by_level();
	return player;
}

object create_profession_player(string name,string race_id,
	string profession_id,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "老职业任务引导测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->level = level;
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

void test_growth_guide_real_teleport()
{
	test_start("九级方士领取每级历练后真实飞往有效练级房间");
	object player =
		create_player("__testunit_task_guide_growth__",9);
	object command =
		(object)(ROOT+"/gamelib/cmds/task_guide.pike");
	object start_room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object original_player = this_player();
	mapping target = ([]);
	string destination = "";
	int accepted = 0;
	int valid_npc = 0;
	string error_desc = "";

	mixed err = catch {
		player->move(start_room);
		accepted = TASKD->accept_growth_task(player);
		target = TASKD->queryGrowthTaskGuideTarget(player);
		set_this_player(player);
		command->main("growth");
		destination = file_name(environment(player));
		foreach(all_inventory(environment(player)),object ob){
			if(ob->is("npc") &&
			   ob->query_level()>=4 &&
			   ob->query_level()<=14)
				valid_npc = 1;
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && accepted==1 &&
	   target["path"]=="kunlunshan/pubudongxuesiceng" &&
	   search(destination,
		"/gamelib/d/kunlunshan/pubudongxuesiceng")!=-1 &&
	   valid_npc)
		test_pass();
	else
		test_fail(sprintf(
			"领取=%d 目标=%O 到达=%O 有效怪=%d: %s",
			accepted,target,destination,valid_npc,error_desc));
	destroy_player(player);
}

void test_growth_guide_static_dynamic_boundaries()
{
	test_start("20至69级固定成长区与70级动态区引导边界正确");
	array(mapping(string:mixed)) cases = ({
		(["level":20,
			"path":"shierxianjing/taoyuantongshijiuceng"]),
		(["level":50,"path":"liuguangpingyuan/liuguangchalu"]),
		(["level":58,"path":"plxianjing/binghuanyuntai"]),
		(["level":59,"path":"penglaihuanjing/yunyepingyuan"]),
		(["level":69,"path":"klshuanjingwaicheng/heishandong"]),
		(["level":70,"path":"plxianjing/binghuanyuntai"]),
	});
	string error_desc = "";
	int valid = 1;
	int number = 0;
	foreach(cases,mapping(string:mixed) one){
		number++;
		object player = create_player("__testunit_growth_boundary_"+
			number+"__",(int)one["level"]);
		mixed err = catch {
			int accepted = TASKD->accept_growth_task(player);
			mapping target = TASKD->queryGrowthTaskGuideTarget(player);
			valid = valid && accepted == 1 &&
				target["path"] == one["path"] &&
				Stdio.exist(ROOT+"/gamelib/d/"+(string)one["path"]);
		};
		if(err){
			valid = 0;
			error_desc += one["level"]+": "+describe_error(err);
		}
		destroy_player(player);
	}
	if(valid)
		test_pass();
	else
		test_fail("固定/动态成长任务引导边界错误: "+error_desc);
}

void test_fangshi_next_target_and_dungeon_entrance()
{
	test_start("方士任务按未完成目标引导且不直飞副本内部");
	object level_twenty =
		create_player("__testunit_task_guide_twenty__",20);
	object level_fifty_three =
		create_player("__testunit_task_guide_fifty_three__",53);
	object teacher = clone(
		ROOT+"/gamelib/clone/npc/fangshi_teacher");
	mapping first_target = ([]);
	mapping second_target = ([]);
	mapping mingfu_target = ([]);
	mapping jiaolong_target = ([]);
	int accepted_twenty = 0;
	int accepted_mingfu = 0;
	int accepted_jiaolong = 0;
	string error_desc = "";

	mixed err = catch {
		accepted_twenty =
			TASKD->get_task(level_twenty,364,teacher);
		first_target =
			TASKD->queryTaskGuideTarget(level_twenty,364);
		level_twenty["/taskd/kill"][364]["清云兽"] = 3;
		second_target =
			TASKD->queryTaskGuideTarget(level_twenty,364);

		level_fifty_three["/taskd/done"] = ([365:1]);
		accepted_mingfu =
			TASKD->get_task(level_fifty_three,366,teacher);
		mingfu_target =
			TASKD->queryTaskGuideTarget(level_fifty_three,366);
		level_fifty_three["/taskd/done"][366] = 1;
		accepted_jiaolong =
			TASKD->get_task(level_fifty_three,367,teacher);
		jiaolong_target =
			TASKD->queryTaskGuideTarget(level_fifty_three,367);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && accepted_twenty==1 &&
	   first_target["target"]=="清云兽所在地图" &&
	   first_target["path"]=="shierxianjing/shierxianjing" &&
	   second_target["target"]=="灵龟所在地图" &&
	   accepted_mingfu==1 &&
	   mingfu_target["path"]==
		"jiangjunmu/dajiangjunlingershiceng" &&
	   search(mingfu_target["path"],"mf/")==-1 &&
	   accepted_jiaolong==1 &&
	   jiaolong_target["path"]=="muye/huanghean" &&
	   search(jiaolong_target["path"],"jiaolong/")==-1)
		test_pass();
	else
		test_fail(sprintf(
			"20=%d %O/%O 冥府=%d %O 蛟龙=%d %O: %s",
			accepted_twenty,first_target,second_target,
			accepted_mingfu,mingfu_target,
			accepted_jiaolong,jiaolong_target,error_desc));
	if(teacher)
		destruct(teacher);
	destroy_player(level_twenty);
	destroy_player(level_fifty_three);
}

void test_old_profession_task_guide_parity()
{
	test_start("六个老职业53级四段任务均有安全地图引导");
	mapping(string:array(mixed)) professions = ([
		"jianxian":({"human",253,"plxianjing/yuyixian400"}),
		"yushi":({"human",257,"plxianjing/yuyixian400"}),
		"zhuxian":({"human",261,"plxianjing/yuyixian400"}),
		"kuangyao":({"monst",265,"plxianjin/yuyuan400"}),
		"wuyao":({"monst",269,"plxianjin/yuyuan400"}),
		"yinggui":({"monst",273,"plxianjin/yuyuan400"}),
	]);
	array(string) human_paths = ({
		"plxianjing/xianzhenplxianjing",
		"jiangjunmu/dajiangjunlingershiceng",
		"muye/huanghean",
		"plxianjing/xianzhenplxianjing",
	});
	array(string) monster_paths = ({
		"plxianjing/xianzhenplxianjing",
		"fushoushan/dijiaoershiceng",
		"muye/huanghean",
		"plxianjing/xianzhenplxianjing",
	});
	int checked = 0;
	int failed = 0;
	string failure_details = "";
	string error_desc = "";

	mixed err = catch {
		foreach(sort(indices(professions)),string profession_id){
			array(mixed) config = professions[profession_id];
			string race_id = (string)config[0];
			int first_task = (int)config[1];
			object player = create_profession_player(
				"__testunit_task_guide_"+profession_id+"__",
				race_id,profession_id,53);
			object mentor = clone(
				ROOT+"/gamelib/clone/npc/"+(string)config[2]);
			array(string) expected_paths =
				race_id=="human" ? human_paths : monster_paths;
			player["/taskd/done"] = ([]);
			for(int offset=0;offset<4;offset++){
				int taskid = first_task+offset;
				if(offset)
					player["/taskd/done"][taskid-1] = 1;
				int accepted =
					TASKD->get_task(player,taskid,mentor);
				mapping target =
					TASKD->queryTaskGuideTarget(player,taskid);
				if((accepted==1 || accepted==5) &&
				   TASKD->queryTaskHasGuide(taskid) &&
				   target["path"]==expected_paths[offset] &&
				   search(target["path"],"mf/")==-1 &&
				   search(target["path"],"jiaolong/")==-1 &&
				   search(target["path"],"dwgy/")==-1)
					checked++;
				else{
					failed++;
					failure_details += sprintf(
						"%s/%d accept=%d has=%d target=%O expected=%s; ",
						profession_id,taskid,accepted,
						TASKD->queryTaskHasGuide(taskid),
						target,expected_paths[offset]);
				}
			}
			if(mentor)
				destruct(mentor);
			destroy_player(player);
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && checked==24 && failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"检查=%d/24 失败=%d %s: %s",
			checked,failed,failure_details,error_desc));
}

void test_combined_accept_and_forged_argument()
{
	test_start("接受并前往按钮有效且伪造任务编号不能改变目的地");
	object player =
		create_player("__testunit_task_guide_combined__",20);
	object command =
		(object)(ROOT+"/gamelib/cmds/task_guide.pike");
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object teacher = clone(
		ROOT+"/gamelib/clone/npc/fangshi_teacher");
	object original_player = this_player();
	string accepted_destination = "";
	string forged_before = "";
	string forged_after = "";
	int active = 0;
	string error_desc = "";

	mixed err = catch {
		player->move(room);
		teacher->move(room);
		set_this_player(player);
		command->main("accept "+teacher->query_name()+" 364");
		accepted_destination = file_name(environment(player));
		active = mappingp(player["/taskd/Cont"][364]);
		forged_before = file_name(environment(player));
		command->main("999999");
		forged_after = file_name(environment(player));
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && active &&
	   search(accepted_destination,
		"/gamelib/d/shierxianjing/shierxianjing")!=-1 &&
	   forged_before==forged_after)
		test_pass();
	else
		test_fail(sprintf(
			"active=%d 到达=%O 伪造前后=%O/%O: %s",
			active,accepted_destination,
			forged_before,forged_after,error_desc));
	if(teacher)
		destruct(teacher);
	destroy_player(player);
}

void test_ui_and_http_wiring()
{
	test_start("任务详情、任务列表和HTTP核心锁均接入引导");
	object player =
		create_player("__testunit_task_guide_ui__",9);
	string growth_page = TASKD->queryGrowthTaskPage(player);
	string accept_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/char_task_accept.pike");
	string refer_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/view_mytask.pike");
	string task_accept_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/task_accept.pike");
	string thread_one = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string thread_two = Stdio.read_file(
		ROOT+"/gamelib/single/d/http_api/thread_manager.pike");

	if(search(growth_page,
		"[领取并前往任务地图:task_guide growth_accept]")!=-1 &&
	   accept_source &&
	   search(accept_source,
		"[接受并前往任务地图:task_guide accept ")!=-1 &&
	   refer_source &&
	   search(refer_source,"queryTaskGuideLink")!=-1 &&
	   task_accept_source &&
	   search(task_accept_source,"queryTaskGuideLink")!=-1 &&
	   thread_one && search(thread_one,"\"task_guide\"")!=-1 &&
	   thread_two && search(thread_two,
		"../../daemons/_http_api_mod/thread_manager.pike")!=-1)
		test_pass();
	else
		test_fail("任务引导按钮或HTTP核心命令接线不完整");
	destroy_player(player);
}

int main(int argc,array(string) argv)
{
	werror("\n╔════════════════════════════════════════════════╗\n");
	werror("║              任务引导完整测试                ║\n");
	werror("╚════════════════════════════════════════════════╝\n");

	test_growth_guide_real_teleport();
	test_growth_guide_static_dynamic_boundaries();
	test_fangshi_next_target_and_dungeon_entrance();
	test_old_profession_task_guide_parity();
	test_combined_accept_and_forged_argument();
	test_ui_and_http_wiring();

	werror("\n任务引导测试：%d通过，%d失败\n",
		test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
