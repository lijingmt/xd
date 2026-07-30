#!/usr/bin/env pike
/**
 * 新手引导测试：
 * 真实动作推进、七职业分支、一次性奖励、装备状态与成长路线。
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
	werror("\n[新手引导 %d] %s\n",test_results["total"],name);
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
	player->name_cn = "引导测试方士";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = level;
	player->set_att_by_level();
	player->skills["lingdanshu"] = ({1,0});
	player["/tmp/newbie_tutorial/disable_auto"] = 1;
	return player;
}

object create_profession_player(string name,string profession,int level)
{
	mapping(string:string) races = ([
		"jianxian":"human",
		"yushi":"human",
		"zhuxian":"human",
		"kuangyao":"monst",
		"wuyao":"monst",
		"yinggui":"monst",
		"fangshi":"third",
	]);
	mapping(string:string) starters = ([
		"jianxian":"qieyunzhan",
		"yushi":"yinghuozhou",
		"zhuxian":"suixinjue",
		"kuangyao":"silie",
		"wuyao":"wudushu",
		"yinggui":"fuji",
		"fangshi":"lingdanshu",
	]);
	object player = clone(GAMELIB_USER);
	string race = races[profession];

	if(!player || !race)
		return 0;
	player->set_name(name);
	player->name_cn = "七职业引导测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level = level;
	player->set_att_by_level();
	player->skills[starters[profession]] = ({1,0});
	player["/tmp/newbie_tutorial/disable_auto"] = 1;
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

void test_real_equipment_state()
{
	test_start("引导根据真实穿戴状态判断，不靠点击完成");
	object player = create_player("__testunit_guide_equip__",1);
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object assistant = (object)(ROOT+"/gamelib/cmds/auto_equip.pike");
	array(string) paths = ({
		"/gamelib/clone/item/weapon/1taomujian/1taomujian",
		"/gamelib/clone/item/armor/2caoxie/2caoxie",
		"/gamelib/clone/item/armor/2cubuchangku/2cubuchangku",
		"/gamelib/clone/item/armor/2cubuyi/2cubuyi",
	});
	string before = guide->render_guide(player);
	foreach(paths,string path){
		object item = clone(ROOT+path);
		if(item)
			item->move(player);
	}
	assistant->auto_equip_player(player);
	string after = guide->render_guide(player);

	if(guide->query_equipped_count(player)==4 &&
	   search(before,"还有基础空位")!=-1 &&
	   search(after,"基础武器和防具已经穿好")!=-1 &&
	   search(after,"只补空位")!=-1)
		test_pass();
	else
		test_fail("引导没有随真实装备状态更新");
	destroy_player(player);
}

void test_fangshi_level_guidance()
{
	test_start("方士1级、8级、24级技能成长提示完整");
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object level_one = create_player("__testunit_guide_l1__",1);
	object level_eight = create_player("__testunit_guide_l8__",8);
	object level_twenty_four =
		create_player("__testunit_guide_l24__",24);
	string one = guide->render_guide(level_one);
	string eight;
	string twenty_four;

	level_eight->skills["lingzhi"] = ({1,0});
	level_twenty_four->skills["lingzhi"] = ({1,0});
	level_twenty_four->skills["linglianpu"] = ({1,0});
	eight = guide->render_guide(level_eight);
	twenty_four = guide->render_guide(level_twenty_four);

	if(search(one,"8级可学习“灵治”")!=-1 &&
	   search(one,"24级解锁“灵莲铺”")!=-1 &&
	   search(eight,"“灵治”治疗自己")!=-1 &&
	   search(twenty_four,"没组队时只治疗自己")!=-1 &&
	   search(twenty_four,"[召唤灵兽:summon]")!=-1)
		test_pass();
	else
		test_fail("等级解锁、单体治疗或组队治疗说明缺失");

	destroy_player(level_one);
	destroy_player(level_eight);
	destroy_player(level_twenty_four);
}

void test_common_growth_and_home_links()
{
	test_start("打怪、掉落、任务、队伍、聊天与家园说明齐全");
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object player = create_player("__testunit_guide_common__",10);
	string output = guide->render_guide(player);
	player->set_home_path("xd/test/test/lei/001");
	string home_output = guide->render_guide(player);

	if(search(output,"怪物会提供经验、金钱和随机装备")!=-1 &&
	   search(output,"[查看地图:map_display]")!=-1 &&
	   search(output,"[查看任务:mytasks]")!=-1 &&
	   search(output,"[队伍:my_term]")!=-1 &&
	   search(output,"[聊天:chatroom_list]")!=-1 &&
	   search(output,"家园系统不限制职业")!=-1 &&
	   search(home_output,
		"[返回家园:home_return xd/test/test/lei/001]")!=-1)
		test_pass();
	else
		test_fail("通用成长或家园入口不完整");
	destroy_player(player);
}

void test_fangshi_advanced_milestones()
{
	test_start("方士30至75级召唤、高级书、隐藏书与职业任务提示完整");
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object level_thirty = create_player("__testunit_guide_l30__",30);
	object level_fifty = create_player("__testunit_guide_l50__",50);
	object level_sixty = create_player("__testunit_guide_l60__",60);
	object level_sixty_five = create_player("__testunit_guide_l65__",65);
	object level_seventy = create_player("__testunit_guide_l70__",70);
	object level_seventy_five = create_player("__testunit_guide_l75__",75);
	string thirty = guide->query_fangshi_growth_guide(level_thirty);
	string fifty;
	string sixty;
	string sixty_five;
	string seventy;
	string seventy_five;

	level_fifty->skills["sanlingheyi"] = ({1,0});
	fifty = guide->query_fangshi_growth_guide(level_fifty);
	sixty = guide->query_fangshi_growth_guide(level_sixty);
	sixty_five = guide->query_fangshi_growth_guide(level_sixty_five);
	seventy = guide->query_fangshi_growth_guide(level_seventy);
	seventy_five = guide->query_fangshi_growth_guide(level_seventy_five);

	if(search(thirty,"30级起可同时保留2只灵兽")!=-1 &&
	   search(fifty,"已掌握“三灵合一”")!=-1 &&
	   search(sixty,"每天为每个职业独立轮换2种")!=-1 &&
	   search(sixty,"[高级技能书:yushi_buy_hlbook_list]")!=-1 &&
	   search(sixty_five,"65级进阶书会替换旧技能")!=-1 &&
	   search(seventy,"实际等级70以上怪物")!=-1 &&
	   search(seventy,"不会出现在任何商店")!=-1 &&
	   search(seventy_five,"75级秘传可强化")!=-1 &&
	   search(seventy_five,"53级四段职业传承")!=-1)
		test_pass();
	else
		test_fail("30/50/60/65/70/75级关键路线仍有缺项");

	destroy_player(level_thirty);
	destroy_player(level_fifty);
	destroy_player(level_sixty);
	destroy_player(level_sixty_five);
	destroy_player(level_seventy);
	destroy_player(level_seventy_five);
}

void test_creation_and_ui_wiring()
{
	test_start("建角提示与新手快捷入口已经接线");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	program|zero guide_program = 0;
	mixed err = catch {
		guide_program =
			(program)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	};

	if(!err && guide_program && init_source && user_source &&
	   search(init_source,
		"[查看新手引导:newbie_guide]")!=-1 &&
	   search(user_source,
		"[新手引导:newbie_guide]|[自动穿装:auto_equip]")!=-1)
		test_pass();
	else
		test_fail("建角或常驻新手入口没有完整接线");
}

void test_check_cannot_fake_progress()
{
	test_start("重复点击检查不能伪造真实动作或重复领奖");
	object player = create_player("__testunit_guide_check__",1);
	mapping first = NEWBIED->claim_current_step(player);
	int before_money = player->query_account();
	int before_step = NEWBIED->query_step(player);
	mapping second;
	mapping third;
	int after_money;

	NEWBIED->record_action(player,"status");
	second = NEWBIED->claim_current_step(player);
	after_money = player->query_account();
	third = NEWBIED->claim_current_step(player);

	if(first["code"]==1 && before_step==1 &&
	   second["code"]==2 && NEWBIED->query_step(player)==2 &&
	   after_money==before_money+100 &&
	   third["code"]==1 && player->query_account()==after_money)
		test_pass();
	else
		test_fail("检查按钮推进了未完成步骤或重复发放奖励");
	destroy_player(player);
}

void test_automatic_completion_popup_queue()
{
	test_start("真实动作自动结算、弹窗入队且重复动作不重复领奖");
	object player = create_player("__testunit_guide_auto__",1);
	int before_money = player->query_account();
	array(mapping) first_queue;
	array(mapping) duplicate_queue;

	player["/tmp/newbie_tutorial/disable_auto"] = 0;
	player->is_http_api_user = 1;
	NEWBIED->record_action(player,"status");
	first_queue = NEWBIED->consume_completion_notices(player);
	NEWBIED->record_action(player,"status");
	duplicate_queue = NEWBIED->consume_completion_notices(player);

	if(NEWBIED->query_step(player)==2 &&
	   player->query_account()==before_money+100 &&
	   sizeof(first_queue)==1 &&
	   first_queue[0]["code"]==2 &&
	   first_queue[0]["step"]==1 &&
	   first_queue[0]["total"]==20 &&
	   first_queue[0]["next_action_command"]=="inventory" &&
	   sizeof(duplicate_queue)==0)
		test_pass();
	else
		test_fail("自动推进、结构化弹窗或重复奖励保护没有生效");
	destroy_player(player);
}

void test_completed_growth_task_does_not_block_tutorial()
{
	test_start("已完成本级历练的旧人物不会卡在领取或任务引导步骤");
	object player = create_player("__testunit_guide_growth_done__",9);

	player["/taskd/growth_done"] = ([9:time()]);
	if(NEWBIED->query_step_ready(player,7) &&
	   NEWBIED->query_step_ready(player,8))
		test_pass();
	else
		test_fail("历史上已完成本级历练的人物仍会卡死在第7或第8步");
	destroy_player(player);
}

void test_historical_growth_progress_auto_reconciles()
{
	test_start("历史历练进度可连续自动结算且完成弹窗不会互相覆盖");
	object player = create_player("__testunit_guide_growth_auto__",9);
	object growth_command =
		(object)(ROOT+"/gamelib/cmds/growth_task.pike");
	object|zero original_player = this_player();
	array(mapping) notices;

	player["/plus/newbie_tutorial/step"] = 7;
	player["/taskd/growth_done"] = ([9:time()]);
	player["/tmp/newbie_tutorial/disable_auto"] = 0;
	player->is_http_api_user = 1;
	set_this_player(player);
	growth_command->main("accept");
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	notices = NEWBIED->consume_completion_notices(player);

	if(NEWBIED->query_step(player)==9 &&
	   sizeof(notices)==2 &&
	   notices[0]["step"]==7 &&
	   notices[1]["step"]==8)
		test_pass();
	else
		test_fail("历史进度未自动推进两步，或连续弹窗发生覆盖/丢失");
	destroy_player(player);
}

void test_automatic_graduation_notice()
{
	test_start("最后一步自动毕业并提供职业成长路线且不可重复毕业");
	object player = create_player("__testunit_guide_graduate__",10);
	array(mapping) notices;
	array(mapping) duplicate_notices;

	player["/plus/newbie_tutorial/step"] = 20;
	player->skills["huling"] = ({1,0});
	player["/tmp/newbie_tutorial/disable_auto"] = 0;
	player->is_http_api_user = 1;
	NEWBIED->record_summon(player,"huling");
	notices = NEWBIED->consume_completion_notices(player);
	NEWBIED->record_summon(player,"huling");
	duplicate_notices = NEWBIED->consume_completion_notices(player);

	if(NEWBIED->query_step(player)==21 &&
	   sizeof(notices)==1 &&
	   notices[0]["step"]==20 &&
	   notices[0]["complete"]==1 &&
	   notices[0]["next_action_command"]=="newbie_guide roadmap" &&
	   sizeof(duplicate_notices)==0)
		test_pass();
	else
		test_fail("自动毕业弹窗、成长路线入口或重复毕业保护异常");
	destroy_player(player);
}

void test_seven_profession_branches()
{
	test_start("七职业首本书与职业实战采用各自真实分支");
	array(string) professions = ({
		"jianxian","yushi","zhuxian","kuangyao",
		"wuyao","yinggui","fangshi",
	});
	int all_ok = 1;

	foreach(professions,string profession){
		object player = create_profession_player(
			"__testunit_guide_"+profession+"__",profession,1);
		mapping config = NEWBIED->query_profession_config(player);
		if(!sizeof(config) || config["name"]=="" ||
		   config["starter"]=="" || config["book"]=="" ||
		   config["skill"]=="")
			all_ok = 0;

		player["/plus/newbie_tutorial/step"] = 16;
		NEWBIED->record_book_shop(player,"not_"+profession);
		if(NEWBIED->query_step_ready(player,16))
			all_ok = 0;
		NEWBIED->record_book_shop(player,profession);
		if(!NEWBIED->query_step_ready(player,16))
			all_ok = 0;

		player["/plus/newbie_tutorial/step"] = 18;
		NEWBIED->record_book_purchase(player,"book/not_the_book");
		if(NEWBIED->query_step_ready(player,18))
			all_ok = 0;
		NEWBIED->record_book_purchase(player,config["book"]);
		if(!NEWBIED->query_step_ready(player,18))
			all_ok = 0;

		player->skills[config["skill"]] = ({1,0});
		NEWBIED->record_book_read(player);
		player["/plus/newbie_tutorial/step"] = 19;
		if(!NEWBIED->query_step_ready(player,19))
			all_ok = 0;

		player["/plus/newbie_tutorial/step"] = 20;
		if(config["practice"]=="active")
			NEWBIED->record_perform(player,config["skill"]);
		else if(config["practice"]=="passive")
			NEWBIED->record_kill(player);
		else{
			player->level = 10;
			player->skills["huling"] = ({1,0});
			NEWBIED->record_summon(player,"huling");
		}
		if(!NEWBIED->query_step_ready(player,20))
			all_ok = 0;
		destroy_player(player);
	}

	if(all_ok)
		test_pass();
	else
		test_fail("至少一个职业可被错误书籍绕过，或正确职业动作未通过");
}

void test_book_funds_are_once_only()
{
	test_start("首本职业书资金与碎玉奖励不可重复领取");
	object player = create_player("__testunit_guide_reward__",2);
	int money_before = player->query_account();
	int jade_before = YUSHID->query_all_num(player);
	mapping first;
	mapping replay;
	int money_after;
	int jade_after;

	player["/plus/newbie_tutorial/step"] = 17;
	first = NEWBIED->claim_current_step(player);
	money_after = player->query_account();
	jade_after = YUSHID->query_all_num(player);
	player["/plus/newbie_tutorial/step"] = 17;
	replay = NEWBIED->claim_current_step(player);

	if(first["code"]==2 && replay["code"]==2 &&
	   money_after==money_before+4000 &&
	   jade_after==jade_before+3 &&
	   player->query_account()==money_after &&
	   YUSHID->query_all_num(player)==jade_after)
		test_pass();
	else
		test_fail("方士首本书专项资金数额不对或可重复领取");
	destroy_player(player);
}

void test_real_action_sources_are_wired()
{
	test_start("全部功能步骤由真实命令成功路径写入证据");
	mapping(string:array(string)) checks = ([
		"gamelib/cmds/myhp.pike":({"record_action(me,\"status\")"}),
		"lowlib/wapmud2/cmds/inventory.pike":({"record_action(me,\"inventory\")"}),
		"gamelib/cmds/auto_equip.pike":({"record_action(player,\"auto_equip\")"}),
		"gamelib/cmds/myskills.pike":({"record_action(this_player(),\"skills\")"}),
		"gamelib/cmds/map_display.pike":({"record_action(me,\"map\")"}),
		"gamelib/cmds/mytasks.pike":({"record_action(this_player(),\"tasks\")"}),
		"gamelib/cmds/task_guide.pike":({"environment(me)==room","record_action(me,\"task_guide\")"}),
		"lowlib/wapmud2/cmds/use_perform.pike":({"record_perform(me,arg)"}),
		"gamelib/single/daemons/taskd.pike":({"record_kill(player)"}),
		"lowlib/wapmud2/cmds/eat.pike":({"if(tmp==1)","record_action(this_player(),\"eat\")"}),
		"gamelib/cmds/look_top.pike":({"record_action(me,\"top\")"}),
		"gamelib/cmds/mailbox.pike":({"record_action(this_player(),\"mailbox\")"}),
		"gamelib/cmds/chatroom_list.pike":({"record_action(me,\"chat\")"}),
		"gamelib/cmds/my_term.pike":({"record_action(me,\"team\")"}),
		"gamelib/cmds/buy_items.pike":({"record_book_shop(me,type)"}),
		"gamelib/single/daemons/buyd.pike":({"record_book_purchase(me,item_name)"}),
		"lowlib/wapmud2/cmds/read.pike":({"if(tmp==1)","record_book_read(this_player())"}),
		"gamelib/cmds/summon.pike":({"record_summon(me,summon_type)"}),
		"gamelib/cmds/growth_task.pike":({"try_auto_complete(me)"}),
		"lowlib/mudlib/inherit/feature/level.pike":({"try_auto_complete"}),
		"gamelib/single/daemons/http_api_daemon.pike":
			({"consume_completion_notices","newbie_completions"}),
		"gamelib/single/daemons/newbied.pike":
			({"claim_current_step","claim_with_notice",
			  "try_auto_complete",
			  "consume_completion_notices","GUIDE_TOTAL 20"}),
	]);
	int all_ok = 1;

	foreach(checks; string relative; array(string) needles){
		string source = Stdio.read_file(ROOT+"/"+relative);
		program|zero action_program = 0;
		mixed err = catch {
			action_program = (program)(ROOT+"/"+relative);
		};
		if(!source || err || !action_program){
			all_ok = 0;
			continue;
		}
		foreach(needles,string needle){
			if(search(source,needle)==-1)
				all_ok = 0;
		}
	}
	if(all_ok)
		test_pass();
	else
		test_fail("有功能步骤仍由引导按钮自身伪造，或成功条件缺失");
}

void test_tutorial_and_roadmaps_render()
{
	test_start("分步课程、七职业路线及方士高阶特色完整显示");
	array(string) professions = ({
		"jianxian","yushi","zhuxian","kuangyao",
		"wuyao","yinggui","fangshi",
	});
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	int all_ok = 1;

	foreach(professions,string profession){
		object player = create_profession_player(
			"__testunit_guide_render_"+profession+"__",profession,1);
		string tutorial = guide->render_tutorial(player);
		string roadmap = guide->render_roadmap(player);
			if(search(tutorial,"【新手引导 1/20】")==-1 ||
			   search(tutorial,"无需返回本页检查")==-1 ||
			   search(roadmap,player->query_profe_cn(profession)+
			"·从入门到高阶")==-1 ||
		   search(roadmap,"装备与副业")==-1 ||
		   search(roadmap,"队伍与副本")==-1 ||
		   search(roadmap,"帮派、家园与交易")==-1 ||
		   search(roadmap,"60级以后")==-1)
			all_ok = 0;
		if(profession=="fangshi" &&
		   (search(roadmap,"10级虎灵攻击")==-1 ||
		    search(roadmap,"24级灵莲铺")==-1 ||
		    search(roadmap,"70级隐藏大神书")==-1))
			all_ok = 0;
		destroy_player(player);
	}
	if(all_ok)
		test_pass();
	else
		test_fail("分步页面或至少一个职业的长期路线缺失");
}

void test_fangshi_can_use_tutorial_ration()
{
	test_start("中立方士可食用新手干粮");
	object player = create_player("__testunit_guide_food__",1);
	object ration = clone(ROOT+"/gamelib/clone/item/food/ganliang");
	object|zero original_player = this_player();
	int result;

	ration->move(player);
	player->set_life(player->get_cur_life()-1);
	set_this_player(player);
	result = ration->eat();
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(result==1)
		test_pass();
	else
		test_fail("干粮仍受旧六职业限制，方士无法完成吃药课程");
	destroy_player(player);
}

int claim_ready_step(object player,int expected_step)
{
	mapping state = NEWBIED->query_step_state(player);
	mapping result;

	if(state["step"]!=expected_step || !state["ready"])
		return 0;
	result = NEWBIED->claim_current_step(player);
	return result["code"]==2 &&
		NEWBIED->query_step(player)==expected_step+1;
}

void test_all_professions_complete_twenty_steps()
{
	test_start("七职业均可按真实状态连续完成20步并毕业");
	array(string) professions = ({
		"jianxian","yushi","zhuxian","kuangyao",
		"wuyao","yinggui","fangshi",
	});
	array(string) equipment_paths = ({
		"/gamelib/clone/item/weapon/1taomujian/1taomujian",
		"/gamelib/clone/item/armor/2caoxie/2caoxie",
		"/gamelib/clone/item/armor/2cubuchangku/2cubuchangku",
		"/gamelib/clone/item/armor/2cubuyi/2cubuyi",
	});
	object assistant = (object)(ROOT+"/gamelib/cmds/auto_equip.pike");
	int all_ok = 1;

	foreach(professions,string profession){
		object player = create_profession_player(
			"__testunit_guide_full_"+profession+"__",profession,1);
		mapping config = NEWBIED->query_profession_config(player);
		mapping final_state;

		NEWBIED->record_action(player,"status");
		if(!claim_ready_step(player,1))
			all_ok = 0;
		NEWBIED->record_action(player,"inventory");
		if(!claim_ready_step(player,2))
			all_ok = 0;

		foreach(equipment_paths,string path){
			object item = clone(ROOT+path);
			if(item)
				item->move(player);
		}
		assistant->auto_equip_player(player);
		NEWBIED->record_action(player,"auto_equip");
		if(!claim_ready_step(player,3))
			all_ok = 0;

		NEWBIED->record_action(player,"skills");
		if(!claim_ready_step(player,4))
			all_ok = 0;
		NEWBIED->record_action(player,"map");
		if(!claim_ready_step(player,5))
			all_ok = 0;
		NEWBIED->record_action(player,"tasks");
		if(!claim_ready_step(player,6))
			all_ok = 0;
		if(TASKD->accept_growth_task(player)!=1 ||
		   !claim_ready_step(player,7))
			all_ok = 0;
		NEWBIED->record_action(player,"task_guide");
		if(!claim_ready_step(player,8))
			all_ok = 0;
		NEWBIED->record_perform(player,config["starter"]);
		if(!claim_ready_step(player,9))
			all_ok = 0;
		NEWBIED->record_kill(player);
		NEWBIED->record_kill(player);
		NEWBIED->record_kill(player);
		if(!claim_ready_step(player,10))
			all_ok = 0;
		NEWBIED->record_action(player,"eat");
		if(!claim_ready_step(player,11))
			all_ok = 0;
		NEWBIED->record_action(player,"top");
		if(!claim_ready_step(player,12))
			all_ok = 0;
		NEWBIED->record_action(player,"mailbox");
		if(!claim_ready_step(player,13))
			all_ok = 0;
		NEWBIED->record_action(player,"chat");
		if(!claim_ready_step(player,14))
			all_ok = 0;
		NEWBIED->record_action(player,"team");
		if(!claim_ready_step(player,15))
			all_ok = 0;
		NEWBIED->record_book_shop(player,profession);
		if(!claim_ready_step(player,16))
			all_ok = 0;

		player->level = config["level"];
		player->set_att_by_level();
		if(!claim_ready_step(player,17))
			all_ok = 0;
		NEWBIED->record_book_purchase(player,config["book"]);
		if(!claim_ready_step(player,18))
			all_ok = 0;
		player->skills[config["skill"]] = ({1,0});
		NEWBIED->record_book_read(player);
		if(!claim_ready_step(player,19))
			all_ok = 0;

		if(config["practice"]=="active")
			NEWBIED->record_perform(player,config["skill"]);
		else if(config["practice"]=="passive")
			NEWBIED->record_kill(player);
		else{
			player->level = 10;
			player->skills["huling"] = ({1,0});
			NEWBIED->record_summon(player,"huling");
		}
		if(!claim_ready_step(player,20))
			all_ok = 0;
		final_state = NEWBIED->query_step_state(player);
		if(!final_state["complete"])
			all_ok = 0;
		destroy_player(player);
	}

	if(all_ok)
		test_pass();
	else
		test_fail("至少一个职业在20步中的步骤条件、奖励或衔接发生中断");
}

void print_summary()
{
	werror("\n========================================\n");
	werror("新手引导测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_real_equipment_state();
	test_fangshi_level_guidance();
	test_common_growth_and_home_links();
	test_fangshi_advanced_milestones();
	test_creation_and_ui_wiring();
	test_check_cannot_fake_progress();
	test_automatic_completion_popup_queue();
	test_completed_growth_task_does_not_block_tutorial();
	test_historical_growth_progress_auto_reconciles();
	test_automatic_graduation_notice();
	test_seven_profession_branches();
	test_book_funds_are_once_only();
	test_real_action_sources_are_wired();
	test_tutorial_and_roadmaps_render();
	test_fangshi_can_use_tutorial_ration();
	test_all_professions_complete_twenty_steps();
	print_summary();
	return test_results["failed"];
}
