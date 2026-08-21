#!/usr/bin/env pike
/** 同一账号会员通用回归：账号最高档共享、过期不共享、更高人物回写账号。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[账号会员] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[账号会员] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string userid,string account_id)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="账号会员测试"+userid;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->set_account_owner(account_id);
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

int main()
{
	string account="xd01testvipacct01";
	string path=DATA_ROOT+"accounts/"+account[sizeof(account)-2..]+
		"/"+account+".vip.json";
	object buyer=create_test_player("__testunit_vip_buyer__",account);
	object alt=create_test_player("__testunit_vip_alt__",account);
	object expired=create_test_player("__testunit_vip_old__",account);
	int shared=0;
	int expired_not_shared=1;
	int backfilled=0;
	string error_desc="";
	rm(path);
	mixed err=catch{
		// 主号购买：give_vip_to 记录账号档位。
		VIPD->give_vip_to(buyer,2);
		// 小号登录对账：应升到同账号最高档。
		shared=VIPD->reconcile_account_vip(alt);
		// 过期记录不给任何人共享。
		mapping(string:mixed) record=Standards.JSON.decode(
			Stdio.read_file(path));
		record["end_time"]=time()-10;
		Stdio.write_file(path+".manual",Standards.JSON.encode(record));
		mv(path+".manual",path);
		object fresh=create_test_player("__testunit_vip_fresh__",account);
		expired_not_shared=VIPD->reconcile_account_vip(fresh)==0 &&
			(int)fresh->query_vip_flag()==0;
		destroy_test_player(fresh);
		// 人物自身更高档时回写账号（老账号迁移）。
		rm(path);
		expired->set_vip_flag(3);
		expired->set_vip_end_time(time()+7200);
		backfilled=VIPD->reconcile_account_vip(expired);
		object seeded=create_test_player("__testunit_vip_seeded__",account);
		int seeded_ok=VIPD->reconcile_account_vip(seeded) &&
			(int)seeded->query_vip_flag()==3;
		destroy_test_player(seeded);
		backfilled=backfilled && seeded_ok;
	};
	if(err)
		error_desc=describe_error(err);
	check("同账号小号登录对账共享最高档会员",
		!err && shared &&
		(int)alt->query_vip_flag()==2 &&
		(int)alt->query_vip_end_time()==(int)buyer->query_vip_end_time(),
		error_desc!="" ? error_desc :
			sprintf("shared=%d alt_flag=%d",shared,
				(int)alt->query_vip_flag()));
	check("账号记录过期后不再共享且不发放",
		!err && expired_not_shared,
		"过期账号记录仍被同步");
	check("人物更高档时回写账号供其他人物共享",
		!err && backfilled,
		"老账号迁移回写失败");
	rm(path);
	rm(path+".lock");
	destroy_test_player(buyer);
	destroy_test_player(alt);
	destroy_test_player(expired);
	werror("账号会员：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
