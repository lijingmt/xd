#!/usr/bin/env pike
/** New Moon limited-free-trade binding and transfer boundary regression. */

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
	player->name_cn="新月绑定测试";
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

void test_raw_and_binding_core()
{
	object player=create_player("xd99testunitmoonbind","xd99moonaccount");
	object other=create_player("xd98testunitmoonbind","xd98moonaccount");
	object item=clone(newmoon_path());
	item->move(player);
	check("新月世界掉落实例进入背包后仍保持自由流通",
		!item->query_newmoon_account_bound() &&
		item->query_item_canDrop()==1 && item->query_item_canTrade()==1 &&
		item->query_item_canSend()==1 && item->query_item_canStorage()==1,
		sprintf("bound=%d drop=%d trade=%d send=%d storage=%d",
			item->query_newmoon_account_bound(),item->query_item_canDrop(),
			item->query_item_canTrade(),item->query_item_canSend(),
			item->query_item_canStorage()));
	int first=ITEMSD->bind_newmoon_item_to_player(item,player,"equip");
	string binding_id=(string)item->query_newmoon_account_bind_id();
	int second=ITEMSD->bind_newmoon_item_to_player(item,player,"equip");
	int foreign=ITEMSD->bind_newmoon_item_to_player(item,other,"equip");
	check("首次使用生成不可变账号绑定凭据且同账号调用幂等",
		first==2 && second==1 && foreign==0 && sizeof(binding_id)==64 &&
		item->query_newmoon_account_bind_owner()=="xd99moonaccount" &&
		item->query_newmoon_account_bind_reason()=="equip" &&
		item->query_newmoon_account_bind_time()>0,
		"绑定状态、凭据、幂等或跨账号检查不正确");
	check("绑定后关闭丢弃赠送交易并保留同账号仓库能力",
		item->query_item_canDrop()==0 && item->query_item_canTrade()==0 &&
		item->query_item_canSend()==0 && item->query_item_canStorage()==1,
		"绑定后的四个物品权限不符合有限自由交易规则");
	check("炼化生成新对象前仍会拒绝外账号绑定原件",
		ITEMSD->newmoon_item_usable_by_player(item,player) &&
		!ITEMSD->newmoon_item_usable_by_player(item,other),
		"外账号绑定原件可借新对象生成流程洗掉归属");
	object case_owner=create_player("xd92testunitmooncase","LSQ2026");
	object case_other=create_player("xd91testunitmooncase","lsq2026");
	object case_item=clone(newmoon_path());
	int case_bound=ITEMSD->bind_newmoon_item_to_player(
		case_item,case_owner,"equip");
	check("注册账号绑定严格区分大小写",
		case_bound==2 &&
		case_item->query_newmoon_account_bind_owner()=="LSQ2026" &&
		!ITEMSD->newmoon_item_usable_by_player(case_item,case_other),
		"大小写不同的注册账号被错误视为同一归属");
	destruct(case_item);
	destroy_player(case_owner);
	destroy_player(case_other);
	object restricted=clone(newmoon_path());
	restricted->set_item_canDrop(0);
	restricted->set_item_canTrade(0);
	restricted->set_item_canSend(0);
	int restricted_bound=ITEMSD->bind_newmoon_item_to_player(
		restricted,player,"equip");
	string restricted_id=(string)restricted->query_newmoon_account_bind_id();
	int restricted_rollback=ITEMSD->rollback_newmoon_item_binding(
		restricted,player,restricted_id);
	check("未持久化绑定回滚不会抬高装备原始流通权限",
		restricted_bound==2 && restricted_rollback &&
		!restricted->query_newmoon_account_bound() &&
		restricted->query_item_canDrop()==0 &&
		restricted->query_item_canTrade()==0 &&
		restricted->query_item_canSend()==0,
		"绑定回滚把原本受限的装备错误恢复成可流通");
	destruct(restricted);
	object|zero original_player=this_player();
	set_this_player(player);
	string detail=item->query_content();
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	check("装备详情同时向新旧前端说明绑定与共享仓库规则",
		search(detail,"【账号绑定】")!=-1 &&
		search(detail,"同注册账号共享仓库可用")!=-1 &&
		search(detail,"不可丢弃、赠送、交易或拍卖")!=-1,
		"服务端装备详情缺少可见的绑定规则");
	string saved=pikenv_save_object(item,1);
	object restored=clone(newmoon_path());
	pikenv_restore_object(restored,saved);
	check("账号绑定凭据和流通权限随装备实例存档往返",
		restored->query_newmoon_account_bound() &&
		restored->query_newmoon_account_bind_owner()=="xd99moonaccount" &&
		restored->query_newmoon_account_bind_id()==binding_id &&
		restored->query_item_canTrade()==0 &&
		restored->query_item_canStorage()==1,
		sprintf("bound=%d owner=%O id=%O/%O trade=%d storage=%d saved=%d",
			restored->query_newmoon_account_bound(),
			restored->query_newmoon_account_bind_owner(),
			restored->query_newmoon_account_bind_id(),binding_id,
			restored->query_item_canTrade(),
			restored->query_item_canStorage(),
			search(saved,"binding")));
	object normal=clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	int normal_result=ITEMSD->bind_newmoon_item_to_player(
		normal,player,"equip");
	check("普通旧装备不进入新月绑定系统且原权限不变",
		normal_result==1 && normal->query_item_canTrade()==1 &&
		normal->query_item_canSend()==1 && normal->query_item_canDrop()==1,
		"非新月装备受到绑定规则污染");
	destruct(normal);
	destruct(restored);
	destroy_player(player);
	destroy_player(other);
}

