#!/usr/bin/env pike
/** 客户端参数伪造、奖励先发后扣及玉石精确发放回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[经济收口] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[经济收口] ✗ %s: %s\n",name,detail);
	}
}

void cleanup_player_file(string userid)
{
	string path=DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_player(string userid)
{
	cleanup_player_file(userid);
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="经济收口测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	return player;
}

int amount_of(object player,string name)
{
	int amount=0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

void destroy_player(object player)
{
	string userid=(string)player->query_name();
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	cleanup_player_file(userid);
}

void run_command(string path,string arg)
{
	object command=(object)(ROOT+path);
	command->main(arg);
}

void test_all_changed_entries_compile()
{
	array(string) files=({
		"/gamelib/clone/user.pike",
		"/gamelib/cmds/auto_learn_confirm.pike",
		"/gamelib/cmds/bang_create.pike",
		"/gamelib/cmds/bz_equip_exchange.pike",
		"/gamelib/cmds/convert_bx_open.pike",
		"/gamelib/cmds/convert_equip_confirm.pike",
		"/gamelib/cmds/convert_equip_detail.pike",
		"/gamelib/cmds/convert_equip_vip_off.pike",
		"/gamelib/cmds/dhzz.pike",
		"/gamelib/cmds/fee_exchange_to_confirm.pike",
		"/gamelib/cmds/hb_open.pike",
		"/gamelib/cmds/home_apply_shopLicense.pike",
		"/gamelib/cmds/home_apply_shopLicense_confirm.pike",
		"/gamelib/cmds/home_buy_dog_detail.pike",
		"/gamelib/cmds/home_buy_dog_conferm.pike",
		"/gamelib/cmds/home_get_pass_time_item.pike",
		"/gamelib/cmds/home_buy_shopItem_confirm.pike",
		"/gamelib/cmds/home_shopItem_cancel.pike",
		"/gamelib/cmds/home_shop_item_detail.pike",
		"/gamelib/cmds/home_shop_item_confirm.pike",
		"/gamelib/cmds/home_shopItem_marked_price_confirm.pike",
		"/gamelib/cmds/honer_buy.pike",
		"/gamelib/cmds/huanjin_equip_exchange.pike",
		"/gamelib/cmds/hyq_exchange.pike",
		"/gamelib/cmds/jjbx_open.pike",
		"/gamelib/cmds/ljs_chongzhi_confirm.pike",
		"/gamelib/cmds/lottery_join_in.pike",
		"/gamelib/cmds/spy_start_confirm.pike",
		"/gamelib/cmds/tfzz.pike",
		"/gamelib/cmds/user_package_buy_confirm.pike",
		"/gamelib/cmds/user_package_replace_confirm.pike",
		"/gamelib/cmds/viceskill_book_buy.pike",
		"/gamelib/cmds/viceskill_peifang_buy.pike",
		"/gamelib/cmds/yblh_open.pike",
		"/gamelib/cmds/yuebing_buy.pike",
		"/gamelib/cmds/yushi_buy_teyao_confirm.pike",
		"/gamelib/single/daemons/homed.pike",
		"/gamelib/single/daemons/fee_exchanged.pike",
		"/gamelib/single/daemons/items_exchanged.pike",
		"/gamelib/single/daemons/itemsd.pike",
		"/gamelib/single/daemons/peifangd.pike",
		"/gamelib/single/daemons/yushid.pike"
	});
	array(string) failures=({});
	foreach(files,string file){
		mixed err=catch{ compile_file(ROOT+file); };
		if(err)
			failures+=({file+": "+describe_error(err)});
	}
	check("所有经济安全修改均可由真实 Pike 运行时编译",
		!sizeof(failures),failures*" | ");
}

void test_negative_removal_and_exact_grant()
{
	object player=create_player("xd99testuniteconomyguard");
	object jade=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	jade->amount=5;
	jade->move_player(player->query_name());
	int before=YUSHID->query_physical_all_num(player);
	int removed=player->remove_combine_item("suiyu",-7);
	check("负数复数扣除不会增加堆叠",
		removed==0 && amount_of(player,"suiyu")==5,
		sprintf("removed=%d amount=%d",removed,amount_of(player,"suiyu")));
	int granted=YUSHID->give_yushi(player,120345);
	check("超过五位的玉石发放仍保持精确总价值",
		granted==1 && YUSHID->query_physical_all_num(player)==before+120345,
		sprintf("grant=%d before=%d after=%d",granted,before,
			YUSHID->query_physical_all_num(player)));
	int rejected=YUSHID->give_yushi(player,-1);
	check("负数玉石发放被拒绝且库存不变",
		rejected==0 && YUSHID->query_physical_all_num(player)==before+120345,
		"负数发放改变了库存");
	destroy_player(player);
}

void test_server_authority_markers()
{
	string home=Stdio.read_file(ROOT+"/gamelib/single/daemons/homed.pike");
	string boxes=Stdio.read_file(ROOT+"/gamelib/cmds/hb_open.pike")+
		Stdio.read_file(ROOT+"/gamelib/cmds/jjbx_open.pike")+
		Stdio.read_file(ROOT+"/gamelib/cmds/convert_bx_open.pike");
	string shops=Stdio.read_file(ROOT+"/gamelib/cmds/bz_equip_exchange.pike")+
		Stdio.read_file(ROOT+"/gamelib/cmds/huanjin_equip_exchange.pike")+
		Stdio.read_file(ROOT+"/gamelib/cmds/viceskill_book_buy.pike");
	string convert=Stdio.read_file(ROOT+"/gamelib/cmds/convert_equip_confirm.pike");
	string cross_game=Stdio.read_file(ROOT+
		"/gamelib/cmds/fee_exchange_to_confirm.pike");
	check("家园摆摊创建、售出状态与领取均在锁内持久化",
		home && search(home,"create_shop_listing")!=-1 &&
		search(home,"purchase_shop_listing")!=-1 &&
		search(home,"cancel_shop_listing")!=-1 &&
		search(home,"purchase_infancy")!=-1 &&
		search(home,"homeStateLock->lock()")!=-1 &&
		search(home,"he->shop[ind]=DEFAULT_SHOP_S")!=-1 &&
		search(home,"masterId+\"领回\"+YUSHID->give_yushi") == -1,
		"仍存在重复发放或非原子领取");
	check("红包和旧宝箱校验真实文件且先消费后发奖",
		boxes && search(boxes,"baoxiang/hongbao")!=-1 &&
		search(boxes,"baoxiang/jingjinbaoxiang")!=-1 &&
		search(boxes,"baoxiang/jinsibaoshidai")!=-1 &&
		search(boxes,"YUSHID->pay_yushi(me,cost_reb)")!=-1,
		"宝箱仍可由任意同名物品或客户端价格触发");
	check("活动兑换与副技能书使用服务端目录",
		shops && search(shops,"exchange_catalog")!=-1 &&
		search(shops,"human_books")!=-1 && search(shops,"monst_books")!=-1,
		"兑换路径或成本仍由客户端控制");
	check("炼化费用由 ITEMSD 权威公式重算",
		convert && search(convert,"query_convert_equip_yushi_cost(item)")!=-1 &&
		search(convert,"actual_item_type!=item_type")!=-1,
		"炼化仍信任客户端 cost 或装备类型");
	check("跨区兑换先事务扣玉且余额不足立即停止",
		cross_game && search(cross_game,"return 1;")!=-1 &&
		search(cross_game,"remove_combine_item_transaction")!=-1 &&
		search(cross_game,"rollback_combine_item_transaction")!=-1,
		"跨区领取记录仍可能先于本区玉石扣除");
}

void test_home_infancy_authoritative_purchase()
{
	object player=create_player("xd99testunithomeinfancy");
	object jade=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	jade->amount=5;
	jade->move_player((string)player->query_name());
	mapping bought=HOMED->purchase_infancy(player,"plant/bairicaozi",2,1);
	int after_jade=YUSHID->query_physical_all_num(player);
	check("家园幼年体按服务端目录扣价并精确发放",
		(int)bought["ok"] && after_jade==3 &&
		amount_of(player,"bairicaozi")==2,
		sprintf("ok=%d jade=%d item=%d message=%s",(int)bought["ok"],
			after_jade,amount_of(player,"bairicaozi"),
			(string)bought["message"]));
	int before=YUSHID->query_physical_all_num(player);
	mapping forged=HOMED->purchase_infancy(player,"../yushi/suiyu",20,1);
	check("伪造家园商品路径不会扣费或发放物品",
		!(int)forged["ok"] &&
		YUSHID->query_physical_all_num(player)==before,
		(string)forged["message"]);
	int before_wallet=ACCOUNT_WALLETD->query_balance(player);
	int before_physical=YUSHID->query_physical_all_num(player);
	int paid=YUSHID->pay_yushi(player,1);
	int refunded=YUSHID->rollback_yushi_payment(player,before_wallet,
		before_physical,"testunit_rollback");
	check("玉石支付失败补偿按原渠道恢复且总值守恒",
		paid && refunded &&
		YUSHID->query_physical_all_num(player)==before_physical,
		sprintf("paid=%d refunded=%d before=%d after=%d",paid,refunded,
			before_physical,YUSHID->query_physical_all_num(player)));
	destroy_player(player);
}

void test_raw_tampering_does_not_grant()
{
	object player=create_player("xd99testuniteconomyraw");
	object|zero original=this_player();
	object jade=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	jade->amount=5;
	jade->move_player(player->query_name());
	int before=YUSHID->query_physical_all_num(player);
	mixed err=catch{
		set_this_player(player);
		run_command("/gamelib/cmds/hb_open.pike","suiyu 0 3 1");
		run_command("/gamelib/cmds/yblh_open.pike","suiyu");
		run_command("/gamelib/cmds/yuebing_buy.pike","../../yushi/xuantianbaoyu 1");
		run_command("/gamelib/cmds/viceskill_book_buy.pike",
			"human ../../yushi/xuantianbaoyu 1");
		run_command("/gamelib/cmds/user_package_buy_confirm.pike",
			"beibao 20 0 1");
		run_command("/gamelib/cmds/ljs_chongzhi_confirm.pike",
			"3600 0 1");
	};
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	check("伪造宝箱、路径和零价付费链接不会发奖或消费普通物品",
		!err && YUSHID->query_physical_all_num(player)==before &&
		amount_of(player,"xuantianbaoyu")==0 && !player->ljs_time &&
		BUYD->query_cangku_num(player,"beibao")==0,
		err ? describe_error(err) : sprintf("jade=%d/%d top=%d ljs=%d bag=%d",
			before,YUSHID->query_physical_all_num(player),
			amount_of(player,"xuantianbaoyu"),(int)player->ljs_time,
			BUYD->query_cangku_num(player,"beibao")));
	destroy_player(player);
}

int main()
{
	werror("\n========== 经济与玉石漏洞收口测试 ==========\n");
	test_all_changed_entries_compile();
	test_negative_removal_and_exact_grant();
	test_server_authority_markers();
	test_home_infancy_authoritative_purchase();
	test_raw_tampering_does_not_grant();
	werror("经济收口测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"];
}
