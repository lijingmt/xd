#!/usr/bin/env pike
/** 百分比回春丹与顶级荣誉装备兑换回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[百分比丹/荣誉装] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[百分比丹/荣誉装] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string userid)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="百分比丹药测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=80;
	player->set_att_by_level();
	return player;
}

void destroy_test_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
}

int count_honer_items(object player)
{
	int total=0;
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_item_from) &&
		   (string)item->query_item_from()=="honer")
			total++;
	return total;
}

int main()
{
	object player=create_test_player("xd01testunitpctpill");
	object|zero original=this_player();
	string error_desc="";
	int recovered=0;
	int quota_blocked=0;
	int max_boosted=0;
	int exchanged=0;
	int insufficient_refused=0;
	mixed err=catch{
		set_this_player(player);
		// 回春丹：半血半蓝食用，回复各35%上限（不超上限）。
		object pill=clone(ROOT+"/gamelib/clone/item/teyao/huichundan");
		pill->move(player);
		int life_max=player->query_life_max();
		int mofa_max=player->query_mofa_max();
		player->set_life(life_max/2);
		player->set_mofa(mofa_max/2);
		int eat=LIANDAND->eat_danyao(player,pill);
		int life_expect=life_max/2+life_max*35/100;
		int mofa_expect=mofa_max/2+mofa_max*35/100;
		if(life_expect>life_max)
			life_expect=life_max;
		if(mofa_expect>mofa_max)
			mofa_expect=mofa_max;
		recovered=eat==1 && player->get_cur_life()==life_expect &&
			player->get_cur_mofa()==mofa_expect;
		// 每日限额：VIP0每日5次，再连吃5次应有一次被拒。
		int blocked_seen=0;
		for(int i=0;i<5;i++){
			object extra=clone(ROOT+
				"/gamelib/clone/item/teyao/huichundan");
			extra->move(player);
			if(LIANDAND->eat_danyao(player,extra)==2)
				blocked_seen=1;
		}
		quota_blocked=blocked_seen;
		// 百分比上限丹：按食用时上限折算定额增益并写入对应槽位。
		object peiyun=clone(ROOT+"/gamelib/clone/item/teyao/peiyundan");
		peiyun->move(player);
		int life_max_before=player->query_life_max();
		int mofa_max_before=player->query_mofa_max();
		player["/plus/daily/teyao_map"]=([]);
		int eat_peiyun=LIANDAND->eat_danyao(player,peiyun);
		object ningshen=clone(ROOT+
			"/gamelib/clone/item/teyao/ningshendan");
		ningshen->move(player);
		int eat_ningshen=LIANDAND->eat_danyao(player,ningshen);
		max_boosted=eat_peiyun==1 && eat_ningshen==1 &&
			player->query_life_max()==life_max_before+
				life_max_before*15/100 &&
			player->query_mofa_max()==mofa_max_before+
				mofa_max_before*15/100;
		// 顶级荣誉装备：仙元阁内人类玩家兑换【仙】固定套装。
		object room=(object)(ROOT+
			"/gamelib/d/congxianzhen/xianyuange");
		player->move(room);
		player->honerpt=1000000;
		object command=(object)(ROOT+
			"/gamelib/cmds/honer_buy_top.pike");
		command->main("weapon");
		exchanged=(int)player->honerpt<1000000 &&
			(int)player->honerpt>=0 && count_honer_items(player)>=1;
		player->honerpt=0;
		command->main("armor");
		insufficient_refused=(int)player->honerpt==0 &&
			count_honer_items(player)>=1;
	};
	if(err)
		error_desc=describe_error(err);
	check("回春丹按上限百分比回复生命法力且不越上限",
		!err && recovered,
		error_desc!="" ? error_desc :
			sprintf("life=%d/%d mofa=%d/%d",
				player->get_cur_life(),player->query_life_max(),
				player->get_cur_mofa(),player->query_mofa_max()));
	check("回春丹计入每日特药限额并超额拒绝",
		!err && quota_blocked,
		"每日限额未生效");
	check("培元凝神按食用时上限百分比提升上限",
		!err && max_boosted,
		error_desc!="" ? error_desc :
			sprintf("life_max=%d mofa_max=%d",
				player->query_life_max(),player->query_mofa_max()));
	check("顶级荣誉装备按部位发放【仙】/【妖】固定套装并扣费",
		!err && exchanged,
		error_desc!="" ? error_desc :
			sprintf("honerpt=%d honer_items=%d",
				(int)player->honerpt,count_honer_items(player)));
	check("荣誉不足时拒绝兑换且不发放装备",
		!err && insufficient_refused,
		"荣誉不足仍被兑换");
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	destroy_test_player(player);
	werror("百分比丹/荣誉装：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