void test_first_equip_and_legacy_migration()
{
	object player=create_player("xd97testunitmoonwear","xd97moonaccount");
	object item=clone(newmoon_path());
	item->move(player);
	int worn=player->wield(item);
	check("真实首次穿戴入口先持久化账号绑定再装备",
		worn!=0 && item->equiped && item->query_newmoon_account_bound() &&
		item->query_newmoon_account_bind_owner()=="xd97moonaccount" &&
		Stdio.file_size(DATA_ROOT+"u/ar/xd97testunitmoonwear.o")>0,
		"wield入口未绑定、未装备或未保存");
	destroy_player(player);

	object legacy=create_player("xd96testunitmoonold","xd96moonaccount");
	object old_item=clone(newmoon_path());
	old_item->move(legacy);
	legacy->query_equip()[old_item->query_item_kind()]=old_item;
	old_item->equiped=1;
	int migrated=ITEMSD->bind_equipped_newmoon_items(
		legacy,"legacy_equip");
	check("上线迁移只绑定历史已穿戴的新月装备",
		migrated==1 && old_item->query_newmoon_account_bound() &&
		old_item->query_newmoon_account_bind_reason()=="legacy_equip",
		"历史穿戴装备没有迁移到账号绑定");
	object unused=clone(newmoon_path());
	unused->move(legacy);
	ITEMSD->bind_equipped_newmoon_items(legacy,"legacy_equip");
	check("上线迁移不提前绑定背包里尚未使用的新月掉落",
		!unused->query_newmoon_account_bound() &&
		unused->query_item_canTrade()==1,
		"未穿戴掉落被登录迁移误绑定");
	destroy_player(legacy);
}

void test_personal_storage_and_transfer_guards()
{
	object owner=create_player("xd95testunitmoonstore","xd95moonaccount");
	object receiver=create_player("xd94testunitmoonrecv","xd94moonaccount");
	object item=clone(newmoon_path());
	ITEMSD->bind_newmoon_item_to_player(item,owner,"socket");
	int stored=owner->packaged(item,owner->query_cangku_size())==0;
	destruct(item);
	array row=stored ? owner->packaged_items[0] : ({});
	object restored=stored ? owner->repackaged((string)row[0]) : 0;
	check("个人仓库以第10列快照完整保存新月绑定实例",
		stored && sizeof(row)==10 && mappingp(row[9]) &&
		row[9]["owner"]=="xd95moonaccount" && objectp(restored) &&
		restored->query_newmoon_account_bound() &&
		restored->query_newmoon_account_bind_owner()=="xd95moonaccount" &&
		restored->query_item_canTrade()==0 &&
		restored->query_item_canStorage()==1,
		"角色仓库存取洗掉绑定状态或禁止了共享存储");
	if(restored)
		restored->move(owner);
	owner->move(ROOT+"/gamelib/d/kunlunshan/wuge");
	receiver->move(ROOT+"/gamelib/d/kunlunshan/wuge");
	if(restored){
		// Defense in depth: even manually restored flags cannot bypass the
		// immutable binding marker in the transaction daemon.
		restored->set_item_canSend(1);
		restored->set_item_canTrade(1);
	}
	mapping gift=PLAYER_TRANSFERD->create_gift_offer(owner,receiver,
		restored ? (string)restored->query_name() : "",0);
	mapping trade=PLAYER_TRANSFERD->create_trade_offer(owner,receiver,
		restored ? (string)restored->query_name() : "",0,100);
	check("绑定装备即使权限字段被篡改也无法跨账号赠送或交易",
		!gift["ok"] && !trade["ok"],
		"不可变绑定标记未被交易事务守护进程复核");
	destroy_player(owner);
	destroy_player(receiver);
}

