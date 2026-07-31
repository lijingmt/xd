#!/usr/bin/env pike
/**
 * 新手免费红蓝药测试：
 * 运行时编译 -> 七职业药效 -> 首次赠送防重复 ->
 * 分级领取与小时限制 -> 挂机缺药自动补领 -> 页面与创建接线。
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
	werror("\n[新手药品 %d] %s\n",test_results["total"],name);
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

object create_player(string player_name,string race,string profession,
	int level)
{
	object player;
	player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(player_name);
	player->name_cn = "新手药品测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level = level;
	player->set_att_by_level();
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

void test_runtime_compile()
{
	test_start("守护进程、领取命令和两种新手药运行时编译");
	array(string) paths = ({
		"/gamelib/single/daemons/newbied.pike",
		"/gamelib/single/daemons/autofightd.pike",
		"/gamelib/cmds/get_free_yao.pike",
		"/gamelib/clone/item/food/xinshouhongyao",
		"/gamelib/clone/item/water/xinshoulanyao",
		"/lowlib/wapmud2/cmds/flushview.pike",
	});
	int failed = 0;
	string error_desc = "";
	foreach(paths,string path){
		mixed err = catch {
			program compiled = (program)(ROOT+path);
			if(!compiled)
				failed++;
		};
		if(err){
			failed++;
			error_desc += path+": "+describe_error(err);
		}
	}
	if(failed == 0)
		test_pass();
	else
		test_fail("新手药品相关文件编译失败: "+error_desc);
}

void test_all_professions_can_use()
{
	test_start("人妖中立七职业均可使用红蓝药");
	array(mapping(string:string)) professions = ({
		(["race":"human","profession":"jianxian"]),
		(["race":"human","profession":"yushi"]),
		(["race":"human","profession":"zhuxian"]),
		(["race":"monst","profession":"kuangyao"]),
		(["race":"monst","profession":"wuyao"]),
		(["race":"monst","profession":"yinggui"]),
		(["race":"third","profession":"fangshi"]),
	});
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 1;
	int number = 0;
	foreach(professions,mapping(string:string) config){
		number++;
		object player = create_player("__testunit_newbie_use_"+number+"__",
			config["race"],config["profession"],1);
		object red;
		object blue;
		mixed err = catch {
			red = clone(ROOT+
				"/gamelib/clone/item/food/xinshouhongyao");
			blue = clone(ROOT+
				"/gamelib/clone/item/water/xinshoulanyao");
			red->move(player);
			blue->move(player);
			player->set_life(1);
			player->set_mofa(1);
			set_this_player(player);
			int before_life = player->query_life();
			int before_mana = player->query_mofa();
			int eat_result = red->eat();
			int drink_result = blue->drink();
			valid = valid && eat_result == 1 && drink_result == 1 &&
				player->query_life() > before_life &&
				player->query_mofa() > before_mana;
		};
		if(err){
			valid = 0;
			error_desc += config["profession"]+": "+describe_error(err);
		}
		destroy_player(player);
	}
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(valid)
		test_pass();
	else
		test_fail("职业限制或药效错误: "+error_desc);
}

void test_starter_grant_once()
{
	test_start("创建人物首次赠送20红15蓝且不能重复领取");
	object player = create_player("__testunit_newbie_starter__",
		"third","fangshi",1);
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/newbied.pike");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		mapping first = daemon->grant_starter_supplies(player);
		object red_item = present("xinshouhongyao",player);
		object blue_item = present("xinshoulanyao",player);
		int first_red = daemon->query_newbie_supply_amount(
			player,"xinshouhongyao");
		int first_blue = daemon->query_newbie_supply_amount(
			player,"xinshoulanyao");
		mapping second = daemon->grant_starter_supplies(player);
		valid = first["code"] == 1 && first["red"] == 20 &&
			first["blue"] == 15 && first_red == 20 &&
			first_blue == 15 && second["code"] == 2 &&
			daemon->query_newbie_supply_amount(
				player,"xinshouhongyao") == 20 &&
			daemon->query_newbie_supply_amount(
				player,"xinshoulanyao") == 15 &&
			player["/plus/autofight_food"] == "xinshouhongyao" &&
			player["/plus/autofight_water"] == "xinshoulanyao" &&
			red_item && blue_item &&
			red_item->query_item_canDrop() == 0 &&
			red_item->query_item_canTrade() == 0 &&
			red_item->query_item_canSend() == 0 &&
			red_item->query_item_canStorage() == 0 &&
			blue_item->query_item_canDrop() == 0 &&
			blue_item->query_item_canTrade() == 0 &&
			blue_item->query_item_canSend() == 0 &&
			blue_item->query_item_canStorage() == 0;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("首次赠送数量、防重复或挂机药品设置错误: "+
			error_desc);
	destroy_player(player);
}

void test_claim_policy()
{
	test_start("1至30级分档领取次数与数量正确，31级停止赠送");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/newbied.pike");
	string error_desc = "";
	int valid = 1;
	array(mapping(string:mixed)) cases = ({
		(["level":10,"limit":3,"red":15,"blue":12]),
		(["level":15,"limit":2,"red":12,"blue":10]),
		(["level":25,"limit":1,"red":8,"blue":6]),
	});
	int number = 0;
	foreach(cases,mapping(string:mixed) one){
		number++;
		object player = create_player("__testunit_newbie_claim_"+number+
			"__","third","fangshi",(int)one["level"]);
		mixed err = catch {
			mapping policy = daemon->query_newbie_supply_policy(player);
			valid = valid && policy["limit"] == one["limit"] &&
				policy["red"] == one["red"] &&
				policy["blue"] == one["blue"];
			for(int i=0;i<(int)one["limit"];i++){
				mapping result = daemon->claim_newbie_supplies(player);
				valid = valid && result["code"] == 1 &&
					result["red"] == one["red"] &&
					result["blue"] == one["blue"] &&
					result["used"] == i+1;
			}
			mapping exhausted = daemon->claim_newbie_supplies(player);
			valid = valid && exhausted["code"] == 3 &&
				exhausted["used"] == one["limit"] &&
				daemon->query_newbie_supply_amount(
					player,"xinshouhongyao") ==
					(int)one["limit"]*(int)one["red"] &&
				daemon->query_newbie_supply_amount(
					player,"xinshoulanyao") ==
					(int)one["limit"]*(int)one["blue"];
		};
		if(err){
			valid = 0;
			error_desc += "level "+one["level"]+": "+
				describe_error(err);
		}
		destroy_player(player);
	}
	object high_player = create_player("__testunit_newbie_high__",
		"third","fangshi",31);
	mixed high_err = catch {
		mapping high_result = daemon->claim_newbie_supplies(high_player);
		valid = valid && high_result["code"] == 2 &&
			daemon->query_newbie_supply_amount(
				high_player,"xinshouhongyao") == 0 &&
			daemon->query_newbie_supply_amount(
				high_player,"xinshoulanyao") == 0;
	};
	if(high_err){
		valid = 0;
		error_desc += "level 31: "+describe_error(high_err);
	}
	if(valid)
		test_pass();
	else
		test_fail("分档领取或等级边界错误: "+error_desc);
	destroy_player(high_player);
}

void test_autofight_auto_claim()
{
	test_start("低级挂机采用安全阈值并在缺药时自动补领");
	object player = create_player("__testunit_newbie_autoclaim__",
		"third","fangshi",10);
	object high_player = create_player("__testunit_newbie_autoclaim_high__",
		"third","fangshi",40);
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(player);
		object red = daemon->query_recovery_item_with_newbie_supply(
			player,"life");
		int used_after_red =
			(int)player["/plus/newbie_supply/count"];
		object blue = daemon->query_recovery_item_with_newbie_supply(
			player,"mana");
		int used_after_blue =
			(int)player["/plus/newbie_supply/count"];
		daemon->initialize_player(high_player);
		object high_item =
			daemon->query_recovery_item_with_newbie_supply(
				high_player,"life");
		valid = daemon->query_hp_percent(player) == 70 &&
			daemon->query_mana_percent(player) == 50 &&
			red && red->query_name() == "xinshouhongyao" &&
			blue && blue->query_name() == "xinshoulanyao" &&
			used_after_red == 1 && used_after_blue == 1 &&
			daemon->query_hp_percent(high_player) == 50 &&
			daemon->query_mana_percent(high_player) == 30 &&
			!high_item;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("挂机阈值、自动领取或等级边界错误: "+error_desc);
	destroy_player(player);
	destroy_player(high_player);
}

void test_integration_wiring()
{
	test_start("创建人物、背包、引导、挂机设置与战斗循环完整接线");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string inventory_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/single/viewd.pike");
	string guide_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/newbie_guide.pike");
	string autofight_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/autofight.pike");
	string flush_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/flushview.pike");
	if(init_source && inventory_source && guide_source &&
	   autofight_source && flush_source &&
	   search(init_source,
		"NEWBIED->grant_starter_supplies(me)") != -1 &&
	   search(inventory_source,
		"[新手免费领红蓝药:get_free_yao]") != -1 &&
	   search(guide_source,
		"[免费领取红蓝药:get_free_yao]") != -1 &&
	   search(autofight_source,
		"[新手免费领红蓝药:get_free_yao]") != -1 &&
	   search(flush_source,
		"query_recovery_item_with_newbie_supply") != -1)
		test_pass();
	else
		test_fail("新手药品入口或挂机自动补领缺少接线");
}

int main()
{
	werror("\n========== 新手免费红蓝药测试 ==========\n");
	test_runtime_compile();
	test_all_professions_can_use();
	test_starter_grant_once();
	test_claim_policy();
	test_autofight_auto_claim();
	test_integration_wiring();
	werror("\n新手药品测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
