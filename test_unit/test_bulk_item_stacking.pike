#!/usr/bin/env pike
/** 技能书/配方/药品/材料高堆叠、单本消耗与容量守恒回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[批量堆叠] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[批量堆叠] ✗ %s: %s\n",name,detail);
	}
}

object create_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("xd01testunitbulkstack");
	player->name_cn="批量堆叠测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=20;
	player->set_att_by_level();
	return player;
}

array(object) named_items(object player,string name)
{
	return filter(all_inventory(player),lambda(object item){
		return item && item->query_name()==name;
	});
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
	object|zero original_player=this_player();
	string error_desc="";
	mixed err=catch{
		set_this_player(player);
		object first=clone(ROOT+"/gamelib/clone/item/book/qieyunzhan");
		object second=clone(ROOT+"/gamelib/clone/item/book/qieyunzhan");
		first->move(player);
		second->move(player);
		int removed=player->normalize_bulk_item_stacks();
		array(object) books=named_items(player,"qieyunzhan");
		object book=sizeof(books) ? books[0] : 0;
		check("老档案独立技能书守恒整理为一组",
			removed==1 && sizeof(books)==1 && book &&
			book->is("combine_item") && (int)book->amount==2 &&
			(int)book->max_count==9999,
			sprintf("removed=%d groups=%d amount=%d",removed,
				sizeof(books),book ? (int)book->amount : 0));

		object third=clone(ROOT+"/gamelib/clone/item/book/qieyunzhan");
		third->move_player(player->query_name());
		check("新获得同路径技能书自动并入旧组",
			(int)book->amount==3 && environment(third)!=player,
			"amount="+(string)book->amount);

		int learned=book->read();
		check("学习成功只消耗一本并恢复下一本可读状态",
			learned==1 && (int)book->amount==2 &&
			(int)book->read_flag==1 && player->skills["qieyunzhan"],
			sprintf("result=%d amount=%d flag=%d",learned,
				(int)book->amount,(int)book->read_flag));
		int repeated=book->read();
		check("重复学习失败不会误扣整组或一本",
			repeated==2 && (int)book->amount==2 &&
			(int)book->read_flag==1,
			sprintf("result=%d amount=%d",repeated,(int)book->amount));
		object unlearned=clone(ROOT+
			"/gamelib/clone/item/book/yufengjianqi");
		unlearned->move(player);
		object recipe=clone(ROOT+
			"/gamelib/clone/item/peifang/duanzao/p_juquejian");
		recipe->move(player);
		object cleanup=(object)(ROOT+
			"/gamelib/cmds/cleanup_redundant_books.pike");
		array(object) redundant=cleanup->query_redundant_books(player);
		check("清理候选只含已学重复书并永久保留未学技能书",
			search(redundant,book)!=-1 && search(redundant,unlearned)==-1,
			sprintf("candidates=%O",redundant));

		object material_a=clone(ROOT+
			"/gamelib/clone/item/material/tongkuangshi");
		object material_b=clone(ROOT+
			"/gamelib/clone/item/material/tongkuangshi");
		material_a->amount=30;
		material_b->amount=40;
		material_a->move(player);
		material_b->move(player);
		player->normalize_bulk_item_stacks();
		array(object) materials=named_items(player,"tongkuangshi");
		check("矿材旧30上限升级并守恒合并",
			sizeof(materials)==1 && (int)materials[0]->amount==70 &&
			(int)materials[0]->max_count==9999,
			sprintf("groups=%d amount=%d",sizeof(materials),
				sizeof(materials) ? (int)materials[0]->amount : 0));

		// 模拟旧档案恰好中断在“已学习、待消费”状态；清理仍应删除整组。
		book->read_flag=0;
		mapping cleaned=cleanup->perform_cleanup(player);
		check("确认清理删除整组已学重复书且不碰未学书",
			(int)cleaned["amount"]==2 &&
			!sizeof(named_items(player,"qieyunzhan")) &&
			environment(unlearned)==player,
			sprintf("result=%O",cleaned));
		check("背包入口公开重复书卷清理且命令可编译",
			search(player->view_inventory_browser("book",1,""),
				"cleanup_redundant_books")!=-1 &&
			search(player->view_inventory_browser("book",1,""),
				"锻造熟练度135")!=-1,
			"背包入口缺失");
	};
	if(err)
		error_desc=describe_error(err)+" "+describe_backtrace(err);
	if(err)
		check("测试运行时无异常",0,error_desc);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	destroy_player(player);
	werror("批量堆叠：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