void test_mutation_reasons_and_entry_contracts()
{
	array(string) reasons=({"reforge","socket","artisan","pity",
		"choice","compensation"});
	int reasons_valid=1;
	object player=create_player("xd93testunitmoonreason","xd93moonaccount");
	foreach(reasons,string reason){
		object item=clone(newmoon_path());
		int status=ITEMSD->bind_newmoon_item_to_player(item,player,reason);
		if(status!=2 || item->query_newmoon_account_bind_reason()!=reason)
			reasons_valid=0;
		destruct(item);
	}
	object invalid=clone(newmoon_path());
	int invalid_status=ITEMSD->bind_newmoon_item_to_player(
		invalid,player,"client_supplied_reason");
	check("炼化镶嵌锻造保底自选补偿均使用受控绑定原因",
		reasons_valid && invalid_status==0 &&
		!invalid->query_newmoon_account_bound(),
		"绑定原因白名单可被客户端扩展或合法入口缺失");
	destruct(invalid);
	destroy_player(player);

	array(string) compile_paths=({
		"/gamelib/cmds/convert_equip_confirm.pike",
		"/gamelib/cmds/convert_equip_reset.pike",
		"/gamelib/cmds/equip_xiangqian_confirm.pike",
		"/gamelib/cmds/equip_xiangqian_change.pike",
		"/gamelib/cmds/vendue_confirm.pike",
		"/gamelib/single/daemons/auctiond.pike",
		"/gamelib/single/daemons/player_transferd.pike",
		"/gamelib/single/daemons/account_storaged.pike",
		"/gamelib/single/daemons/homed.pike",
		"/gamelib/single/daemons/artisand.pike",
	});
	array(string) failures=({});
	foreach(compile_paths,string path){
		mixed compile_error=catch{ compile_file(ROOT+path); };
		if(compile_error)
			failures+=({path+":"+describe_error(compile_error)});
	}
	check("新旧前端共用的炼化镶嵌交易拍卖仓库入口全部可编译",
		!sizeof(failures),failures*" | ");

	string reforge=Stdio.read_file(ROOT+
		"/gamelib/cmds/convert_equip_confirm.pike") || "";
	string reset=Stdio.read_file(ROOT+
		"/gamelib/cmds/convert_equip_reset.pike") || "";
	string socket_a=Stdio.read_file(ROOT+
		"/gamelib/cmds/equip_xiangqian_confirm.pike") || "";
	string socket_b=Stdio.read_file(ROOT+
		"/gamelib/cmds/equip_xiangqian_change.pike") || "";
	string auction=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/auctiond.pike") || "";
	string stale=Stdio.read_file(ROOT+
		"/gamelib/cmds/vendue_confirm.pike") || "";
	string home=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/homed.pike") || "";
	check("所有装备改造与市场最终写入口均有服务端绑定门禁",
		search(reforge,"newmoon_item_usable_by_player")!=-1 &&
		search(reforge,"\"reforge\"")!=-1 &&
		search(reset,"\"reforge\"")!=-1 &&
		search(socket_a,"\"socket\"")!=-1 &&
		search(socket_b,"\"socket\"")!=-1 &&
		search(auction,"newmoon_item_cross_account_blocked")!=-1 &&
		search(stale,"newmoon_item_cross_account_blocked")!=-1 &&
		search(home,"newmoon_item_cross_account_blocked")!=-1,
		"存在只依赖页面展示或遗漏二次确认的入口");
}

int main()
{
	werror("\n========== 新月有限自由交易绑定测试 ==========\n");
	test_raw_and_binding_core();
	test_first_equip_and_legacy_migration();
	test_personal_storage_and_transfer_guards();
	test_mutation_reasons_and_entry_contracts();
	werror("新月绑定测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
