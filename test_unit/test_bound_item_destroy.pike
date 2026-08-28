#!/usr/bin/env pike
/** Permanently bound items stay destroyable by their own account owner. */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string newmoon_path()
{
	return ROOT+
		"/gamelib/clone/item/weapon/69xinyuetianfengjian/69xinyuetianfengjian";
}

string ancient_book_path()
{
	return ROOT+"/gamelib/clone/item/book/taixujianhen";
}

void cleanup_player_files(string name)
{
	string path;
	if(!name || search(name,"testunit")<0)
		return;
	path=DATA_ROOT+"u/"+name[sizeof(name)-2..]+"/"+name+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_player(string name,string account_owner)
{
	object player;
	cleanup_player_files(name);
	player=clone(GAMELIB_USER);
	player->set_name(name);
	player->set_account_owner(account_owner);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn="绑定销毁测试";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=120;
	player->packageLevel=20;
	return player;
}

void destroy_player(object|zero player)
{
	string name="";
	if(!player)
		return;
	name=(string)player->query_name();
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	cleanup_player_files(name);
}

void test_destroy_eligibility()
{
	object player=create_player("xd89testunitbdest","xd89bdestacct");
	object other=create_player("xd88testunitbdest","xd88bdestacct");
	object item=clone(newmoon_path());
	check("未绑定新月掉落不进入绑定销毁通道",
		item->query_item_canDrop()==1 &&
		!ITEMSD->bound_item_destroyable_by_player(item,player),
		"自由流通掉落被误判为可绑定销毁");
	ITEMSD->bind_newmoon_item_to_player(item,player,"equip");
	check("绑定到本人的新月套装可经二次确认销毁",
		item->query_item_canDrop()==0 &&
		ITEMSD->bound_item_destroyable_by_player(item,player),
		"本人绑定物仍无任何清理出口");
	check("绑定到他人的新月套装销毁失败关闭",
		!ITEMSD->bound_item_destroyable_by_player(item,other),
		"跨账号销毁未失败关闭");
	object book=clone(ancient_book_path());
	check("未绑定太古隐藏书对持有人开放销毁",
		book->query_item_canDrop()==0 &&
		ITEMSD->bound_item_destroyable_by_player(book,player),
		"误拾的非本职业隐藏书无法清理");
	int bound=book->bind_to_account(player);
	object foreign=clone(ancient_book_path());
	int foreign_bound=foreign->bind_to_account(other);
	check("太古隐藏书仅账号归属人可销毁",
		bound && foreign_bound &&
		ITEMSD->bound_item_destroyable_by_player(book,player) &&
		!ITEMSD->bound_item_destroyable_by_player(book,other) &&
		!ITEMSD->bound_item_destroyable_by_player(foreign,player),
		"隐藏书归属销毁门禁不正确");
	object normal=clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	check("普通装备不进入绑定销毁通道",
		normal->query_item_canDrop()==1 &&
		!ITEMSD->bound_item_destroyable_by_player(normal,player),
		"普通装备被误判为绑定销毁");
	destruct(normal);
	destruct(foreign);
	destruct(book);
	destruct(item);
	destroy_player(player);
	destroy_player(other);
}

void test_transfer_guards_unchanged()
{
	object owner=create_player("xd87testunitbguard","xd87bguard");
	object item=clone(newmoon_path());
	ITEMSD->bind_newmoon_item_to_player(item,owner,"equip");
	object book=clone(ancient_book_path());
	book->bind_to_account(owner);
	check("绑定销毁通道不放松转移与仓库门禁",
		item->query_item_canDrop()==0 &&
		item->query_item_canTrade()==0 &&
		item->query_item_canSend()==0 &&
		book->query_item_canDrop()==0 &&
		book->query_item_canTrade()==0 &&
		book->query_item_canSend()==0 &&
		book->query_item_canStorage()==0,
		"销毁通道意外抬高了转移权限");
	destruct(book);
	destruct(item);
	destroy_player(owner);
}

void test_drop_entry_contracts()
{
	array(string) failures=({});
	// 不 compile_file 共享守护进程 itemsd：重编译会让后续测试通过
	// (object)"..." 拿到丢失 item_list 缓存的新实例。它由游戏进程加载。
	foreach(({
		"/lowlib/wapmud2/cmds/drop.pike",
		"/lowlib/wapmud2/cmds/drop_confirm.pike",
		"/lowlib/mudlib/inherit/feature/equip.pike",
		"/gamelib/inherit/ancient_hidden_book.pike",
	}),string path){
		mixed err=catch{ compile_file(ROOT+path); };
		if(err)
			failures+=({path+":"+describe_error(err)});
	}
	check("销毁链路全部文件可编译",!sizeof(failures),failures*" | ");
	string drop=Stdio.read_file(ROOT+"/lowlib/wapmud2/cmds/drop.pike") || "";
	string confirm=Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/drop_confirm.pike") || "";
	int gate=search(drop,"bound_item_destroyable_by_player");
	int candrop=search(drop,"query_item_canDrop");
	int cgate=search(confirm,"bound_item_destroyable_by_player");
	int ccandrop=search(confirm,"query_item_canDrop");
	check("drop与确认入口的绑定销毁分支先于不可摧毁拒绝",
		gate!=-1 && candrop!=-1 && gate<candrop &&
		cgate!=-1 && ccandrop!=-1 && cgate<ccandrop,
		"绑定销毁分支缺失或顺序错误");
	check("drop先确认而drop_confirm复核归属并审计销毁",
		search(drop,"【销毁确认】")!=-1 &&
		search(drop,"drop_confirm")!=-1 &&
		search(confirm,"销毁账号绑定物")!=-1 &&
		search(confirm,"drop.log")!=-1 &&
		search(confirm,"ob->remove()")!=-1,
		"二次确认入口缺少归属复核或审计");
	string equip_text=Stdio.read_file(ROOT+
		"/lowlib/mudlib/inherit/feature/equip.pike") || "";
	string book_text=Stdio.read_file(ROOT+
		"/gamelib/inherit/ancient_hidden_book.pike") || "";
	check("装备与隐藏书详情文案说明本人确认销毁",
		search(equip_text,"二次确认销毁")!=-1 &&
		search(book_text,"二次确认销毁")!=-1,
		"前端可见文案未同步销毁规则");
}

int main()
{
	werror("\n========== 绑定物品本人确认销毁测试 ==========\n");
	test_destroy_eligibility();
	test_transfer_guards_unchanged();
	test_drop_entry_contracts();
	werror("绑定销毁测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
