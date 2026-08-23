#!/usr/bin/env pike
/** 同账号多角色在线与独立共享仓库防复制回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

string storage_file(string account_id)
{
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".storage.json";
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_legacy_player(string userid,string password)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "共享仓库测试人物";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->packageLevel = 20;
	player->packaged_items = ({({
		"tongkuangshi","铜矿石","铜矿石",
		"material/tongkuangshi",0,0,150,
	})});
	player->save_with_result();
	return player;
}

int count_personal_id(object player,string item_id)
{
	int count = 0;
	if(!player || !arrayp(player->packaged_items))
		return 0;
	for(int i=0;i<sizeof(player->packaged_items);i++){
		array one = player->packaged_items[i];
		if(arrayp(one) && sizeof(one)>7 && one[7]==item_id)
			count++;
	}
	return count;
}

int main()
{
	string account_id = "xd99testunitshared";
	string child_id = "";
	string item_id = "";
	string valid_storage = "";
	object|zero root_player = 0;
	object|zero root_relogin = 0;
	object|zero child_player = 0;
	object original_player = this_player();
	array(object) extra_players = ({});
	werror("\n========== 账号共享仓库测试 ==========\n");
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		root_player = create_legacy_player(account_id,"testunit88");
		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		if(created["ok"])
			child_id = (string)created["character"]["id"];
		check("测试账号建立两个独立人物档案",
			created["ok"] && child_id!="",
			(string)(created["message"] || "子人物创建失败"));

		mapping initial = ACCOUNT_STORAGED->query_storage(root_player);
		if(initial["ok"] && sizeof((array)initial["personal_items"]))
			item_id = (string)initial["personal_items"][0][7];
		check("读取共享仓库只为旧仓库物品追加永久唯一ID",
			initial["ok"] && item_id!="" &&
			Stdio.file_size(storage_file(account_id))<=0 &&
			count_personal_id(root_player,item_id)==1,
			"旧人物仓库被迁移或唯一ID没有持久化");

		object expand_yushi=clone(ROOT+
			"/gamelib/clone/item/yushi/suiyu");
		expand_yushi->amount=25;
		expand_yushi->move(root_player);
		mapping expanded=ACCOUNT_STORAGED->purchase_capacity(root_player,20);
		int yushi_after_expand=YUSHID->query_physical_all_num(root_player);
		mapping stale_expand=ACCOUNT_STORAGED->purchase_capacity(root_player,20);
		mapping expanded_state=ACCOUNT_STORAGED->query_storage(root_player);
		check("共享仓库20格可按账号永久扩容且旧页面不能重复扣费",
			expanded["ok"] && (int)expanded_state["capacity"]==40 &&
			yushi_after_expand==5 && !stale_expand["ok"] &&
			YUSHID->query_physical_all_num(root_player)==5,
			sprintf("expanded=%O stale=%O state=%O",
				expanded,stale_expand,expanded_state));
		object rollback_yushi=clone(ROOT+
			"/gamelib/clone/item/yushi/suiyu");
		rollback_yushi->amount=20;
		rollback_yushi->move(root_player);
		int before_failed_expand=YUSHID->query_physical_all_num(root_player);
		mapping failed_expand=ACCOUNT_STORAGED->purchase_capacity(
			root_player,40,"before_storage_save");
		mapping after_failed_expand=ACCOUNT_STORAGED->query_storage(root_player);
		check("共享仓库扩容落盘失败会原路退玉且不改变容量",
			!failed_expand["ok"] &&
			(int)after_failed_expand["capacity"]==40 &&
			YUSHID->query_physical_all_num(root_player)==before_failed_expand,
			sprintf("failed=%O state=%O jade=%d/%d",failed_expand,
				after_failed_expand,
				YUSHID->query_physical_all_num(root_player),
				before_failed_expand));

		// 同一随机ID即使出现在其他存档字段，也不能冒充个人仓库所有权。
		root_player->desc = "事务恢复干扰值"+item_id;
		mapping interrupted_in = ACCOUNT_STORAGED->transfer_to_shared(
			root_player,item_id,"after_personal_save");
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping recovered_in = ACCOUNT_STORAGED->query_storage(root_player);
		check("人物转共享中断按仓库字段精确恢复且不受其他存档文本干扰",
			interrupted_in["pending"] && recovered_in["ok"] &&
			recovered_in["used"]==1 &&
			count_personal_id(root_player,item_id)==0 &&
			recovered_in["items"][0]["id"]==item_id,
			"中断恢复造成物品丢失或两端并存");

		mapping duplicate = ACCOUNT_STORAGED->transfer_to_shared(
			root_player,item_id);
		mapping after_duplicate = ACCOUNT_STORAGED->query_storage(root_player);
		check("重复点击转入请求不会复制或转移其他同名物品",
			!duplicate["ok"] && after_duplicate["used"]==1,
			"幂等边界没有拒绝已完成的物品ID");

		mapping interrupted_out = ACCOUNT_STORAGED->transfer_to_personal(
			root_player,item_id,"after_personal_save");
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping recovered_out = ACCOUNT_STORAGED->query_storage(root_player);
		check("共享转人物在目标保存后中断只确认一次",
			interrupted_out["pending"] && recovered_out["ok"] &&
			recovered_out["used"]==0 &&
			count_personal_id(root_player,item_id)==1,
			"恢复时重复写入人物仓库或错误回滚");

		mapping normal_in = ACCOUNT_STORAGED->transfer_to_shared(
			root_player,item_id);
		child_player = clone(GAMELIB_USER);
		child_player->set_name(child_id);
		child_player->set_project("gamelib");
		child_player->restore();
		child_player->set_raceId("third");
		child_player->set_profeId("fangshi");
		child_player->setup_player("third","fangshi");
		child_player->packageLevel = 20;
		child_player->save_with_result();
		mapping normal_out = ACCOUNT_STORAGED->transfer_to_personal(
			child_player,item_id);
		mapping final_state = ACCOUNT_STORAGED->query_storage(child_player);
		check("不同职业角色通过独立共享仓库移动而不是复制物品",
			normal_in["ok"] && normal_out["ok"] &&
			final_state["used"]==0 &&
			count_personal_id(root_player,item_id)==0 &&
			count_personal_id(child_player,item_id)==1,
			"账号内跨人物移动后唯一ID总数不是1");

		object gemmed_gear = clone(ROOT+
			"/gamelib/clone/item/decorate/70feicuipifeng/70feicuipifeng");
		object red_gem = clone(ROOT+
			"/gamelib/clone/item/bossdrop/nianshoulingshi");
		object blue_gem = clone(ROOT+
			"/gamelib/clone/item/bossdrop/nianshoulingshi2");
		object yellow_gem = clone(ROOT+
			"/gamelib/clone/item/bossdrop/nianshoulingshi3");
		gemmed_gear->set_baoshi("red",red_gem);
		gemmed_gear->set_aocao("red",0);
		gemmed_gear->set_baoshi("blue",blue_gem);
		gemmed_gear->set_aocao("blue",0);
		gemmed_gear->set_baoshi("yellow",yellow_gem);
		gemmed_gear->set_aocao("yellow",0);
		int gem_stored = !child_player->packaged(gemmed_gear,20);
		destruct(gemmed_gear);
		destruct(red_gem);
		destruct(blue_gem);
		destruct(yellow_gem);
		mapping gem_personal = ACCOUNT_STORAGED->query_storage(child_player);
		string gem_item_id = "";
		array gem_item_data = ({});
		foreach((array)gem_personal["personal_items"],array personal_item)
			if(sizeof(personal_item)>8 &&
			   (string)personal_item[3]==
			   "decorate/70feicuipifeng/70feicuipifeng"){
				gem_item_id = (string)personal_item[7];
				gem_item_data = personal_item;
				break;
			}
		object gem_relogin = clone(GAMELIB_USER);
		gem_relogin->set_name(child_id);
		gem_relogin->set_project("gamelib");
		gem_relogin->restore();
		int gem_snapshot_reloaded = 0;
		foreach((array)(gem_relogin->packaged_items || ({})),array disk_item)
			if(sizeof(disk_item)>8 && (string)disk_item[7]==gem_item_id &&
			   mappingp(disk_item[8]))
				gem_snapshot_reloaded = 1;
		destruct(gem_relogin);
		mapping gem_to_shared = ACCOUNT_STORAGED->transfer_to_shared(
			child_player,gem_item_id);
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping gem_shared_disk = ACCOUNT_STORAGED->query_storage(root_player);
		int gem_shared_reloaded = gem_shared_disk["ok"] &&
			sizeof((array)gem_shared_disk["items"])==1 &&
			mappingp(gem_shared_disk["items"][0]["data"][8]);
		mapping gem_to_root = ACCOUNT_STORAGED->transfer_to_personal(
			root_player,gem_item_id);
		object restored_gear = root_player->repackaged_by_storage_id(
			gem_item_id);
		check("镶嵌装备跨角色共享仓库后完整保留三色年兽灵石与凹槽",
			gem_stored && sizeof(gem_item_data)==9 &&
			mappingp(gem_item_data[8]) && gem_snapshot_reloaded &&
			gem_to_shared["ok"] && gem_shared_reloaded &&
			gem_to_root["ok"] && objectp(restored_gear) &&
			restored_gear->query_baoshi_by_id("red",0)==
				"bossdrop/nianshoulingshi" &&
			restored_gear->query_baoshi_by_id("blue",0)==
				"bossdrop/nianshoulingshi2" &&
			restored_gear->query_baoshi_by_id("yellow",0)==
				"bossdrop/nianshoulingshi3" &&
			restored_gear->query_aocao("red")==0 &&
			restored_gear->query_aocao_max("red")==1 &&
			restored_gear->query_aocao("blue")==0 &&
			restored_gear->query_aocao_max("blue")==1 &&
			restored_gear->query_aocao("yellow")==0 &&
			restored_gear->query_aocao_max("yellow")==1,
			"仓库快照、永久ID或跨人物重建丢失了镶嵌状态");
		if(restored_gear)
			destruct(restored_gear);

		object vip_gear = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		vip_gear->set_toVip(1);
		vip_gear->move(child_player);
		object personal_browser = (object)(ROOT+
			"/gamelib/cmds/personal_storage.pike");
		array vip_rows = personal_browser->query_backpack_rows(
			child_player,"equip","");
		int vip_visible = 0;
		foreach(vip_rows,mapping vip_row)
			if(vip_row["object"]==vip_gear)
				vip_visible = 1;
		object vip_consumable = clone(ROOT+
			"/gamelib/clone/item/food/jinchuangyao");
		vip_consumable->set_toVip(1);
		vip_consumable->move(child_player);
		array vip_all_rows = personal_browser->query_backpack_rows(
			child_player,"all","");
		int vip_consumable_visible = 0;
		foreach(vip_all_rows,mapping vip_row)
			if(vip_row["object"]==vip_consumable)
				vip_consumable_visible = 1;
		int vip_consumable_stored = !child_player->packaged(
			vip_consumable,20);
		int vip_stored = !child_player->packaged(vip_gear,20);
		destruct(vip_gear);
		mapping vip_personal = ACCOUNT_STORAGED->query_storage(child_player);
		string vip_item_id = "";
		array vip_item_data = ({});
		foreach((array)vip_personal["personal_items"],array personal_item)
			if(sizeof(personal_item)>11 &&
			   (string)personal_item[3]=="weapon/1taomujian/1taomujian" &&
			   (int)personal_item[11]==1){
				vip_item_id = (string)personal_item[7];
				vip_item_data = copy_value(personal_item);
				break;
			}
		mapping vip_to_shared = ACCOUNT_STORAGED->transfer_to_shared(
			child_player,vip_item_id);
		mapping vip_to_root = ACCOUNT_STORAGED->transfer_to_personal(
			root_player,vip_item_id);
		object restored_vip = root_player->repackaged_by_storage_id(
			vip_item_id);
		check("会员绑定装备可经共享仓库在同账号人物间流转且不洗白",
			vip_visible && !vip_consumable_visible &&
			!vip_consumable_stored && environment(vip_consumable)==child_player &&
			vip_stored && sizeof(vip_item_data)==12 &&
			vip_to_shared["ok"] && vip_to_root["ok"] &&
			objectp(restored_vip) && restored_vip->query_toVip()==1 &&
			restored_vip->query_item_canTrade()==1,
			sprintf("visible=%d stored=%d row=%O in=%O out=%O restored=%O vip=%d",
				vip_visible,vip_stored,vip_item_data,vip_to_shared,vip_to_root,
				restored_vip,restored_vip ? restored_vip->query_toVip() : -1));
		check("会员绑定装备仍禁止同账号直接赠送以保持跨账号强绑定边界",
			objectp(restored_vip) && restored_vip->query_toVip()==1 &&
			!PLAYER_TRANSFERD->can_batch_gift_item(
				root_player,child_player,restored_vip),
			"会员标记可能被共享仓库存取洗掉或直接赠送绕过");
		if(restored_vip)
			destruct(restored_vip);
		if(vip_consumable)
			destruct(vip_consumable);

		object newmoon_gear = clone(ROOT+
			"/gamelib/clone/item/weapon/69xinyuetianfengjian/69xinyuetianfengjian");
		newmoon_gear->move(child_player);
		int newmoon_bound = ITEMSD->bind_newmoon_item_to_player(
			newmoon_gear,child_player,"socket");
		int newmoon_stored = !child_player->packaged(newmoon_gear,20);
		destruct(newmoon_gear);
		mapping newmoon_personal = ACCOUNT_STORAGED->query_storage(
			child_player);
		string newmoon_item_id = "";
		array newmoon_item_data = ({});
		foreach((array)newmoon_personal["personal_items"],array personal_item)
			if(sizeof(personal_item)>9 && (string)personal_item[3]==
			   "weapon/69xinyuetianfengjian/69xinyuetianfengjian"){
				newmoon_item_id = (string)personal_item[7];
				newmoon_item_data = copy_value(personal_item);
				break;
			}
		mapping newmoon_to_shared = ACCOUNT_STORAGED->transfer_to_shared(
			child_player,newmoon_item_id);
		mapping newmoon_to_root = ACCOUNT_STORAGED->transfer_to_personal(
			root_player,newmoon_item_id);
		object restored_newmoon = root_player->repackaged_by_storage_id(
			newmoon_item_id);
		check("账号绑定新月装备经同账号共享仓库跨人物后保持绑定",
			newmoon_bound==2 && newmoon_stored &&
			sizeof(newmoon_item_data)==10 &&
			mappingp(newmoon_item_data[9]) &&
			newmoon_item_data[9]["owner"]==account_id &&
			newmoon_to_shared["ok"] && newmoon_to_root["ok"] &&
			objectp(restored_newmoon) &&
			restored_newmoon->query_newmoon_account_bound() &&
			restored_newmoon->query_newmoon_account_bind_owner()==account_id &&
			restored_newmoon->query_item_canTrade()==0 &&
			restored_newmoon->query_item_canStorage()==1,
			"绑定快照在角色仓库或共享仓库往返中丢失");
		if(restored_newmoon)
			destruct(restored_newmoon);

		object starshine_gear = clone(ROOT+
			"/gamelib/clone/item/weapon/69xinyuetianfengjian/69xinyuetianfengjian");
		int starshine_marked = starshine_gear->
			set_newmoon_collection("starshine");
		int starshine_bound = ITEMSD->bind_newmoon_item_to_player(
			starshine_gear,child_player,"socket");
		int starshine_stored = !child_player->packaged(starshine_gear,20);
		destruct(starshine_gear);
		mapping starshine_personal = ACCOUNT_STORAGED->query_storage(
			child_player);
		string starshine_item_id = "";
		array starshine_item_data = ({});
		foreach((array)starshine_personal["personal_items"],
		   array personal_item)
			if(sizeof(personal_item)>10 &&
			   (string)personal_item[10]["collection_id"]=="starshine"){
				starshine_item_id=(string)personal_item[7];
				starshine_item_data=copy_value(personal_item);
				break;
			}
		mapping starshine_to_shared=ACCOUNT_STORAGED->transfer_to_shared(
			child_player,starshine_item_id);
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping starshine_shared=ACCOUNT_STORAGED->query_storage(root_player);
		array starshine_filtered=ACCOUNT_STORAGED->query_filtered_storage_items(
			(array)starshine_shared["items"],"take","set","");
		int starshine_shared_snapshot=0;
		foreach((array)starshine_shared["items"],mapping shared_item)
			if((string)shared_item["id"]==starshine_item_id &&
			   sizeof((array)shared_item["data"])==11 &&
			   shared_item["data"][10]["collection_id"]=="starshine")
				starshine_shared_snapshot=1;
		mapping starshine_to_root=ACCOUNT_STORAGED->transfer_to_personal(
			root_player,starshine_item_id);
		object restored_starshine=root_player->repackaged_by_storage_id(
			starshine_item_id);
		check("账号绑定曜星装备跨共享仓库保持绑定与二阶品质双快照",
			starshine_marked && starshine_bound==2 && starshine_stored &&
			sizeof(starshine_item_data)==11 &&
			mappingp(starshine_item_data[9]) &&
			starshine_item_data[9]["owner"]==account_id &&
			mappingp(starshine_item_data[10]) &&
			starshine_item_data[10]["collection_id"]=="starshine" &&
			starshine_to_shared["ok"] && starshine_shared_snapshot &&
			starshine_to_root["ok"] && objectp(restored_starshine) &&
			restored_starshine->query_newmoon_account_bound() &&
			restored_starshine->query_newmoon_account_bind_owner()==account_id &&
			restored_starshine->query_newmoon_collection_id()=="starshine" &&
			restored_starshine->query_newmoon_collection_rank()==2,
			"绑定或集合快照在角色/共享仓库往返中丢失");
		check("共享仓库套装筛选与普通装备分开",
			sizeof(starshine_filtered)==1,
			sprintf("set filtered=%d",sizeof(starshine_filtered)));
		if(restored_starshine)
			destruct(restored_starshine);

		array foreign_bound_data = copy_value(newmoon_item_data);
		foreign_bound_data[7] = "";
		foreign_bound_data[9]["owner"] = "xd98foreignaccount";
		child_player->packaged_items += ({foreign_bound_data});
		mapping foreign_personal = ACCOUNT_STORAGED->query_storage(
			child_player);
		string foreign_item_id = (string)foreign_personal["personal_items"][-1][7];
		mapping foreign_to_shared = ACCOUNT_STORAGED->transfer_to_shared(
			child_player,foreign_item_id);
		check("共享仓库拒绝绑定归属与当前注册账号不一致的装备",
			!foreign_to_shared["ok"] &&
			search((string)foreign_to_shared["message"],"不属于当前注册账号")!=-1,
			"跨账号绑定快照进入了共享仓库");
		if(sizeof(child_player->packaged_items)>1)
			child_player->packaged_items = child_player->packaged_items[
				..sizeof(child_player->packaged_items)-2];
		else
			child_player->packaged_items = ({});

		mapping put_back = ACCOUNT_STORAGED->transfer_to_shared(
			child_player,item_id);
		mapping before_reconcile = ACCOUNT_STORAGED->
			query_storage(child_player);
		child_player->packaged_items += ({copy_value(
			before_reconcile["items"][0]["data"])});
		child_player->save_with_result();
		int reconciled = ACCOUNT_STORAGED->
			reconcile_player_login(child_player);
		mapping after_reconcile = ACCOUNT_STORAGED->
			query_storage(child_player);
		check("登录恢复旧角色备份时删除共享仓库已有ID的克隆影子",
			put_back["ok"] && reconciled &&
			after_reconcile["used"]==1 &&
			count_personal_id(child_player,item_id)==0,
			"角色旧备份与共享仓库同时保留了相同物品ID");

		object storage_ui =
			(object)(ROOT+"/gamelib/cmds/account_storage.pike");
		object storage_take =
			(object)(ROOT+"/gamelib/cmds/account_storage_withdraw.pike");
		object storage_put =
			(object)(ROOT+"/gamelib/cmds/account_storage_deposit.pike");
		object storage_batch =
			(object)(ROOT+"/gamelib/cmds/account_storage_batch.pike");
		child_player->move(ROOT+"/gamelib/d/kunlunshan/wuge");
		set_this_player(child_player);
		storage_ui->main(0);
		storage_ui->main("personal");
		storage_ui->main("shared");
		storage_ui->main("put 999");
		storage_ui->main("take 999");
		storage_take->main(item_id+" 0");
		mapping ui_taken = ACCOUNT_STORAGED->query_storage(child_player);
		int ui_taken_personal =
			count_personal_id(child_player,item_id);
		storage_put->main(item_id+" 0");
		mapping ui_returned = ACCOUNT_STORAGED->query_storage(child_player);
		if(original_player)
			set_this_player(original_player);
		else
			set_this_player(this_object());
		check("共享仓库新旧入口、分页和连续取放真实运行",
			ui_taken["used"]==0 &&
			ui_taken_personal==1 &&
			count_personal_id(child_player,item_id)==0 &&
			ui_returned["used"]==1 &&
			ui_returned["items"][0]["id"]==item_id,
			"分页界面或带页码的连续取放没有保持唯一物品");
		array extra_personal = ({
			"tiekuangshi","铁矿石","铁矿石",
			"material/tiekuangshi",0,0,150,
		});
		child_player->packaged_items += ({extra_personal});
		child_player->save_with_result();
		mapping before_batch_put = ACCOUNT_STORAGED->
			query_storage(child_player);
		array batch_personal = before_batch_put["personal_items"];
		array(string) batch_put_ids = ({});
		foreach(batch_personal,array personal)
			batch_put_ids += ({(string)personal[7]});
		string batch_put_token = storage_ui->account_storage_batch_token(
			"put",(int)before_batch_put["revision"],batch_put_ids);
		set_this_player(child_player);
		storage_batch->main("put 0 "+batch_put_token);
		mapping after_batch_put = ACCOUNT_STORAGED->
			query_storage(child_player);
		check("本页批量放入逐件事务化转移且不复制物品",
			after_batch_put["used"]==2 &&
			!sizeof(child_player->packaged_items),
			"批量放入后共享仓库或角色仓库数量异常");
		array stale_page_item = ({
			"tongkuangshi","铜矿石","铜矿石",
			"material/tongkuangshi",0,0,150,
		});
		child_player->packaged_items += ({stale_page_item});
		child_player->save_with_result();
		set_this_player(child_player);
		storage_batch->main("put 0 "+batch_put_token);
		mapping after_duplicate_batch = ACCOUNT_STORAGED->
			query_storage(child_player);
		check("重复点击同一批量链接不会继续移动下一批物品",
			after_duplicate_batch["used"]==2 &&
			sizeof(child_player->packaged_items)==1,
			"过期批量令牌未被拦截");
		array shared_batch_items = after_batch_put["items"];
		array(string) batch_take_ids = ({});
		foreach(shared_batch_items,mapping shared_item)
			batch_take_ids += ({(string)shared_item["id"]});
		string batch_take_token = storage_ui->account_storage_batch_token(
			"take",(int)after_batch_put["revision"],batch_take_ids);
		set_this_player(child_player);
		storage_batch->main("take 0 "+batch_take_token);
		mapping after_batch_take = ACCOUNT_STORAGED->
			query_storage(child_player);
		check("本页批量取回按角色容量逐件安全保存",
			after_batch_take["used"]==0 &&
			sizeof(child_player->packaged_items)==3,
			"批量取回后共享仓库或角色仓库数量异常");
		object personal_ui =
			(object)(ROOT+"/gamelib/cmds/personal_storage.pike");
		object personal_batch =
			(object)(ROOT+"/gamelib/cmds/personal_storage_batch.pike");
		object token_stack = clone(ROOT+
			"/gamelib/clone/item/yushi/suiyu");
		token_stack->amount = 3;
		string stack_token_before = personal_ui->
			personal_storage_object_token(token_stack);
		token_stack->amount = 4;
		string stack_token_after = personal_ui->
			personal_storage_object_token(token_stack);
		check("背包堆叠数量变化会使旧批量页面令牌失效",
			stack_token_before!=stack_token_after &&
			sizeof(stack_token_before)==64 && sizeof(stack_token_after)==64,
			"物品数量未进入背包页面快照令牌");
		check("仓库搜索词展示转义界面控制字符但保留中文",
			personal_ui->personal_storage_safe_display(
				"技能[领取:x]书") == "技能［领取：x］书",
			"搜索词仍可构造伪按钮或转义破坏中文");
		destruct(token_stack);
		object skill_book = clone(ROOT+
			"/gamelib/clone/item/book/lingzhen");
		skill_book->move(child_player);
		array backpack_books = personal_ui->query_backpack_rows(
			child_player,"book","lingzhen");
		array(string) direct_tokens = sizeof(backpack_books) ?
			({(string)backpack_books[0]["token"]}) : ({});
		string direct_token = personal_ui->personal_storage_batch_token(
			"share","book","lingzhen",direct_tokens);
		child_player["/tmp/personal_storage/category"] = "book";
		child_player["/tmp/personal_storage/keyword"] = "lingzhen";
		set_this_player(child_player);
		personal_batch->main("share 0 "+direct_token);
		mapping after_direct_share = ACCOUNT_STORAGED->
			query_storage(child_player);
		array filtered_books = ACCOUNT_STORAGED->
			query_filtered_storage_items((array)after_direct_share["items"],
			"take","book","lingzhen");
		object stale_book = clone(ROOT+
			"/gamelib/clone/item/book/lingzhen");
		stale_book->move(child_player);
		personal_batch->main("share 0 "+direct_token);
		mapping after_stale_direct = ACCOUNT_STORAGED->
			query_storage(child_player);
		check("背包技能书可按关键词批量直存共享且旧令牌不移动下一件",
			sizeof(backpack_books)==1 && after_direct_share["used"]==1 &&
			sizeof(filtered_books)==1 &&
			after_stale_direct["used"]==1 && objectp(stale_book) &&
			environment(stale_book)==child_player,
			"直接共享、技能书筛选或重复批量令牌边界错误");
		string direct_book_id = sizeof(filtered_books) ?
			(string)filtered_books[0]["id"] : "";
		mapping book_to_personal = ACCOUNT_STORAGED->
			transfer_to_personal(child_player,direct_book_id);
		array personal_books = personal_ui->query_personal_rows(
			child_player,"book","lingzhen");
		array(string) take_tokens = sizeof(personal_books) ?
			({(string)personal_books[0]["token"]}) : ({});
		string personal_take_token = personal_ui->
			personal_storage_batch_token("take","book","lingzhen",take_tokens);
		personal_batch->main("take 0 "+personal_take_token);
		mapping after_personal_take = ACCOUNT_STORAGED->
			query_storage(child_player);
		check("角色仓库技能书可按分类关键词批量取到背包",
			book_to_personal["ok"] && sizeof(personal_books)==1 &&
			!sizeof(ACCOUNT_STORAGED->query_filtered_storage_items(
				(array)after_personal_take["personal_items"],"put",
				"book","lingzhen")),
			"角色仓库筛选或批量取出没有使用永久物品ID");
		child_player["/tmp/personal_storage/category"] = "all";
		child_player["/tmp/personal_storage/keyword"] = "";
		if(stale_book)
			destruct(stale_book);
		mapping return_for_recovery = ACCOUNT_STORAGED->
			transfer_to_shared(child_player,item_id);
		valid_storage = Stdio.read_file(storage_file(account_id));
		Stdio.write_file(storage_file(account_id)+".bak",valid_storage);
		Stdio.write_file(storage_file(account_id),"{broken");
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping corrupt_health = ACCOUNT_STORAGED->
			query_storage_health(account_id);
		check("共享仓库主文件损坏时不自动恢复旧备份复活装备",
			put_back["ok"] && return_for_recovery["ok"] &&
			!corrupt_health["ok"],
			"过期备份被自动作为权威仓库读取");
		Stdio.write_file(storage_file(account_id),valid_storage);
		rm(storage_file(account_id)+".bak");
		ACCOUNT_STORAGED->drop_test_cache(account_id);

		object root_mutex = ACCOUNT_CHARACTERD->
			query_account_runtime_mutex(account_id);
		object child_mutex = ACCOUNT_CHARACTERD->
			query_account_runtime_mutex(child_id);
		check("同一注册账号的不同人物复用同一运行时互斥锁",
			root_mutex==child_mutex,
			"HTTP线程仍按人物ID并发执行");
		check("账号同时在线上限从配置热读取且当前默认在线上限",
			ACCOUNT_CHARACTERD->query_max_online_characters()==60 &&
			ACCOUNT_CHARACTERD->query_online_expansion_cost(19)==100 &&
			ACCOUNT_CHARACTERD->query_online_expansion_cost(20)==100 &&
			ACCOUNT_CHARACTERD->query_online_expansion_cost(21)==200 &&
			ACCOUNT_CHARACTERD->query_online_expansion_cost(25)==600 &&
			ACCOUNT_CHARACTERD->query_online_expansion_cost(29)==1000 &&
			ACCOUNT_CHARACTERD->query_online_expansion_cost(30)==1000 &&
			ACCOUNT_CHARACTERD->query_online_expansion_cost(59)==1000,
			"account_characters.conf没有生效");
		object root_key = root_mutex->lock();
		int root_login = ACCOUNT_CHARACTERD->
			prepare_character_login_locked(root_player);
		destruct(root_key);
		object child_key = child_mutex->lock();
		int child_login = ACCOUNT_CHARACTERD->
			prepare_character_login_locked(child_player);
		destruct(child_key);
		array(string) dual_online = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("配置允许时同账号不同职业人物可以同时在线",
			root_login && child_login &&
			search(dual_online,account_id)!=-1 &&
			search(dual_online,child_id)!=-1 &&
			sizeof(dual_online)==2,
			"第二人物登录错误清退了不同职业人物");

		root_relogin = clone(GAMELIB_USER);
		root_relogin->set_name(account_id);
		root_relogin->set_project("gamelib");
		root_relogin->restore();
		object relogin_key = root_mutex->lock();
		int same_character_login = ACCOUNT_CHARACTERD->
			prepare_character_login_locked(root_relogin);
		destruct(relogin_key);
		array(string) after_same_login = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("同一人物共用同一存档且任何配置下都不能双对象在线",
			same_character_login && !objectp(root_player) &&
			sizeof(after_same_login)==2 &&
			search(after_same_login,account_id)!=-1 &&
			search(after_same_login,child_id)!=-1,
			"同一人物重复登录可能并发保存同一个档案");

		// 用 test override 把上限设为 5，和原测试一致
	ACCOUNT_CHARACTERD->set_test_online_limit(account_id,5);
	array(array(string)) extra_professions = ({
			({"human","yushi"}),
			({"human","zhuxian"}),
			({"monst","kuangyao"}),
			({"monst","wuyao"}),
		});
		int extra_login_ok = 1;
		foreach(extra_professions,array(string) pair){
			mapping extra_created = ACCOUNT_CHARACTERD->create_character(
				account_id,pair[0],pair[1]);
			if(!extra_created["ok"]){
				extra_login_ok = 0;
				continue;
			}
			string extra_id = (string)extra_created["character"]["id"];
			object extra = clone(GAMELIB_USER);
			extra->set_name(extra_id);
			extra->set_project("gamelib");
			extra->restore();
			extra->set_raceId(pair[0]);
			extra->set_profeId(pair[1]);
			extra->setup_player(pair[0],pair[1]);
			extra->save_with_result();
			extra_players += ({extra});
			object extra_key = root_mutex->lock();
			if(!ACCOUNT_CHARACTERD->prepare_character_login_locked(extra))
				extra_login_ok = 0;
			destruct(extra_key);
		}
		array(string) five_online = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("第六个不同职业登录时按默认五人上限清退最早人物",
			extra_login_ok && sizeof(five_online)==5 &&
			!objectp(child_player) && objectp(root_relogin),
			"默认在线上限没有准确执行");
		mapping forced_logout = ACCOUNT_CHARACTERD->
			query_recent_forced_logout(child_id);
		check("在线上限清退留下短时拦截标记阻止旧标签页自动重登",
			(int)forced_logout["forced_logout"]==1 &&
			(string)forced_logout["reason"]=="online_limit_reached" &&
			(int)forced_logout["online_limit"]==5,
			sprintf("forced=%O",forced_logout));
		ACCOUNT_CHARACTERD->clear_recent_forced_logout(child_id);
		check("人物中心明确选择后可清除自动重登拦截",
			!(int)ACCOUNT_CHARACTERD->
				query_recent_forced_logout(child_id)["forced_logout"],
			"清除后仍被判定为上限清退");

		ACCOUNT_CHARACTERD->set_test_online_limit(account_id,1);
		int evicted_for_single = ACCOUNT_CHARACTERD->
			enforce_online_limit_now();
		array(string) single_online = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("配置切回一时热检查安全保存并清退四个超额人物",
			evicted_for_single==4 && sizeof(single_online)==1,
			"单人物安全模式没有恢复");
		ACCOUNT_CHARACTERD->set_test_online_limit(account_id,0);

		array(string) compile_files = ({
			"/gamelib/single/daemons/account_characterd.pike",
			"/gamelib/single/daemons/account_storaged.pike",
			"/gamelib/cmds/account_storage.pike",
			"/gamelib/cmds/account_storage_deposit.pike",
			"/gamelib/cmds/account_storage_withdraw.pike",
			"/gamelib/cmds/account_storage_batch.pike",
			"/gamelib/cmds/account_storage_filter.pike",
			"/gamelib/cmds/account_storage_expand.pike",
			"/gamelib/cmds/personal_storage.pike",
			"/gamelib/cmds/personal_storage_move.pike",
			"/gamelib/cmds/personal_storage_batch.pike",
			"/gamelib/cmds/personal_storage_filter.pike",
			"/lowlib/system/inherit/user.pike",
			"/lowlib/system/cmds/login_check.pike",
			"/gamelib/single/daemons/http_api_daemon.pike",
		});
		array(string) failures = ({});
		foreach(compile_files,string file){
			mixed compile_err = catch{ compile_file(ROOT+file); };
			if(compile_err)
				failures += ({file+": "+describe_error(compile_err)});
		}
		check("登录守卫与共享仓库文件由真实Pike运行时编译",
			!sizeof(failures),failures*" | ");
		string http_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/http_api_daemon.pike");
		string select_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/account_characters.pike");
		check("HTTP轮询拒绝被清退人物且明确选角可恢复进入",
			search(http_source,"query_recent_forced_logout")!=-1 &&
			search(http_source,"send_json(req,forced_logout,409)")!=-1 &&
			search(select_source,"clear_recent_forced_logout")!=-1,
			"HTTP 409拦截或明确选角清除链路缺失");
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("共享仓库测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(child_player)
		destruct(child_player);
	if(root_relogin)
		destruct(root_relogin);
	if(root_player)
		destruct(root_player);
	foreach(extra_players,object extra){
		if(extra)
			destruct(extra);
	}
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	if(child_id!="")
		cleanup_player(child_id);
	cleanup_player(account_id);
	werror("账号共享仓库：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
