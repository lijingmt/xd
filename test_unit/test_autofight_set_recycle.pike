#!/usr/bin/env pike
/** 挂机自动套装回收回归：开关、重复件自动回收、硬保护不变。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[挂机套装回收] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[挂机套装回收] ✗ %s: %s\n",name,detail);
	}
}

object create_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("__testunit_afk_set_recycle__");
	player->name_cn="挂机套装回收测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=120;
	player->set_att_by_level();
	return player;
}

object new_weapon(object player,int attack)
{
	object item=clone(ROOT+
		"/gamelib/clone/item/weapon/69xinyuetianfengjian/69xinyuetianfengjian");
	item->set_attack_power(attack);
	item->set_attack_power_limit(attack);
	item->set_item_rareLevel(1);
	item->move(player);
	return item;
}

int main()
{
	object command=(object)(
		ROOT+"/gamelib/cmds/set_equipment_cleanup.pike");
	object player=create_player();
	object best=new_weapon(player,300);
	object dup1=new_weapon(player,100);
	object dup2=new_weapon(player,200);
	object bound=new_weapon(player,50);
	bound->apply_newmoon_account_binding(
		"__testunit_afk_set_recycle__","socket",time(),"b"*64);
	string error_desc="";
	mixed err;

	check("默认关闭",(int)command->query_set_recycle_enabled(player)==0,
		"新玩家默认应为关闭");
	command->set_recycle_enabled(player,1);
	check("可开启",(int)command->query_set_recycle_enabled(player)==1,
		"开关设置失败");
	mapping tick_off;
	err=catch{
		command->set_recycle_enabled(player,0);
		tick_off=command->auto_set_recycle_tick(player);
	};
	check("关闭时tick不做任何事",
		!err && mappingp(tick_off) && (int)tick_off["count"]==0 &&
		sizeof(all_inventory(player))==4,
		err ? describe_error(err) : sprintf("%O",tick_off));
	command->set_recycle_enabled(player,1);
	int money_before=player->query_account();
	mapping tick_on;
	err=catch{
		tick_on=command->auto_set_recycle_tick(player);
	};
	check("开启时自动回收两件重复（保留最好一件）",
		!err && mappingp(tick_on) && (int)tick_on["count"]==2 &&
		environment(best)==player &&
		player->query_account()>money_before,
		err ? describe_error(err) :
			sprintf("tick=%O inv=%d",tick_on,
				sizeof(all_inventory(player))));
	check("绑定套装件永不被自动回收",
		environment(bound)==player,
		"绑定件被误回收");
	mapping tick_again;
	err=catch{
		tick_again=command->auto_set_recycle_tick(player);
	};
	check("无重复时tick幂等（0件）",
		!err && mappingp(tick_again) &&
		(int)tick_again["count"]==0 &&
		sizeof(all_inventory(player))==2,
		err ? describe_error(err) : sprintf("%O",tick_again));
	command->set_recycle_enabled(player,0);
	check("可再次关闭",
		(int)command->query_set_recycle_enabled(player)==0,
		"关闭失败");

	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	werror("挂机套装回收测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
