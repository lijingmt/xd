#!/usr/bin/env pike
/**
 * 新手免费红蓝药测试：
 * 运行时编译 -> 九职业药效 -> 首次赠送防重复 ->
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
		"/gamelib/cmds/newbie_shop.pike",
		"/gamelib/clone/item/food/xinshouhongyao",
		"/gamelib/clone/item/water/xinshoulanyao",
		"/gamelib/clone/item/liandan/lyuzhijiang",
		"/gamelib/clone/item/liandan/lningchenlu",
		"/lowlib/mudlib/inherit/feature/eated.pike",
		"/lowlib/mudlib/inherit/feature/drinked.pike",
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
	test_start("人妖中立九职业均可使用红蓝药");
	array(mapping(string:string)) professions = ({
		(["race":"human","profession":"jianxian"]),
		(["race":"human","profession":"yushi"]),
		(["race":"human","profession":"zhuxian"]),
		(["race":"monst","profession":"kuangyao"]),
		(["race":"monst","profession":"wuyao"]),
		(["race":"monst","profession":"yinggui"]),
		(["race":"third","profession":"fangshi"]),
		(["race":"third","profession":"zhenyue"]),
		(["race":"third","profession":"tianxiang"]),
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

void test_xiaohuandan_fangshi_compatibility()
{
	test_start("三个中立职业与旧职业均可正常服用小还丹");
	array(mapping(string:string)) professions = ({
		(["race":"third","profession":"fangshi"]),
		(["race":"third","profession":"zhenyue"]),
		(["race":"third","profession":"tianxiang"]),
		(["race":"human","profession":"jianxian"]),
	});
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 1;
	int number = 0;
	foreach(professions,mapping(string:string) config){
		number++;
		object player = create_player("__testunit_xiaohuandan_"+number+
			"__",config["race"],config["profession"],5);
		mixed err = catch {
			object medicine = clone(ROOT+
				"/gamelib/clone/item/food/xiaohuandan");
			medicine->move(player);
			player->set_life(1);
			set_this_player(player);
			int before_life = player->query_life();
			int eat_result = medicine->eat();
			valid = valid && eat_result == 1 &&
				player->query_life() == before_life+300;
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
		test_fail("小还丹的阵营、职业或恢复量错误: "+error_desc);
}

void scan_consumable_catalog(string path,mapping(string:int) stats)
{
	array(string)|zero entries = get_dir(path);
	if(!entries)
		return;
	foreach(entries,string entry){
		string child = path+"/"+entry;
		if(Stdio.is_dir(child)){
			scan_consumable_catalog(child,stats);
			continue;
		}
		string source = Stdio.read_file(child);
		if(!source)
			continue;
		if(search(source,"inherit WAP_FOOD")!=-1 ||
		   search(source,"inherit WAP_WATER")!=-1){
			stats["instant"]++;
			if(search(source,"race_limit[\"third\"]")==-1 ||
			   search(source,"profe_limit[\"fangshi\"]")==-1)
				stats["missing_fangshi"]++;
			if(search(source,"profe_limit[\"zhenyue\"]")==-1)
				stats["missing_zhenyue"]++;
			if(search(source,"profe_limit[\"tianxiang\"]")==-1)
				stats["missing_tianxiang"]++;
			program|zero compiled = 0;
			mixed err = catch {
				compiled = (program)child;
			};
			if(err || !compiled){
				stats["compile_failed"]++;
				werror("  ✗ 即时恢复药编译失败: %s (%s)\n",child,
					err ? describe_error(err) : "没有程序对象");
			}
			object|zero item;
			mixed clone_err = catch {
				item = clone(child);
			};
			if(clone_err || !item ||
			   !item->race_limit["third"] ||
			   !item->profe_limit["fangshi"] ||
			   !item->profe_limit["zhenyue"] ||
			   !item->profe_limit["tianxiang"] || item->amount<=0 ||
			   item->eat_flag!=1 ||
			   ((int)item->add_supplay["life_supply"]<=0 &&
			    (int)item->add_supplay["mofa_supply"]<=0) ||
			   (search(source,"inherit WAP_FOOD")!=-1 &&
			    !functionp(item->eat)) ||
			   (search(source,"inherit WAP_WATER")!=-1 &&
			    !functionp(item->drink))){
				stats["runtime_invalid"]++;
				werror("  ✗ 即时恢复药运行态错误: %s (%s)\n",child,
					clone_err ? describe_error(clone_err) : "属性或入口错误");
			}
			if(item)
				destruct(item);
		}
		else if(search(source,"inherit WAP_DANYAO")!=-1){
			stats["buff"]++;
			if(search(source,"add_supplay[")!=-1 ||
			   search(source,"race_limit[")!=-1 ||
			   search(source,"profe_limit[")!=-1 ||
			   search(source,"eat_flag")!=-1)
				stats["wrong_base"]++;
		}
	}
}

void test_consumable_catalog()
{
	test_start("全量药品目录无遗漏职业限制或错误恢复基类");
	mapping(string:int) stats = ([
		"instant":0,
		"buff":0,
		"missing_fangshi":0,
		"missing_zhenyue":0,
		"missing_tianxiang":0,
		"compile_failed":0,
		"runtime_invalid":0,
		"wrong_base":0,
	]);
	array(string) paths = ({
		"/gamelib/clone/item/food",
		"/gamelib/clone/item/water",
		"/gamelib/clone/item/liandan",
		"/gamelib/clone/item/teyao",
		"/gamelib/clone/item/home/mature/plant",
		"/gamelib/clone/item/zongzi",
		"/gamelib/clone/item/zhongqiuyuebing",
		"/gamelib/clone/item/other",
	});
	foreach(paths,string path)
		scan_consumable_catalog(ROOT+path,stats);
	if(stats["instant"]==45 && stats["buff"]>=200 &&
	   stats["missing_fangshi"]==0 &&
	   stats["missing_zhenyue"]==0 &&
	   stats["missing_tianxiang"]==0 &&
	   stats["compile_failed"]==0 && stats["runtime_invalid"]==0 &&
	   stats["wrong_base"]==0)
		test_pass();
	else
		test_fail(sprintf("即时药=%d，增益丹药=%d，漏方士=%d，漏镇越=%d，漏天象=%d，编译失败=%d，运行态错误=%d，错误基类=%d",
			stats["instant"],stats["buff"],
			stats["missing_fangshi"],stats["missing_zhenyue"],
			stats["missing_tianxiang"],
			stats["compile_failed"],
			stats["runtime_invalid"],stats["wrong_base"]));
}

void test_dual_supply_single_consumption()
{
	test_start("复合恢复药按各自当前值回血回蓝且每次只消耗一份");
	array(mapping(string:string)) professions = ({
		(["race":"third","profession":"fangshi"]),
		(["race":"human","profession":"jianxian"]),
	});
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 1;
	int number = 0;
	foreach(professions,mapping(string:string) config){
		number++;
		object player = create_player("__testunit_dual_medicine_"+
			number+"__",config["race"],config["profession"],10);
		mixed err = catch {
			object medicine = clone(ROOT+
				"/gamelib/clone/item/food/1lifemofa");
			medicine->amount = 3;
			medicine->move(player);
			player->set_life(1);
			player->set_mofa(1);
			set_this_player(player);
			int before_life = player->get_cur_life();
			int before_mofa = player->get_cur_mofa();
			int first_result = medicine->eat();
			valid = valid && first_result==1 &&
				player->get_cur_life()==before_life+60 &&
				player->get_cur_mofa()==before_mofa+20 &&
				medicine->amount==2;
			player->set_life(player->query_life_max());
			player->set_mofa(1);
			int second_result = medicine->eat();
			valid = valid && second_result==1 &&
				player->get_cur_life()==player->query_life_max() &&
				player->get_cur_mofa()==21 && medicine->amount==1;
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
		test_fail("复合药恢复值或消耗数量错误: "+error_desc);
}

void test_advanced_instant_medicines()
{
	test_start("方士与旧职业可使用玉芷浆和凝晨露即时恢复药");
	array(mapping(string:string)) professions = ({
		(["race":"third","profession":"fangshi"]),
		(["race":"human","profession":"jianxian"]),
	});
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 1;
	int number = 0;
	foreach(professions,mapping(string:string) config){
		number++;
		object player = create_player("__testunit_advanced_medicine_"+
			number+"__",config["race"],config["profession"],50);
		mixed err = catch {
			object life_medicine = clone(ROOT+
				"/gamelib/clone/item/liandan/lyuzhijiang");
			object mana_medicine = clone(ROOT+
				"/gamelib/clone/item/liandan/lningchenlu");
			life_medicine->move(player);
			mana_medicine->move(player);
			player->set_life(1);
			player->set_mofa(1);
			set_this_player(player);
			int before_life = player->get_cur_life();
			int before_mofa = player->get_cur_mofa();
			int eat_result = life_medicine->eat();
			int drink_result = mana_medicine->drink();
			int expected_life = before_life+2500;
			int expected_mofa = before_mofa+3000;
			if(expected_life>player->query_life_max())
				expected_life = player->query_life_max();
			if(expected_mofa>player->query_mofa_max())
				expected_mofa = player->query_mofa_max();
			valid = valid && eat_result==1 && drink_result==1 &&
				player->get_cur_life()==expected_life &&
				player->get_cur_mofa()==expected_mofa;
		};
		if(err){
			valid = 0;
			error_desc += config["profession"]+": "+describe_error(err);
		}
		destroy_player(player);
	}
	object low_player = create_player("__testunit_advanced_medicine_low__",
		"third","fangshi",49);
	mixed low_err = catch {
		object low_life = clone(ROOT+
			"/gamelib/clone/item/liandan/lyuzhijiang");
		object low_mana = clone(ROOT+
			"/gamelib/clone/item/liandan/lningchenlu");
		low_life->move(low_player);
		low_mana->move(low_player);
		low_player->set_life(1);
		low_player->set_mofa(1);
		set_this_player(low_player);
		valid = valid && low_life->eat()==0 && low_mana->drink()==0 &&
			low_player->get_cur_life()==1 &&
			low_player->get_cur_mofa()==1;
	};
	if(low_err){
		valid = 0;
		error_desc += "level 49: "+describe_error(low_err);
	}
	destroy_player(low_player);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(valid)
		test_pass();
	else
		test_fail("高级即时恢复药入口、限制或药效错误: "+error_desc);
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
				player,"zhuiguanglu") == 0 &&
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
	string shop_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/newbie_shop.pike");
	if(init_source && inventory_source && guide_source &&
	   autofight_source && flush_source && shop_source &&
	   search(init_source,
		"NEWBIED->grant_starter_supplies(me)") != -1 &&
	   search(inventory_source,
		"[新手补给商店:newbie_shop]") != -1 &&
	   search(guide_source,
		"[新手补给商店:newbie_shop]") != -1 &&
	   search(autofight_source,
		"[新手补给商店:newbie_shop]") != -1 &&
	   search(shop_source,"[领取免费红蓝药:get_free_yao]") != -1 &&
	   search(shop_source,
		"[免费领取二倍追光露:catchup_exp_potion claim]") != -1 &&
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
	test_xiaohuandan_fangshi_compatibility();
	test_consumable_catalog();
	test_dual_supply_single_consumption();
	test_advanced_instant_medicines();
	test_starter_grant_once();
	test_claim_policy();
	test_autofight_auto_claim();
	test_integration_wiring();
	werror("\n新手药品测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
