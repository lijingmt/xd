#!/usr/bin/env pike
/** 套装分类、重复件清理候选及永久保护回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[套装整理] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[套装整理] ✗ %s: %s\n",name,detail);
	}
}

object create_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("__testunit_set_cleanup__");
	player->name_cn="套装整理测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=200;
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
	object player=create_player();
	object command=(object)(ROOT+"/gamelib/cmds/set_equipment_cleanup.pike");
	object weak=new_weapon(player,100);
	object medium=new_weapon(player,200);
	object best=new_weapon(player,300);
	object bound=new_weapon(player,50);
	object other_collection=new_weapon(player,40);
	other_collection->set_newmoon_collection("starshine");
	bound->apply_newmoon_account_binding("__testunit_set_cleanup__",
		"socket",time(),"a"*64);
	array(object) candidates=({});
	string error_desc="";
	mixed err=catch{
		candidates=command->query_set_cleanup_candidates(player);
	};
	if(err)
		error_desc=describe_error(err);
	check("同系列同职业同部位只保留评分最高一件",
		!err && sizeof(candidates)==2 &&
		search(candidates,weak)!=-1 && search(candidates,medium)!=-1 &&
		search(candidates,best)==-1,
		error_desc+sprintf(" candidates=%O",candidates));
	check("绑定套装和另一系列单件永久排除",
		command->query_set_cleanup_reject_reason(player,bound)=="bound" &&
		search(candidates,bound)==-1 &&
		search(candidates,other_collection)==-1,
		"绑定或跨系列装备进入了候选");
	// 升级/洗炼过的套装重复件允许清理：原converted一刀切让升级后的
	// 重复件无处可去。
	object converted=new_weapon(player,150);
	converted->set_convert_count(1);
	string converted_reject=command->query_set_cleanup_reject_reason(
		player,converted);
	check("升级/洗炼过的套装重复件不再被清理拒绝",
		converted_reject=="",
		sprintf("reason=%O",converted_reject));
	destruct(converted);
	array(string) preview_refs=command->query_set_cleanup_runtime_refs(
		candidates);
	array(object) resolved_refs=command->resolve_set_cleanup_runtime_refs(
		player,preview_refs);
	check("清理预览只保存字符串标识并能精确还原当前对象",
		sizeof(preview_refs)==2 && sizeof(resolved_refs)==2 &&
		stringp(preview_refs[0]) && search(resolved_refs,weak)!=-1 &&
		search(resolved_refs,medium)!=-1,
		sprintf("refs=%O resolved=%O",preview_refs,resolved_refs));
	destruct(weak);
	object replacement=new_weapon(player,100);
	resolved_refs=command->resolve_set_cleanup_runtime_refs(player,
		preview_refs);
	check("原对象消失后同路径替代品不能复用旧清理确认",
		search(resolved_refs,replacement)==-1 && sizeof(resolved_refs)==1,
		sprintf("refs=%O resolved=%O",preview_refs,resolved_refs));
	weak=replacement;
	candidates=command->query_set_cleanup_candidates(player);
	int money_before=player->query_account();
	mapping cleaned=command->perform_set_cleanup(player,candidates);
	check("确认执行重新校验、清理两件且不会删除保留件",
		(int)cleaned["count"]==2 && environment(best)==player &&
		environment(bound)==player && environment(other_collection)==player &&
		player->query_account()>money_before,
		sprintf("result=%O inventory=%d",cleaned,sizeof(all_inventory(player))));
	mixed compile_error=catch{
		compile_file(ROOT+"/gamelib/cmds/set_equipment_cleanup.pike");
	};
	check("套装整理命令可由真实Pike运行时编译",!compile_error,
		compile_error ? describe_error(compile_error) : "");
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	werror("套装整理测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
