#!/usr/bin/env pike
/** 会员免费物品一键领取回归：逐件配额、重复领取封顶与档位校验。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[会员一键领] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[会员一键领] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string userid)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="一键领取测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->set_account(100000);
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

void run_command(string path,string arg)
{
	object command=(object)(ROOT+path);
	command->main(arg);
}

int inventory_amount(object player,string item_name)
{
	int total=0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==item_name)
			total+=(int)item->amount;
	return total;
}

int main()
{
	object player=create_test_player("xd01testunitvipfreeall");
	object|zero original_player=this_player();
	string error_desc="";
	array(string) teyao_paths;
	int all_present=1;
	int quota_respected=1;
	string detail="";
	mixed err=catch{
		set_this_player(player);
		player->set_vip_flag(1);
		player->set_vip_end_time(time()+3600);
		teyao_paths=VIPD->query_free_goods_paths(1,"teyao");
		run_command("/gamelib/cmds/vip_myzone_free_all.pike","teyao");
		run_command("/gamelib/cmds/vip_myzone_free_all.pike","teyao");
		foreach(teyao_paths,string path){
			object probe=clone(ROOT+"/gamelib/clone/item/"+path);
			if(!probe){
				all_present=0;
				detail+=" clone_failed:"+path;
				continue;
			}
			int amount=inventory_amount(player,(string)probe->query_name());
			if(amount<1){
				all_present=0;
				detail+=" missing:"+(string)probe->query_name();
			}
			if(amount>(int)player->query_max_yao()){
				quota_respected=0;
				detail+=" over_quota:"+(string)probe->query_name()+
					"="+amount;
			}
			destruct(probe);
		}
	};
	if(err)
		error_desc=describe_error(err);
	check("一键领取发放本类全部免费物品且重复领取不越每日配额",
		!err && sizeof(teyao_paths)>0 && all_present && quota_respected,
		error_desc!="" ? error_desc : detail);

	player->set_vip_flag(0);
	player->set_vip_end_time(0);
	int items_before=sizeof(all_inventory(player));
	mixed err2=catch{
		run_command("/gamelib/cmds/vip_myzone_free_all.pike","teyao");
	};
	check("无生效会员档位时一键领取拒绝发放",
		!err2 && sizeof(all_inventory(player))==items_before,
		err2 ? describe_error(err2) :
			sprintf("items %d -> %d",items_before,
				sizeof(all_inventory(player))));
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	destroy_test_player(player);
	werror("会员一键领：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
