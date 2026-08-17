#!/usr/bin/env pike
/** 神秘商店货币和无等级装备停产回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("[稀有经济] ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("[稀有经济] ✗ %s: %s\n",name,detail);
	}
}

object create_shop_test_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("xd99testunitmysterygear");
	player->name_cn="神秘装备回归测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level=101;
	return player;
}

int main()
{
	string shop = Stdio.read_file(ROOT+"/lowlib/wapmud2/cmds/list_spec.pike");
	string boss = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/bossdropd.pike");
	string items = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/itemsd.pike");
	string shelf = Stdio.read_file(ROOT+
		"/lowlib/mudlib/single/specstored.pike");
	string buy = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/cmds/buy_goods_spec.pike");
	string detail = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/cmds/buy_detail_spec.pike");
	mixed shop_compile = catch {
		compile_file(ROOT+"/lowlib/wapmud2/cmds/list_spec.pike");
	};
	mixed boss_compile = catch {
		compile_file(ROOT+"/gamelib/single/daemons/bossdropd.pike");
	};
	mixed shelf_compile = catch {
		compile_file(ROOT+"/lowlib/mudlib/single/specstored.pike");
	};
	mixed items_compile = catch {
		compile_file(ROOT+"/gamelib/single/daemons/itemsd.pike");
	};
	check("神秘技能货架仅接受服务端固定30碎玉",
		!shop_compile && shop && search(shop,"type==2 ? 30 : 10")!=-1 &&
		search(shop,"pay_yushi(me,need_amount)")!=-1 &&
		search(shop,"1000000000")==-1 && search(shop,"pay_money") == -1,
		"仍存在客户端金额、金币或编译错误");
	check("Boss新装备不再随机生成无等级需求",
		!boss_compile && boss && search(boss,"set_item_canLevel(-1)")==-1 &&
		search(boss,"set_item_canLevel(\"+boss_level+\");")!=-1,
		"Boss生成器仍可能写入-1或编译失败");
	check("普通掉落仅保留显式旧装备-1兼容入口",
		items && search(items,"if(flag_no_level == 1)")!=-1 &&
		search(items,"random(10000)<=1 || flag_no_level") == -1 &&
		search(items,"rtn_ob->query_item_canLevel()<0")!=-1 &&
		search(items,"rtn_ob->set_item_canLevel(target_item_level)")!=-1 &&
		search(items,"只兼容旧无等级装备明确传入-1后的炼化")!=-1,
		"随机无等级分支仍存在或旧数据兼容说明缺失");
	check("神秘货架使用真实模板等级并保留初始装备外观",
		!shelf_compile && shelf &&
		search(shelf,"query_safe_shop_template_level")!=-1 &&
		search(shelf,"levels=filter(levels")!=-1 &&
		search(shelf,"level>=1 && level<=71")!=-1 &&
		search(shelf,"60+random(12)")==-1 &&
		search(shelf,"item_name,\n\t\t\tstore_level")!=-1 &&
		search(shelf,"spec_shop_guard.log")!=-1 &&
		search(shelf,"obt->query_item_canLevel()!=me->query_level()")!=-1 &&
		search(shelf,"query_random_goods_normal(random(71)+1")==-1,
		"初始模板被过度过滤或货架仍可以伪造模板等级");
	check("动态装备文件名隔离不同目标等级并保持货架所见即所得",
		!items_compile && items &&
		search(items,"void|int original_item_level")!=-1 &&
		search(items,"original_item_level>0 ? original_item_level")!=-1 &&
		search(items,"target_item_level!=orginal_level")!=-1,
		"不同等级仍可能复用同一动态装备源码并串换攻防属性");
	check("动态装备报价固定10碎玉且货币写入玩家专属凭证",
		shelf && search(shelf,"SPEC_EQUIPMENT_SUIYU_FEE 10")!=-1 &&
		search(shelf,"t,\"suiyu\")")!=-1 &&
		search(shelf,"\"currency\":currency")!=-1 &&
		detail && search(detail,"currency==\"suiyu\"")!=-1,
		"装备报价仍可能使用金币或详情页显示错误货币");
	check("碎玉装备发放失败使用钱包与实体玉快照原路回滚",
		buy && search(buy,"ACCOUNT_WALLETD->query_balance(me)")!=-1 &&
		search(buy,"YUSHID->query_physical_all_num(me)")!=-1 &&
		search(buy,"rollback_yushi_payment(me,")!=-1 &&
		search(buy,"delivery_saved=me->save_with_result()")!=-1 &&
		search(buy,"spec_shop_equipment_delivery_failed")!=-1 &&
		search(buy,"spec_shop_jade.log")!=-1,
		"高价值装备交易缺少扣款快照、原路退款或审计日志");
	object items_daemon=(object)(ROOT+
		"/gamelib/single/daemons/itemsd.pike");
	object valid_equipment=clone(ROOT+
		"/gamelib/clone/item/weapon/25bailudao/25bailudao");
	check("动态装备掉落前拒绝缺失等级接口的旧文件",
		!items_compile && items_daemon && valid_equipment &&
		items_daemon->dynamic_equipment_level_api_valid(valid_equipment)==1 &&
		items_daemon->dynamic_equipment_level_api_valid(items_daemon)==0 &&
		search(items,"[ITEMSD][DYNAMIC_EQUIPMENT_REJECT]")!=-1,
		"坏动态装备仍可进入 NPC 死亡掉落心跳");
	if(valid_equipment)
		destruct(valid_equipment);
	object player=create_shop_test_player();
	object shelf_daemon=(object)(ROOT+
		"/lowlib/mudlib/single/specstored.pike");
	string candidate=shelf_daemon->test_query_normal_candidate(player,1);
	string item_name="";
	int fee;
	int parsed=candidate!="" ? sscanf(candidate,
		"%*s:buy_detail_spec %s %d]",item_name,fee) : 0;
	object generated;
	mixed generated_err=catch{
		if(parsed==3)
			generated=clone(ROOT+"/gamelib/clone/item/"+item_name);
	};
	check("101级玩家能刷出带词缀初始模板且不可低级穿戴",
		!generated_err && candidate!="" && parsed==3 && generated &&
		generated->query_item_canLevel()==101 &&
		search(item_name,"weapon/1")!=-1 && fee==10 &&
		search(candidate,"10碎玉")!=-1,
		"初始装备仍不上架，或高级属性错误保留了1级穿戴门槛");
	if(generated)
		destruct(generated);
	object buy_command=(object)(ROOT+
		"/lowlib/wapmud2/cmds/buy_goods_spec.pike");
	object detail_command=(object)(ROOT+
		"/lowlib/wapmud2/cmds/buy_detail_spec.pike");
	object|zero original_player=this_player();
	int jade_before;
	int jade_after;
	int equipment_before;
	int equipment_after;
	int money_before=(int)player->query_account();
	string token;
	string detail_view="";
	YUSHID->give_yushi(player,20);
	jade_before=YUSHID->query_all_num(player);
	equipment_before=sizeof(all_inventory(player));
	set_this_player(player);
	token=shelf_daemon->issue_test_offer_with_currency(player,
		"weapon/1taomujian/1taomujian",10,"suiyu");
	detail_command->main("weapon/1taomujian/1taomujian 0 "+token);
	detail_view=(string)(player->query_spliter()["text"] || "");
	buy_command->main("weapon/1taomujian/1taomujian 0 "+token);
	jade_after=YUSHID->query_all_num(player);
	equipment_after=sizeof(all_inventory(player));
	buy_command->main("weapon/1taomujian/1taomujian 999999 "+token);
	check("真实碎玉装备购买忽略伪造显示价、扣10碎玉且防重放",
		sizeof(token)==64 && search(detail_view,"10碎玉")!=-1 &&
		jade_before-jade_after==10 &&
		equipment_after==equipment_before+1 &&
		YUSHID->query_all_num(player)==jade_after &&
		sizeof(all_inventory(player))==equipment_after &&
		player->query_account()==money_before,
		sprintf("token=%d jade=%d->%d items=%d->%d money=%d->%d",
			sizeof(token),jade_before,jade_after,equipment_before,
			equipment_after,money_before,(int)player->query_account()));
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	{
		string userid="xd99testunitmysterygear";
		string path=DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
		rm(path);
		rm(path+".bak");
		rm(path+".tmp");
	}
	werror("稀有经济：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
