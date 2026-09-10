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
		!err && sizeof(candidates)==3 &&
		search(candidates,weak)!=-1 && search(candidates,medium)!=-1 &&
		search(candidates,bound)!=-1 &&
		search(candidates,best)==-1,
		error_desc+sprintf(" candidates=%O",candidates));
	check("绑定重复件不再被清理拒绝，另一系列单件仍非重复候选",
		command->query_set_cleanup_reject_reason(player,bound)=="" &&
		search(candidates,other_collection)==-1,
		sprintf("bound_reason=%O candidates=%O",
			command->query_set_cleanup_reject_reason(player,bound),
			candidates));
	// 绑定归属不是当前人物的套装必须失败关闭。
	object foreign=new_weapon(player,120);
	foreign->apply_newmoon_account_binding("__testunit_other_owner__",
		"socket",time(),"b"*64);
	check("绑定归属不匹配的套装拒绝清理",
		command->query_set_cleanup_reject_reason(player,foreign)=="not_owner",
		sprintf("reason=%O",
			command->query_set_cleanup_reject_reason(player,foreign)));
	destruct(foreign);
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
		sizeof(preview_refs)==3 && sizeof(resolved_refs)==3 &&
		stringp(preview_refs[0]) && search(resolved_refs,weak)!=-1 &&
		search(resolved_refs,medium)!=-1 &&
		search(resolved_refs,bound)!=-1,
		sprintf("refs=%O resolved=%O",preview_refs,resolved_refs));
	destruct(weak);
	object replacement=new_weapon(player,100);
	resolved_refs=command->resolve_set_cleanup_runtime_refs(player,
		preview_refs);
	check("原对象消失后同路径替代品不能复用旧清理确认",
		search(resolved_refs,replacement)==-1 && sizeof(resolved_refs)==2,
		sprintf("refs=%O resolved=%O",preview_refs,resolved_refs));
	weak=replacement;
	candidates=command->query_set_cleanup_candidates(player);
	int money_before=player->query_account();
	mapping cleaned=command->perform_set_cleanup(player,candidates);
	check("确认执行重新校验、清理三件且不会删除保留件",
		(int)cleaned["count"]==3 && environment(best)==player &&
		environment(other_collection)==player &&
		player->query_account()>money_before,
		sprintf("result=%O inventory=%d",cleaned,sizeof(all_inventory(player))));
	// 绑定单件清理：换系列后遗留的独件绑定套装没有重复件出口，
	// 只能通过显式预览确认销毁（幻境角色不能使用共享仓库）。
	object bound_single=new_weapon(player,80);
	bound_single->set_newmoon_collection("firmament");
	bound_single->apply_newmoon_account_binding(
		"__testunit_set_cleanup__","equip",time(),"c"*64);
	object bound_worn=new_weapon(player,90);
	bound_worn->set_newmoon_collection("firmament");
	bound_worn->apply_newmoon_account_binding(
		"__testunit_set_cleanup__","equip",time(),"d"*64);
	bound_worn->equiped=1;
	array(object) bound_items=({});
	mixed bound_err=catch{
		bound_items=command->query_bound_set_cleanup_candidates(player);
	};
	check("绑定清理候选包含未穿绑定件并排除已穿绑定件",
		!bound_err && sizeof(bound_items)==1 &&
		search(bound_items,bound_single)!=-1 &&
		search(bound_items,bound_worn)==-1,
		sprintf("err=%O items=%O",bound_err,bound_items));
	bound_worn->equiped=0;
	int bound_money_before=player->query_account();
	mapping bound_cleaned=command->perform_bound_set_cleanup(player,
		({bound_single,bound_worn,best}));
	check("绑定清理只销毁通过复验的绑定件并支付银两",
		(int)bound_cleaned["count"]==2 &&
		!bound_single && !bound_worn && environment(best)==player &&
		environment(other_collection)==player &&
		player->query_account()>bound_money_before,
		sprintf("result=%O",bound_cleaned));
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
