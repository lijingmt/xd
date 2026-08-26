#!/usr/bin/env pike
/** 同房间双账号赠送/交易、重载守恒与跨 Worker 边界测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(string userid)
{
	string path=player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[本地双人事务] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[本地双人事务] ✗ %s: %s\n",name,detail);
	}
}

object create_player(string userid,string name_cn)
{
	cleanup_player(userid);
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn=name_cn;
	player->set_project("gamelib");
	player->setup("testunit-player-transfer");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=30;
	player->set_att_by_level();
	player->set_account(10000);
	return player;
}

object restore_player(string userid)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_project("gamelib");
	return player->restore() ? player : 0;
}

int item_amount(object player,string item_name)
{
	int amount;
	foreach(all_inventory(player),object item){
		if(!item || item->query_name()!=item_name)
			continue;
		amount+=item->is("combine_item") ? (int)item->amount : 1;
	}
	return amount;
}

void give_suiyu(object player,int amount)
{
	object item=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	item->amount=amount;
	if(item->move(player)!=1 || environment(item)!=player)
		error("test fixture could not move suiyu to player\n");
}

void discard_player(object|zero player)
{
	if(!player)
		return;
	if(functionp(player->discard_stale_worker_copy))
		player->discard_stale_worker_copy();
	else
		destruct(player);
}

int main()
{
	string sender_id="xd99transfer_sender";
	string receiver_id="xd99transfer_receiver";
	object sender;
	object receiver;
	object room=(object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object other_room=(object)(ROOT+"/gamelib/d/congxianzhen/suishizilu");
	string error_desc="";
	werror("\n========== 同房间玩家赠送/交易测试 ==========\n");
	mixed err=catch{
		sender=create_player(sender_id,"赠送测试甲");
		receiver=create_player(receiver_id,"赠送测试乙");
		sender->move(room);
		receiver->move(room);
		give_suiyu(sender,7);
		// 太古传承等拾取绑定物：同账号放行、跨账号仍拒绝。
		object alt=create_player("xd99transfer_sameacct","同账号小号");
		alt->set_account_owner(sender_id);
		alt->move(room);
		object bound=clone(ROOT+
			"/gamelib/clone/item/book/taigushanyin");
		bound->move(sender);
		bound->bind_to_account(sender);
		int same_account_ok=PLAYER_TRANSFERD->
			can_batch_gift_item(sender,alt,bound);
		int cross_account_ok=PLAYER_TRANSFERD->
			can_batch_gift_item(sender,receiver,bound);
		check("账号绑定传承物同账号可转移且跨账号仍禁止",
			same_account_ok && !cross_account_ok,
			sprintf("same=%d cross=%d",same_account_ok,
				cross_account_ok));
		if(bound)
			destruct(bound);
		discard_player(alt);
		cleanup_player("xd99transfer_sameacct");
		mapping gift_offer=PLAYER_TRANSFERD->create_gift_offer(sender,receiver,
			"suiyu",0);
		mapping gift=PLAYER_TRANSFERD->execute_gift(receiver,sender,
			"suiyu",0,(string)gift_offer["token"]);
		check("同房间赠送精确转移并同时保存双方档案",
			(int)gift_offer["ok"] && (int)gift["ok"] &&
			item_amount(sender,"suiyu")==0 &&
			item_amount(receiver,"suiyu")==7,
			(string)gift["message"]);
		mapping duplicate=PLAYER_TRANSFERD->execute_gift(receiver,sender,
			"suiyu",0,(string)gift_offer["token"]);
		check("重复确认不能再次生成同一批物品",
			!(int)duplicate["ok"] && item_amount(sender,"suiyu")==0 &&
			item_amount(receiver,"suiyu")==7,
			(string)duplicate["message"]);
		mapping trade_offer=PLAYER_TRANSFERD->create_trade_offer(receiver,
			sender,"suiyu",0,500);
		mapping trade=PLAYER_TRANSFERD->execute_trade(sender,receiver,
			"suiyu",0,500,(string)trade_offer["token"]);
		check("面对面交易同时结算物品与银两",
			(int)trade_offer["ok"] && (int)trade["ok"] &&
			item_amount(sender,"suiyu")==7 &&
			item_amount(receiver,"suiyu")==0 &&
			(int)sender->query_account()==9500 &&
			(int)receiver->query_account()==10500,
			(string)trade["message"]);
		object batch_weapon=clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		object batch_armor=clone(ROOT+
			"/gamelib/clone/item/armor/2caoxie/2caoxie");
		batch_weapon->move(sender);
		batch_armor->move(sender);
		mapping batch_offer=PLAYER_TRANSFERD->create_batch_gift_offer(
			sender,receiver,({batch_weapon,batch_armor}));
		mapping batch=PLAYER_TRANSFERD->execute_batch_gift(receiver,sender,
			(string)batch_offer["token"]);
		mapping repeated_batch=PLAYER_TRANSFERD->execute_batch_gift(
			receiver,sender,(string)batch_offer["token"]);
		check("批量赠送一次确认原子转移多件并保存双方",
			(int)batch_offer["ok"] && (int)batch["ok"] &&
			(int)batch["count"]==2 && environment(batch_weapon)==receiver &&
			environment(batch_armor)==receiver && !(int)repeated_batch["ok"],
			sprintf("offer=%O batch=%O repeated=%O",
				batch_offer,batch,repeated_batch));
		// 异常装备不可经赠送/交易转移：旧双重缩放存量只允许所有者
		// 在登录时被替换为正常数据，堵住买家付款买虚高属性的诈骗。
		object legacy_gear=clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		legacy_gear->set_attack_add(999999);
		legacy_gear->move(sender);
		mapping legacy_gift=PLAYER_TRANSFERD->create_gift_offer(sender,
			receiver,legacy_gear->query_name(),0);
		mapping legacy_trade=PLAYER_TRANSFERD->create_trade_offer(sender,
			receiver,legacy_gear->query_name(),0,100);
		check("异常装备禁止赠送与交易(待所有者登录矫正)",
			!(int)legacy_gift["ok"] && !(int)legacy_trade["ok"] &&
			environment(legacy_gear)==sender,
			sprintf("gift=%O trade=%O",legacy_gift,legacy_trade));
		destruct(legacy_gear);
		string vendue_source=Stdio.read_file(ROOT+
			"/gamelib/cmds/vendue_confirm.pike") || "";
		string homed_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/homed.pike") || "";
		check("拍卖与家园摆摊上架同样拒绝异常装备",
			search(vendue_source,"query_abnormal_gear_class")!=-1 &&
			search(homed_source,"query_abnormal_gear_class")!=-1,
			"vendue_confirm或homed缺少异常装备闸门");
		object stale_batch_weapon=clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		object stale_batch_armor=clone(ROOT+
			"/gamelib/clone/item/armor/2caoxie/2caoxie");
		stale_batch_weapon->move(sender);
		stale_batch_armor->move(sender);
		mapping stale_batch_offer=PLAYER_TRANSFERD->create_batch_gift_offer(
			sender,receiver,({stale_batch_weapon,stale_batch_armor}));
		destruct(stale_batch_weapon);
		object replacement_weapon=clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		replacement_weapon->move(sender);
		mapping stale_batch=PLAYER_TRANSFERD->execute_batch_gift(
			receiver,sender,(string)stale_batch_offer["token"]);
		check("批量赠送任一对象变化都会整体拒绝且不转移其余物品",
			(int)stale_batch_offer["ok"] && !(int)stale_batch["ok"] &&
			environment(stale_batch_armor)==sender &&
			environment(replacement_weapon)==sender,
			sprintf("offer=%O result=%O",stale_batch_offer,stale_batch));
		discard_player(sender);
		discard_player(receiver);
		sender=restore_player(sender_id);
		receiver=restore_player(receiver_id);
		check("重载唯一档案后物品与银两仍严格守恒",
			sender && receiver && item_amount(sender,"suiyu")==7 &&
			item_amount(receiver,"suiyu")==0 &&
			item_amount(receiver,"1taomujian")==1 &&
			item_amount(receiver,"2caoxie")==1 &&
			(int)sender->query_account()==9500 &&
			(int)receiver->query_account()==10500,
			"交易提交未同时持久化两份档案");
		sender->move(room);
		receiver->move(other_room);
		give_suiyu(receiver,2);
		mapping remote=PLAYER_TRANSFERD->execute_gift(sender,receiver,
			"suiyu",0,"invalid");
		check("跨房间或跨 Worker 请求不移动任何物品",
			!(int)remote["ok"] && item_amount(sender,"suiyu")==7 &&
			item_amount(receiver,"suiyu")==2,
			sprintf("%s sender=%d receiver=%d",(string)remote["message"],
				item_amount(sender,"suiyu"),item_amount(receiver,"suiyu")));
		receiver->move(room);
		mapping stale_offer=PLAYER_TRANSFERD->create_gift_offer(receiver,
			sender,"suiyu",0);
		object stale_item=PLAYER_TRANSFERD->query_owned_item(receiver,
			"suiyu",0);
		if(stale_item)
			destruct(stale_item);
		give_suiyu(receiver,2);
		mapping stale=PLAYER_TRANSFERD->execute_gift(sender,receiver,
			"suiyu",0,(string)stale_offer["token"]);
		check("发起后替换同名物品不能复用旧确认链接",
			(int)stale_offer["ok"] && !(int)stale["ok"] &&
			item_amount(sender,"suiyu")==7 && item_amount(receiver,"suiyu")==2,
			(string)stale["message"]);
		string transfer_source=Stdio.read_file(ROOT+
			"/gamelib/single/daemons/player_transferd.pike") || "";
		string batch_command_source=Stdio.read_file(ROOT+
			"/gamelib/cmds/batch_gift.pike") || "";
		string runtime_nonce=PLAYER_TRANSFERD->query_ephemeral_runtime_nonce();
		check("进程临时标识稳定且可使重启或跨 Worker 选择安全失效",
			runtime_nonce!="" && runtime_nonce==
				PLAYER_TRANSFERD->query_ephemeral_runtime_nonce(),
			"临时标识为空或同一进程内发生变化");
		check("批量选择状态不把活对象写进可序列化玩家临时档案",
			search(batch_command_source,
				"sender[\"/tmp/batch_gift/items\"]=selected_refs")!=-1 &&
			search(batch_command_source,
				"sender[\"/tmp/batch_gift/items\"]=selected;")==-1,
			"批量选择仍可能持久化对象引用");
		check("一次性确认凭证在并发点击下原子消费",
			search(transfer_source,
				"transfer_offer_lock->lock()")!=-1 &&
			search(transfer_source,"m_delete(gift_offers,token)")!=-1 &&
			search(transfer_source,"m_delete(trade_offers,token)")!=-1,
			"确认凭证缺少互斥保护或消费后未删除");
		array(string) compile_paths=({
			"/gamelib/single/daemons/player_transferd.pike",
			"/gamelib/cmds/trade.pike",
			"/gamelib/cmds/trade_daoju.pike",
			"/gamelib/cmds/sendother.pike",
			"/gamelib/cmds/sendother_to.pike",
			"/gamelib/cmds/sendother_daoju.pike",
			"/gamelib/cmds/sendother_daoju_to.pike",
			"/gamelib/cmds/sendother_ok.pike",
			"/gamelib/cmds/batch_gift.pike",
			"/gamelib/cmds/batch_gift_ok.pike",
		});
		int compiled=1;
		foreach(compile_paths,string path){
			mixed compile_err=catch{ program one=(program)(ROOT+path); };
			if(compile_err)
				compiled=0;
		}
		check("赠送与交易全部 Pike 入口可由真实运行时编译",compiled,
			"至少一个命令未通过 Pike 编译");
	};
	if(err)
		error_desc=describe_error(err);
	if(err)
		check("测试流程无运行时异常",0,error_desc);
	discard_player(sender);
	discard_player(receiver);
	cleanup_player(sender_id);
	cleanup_player(receiver_id);
	werror("同房间玩家赠送/交易：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
