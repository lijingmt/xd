#!/usr/bin/env pike
/** 付费商城批量交付、回滚与限量库存回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[商城批量] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[商城批量] ✗ %s: %s\n",name,detail);
	}
}

object create_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("xd99testunitshopbatch");
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	return player;
}

int item_amount(object player,string name)
{
	int amount;
	foreach(all_inventory(player),object item)
		if(item && (string)item->query_name()==name)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

int stacks_valid(object player,string name)
{
	foreach(all_inventory(player),object item)
		if(item && (string)item->query_name()==name &&
		   ((int)item->amount<1 || (int)item->amount>(int)item->max_count))
			return 0;
	return 1;
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
	object player=create_player();
	mixed err=catch{
		object existing=clone(ROOT+
			"/gamelib/clone/item/teyao/fenfanglu");
		existing->amount=25;
		existing->move(player);
		mapping delivery=SHOP_BATCHD->deliver(player,
			"teyao/fenfanglu",100,0);
		check("一次买100件会补入旧堆且按当前堆叠上限完整交付",
			delivery["ok"] && item_amount(player,"fenfanglu")==125 &&
			stacks_valid(player,"fenfanglu"),
			sprintf("delivery=%O amount=%d",delivery,
				item_amount(player,"fenfanglu")));
		check("交付失败回滚可精确恢复原堆叠",
			SHOP_BATCHD->rollback(player,delivery) &&
			item_amount(player,"fenfanglu")==25 &&
			environment(existing)==player && (int)existing->amount==25,
			sprintf("amount=%d existing=%O",
				item_amount(player,"fenfanglu"),existing));
		check("数量和物品路径均服务端白名单校验",
			SHOP_BATCHD->parse_count("no=100")==100 &&
			SHOP_BATCHD->parse_count("no=101")==101 &&
			!SHOP_BATCHD->deliver(player,"../clone/user",1,0)["ok"] &&
			!SHOP_BATCHD->deliver(player,"teyao/fenfanglu",101,0)["ok"],
			"越界路径或超上限订单被接受");

		// 丹药上限已提升，不能再用芬芳露伪造“仅余5格”的场景。
		// 铜矿石仍采用通用30上限，继续验证满包订单的原子拒绝。
		object capacity_item=clone(ROOT+
			"/gamelib/clone/item/material/tongkuangshi");
		capacity_item->amount=25;
		capacity_item->move(player);
		while(sizeof(all_inventory(player))<player->query_beibao_size()){
			object filler=clone(ROOT+"/gamelib/clone/item/book/lingzhen");
			filler->move(player);
		}
		int before=item_amount(player,"tongkuangshi");
		mapping rejected=SHOP_BATCHD->deliver(player,
			"material/tongkuangshi",6,0);
		check("满背包仅剩5个合并空位时整单6个原子拒绝",
			!rejected["ok"] && item_amount(player,"tongkuangshi")==before,
			sprintf("rejected=%O before=%d after=%d",rejected,before,
				item_amount(player,"tongkuangshi")));

		int stock_before=BROADCASTD->query_num("qianlichuanyinfu");
		int reserve_count=stock_before>=2 ? 2 : 0;
		int reserved=reserve_count && BROADCASTD->reserve_bc_num(
			"qianlichuanyinfu",reserve_count);
		int stock_middle=BROADCASTD->query_num("qianlichuanyinfu");
		int released=reserved && BROADCASTD->release_bc_num(
			"qianlichuanyinfu",reserve_count);
		check("限量商品库存预留和失败归还成对",
			reserve_count && reserved && released &&
			stock_middle==stock_before-reserve_count &&
			BROADCASTD->query_num("qianlichuanyinfu")==stock_before,
			sprintf("before=%d middle=%d after=%d",stock_before,
				stock_middle,BROADCASTD->query_num("qianlichuanyinfu")));
	};
	if(err)
		check("批量交易测试无运行异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	destroy_player(player);
	werror("商城批量事务：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
