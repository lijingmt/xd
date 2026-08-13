#!/usr/bin/env pike
/** VIP5-8增量权益与会员特卖批量结算回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

#define VIP_TEST_USER "xd99testunitvipshop"

void cleanup_player_file()
{
	string path=DATA_ROOT+"u/"+VIP_TEST_USER[sizeof(VIP_TEST_USER)-2..]+
		"/"+VIP_TEST_USER+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[VIP扩展] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[VIP扩展] ✗ %s: %s\n",name,detail);
	}
}

object create_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name(VIP_TEST_USER);
	player->name_cn="会员特卖测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level=200;
	return player;
}

void give_suiyu(object player,int amount)
{
	object jade=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	jade->amount=amount;
	jade->move_player(player->query_name());
}

void give_vip_item(object player,string path,int amount)
{
	object item=clone(ROOT+"/gamelib/clone/item/"+path);
	item->set_toVip(1);
	item->amount=amount;
	item->move_player(player->query_name());
}

int vip_item_amount(object player,string name)
{
	int amount;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name &&
		   (int)item->query_toVip()==1)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
}

int main()
{
	cleanup_player_file();
	object player=create_player();
	object confirm=(object)(ROOT+
		"/gamelib/cmds/vip_myzone_off_confirm.pike");
	object autofightd=(object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object|zero original_player=this_player();
	string error_desc="";
	mixed err=catch{
		player->set_vip_flag(4);
		player->set_vip_end_time(time()+3600);
		check("旧VIP1-4价格、折扣、等级和挂机额度保持原值",
			VIP_MAX_LEVEL==8 && VIPD->get_vip_cost(1)==10 &&
			VIPD->get_vip_cost(4)==100 && VIPD->get_vip_off(1)==9 &&
			VIPD->get_vip_off(4)==5 &&
			VIPD->query_vip_level_limit(1)==140 &&
			VIPD->query_vip_level_limit(4)==200 &&
			autofightd->query_daily_seconds_for(player)==16*3600,
			"旧四档权益被新增档位改写");

		player->set_vip_flag(8);
		check("VIP5-8按每档50元增量开放至280级24小时",
			VIPD->get_vip_name(5)=="星耀会员" &&
			VIPD->get_vip_name(8)=="仙尊会员" &&
			VIPD->get_vip_cost(5)==150 && VIPD->get_vip_cost(6)==200 &&
			VIPD->get_vip_cost(7)==250 && VIPD->get_vip_cost(8)==300 &&
			VIPD->query_vip_level_limit(5)==220 &&
			VIPD->query_vip_level_limit(8)==280 &&
			autofightd->query_daily_seconds_for(player)==24*3600 &&
			player->query_max_yao()==45,
			"新增价格、等级、挂机或药品上限不一致");
		check("新增高阶VIP沿用钻石飞行费用且不因缺失映射退化",
			MAPD->query_player_fly_fee(player)==5000,
			"VIP5-8飞行费用没有继承钻石档");

		check("特卖目录新增实用经验与状态药且旧芬芳露单价不变",
			VIPD->is_off_good("teyao/qinxinlu",4) &&
			VIPD->is_off_good("teyao/yingzhiwan",4) &&
			VIPD->is_off_good("teyao/fenfanglu",8) &&
			VIPD->query_off_good_price("teyao/fenfanglu",4)==35 &&
			VIPD->query_off_good_price("teyao/fenfanglu",8)==21,
			"实用货品缺失或服务端折扣价格变化异常");
		int all_prices_positive=1;
		foreach(({"teyao/nuhuojiu","teyao/liuxianglu",
		   "teyao/yingzhiwan","teyao/fenfanglu"}),string goods_path)
			for(int level=1;level<=VIP_MAX_LEVEL;level++)
				if(VIPD->is_off_good(goods_path,level) &&
				   VIPD->query_off_good_price(goods_path,level)<1)
					all_prices_positive=0;
		check("高阶折扣对低价商品最低仍收1碎玉",
			all_prices_positive &&
			VIPD->query_off_good_price("teyao/nuhuojiu",8)==1,
			"整数折扣产生了零价会员商品");

		set_this_player(player);
		string detail_source=Stdio.read_file(ROOT+
			"/gamelib/cmds/vip_myzone_off_detail.pike") || "";
		check("新旧界面特卖详情提供快捷数量和具名批量表单",
			search(detail_source,"({1,5,10,20,50,100})")!=-1 &&
			search(detail_source,"quick<=quick_max")!=-1 &&
			search(detail_source,"[int no:...]")!=-1 &&
			search(detail_source,
				"[submit 确定购买:vip_myzone_off_confirm")!=-1,
			"特卖详情仍只能单件点击");

		give_suiyu(player,4000);
		int before_yushi=YUSHID->query_all_num(player);
		confirm->main("teyao/fenfanglu 4 0 no=50");
		check("批量特卖忽略客户端价格并按服务端单价整单结算",
			vip_item_amount(player,"fenfanglu")==50 &&
			YUSHID->query_all_num(player)==before_yushi-35*50,
			"芬芳露数量或玉石总值没有50件服务端价格变化");

		int after_batch_yushi=YUSHID->query_all_num(player);
		confirm->main("teyao/fenfanglu 4 0 no=101");
		check("超过100件的伪造批量请求不扣玉也不发货",
			vip_item_amount(player,"fenfanglu")==50 &&
			YUSHID->query_all_num(player)==after_batch_yushi,
			"超上限请求改变了背包或玉石");

		object probe=clone(ROOT+"/gamelib/clone/item/teyao/fenfanglu");
		probe->set_toVip(1);
		int state=VIPD->if_can_get_offly(player,probe,4);
		check("付费特卖可跨过旧药品45件上限但仍有999安全上限",
			vip_item_amount(player,"fenfanglu")==50 &&
			VIPD->query_off_good_remaining(player,probe,4)==949 && state==4,
			"特卖药品仍被旧随身药品数量限制");
		destruct(probe);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err){
		error_desc=describe_error(err)+" "+describe_backtrace(err);
		check("测试运行时无异常",0,error_desc);
	}
	destroy_player(player);
	cleanup_player_file();
	werror("VIP扩展与特卖：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
