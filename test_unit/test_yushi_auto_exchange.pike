#!/usr/bin/env pike
/**
 * 玉石购买自动兑换测试：
 * 总价值判断 -> 大面额自动打碎找零 -> 混合面额支付 ->
 * 余额不足不扣款 -> 购买入口编译与真实扣费。
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
	werror("\n[玉石自动兑换 %d] %s\n",test_results["total"],name);
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

object create_runtime_player(string player_name)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;

	player->set_name(player_name);
	player->name_cn = "玉石测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	return player;
}

void give_test_yushi(object player,string yushi_name,int amount)
{
	object yushi = clone(ROOT+"/gamelib/clone/item/yushi/"+yushi_name);
	if(yushi){
		yushi->amount = amount;
		yushi->move_player(player->query_name());
	}
}

void destroy_runtime_player(object|zero player)
{
	if(player)
		destruct(player);
}

void test_large_yushi_purchase_change()
{
	test_start("碧銮玉支付345碎玉并自动找零");
	object|zero player = create_runtime_player("__testunit_yushi_large__");
	int trade_result = 0;
	string error_desc = "";
	mixed err = catch {
		give_test_yushi(player,"biluanyu",1);
		if(YUSHID->have_enough_yushi(player,345))
			trade_result = BUYD->do_trade(player,345,0);
	};
	if(err)
		error_desc = describe_error(err);

	int valid = !err && player && trade_result == 3 &&
		YUSHID->query_all_num(player) == 655 &&
		YUSHID->query_yushi_num(player,4) == 0 &&
		YUSHID->query_yushi_num(player,3) == 6 &&
		YUSHID->query_yushi_num(player,2) == 5 &&
		YUSHID->query_yushi_num(player,1) == 5;
	if(valid)
		test_pass();
	else
		test_fail("大面额支付或找零错误: "+error_desc);

	destroy_runtime_player(player);
}

void test_mixed_yushi_change()
{
	test_start("两块仙缘玉支付15碎玉");
	object|zero player = create_runtime_player("__testunit_yushi_mixed__");
	int pay_result = 0;
	string error_desc = "";
	mixed err = catch {
		give_test_yushi(player,"xianyuanyu",2);
		pay_result = YUSHID->pay_yushi(player,15);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && player && pay_result == 1 &&
	   YUSHID->query_all_num(player) == 5 &&
	   YUSHID->query_yushi_num(player,2) == 0 &&
	   YUSHID->query_yushi_num(player,1) == 5)
		test_pass();
	else
		test_fail("混合面额支付错误: "+error_desc);

	destroy_runtime_player(player);
}

void test_insufficient_yushi_unchanged()
{
	test_start("余额不足时不扣除玉石");
	object|zero player = create_runtime_player("__testunit_yushi_low__");
	int pay_result = 1;
	string error_desc = "";
	mixed err = catch {
		give_test_yushi(player,"xianyuanyu",1);
		pay_result = YUSHID->pay_yushi(player,11);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && player && pay_result == 0 &&
	   YUSHID->query_all_num(player) == 10 &&
	   YUSHID->query_yushi_num(player,2) == 1)
		test_pass();
	else
		test_fail("余额不足仍发生扣款: "+error_desc);

	destroy_runtime_player(player);
}

void test_convert_equip_auto_exchange()
{
	test_start("装备洗炼使用大面额玉石并自动找零");
	object|zero player = create_runtime_player("__testunit_yushi_convert__");
	object command = (object)(ROOT+
		"/gamelib/cmds/convert_equip_confirm.pike");
	int pay_result = 0;
	int second_result = 1;
	string error_desc = "";
	mixed err = catch {
		give_test_yushi(player,"linglongyu",1);
		pay_result = command->pay_convert_equip_yushi(player,10);
		second_result = command->pay_convert_equip_yushi(player,91);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && player && pay_result == 1 && second_result == 0 &&
	   YUSHID->query_all_num(player) == 90 &&
	   YUSHID->query_yushi_num(player,3) == 0 &&
	   YUSHID->query_yushi_num(player,2) == 9 &&
	   YUSHID->query_yushi_num(player,1) == 0)
		test_pass();
	else
		test_fail("洗炼自动兑换或余额不足保护错误: "+error_desc);

	destroy_runtime_player(player);
}

void test_generic_shop_runtime()
{
	test_start("副职技能书购买入口自动兑换");
	object|zero player = create_runtime_player("__testunit_yushi_shop__");
	object|zero book = 0;
	object|zero invalid_book = 0;
	object|zero original_player = this_player();
	string result = "";
	string invalid_result = "";
	string error_desc = "";
	mixed err = catch {
		give_test_yushi(player,"biluanyu",1);
		player->set_account(10000);
		set_this_player(player);
		invalid_book = clone(ROOT+"/gamelib/clone/item/book/lingren");
		invalid_result = ITEMSD->buy_items(invalid_book,1,0,0);
		if(invalid_book)
			destruct(invalid_book);
		book = clone(ROOT+"/gamelib/clone/item/book/lingren");
		result = ITEMSD->buy_items(book,1,2,0);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && player && book && environment(book) == player &&
	   search(invalid_result,"玉石价格有误") != -1 &&
	   search(result,"购买成功") != -1 &&
	   YUSHID->query_all_num(player) == 990)
		test_pass();
	else
		test_fail("通用购买入口未自动兑换: "+error_desc);

	destroy_runtime_player(player);
}

void test_purchase_commands_compile()
{
	test_start("全部玉石购买入口运行时编译");
	array(string) command_paths = ({
		"/gamelib/cmds/yushi_buy_teyao_list.pike",
		"/gamelib/cmds/yushi_buy_teyao_detail.pike",
		"/gamelib/cmds/yushi_buy_teyao_confirm.pike",
		"/gamelib/cmds/yushi_buy_baoshi_list.pike",
		"/gamelib/cmds/yushi_buy_baoshi_detail.pike",
		"/gamelib/cmds/yushi_buy_baoshi_confirm.pike",
		"/gamelib/cmds/yushi_buy_bc_detail.pike",
		"/gamelib/cmds/yushi_buy_bc_confirm.pike",
		"/gamelib/cmds/dubo_item_confirm.pike",
		"/gamelib/cmds/lottery_join_in.pike",
		"/gamelib/cmds/auto_learn_submit.pike",
		"/gamelib/cmds/convert_equip_confirm.pike",
		"/gamelib/cmds/convert_equip_detail.pike",
		"/lowlib/wapmud2/cmds/list_spec.pike",
	});
	int failed = 0;
	string error_desc = "";
	string list_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/list_spec.pike");

	foreach(command_paths,string command_path){
		mixed err = catch {
			program command_program = (program)(ROOT+command_path);
			if(!command_program)
				failed++;
		};
		if(err){
			failed++;
			error_desc += command_path+": "+describe_error(err);
		}
	}
	if(!list_source ||
	   search(list_source,"type==2 ? 30 : 10") == -1 ||
	   search(list_source,"YUSHID->pay_yushi(me,need_amount)") == -1 ||
	   search(list_source,"1000000000") != -1 ||
	   search(list_source,"pay_money") != -1)
		failed++;

	if(failed == 0)
		test_pass();
	else
		test_fail(sprintf("%d个购买入口编译失败: %s",failed,error_desc));
}

void print_summary()
{
	werror("\n========================================\n");
	werror("玉石自动兑换测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_large_yushi_purchase_change();
	test_mixed_yushi_change();
	test_insufficient_yushi_unchanged();
	test_convert_equip_auto_exchange();
	test_generic_shop_runtime();
	test_purchase_commands_compile();
	print_summary();
	return test_results["failed"];
}
