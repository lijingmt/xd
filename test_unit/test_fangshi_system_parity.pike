#!/usr/bin/env pike
/**
 * 方士老职业对齐测试：
 * 荣誉、传送、公共设施、聊天、阵营保护、任务、装备、家园和复活。
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
	werror("\n[方士系统对齐 %d] %s\n",test_results["total"],name);
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
	player->name_cn = "系统对齐测试人物";
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
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_honor_runtime()
{
	test_start("中立荣誉称号、灵气排行与双阵营荣誉商店");
	object top_command =
		(object)(ROOT+"/gamelib/cmds/look_top.pike");
	object buy_command =
		(object)(ROOT+"/gamelib/cmds/honer_buy.pike");
	object view_command =
		(object)(ROOT+"/gamelib/cmds/honer_equip_view.pike");
	string top_source =
		Stdio.read_file(ROOT+"/gamelib/cmds/look_top.pike");

	if(WAP_HONERD->query_honer_level_desc(0,"third")=="游方者" &&
	   WAP_HONERD->query_honer_level_desc(13,"third")=="混元大方士" &&
	   top_command->query_race_tag("third")=="【方】" &&
	   top_command->query_honer_top_name("third")=="灵气" &&
	   buy_command->query_honer_name("third")=="灵气" &&
	   view_command->query_catalog_race("third","human")=="human" &&
	   view_command->query_catalog_race("third","monst")=="monst" &&
	   view_command->query_catalog_race("human","monst")=="" &&
	   search(top_source,
		"[灵气排行榜:look_top list 灵气 1]")!=-1)
		test_pass();
	else
		test_fail("中立荣誉称号、显示或商店选表不正确");
}

void test_transfer_runtime()
{
	test_start("方士传送列表合并仙妖两边目的地");
	mapping(int:array(string)) human =
		ROOMLEVELD->query_transfer_list("human");
	mapping(int:array(string)) monst =
		ROOMLEVELD->query_transfer_list("monst");
	mapping(int:array(string)) third =
		ROOMLEVELD->query_transfer_list("third");

	if(sizeof(third)==sizeof(human) &&
	   sizeof(third)==sizeof(monst) &&
	   sizeof(third[10])==sizeof(human[10])+sizeof(monst[10]) &&
	   search(third[10],
		"kunlunshan/xianzhenxuyugong")!=-1 &&
	   search(third[10],
		"jinaodao/yaozhenbiyougong")!=-1)
		test_pass();
	else
		test_fail("中立传送目的地没有完整合并");
}

void scan_room_access(string path,mapping(string:int) stats)
{
	array(string)|zero entries = get_dir(path);
	if(!entries)
		return;
	foreach(entries,string entry){
		string child = path+"/"+entry;
		if(Stdio.is_dir(child)){
			scan_room_access(child,stats);
			continue;
		}
		string source = Stdio.read_file(child);
		if(!source)
			continue;
		if(search(source,"can_use_room_race(room_race)")!=-1){
			stats["wired"]++;
			program|zero room_program = 0;
			mixed err = catch {
				room_program = (program)child;
			};
			stats["compiled"]++;
			if(err || !room_program){
				stats["compile_failed"]++;
				werror("  ✗ 公共设施文件编译失败: %s (%s)\n",
					child,err ? describe_error(err) : "没有程序对象");
			}
		}
		if(search(source,
		   "player->query_raceId()==room_race")!=-1 ||
		   search(source,
		   "player->query_raceId() == room_race")!=-1)
			stats["legacy"]++;
	}
}

void test_room_access_runtime()
{
	test_start("驿站、休息点、仓库等公共设施统一支持中立方士");
	object fangshi =
		create_player("__testunit_parity_room__","third","fangshi",100);
	object human =
		create_player("__testunit_parity_human__","human","jianxian",100);
	object original_player = this_player();
	object human_square =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object monst_square =
		(object)(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	object human_transfer =
		(object)(ROOT+"/gamelib/d/kunlunshan/xianzhenxuyugong");
	object monst_transfer =
		(object)(ROOT+"/gamelib/d/jinaodao/yaozhenbiyougong");
	object human_storage =
		(object)(ROOT+"/gamelib/d/kunlunshan/wuge");
	object monst_storage =
		(object)(ROOT+"/gamelib/d/jinaodao/wuge");
	mapping(string:int) stats = ([
		"wired":0,
		"legacy":0,
		"compiled":0,
		"compile_failed":0,
	]);
	string links = "";
	string error_desc = "";

	mixed err = catch {
		set_this_player(fangshi);
		fangshi->move(human_square);
		links += human_square->query_links();
		fangshi->move(monst_square);
		links += monst_square->query_links();
		fangshi->move(human_transfer);
		links += human_transfer->query_links();
		fangshi->move(monst_transfer);
		links += monst_transfer->query_links();
		fangshi->move(human_storage);
		links += human_storage->query_links();
		fangshi->move(monst_storage);
		links += monst_storage->query_links();
		scan_room_access(ROOT+"/gamelib/d",stats);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err &&
	   fangshi->can_use_room_race("human") &&
	   fangshi->can_use_room_race("monst") &&
	   !human->can_use_room_race("monst") &&
	   search(links,"[休息:sleep]")!=-1 &&
	   search(links,"xianzhen")!=-1 &&
	   search(links,"yaozhen")!=-1 &&
	   search(links,"[存:user_package]")!=-1 &&
	   stats["wired"]>=100 &&
	   stats["compiled"]==stats["wired"] &&
	   stats["compile_failed"]==0 &&
	   stats["legacy"]==0)
		test_pass();
	else
		test_fail(sprintf(
			"公共设施接线失败 wired=%d compiled=%d failed=%d legacy=%d: %s",
			stats["wired"],stats["compiled"],stats["compile_failed"],
			stats["legacy"],error_desc));

	destroy_player(fangshi);
	destroy_player(human);
}

void test_chat_runtime()
{
	test_start("方士聊天室和快捷聊天同时连接仙妖频道");
	array(object) human_daemons =
		RACECHATD->query_chat_daemons("human");
	array(object) monst_daemons =
		RACECHATD->query_chat_daemons("monst");
	array(object) third_daemons =
		RACECHATD->query_chat_daemons("third");
	array(string) command_paths = ({
		"/gamelib/cmds/chatroom_chat.pike",
		"/gamelib/cmds/chatroom_entry.pike",
		"/gamelib/cmds/chatroom_list.pike",
		"/gamelib/cmds/ui_chat.pike",
		"/gamelib/clone/user.pike",
	});
	int wired = 0;

	foreach(command_paths,string path){
		string source = Stdio.read_file(ROOT+path);
		if(source && search(source,"RACECHATD")!=-1)
			wired++;
	}

	if(sizeof(human_daemons)==1 &&
	   sizeof(monst_daemons)==1 &&
	   sizeof(third_daemons)==2 &&
	   third_daemons[0]==human_daemons[0] &&
	   third_daemons[1]==monst_daemons[0] &&
	   wired==sizeof(command_paths))
		test_pass();
	else
		test_fail("聊天桥接守护进程或入口接线不完整");
}

void test_faction_change_protection()
{
	test_start("方士不能转换阵营且确认前不会消耗轮回符印");
	object fangshi =
		create_player("__testunit_parity_faction__","third","fangshi",108);
	object human =
		create_player("__testunit_parity_faction_h__",
			"human","jianxian",108);
	string confirm_source =
		Stdio.read_file(ROOT+"/gamelib/cmds/race_change_confirm.pike");
	int guard_pos = search(confirm_source,"!me->can_change_faction()");
	int consume_pos = search(confirm_source,
		"me->remove_combine_item(\"lunhuifuyin\",1)");

	if(!fangshi->can_change_faction() &&
	   human->can_change_faction() &&
	   guard_pos!=-1 && consume_pos!=-1 &&
	   guard_pos<consume_pos)
		test_pass();
	else
		test_fail("阵营保护缺失或保护发生在扣道具之后");
	destroy_player(fangshi);
	destroy_player(human);
}

void test_regional_tasks_runtime()
{
	test_start("方士可承接仙、妖地区旧任务及中立成长任务");
	array(int) task_ids = ({1,11,70});
	int failed = 0;

	for(int i=0;i<sizeof(task_ids);i++){
		object player = create_player(
			"__testunit_parity_task_"+i+"__",
			"third","fangshi",100);
		int result = TASKD->get_task(player,task_ids[i]);
		if(result!=1)
			failed++;
		destroy_player(player);
	}

	if(failed==0)
		test_pass();
	else
		test_fail(sprintf("%d 条地区/中立任务无法承接",failed));
}

void test_npc_interaction_runtime()
{
	test_start("方士面对仙妖NPC均可对话领取任务并保留战斗选择");
	object fangshi =
		create_player("__testunit_parity_npc__","third","fangshi",30);
	object human =
		create_player("__testunit_parity_npc_h__","human","jianxian",30);
	object human_npc = clone(ROOT+
		"/gamelib/clone/npc/kunlunshan/daodezhenjun400");
	object monst_npc = clone(ROOT+
		"/gamelib/clone/npc/jinaodao/zhaogongming400");
	object original_player = this_player();
	string fangshi_human_links = "";
	string fangshi_monst_links = "";
	string human_links = "";
	string error_desc = "";

	mixed err = catch {
		set_this_player(fangshi);
		fangshi_human_links = human_npc->query_npc_links(0);
		fangshi_monst_links = monst_npc->query_npc_links(0);
		set_this_player(human);
		human_links = human_npc->query_npc_links(0);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err &&
	   search(fangshi_human_links,"[对话:ask_npc ")!=-1 &&
	   search(fangshi_human_links,"[杀戮:kill ")!=-1 &&
	   search(fangshi_monst_links,"[对话:ask_npc ")!=-1 &&
	   search(fangshi_monst_links,"[杀戮:kill ")!=-1 &&
	   search(human_links,"[对话:ask_npc ")!=-1 &&
	   search(human_links,"[杀戮:kill ")==-1)
		test_pass();
	else
		test_fail("NPC对话/战斗双入口不正确: "+error_desc);

	if(human_npc)
		destruct(human_npc);
	if(monst_npc)
		destruct(monst_npc);
	destroy_player(fangshi);
	destroy_player(human);
}

void test_guild_runtime()
{
	test_start("方士可查看两边帮派且建帮归属跟随所在阵营城市");
	object fangshi =
		create_player("__testunit_parity_bang__","third","fangshi",40);
	object human_square =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object monst_square =
		(object)(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	string bang_source =
		Stdio.read_file(ROOT+"/lowlib/wapmud2/single/bangd.pike");
	string human_side = "";
	string monst_side = "";
	string error_desc = "";

	mixed err = catch {
		fangshi->move(human_square);
		human_side = BANGD->query_bang_side(fangshi);
		fangshi->move(monst_square);
		monst_side = BANGD->query_bang_side(fangshi);
		BANGD->query_bang_list(fangshi);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && human_side=="human" && monst_side=="monst" &&
	   search(bang_source,"else if(prof == \"third\")")!=-1)
		test_pass();
	else
		test_fail("帮派双边列表或建帮归属失败: "+error_desc);
	destroy_player(fangshi);
}

void test_social_runtime()
{
	test_start("方士可与仙妖两边玩家组队、交易、私聊和加好友");
	object fangshi =
		create_player("__testunit_parity_social_f__","third","fangshi",30);
	object human =
		create_player("__testunit_parity_social_h__","human","jianxian",30);
	object monst =
		create_player("__testunit_parity_social_m__","monst","kuangyao",30);
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object original_player = this_player();
	array(string) wired_paths = ({
		"/gamelib/clone/user.pike",
		"/gamelib/cmds/tell.pike",
		"/gamelib/cmds/qqlist.pike",
		"/lowlib/wapmud2/inherit/feature/qqlist.pike",
	});
	string fangshi_links = "";
	string human_links = "";
	string hostile_links = "";
	int wired = 0;
	string error_desc = "";

	foreach(wired_paths,string path){
		string source = Stdio.read_file(ROOT+path);
		if(source && search(source,"can_socialize_with")!=-1)
			wired++;
	}

	mixed err = catch {
		fangshi->move(room);
		human->move(room);
		monst->move(room);
		set_this_player(fangshi);
		fangshi_links = human->query_links(0);
		set_this_player(human);
		human_links = fangshi->query_links(0);
		hostile_links = monst->query_links(0);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err &&
	   fangshi->can_socialize_with(human) &&
	   fangshi->can_socialize_with(monst) &&
	   human->can_socialize_with(fangshi) &&
	   !human->can_socialize_with(monst) &&
	   search(fangshi_links,"[组队邀请:term_assist ")!=-1 &&
	   search(fangshi_links,"[交易:trade ")!=-1 &&
	   search(fangshi_links,"[加为好友:qqlist ")!=-1 &&
	   search(fangshi_links,"[杀戮:kill ")!=-1 &&
	   search(human_links,"[组队邀请:term_assist ")!=-1 &&
	   search(human_links,"[交易:trade ")!=-1 &&
	   search(human_links,"[杀戮:kill ")!=-1 &&
	   search(hostile_links,"[杀戮:kill ")!=-1 &&
	   search(hostile_links,"[组队邀请:term_assist ")==-1 &&
	   wired==sizeof(wired_paths))
		test_pass();
	else
		test_fail("中立社交入口或旧阵营隔离失败: "+error_desc);

	destroy_player(fangshi);
	destroy_player(human);
	destroy_player(monst);
}

void test_city_guard_runtime()
{
	test_start("方士进入仙妖城池不会被守卫主动攻击或拦住出口");
	object fangshi =
		create_player("__testunit_parity_guard_f__","third","fangshi",30);
	object human =
		create_player("__testunit_parity_guard_h__","human","jianxian",30);
	array(string) guard_paths = ({
		"/gamelib/clone/npc/human_npc/human_gud50",
		"/gamelib/clone/npc/monst_npc/monst_gud50",
		"/gamelib/clone/npc/xiqicheng/mojunshizu",
		"/gamelib/clone/npc/xiqicheng/jingweiduishibing",
		"/gamelib/clone/npc/tianyecheng/mojunshizu",
		"/gamelib/clone/npc/tianyecheng/jingweiduishibing",
		"/gamelib/clone/npc/jadhuanjing/mojunshizu",
		"/gamelib/clone/npc/jadhuanjing/jingweiduishibing",
		"/gamelib/clone/npc/chaogecheng/mojunshizu",
		"/gamelib/clone/npc/chaogecheng/jingweiduishibing",
		"/gamelib/clone/npc/klshuanjing/mojunshizu",
		"/gamelib/clone/npc/klshuanjing/jingweiduishibing",
		"/gamelib/clone/npc/create_city_npc.pike",
		"/lowlib/wapmud2/cmds/leave.pike",
	});
	int wired = 0;
	int compiled = 0;
	int failed = 0;

	foreach(guard_paths,string path){
		string source = Stdio.read_file(ROOT+path);
		program|zero guard_program = 0;
		mixed err = catch {
			guard_program = (program)(ROOT+path);
		};
		if(source && search(source,"can_use_room_race")!=-1)
			wired++;
		if(!err && guard_program)
			compiled++;
		else
			failed++;
	}

	if(fangshi->can_use_room_race("human") &&
	   fangshi->can_use_room_race("monst") &&
	   !human->can_use_room_race("monst") &&
	   wired==sizeof(guard_paths) &&
	   compiled==sizeof(guard_paths) &&
	   failed==0)
		test_pass();
	else
		test_fail(sprintf(
			"城池守卫接线失败 wired=%d compiled=%d failed=%d",
			wired,compiled,failed));
	destroy_player(fangshi);
	destroy_player(human);
}

void test_neutral_misc_ui_runtime()
{
	test_start("方士自动修炼出口与排行榜阵营显示完整");
	object fangshi =
		create_player("__testunit_parity_misc__","third","fangshi",72);
	object original_player = this_player();
	object autolearn_room =
		(object)(ROOT+"/gamelib/d/autolearn/foyuanchantang");
	object ranking_command =
		(object)(ROOT+"/gamelib/cmds/paihang_view_player.pike");
	string links = "";
	string error_desc = "";

	mixed err = catch {
		set_this_player(fangshi);
		links = autolearn_room->query_links();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err &&
	   search(links,"kunlunshan/mengxianjing")!=-1 &&
	   search(links,"jinaodao/anyingchaoxue")!=-1 &&
	   ranking_command->query_race_name("human")=="人类" &&
	   ranking_command->query_race_name("monst")=="妖魔" &&
	   ranking_command->query_race_name("third")=="中立")
		test_pass();
	else
		test_fail("自动修炼出口或排行榜方士标签错误: "+error_desc);
	destroy_player(fangshi);
}

void test_equipment_growth_runtime()
{
	test_start("方士可实际穿戴六个老职业三条装备成长路线");
	object player =
		create_player("__testunit_parity_equip__","third","fangshi",100);
	array(string) paths = ({
		"/gamelib/clone/item/armor/65feiyangsuojia",
		"/gamelib/clone/item/armor/70youmeibushou/70youmeibushou",
		"/gamelib/clone/item/armor/70bailipiwan/70bailipiwan",
	});
	int failed = 0;

	foreach(paths,string path){
		object item = clone(ROOT+path);
		if(!item){
			failed++;
			continue;
		}
		item->move(player);
		if(search(item->query_item_profeLimit(),"fangshi")==-1)
			failed++;
		player->wear(item);
		if(!item->equiped)
			failed++;
	}

	if(failed==0 && sizeof(player->query_equip())==3)
		test_pass();
	else
		test_fail(sprintf("老职业装备实际穿戴失败=%d",failed));
	destroy_player(player);
}

void test_home_and_lifecycle_wiring()
{
	test_start("家园、建角复活、坠崖复活与每日统计不漏方士");
	object player =
		create_player("__testunit_parity_home__","third","fangshi",30);
	string homed_source =
		Stdio.read_file(ROOT+"/gamelib/single/daemons/homed.pike");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string death_source =
		Stdio.read_file(ROOT+"/gamelib/cmds/waihai_qge74hye.pike");
	string daily_source =
		Stdio.read_file(ROOT+"/gamelib/single/daemons/userd.pike");

	player->set_home_path("xd/test/test/lei/001");
	if(player->query_home_path()=="xd/test/test/lei/001" &&
	   homed_source && search(homed_source,"query_raceId")==-1 &&
	   search(init_source,"me->last_pos=me->relife")!=-1 &&
	   search(death_source,
		"if(me->query_raceId()==\"third\")")!=-1 &&
	   search(daily_source,
		"third_\"+month+\"_\"+day+\"_user_day_info.log")!=-1)
		test_pass();
	else
		test_fail("家园或人物生命周期仍有方士遗漏");
	destroy_player(player);
}

void print_summary()
{
	werror("\n========================================\n");
	werror("方士系统对齐测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_honor_runtime();
	test_transfer_runtime();
	test_room_access_runtime();
	test_chat_runtime();
	test_faction_change_protection();
	test_regional_tasks_runtime();
	test_npc_interaction_runtime();
	test_guild_runtime();
	test_social_runtime();
	test_city_guard_runtime();
	test_neutral_misc_ui_runtime();
	test_equipment_growth_runtime();
	test_home_and_lifecycle_wiring();
	print_summary();
	return test_results["failed"];
}
