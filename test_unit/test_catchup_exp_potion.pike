#!/usr/bin/env pike
/**
 * 新手追赶经验药测试：分档配置、免费赠送、玉石购买、
 * 69/70级边界、服务端服用限制和普通经验丹兼容。
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
	werror("\n[追赶经验药 %d] %s\n",test_results["total"],name);
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

object create_player(string player_name,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(player_name);
	player->name_cn = "追赶药测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
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

void test_runtime_compile_and_config()
{
	test_start("三档药品、购买命令与服务端限级入口编译");
	array(string) paths = ({
		"/gamelib/clone/item/teyao/zhuiguanglu",
		"/gamelib/clone/item/teyao/yaoguanglu",
		"/gamelib/clone/item/teyao/xinghelu",
		"/gamelib/cmds/catchup_exp_potion.pike",
		"/gamelib/cmds/newbie_shop.pike",
		"/gamelib/cmds/viceskill_eat_danyao.pike",
		"/gamelib/single/daemons/newbied.pike",
		"/gamelib/single/daemons/liandand.pike",
		"/lowlib/mudlib/inherit/danyao.pike",
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
	mapping(string:mapping(string:mixed)) config =
		NEWBIED->query_catchup_exp_potions();
	if(failed==0 && sizeof(config)==3 &&
	   config["zhuiguanglu"]["multiple"]==2 &&
	   config["zhuiguanglu"]["effect"]==100 &&
	   config["zhuiguanglu"]["price"]==3 &&
	   config["yaoguanglu"]["multiple"]==3 &&
	   config["yaoguanglu"]["effect"]==200 &&
	   config["yaoguanglu"]["price"]==8 &&
	   config["xinghelu"]["multiple"]==5 &&
	   config["xinghelu"]["effect"]==400 &&
	   config["xinghelu"]["price"]==20 &&
	   NEWBIED->query_starter_exp_max_level()==19 &&
	   NEWBIED->query_catchup_exp_min_buy_level()==20 &&
	   NEWBIED->query_catchup_exp_max_level()==69)
		test_pass();
	else
		test_fail("分档配置或运行时编译错误: "+error_desc);
}

void test_newbie_shop_manual_claim_wiring()
{
	test_start("追赶药只在新手商店手动领取或购买");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string shop_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/newbie_shop.pike");
	string special_shop_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/yushi_buy_teyao_list.pike");
	if(init_source && shop_source && special_shop_source &&
	   search(init_source,"grant_starter_exp_potion(me)")==-1 &&
	   search(init_source,"[新手补给商店:newbie_shop]")!=-1 &&
	   search(shop_source,
		"[免费领取二倍追光露:catchup_exp_potion claim]")!=-1 &&
	   search(shop_source,
		"[购买2倍/3倍/5倍追赶经验药:catchup_exp_potion]")!=-1 &&
	   search(special_shop_source,
		"[前往新手补给商店购买追赶药:newbie_shop]")!=-1)
		test_pass();
	else
		test_fail("新手商店入口或手动领取规则接线错误");
}

void test_item_properties()
{
	test_start("二三五倍药效、30分钟时长、69级上限与不可转移属性");
	array(string) names = ({"zhuiguanglu","yaoguanglu","xinghelu"});
	array(int) effects = ({100,200,400});
	int valid = 1;
	string error_desc = "";
	for(int i=0;i<sizeof(names);i++){
		object|zero item;
		mixed err = catch {
			item = clone(ROOT+"/gamelib/clone/item/teyao/"+names[i]);
			valid = valid && item && item->query_name()==names[i] &&
				item->query_danyao_kind()=="te_exp" &&
				item->query_danyao_type()=="exp" &&
				item->query_effect_value()==effects[i] &&
				item->query_danyao_timedelay()==1800 &&
				item->query_danyao_max_level()==69 &&
				item->query_item_canDrop()==0 &&
				item->query_item_canTrade()==0 &&
				item->query_item_canSend()==0 &&
				item->query_item_canStorage()==0;
		};
		if(err){
			valid = 0;
			error_desc += names[i]+": "+describe_error(err);
		}
		if(item)
			destruct(item);
	}
	if(valid)
		test_pass();
	else
		test_fail("追赶药物品属性错误: "+error_desc);
}

void test_free_grant_boundaries()
{
	test_start("1～19级免费一次、重复防领与20级边界");
	object level_one = create_player(
		"__testunit_catchup_exp_free_1__",1);
	object level_nineteen = create_player(
		"__testunit_catchup_exp_free_19__",19);
	object level_twenty = create_player(
		"__testunit_catchup_exp_free_20__",20);
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		mapping first = NEWBIED->grant_starter_exp_potion(level_one);
		mapping repeated = NEWBIED->grant_starter_exp_potion(level_one);
		mapping edge = NEWBIED->grant_starter_exp_potion(level_nineteen);
		mapping blocked = NEWBIED->grant_starter_exp_potion(level_twenty);
		valid = first["code"]==1 && first["exp"]==1 &&
			repeated["code"]==2 && repeated["exp"]==0 &&
			edge["code"]==1 && edge["exp"]==1 &&
			blocked["code"]==3 && blocked["exp"]==0 &&
			NEWBIED->query_newbie_supply_amount(
				level_one,"zhuiguanglu")==1 &&
			NEWBIED->query_newbie_supply_amount(
				level_nineteen,"zhuiguanglu")==1 &&
			NEWBIED->query_newbie_supply_amount(
				level_twenty,"zhuiguanglu")==0;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("免费赠送等级或防重复错误: "+error_desc);
	destroy_player(level_one);
	destroy_player(level_nineteen);
	destroy_player(level_twenty);
}

void test_purchase_prices_and_boundaries()
{
	test_start("20～69级按3/8/20碎玉购买且70级拒绝扣款");
	object level_twenty = create_player(
		"__testunit_catchup_exp_buy_20__",20);
	object level_sixty_nine = create_player(
		"__testunit_catchup_exp_buy_69__",69);
	object level_seventy = create_player(
		"__testunit_catchup_exp_buy_70__",70);
	object command = (object)(ROOT+
		"/gamelib/cmds/catchup_exp_potion.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		YUSHID->give_yushi(level_twenty,31);
		YUSHID->give_yushi(level_sixty_nine,3);
		YUSHID->give_yushi(level_seventy,20);
		set_this_player(level_twenty);
		command->main("buy zhuiguanglu");
		command->main("buy yaoguanglu");
		command->main("buy xinghelu");
		set_this_player(level_sixty_nine);
		command->main("buy zhuiguanglu");
		set_this_player(level_seventy);
		command->main("buy xinghelu");
		valid = YUSHID->query_all_num(level_twenty)==0 &&
			NEWBIED->query_newbie_supply_amount(
				level_twenty,"zhuiguanglu")==1 &&
			NEWBIED->query_newbie_supply_amount(
				level_twenty,"yaoguanglu")==1 &&
			NEWBIED->query_newbie_supply_amount(
				level_twenty,"xinghelu")==1 &&
			YUSHID->query_all_num(level_sixty_nine)==0 &&
			NEWBIED->query_newbie_supply_amount(
				level_sixty_nine,"zhuiguanglu")==1 &&
			YUSHID->query_all_num(level_seventy)==20 &&
			NEWBIED->query_newbie_supply_amount(
				level_seventy,"xinghelu")==0;
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
		test_fail("购买价格、自动兑换或等级边界错误: "+error_desc);
	destroy_player(level_twenty);
	destroy_player(level_sixty_nine);
	destroy_player(level_seventy);
}

void test_use_boundary_and_legacy_compatibility()
{
	test_start("69级可服追赶药、70级不消耗且普通经验丹仍可用");
	object level_sixty_nine = create_player(
		"__testunit_catchup_exp_use_69__",69);
	object level_seventy = create_player(
		"__testunit_catchup_exp_use_70__",70);
	object catchup_ok = clone(ROOT+
		"/gamelib/clone/item/teyao/xinghelu");
	object catchup_blocked = clone(ROOT+
		"/gamelib/clone/item/teyao/xinghelu");
	object legacy = clone(ROOT+
		"/gamelib/clone/item/teyao/huanshendan");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		int ok = LIANDAND->eat_danyao(level_sixty_nine,catchup_ok);
		int blocked = LIANDAND->eat_danyao(level_seventy,catchup_blocked);
		int old_ok = LIANDAND->eat_danyao(level_seventy,legacy);
		valid = ok==1 &&
			level_sixty_nine->query_buff("te_exp",1)==400 &&
			blocked==3 &&
			old_ok==1 &&
			level_seventy->query_buff("te_exp",1)==100 &&
			mappingp(level_seventy["/plus/daily/teyao_map"]) &&
			level_seventy["/plus/daily/teyao_map"]["te_exp"]==1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("服用上限或普通经验丹兼容错误: "+error_desc);
	if(catchup_ok)
		destruct(catchup_ok);
	if(catchup_blocked)
		destruct(catchup_blocked);
	if(legacy)
		destruct(legacy);
	destroy_player(level_sixty_nine);
	destroy_player(level_seventy);
}

int main()
{
	werror("\n========== 新手追赶经验药测试 ==========\n");
	test_runtime_compile_and_config();
	test_newbie_shop_manual_claim_wiring();
	test_item_properties();
	test_free_grant_boundaries();
	test_purchase_prices_and_boundaries();
	test_use_boundary_and_legacy_compatibility();
	werror("\n追赶经验药测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
