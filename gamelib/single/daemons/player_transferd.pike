/**
 * 同房间玩家赠送/交易事务。
 *
 * 一个房间只属于一个 Worker，因此这里只处理对象身份完全相同的本地房间。
 * 跨房间或跨 Worker 请求失败关闭。最终确认期间同时占用双方账号运行锁，
 * 并按“先移出来源并保存、后发放并保存”的顺序避免崩溃产生装备或银两复制。
 */
#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define TRANSFER_LOG ROOT "/log/player_transfer.log"

private mapping(string:mapping(string:mixed)) gift_offers=([]);
private mapping(string:mapping(string:mixed)) batch_gift_offers=([]);
private mapping(string:mapping(string:mixed)) trade_offers=([]);
private Thread.Mutex transfer_offer_lock=Thread.Mutex();
private string ephemeral_runtime_nonce="";

/** Process-local identity used to invalidate serialized UI selections on reload. */
string query_ephemeral_runtime_nonce()
{
	object key=transfer_offer_lock->lock();
	if(ephemeral_runtime_nonce=="")
		ephemeral_runtime_nonce=String.string2hex(
			Crypto.Random.random_string(16));
	string value=ephemeral_runtime_nonce;
	destruct(key);
	return value;
}

private mapping(string:mixed) result(int ok,string code,string message)
{
	return (["ok":ok,"code":code,"message":message]);
}

private void audit(string transaction_id,string kind,string state,
	object first,object second,string detail)
{
	string line=sprintf("[%s] tx=%s kind=%s state=%s first=%s second=%s %s\n",
		MUD_TIMESD->get_mysql_timedesc(),transaction_id,kind,state,
		first ? (string)first->query_name() : "",
		second ? (string)second->query_name() : "",detail || "");
	Stdio.append_file(TRANSFER_LOG,line);
}

private string new_transaction_id(string kind,object first,object second)
{
	object hash=Crypto.SHA256();
	hash->update(kind+"|"+(string)first->query_name()+"|"+
		(string)second->query_name()+"|"+time()+"|"+
		String.string2hex(Crypto.Random.random_string(16)));
	return String.string2hex(hash->digest());
}

private void prune_offers(mapping(string:mapping(string:mixed)) offers)
{
	int now=time();
	foreach(indices(offers),string token){
		mapping offer=offers[token];
		if(!mappingp(offer) || (int)offer["expires_at"]<now)
			m_delete(offers,token);
	}
}

int same_local_room(object first,object second)
{
	object room;
	if(!first || !second || first==second)
		return 0;
	room=environment(first);
	return room && room==environment(second) &&
		LOGICALZONED->can_interact(first,second);
}

/** Resolve the exact zero-based non-VIP inventory occurrence rendered by UI. */
object query_owned_item(object owner,string item_name,int item_index)
{
	int current;
	if(!owner || !item_name || item_name=="" || item_index<0 ||
	   item_index>10000)
		return 0;
	foreach(all_inventory(owner),object item){
		if(!item || item->query_name()!=item_name || item->query_toVip())
			continue;
		if(current==item_index)
			return item;
		current++;
	}
	return 0;
}

private int inventory_amount(object owner,string item_name)
{
	int amount;
	foreach(all_inventory(owner),object item){
		if(!item || item->query_name()!=item_name || item->query_toVip())
			continue;
		amount+=item->is("combine_item") ? (int)item->amount : 1;
	}
	return amount;
}

private int save_player(object player)
{
	int saved;
	mixed err;
	if(!player || !functionp(player->save_with_result))
		return 0;
	err=catch{ saved=player->save_with_result(); };
	return !err && saved;
}

private object try_counterparty_lock(object actor,object counterparty)
{
	object actor_mutex=ACCOUNT_CHARACTERD->query_account_runtime_mutex(
		(string)actor->query_name());
	object other_mutex=ACCOUNT_CHARACTERD->query_account_runtime_mutex(
		(string)counterparty->query_name());
	if(actor_mutex==other_mutex)
		return 0;
	return other_mutex->trylock();
}

private int move_to_recipient(object item,object recipient,int amount)
{
	string item_name;
	int before;
	if(!item || !recipient || amount<=0)
		return 0;
	if(!item->is("combine_item"))
		return item->move(recipient)==1 && environment(item)==recipient;
	item_name=(string)item->query_name();
	before=inventory_amount(recipient,item_name);
	item->move_player((string)recipient->query_name());
	return inventory_amount(recipient,item_name)-before==amount;
}

/** Remove an already delivered item and reconstruct it at the source on rollback. */
private int restore_delivered_item(object recipient,object source,object item,
	string item_name,string item_path,int amount,int combine)
{
	if(!combine){
		if(item && environment(item)==recipient)
			return item->move(source)==1 && environment(item)==source;
		return 0;
	}
	if(item && environment(item)==recipient)
		return item->move(source)==1 && environment(item)==source;
	mapping(string:mixed) removed=
		recipient->remove_combine_item_transaction(item_name,amount);
	if(!(int)removed["ok"])
		return 0;
	object restored;
	mixed err=catch{ restored=clone(item_path); };
	if(err || !restored){
		recipient->rollback_combine_item_transaction(removed);
		return 0;
	}
	restored->amount=amount;
	if(restored->move(source)!=1 || environment(restored)!=source){
		destruct(restored);
		recipient->rollback_combine_item_transaction(removed);
		return 0;
	}
	return 1;
}

// 太古传承等拾取即绑定物：同一注册账号的人物之间允许直接转移，
// 跨账号仍按原绑定禁止。绑定归属以物品上的账号绑定标记为准。
private int same_account_bound_transfer(object item,object recipient)
{
	string bound_account;
	string recipient_account;
	if(!item || !functionp(item->query_bind_account_on_pickup) ||
	   !(int)item->query_bind_account_on_pickup() ||
	   !functionp(item->query_account_bind_owner) || !recipient)
		return 0;
	bound_account=(string)item->query_account_bind_owner();
	recipient_account=functionp(recipient->query_account_owner) ?
		(string)recipient->query_account_owner() : "";
	return bound_account!="" && recipient_account!="" &&
		bound_account==recipient_account;
}

private int transferable(object item,int gift,object first,object second)
{
	if(!item || item->query_toVip() || item->equiped)
		return 0;
	// Binding flags are also persisted on the item, but the immutable binding
	// marker is the authoritative defense against tampered or stale instances.
	if(ITEMSD->newmoon_item_cross_account_blocked(item))
		return 0;
	// 旧双重缩放时代的异常装备只允许所有者本人在登录时被替换为
	// 正常数据，不允许经赠送/交易转移给其他玩家（买家会 在自己
	// 登录时被换成正常数据，形成付款买虚高属性的诈骗向量）。
	if(ITEMSD->query_abnormal_gear_class(item)>=1)
		return 0;
	if(gift && (int)item->query_item_canSend()!=1 &&
	   !same_account_bound_transfer(item,second))
		return 0;
	if(!gift && (int)item->query_item_canTrade()!=1 &&
	   !same_account_bound_transfer(item,second))
		return 0;
	if(item->query_item_type()=="yushi" &&
	   ((int)first->query_level()<=8 || (int)second->query_level()<=8))
		return 0;
	return 1;
}

int can_batch_gift_item(object sender,object recipient,object item)
{
	return same_local_room(sender,recipient) &&
		item && environment(item)==sender &&
		transferable(item,1,sender,recipient);
}

mapping(string:mixed) create_batch_gift_offer(object sender,
	object recipient,array(object) requested_items)
{
	object offer_key;
	array(object) items=({});
	string token;
	if(!same_local_room(sender,recipient))
		return result(0,"not_local","赠送双方必须在同一房间");
	if(!arrayp(requested_items) || !sizeof(requested_items) ||
	   sizeof(requested_items)>20)
		return result(0,"invalid_items","每次请选择1至20件物品");
	foreach(requested_items,object item){
		if(search(items,item)!=-1 ||
		   !can_batch_gift_item(sender,recipient,item))
			return result(0,"invalid_item","赠送清单已经变化，请重新选择");
		items+=({item});
	}
	offer_key=transfer_offer_lock->lock();
	prune_offers(batch_gift_offers);
	token=new_transaction_id("batch_gift_offer",sender,recipient);
	batch_gift_offers[token]=(["sender":sender,"recipient":recipient,
		"items":items,"expires_at":time()+120]);
	destruct(offer_key);
	return (["ok":1,"code":"offered","message":"批量赠送请求已创建",
		"token":token,"count":sizeof(items)]);
}

private mapping consume_batch_gift_offer(string token,object sender,
	object recipient)
{
	object offer_key;
	mapping offer;
	if(!token || token=="")
		return ([]);
	offer_key=transfer_offer_lock->lock();
	prune_offers(batch_gift_offers);
	offer=batch_gift_offers[token];
	m_delete(batch_gift_offers,token);
	if(!mappingp(offer) || offer["sender"]!=sender ||
	   offer["recipient"]!=recipient)
		offer=([]);
	destruct(offer_key);
	return offer;
}

int cancel_batch_gift_offer(string token,object sender,object recipient)
{
	object offer_key;
	mapping offer;
	if(!token || token=="")
		return 0;
	offer_key=transfer_offer_lock->lock();
	prune_offers(batch_gift_offers);
	offer=batch_gift_offers[token];
	if(!mappingp(offer) || offer["sender"]!=sender ||
	   offer["recipient"]!=recipient){
		destruct(offer_key);
		return 0;
	}
	m_delete(batch_gift_offers,token);
	destruct(offer_key);
	return 1;
}

private int rollback_batch_gift(object recipient,object sender,
	array(mapping(string:mixed)) delivered)
{
	int ok=1;
	for(int index=sizeof(delivered)-1;index>=0;index--){
		mapping one=delivered[index];
		if(!restore_delivered_item(recipient,sender,one["item"],
		   (string)one["name"],(string)one["path"],(int)one["amount"],
		   (int)one["combine"]))
			ok=0;
	}
	return ok;
}

mapping(string:mixed) execute_batch_gift(object recipient,object sender,
	string offer_token)
{
	mapping offer;
	object lock_key;
	array(object) items;
	array(mapping(string:mixed)) delivered=({});
	string transaction_id;
	if(!same_local_room(recipient,sender))
		return result(0,"not_local","赠送双方必须在同一房间");
	offer=consume_batch_gift_offer(offer_token,sender,recipient);
	if(!sizeof(offer) || !arrayp(offer["items"]))
		return result(0,"offer_expired","批量赠送请求已失效，请重新发起");
	items=(array(object))offer["items"];
	lock_key=try_counterparty_lock(recipient,sender);
	if(ACCOUNT_CHARACTERD->query_account_runtime_mutex(
	   (string)recipient->query_name())!=
	   ACCOUNT_CHARACTERD->query_account_runtime_mutex(
	   (string)sender->query_name()) && !lock_key)
		return result(0,"counterparty_busy","对方正在执行其他操作，请稍后重试");
	if(!same_local_room(recipient,sender)){
		if(lock_key) destruct(lock_key);
		return result(0,"not_local","批量赠送请求已经失效");
	}
	foreach(items,object item)
		if(!can_batch_gift_item(sender,recipient,item)){
			if(lock_key) destruct(lock_key);
			return result(0,"invalid_item","赠送清单已经变化，请重新选择");
		}
	transaction_id=new_transaction_id("batch_gift",sender,recipient);
	foreach(items,object item){
		string name=(string)item->query_name();
		string path=(file_name(item)/"#")[0];
		int combine=(int)item->is("combine_item");
		int amount=combine ? (int)item->amount : 1;
		if(recipient->if_over_load(item) ||
		   !move_to_recipient(item,recipient,amount)){
			int rollback_ok=rollback_batch_gift(recipient,sender,delivered);
			audit(transaction_id,"batch_gift","delivery_failed",sender,
				recipient,"rollback="+rollback_ok);
			if(lock_key) destruct(lock_key);
			return result(0,"delivery_failed",
				"接收者背包空间不足或物品转移失败，已整体退回");
		}
		delivered+=({(["item":item,"name":name,"path":path,
			"amount":amount,"combine":combine])});
	}
	if(!save_player(sender)){
		int rollback_ok=rollback_batch_gift(recipient,sender,delivered);
		audit(transaction_id,"batch_gift","source_save_failed",sender,
			recipient,"count="+sizeof(delivered)+" rollback="+rollback_ok);
		if(lock_key) destruct(lock_key);
		return result(0,"source_save_failed","赠送保存失败，全部物品已退回");
	}
	if(!save_player(recipient)){
		int rollback_ok=rollback_batch_gift(recipient,sender,delivered);
		int restored=rollback_ok && save_player(sender);
		audit(transaction_id,"batch_gift","target_save_failed",sender,
			recipient,"count="+sizeof(delivered)+" rollback="+rollback_ok+
			" restored="+restored);
		if(lock_key) destruct(lock_key);
		return result(0,"target_save_failed","赠送保存失败，全部物品已退回");
	}
	audit(transaction_id,"batch_gift","committed",sender,recipient,
		"count="+sizeof(delivered));
	if(lock_key) destruct(lock_key);
	return (["ok":1,"code":"committed","message":"批量赠送成功",
		"count":sizeof(delivered),"transaction_id":transaction_id]);
}

mapping(string:mixed) create_gift_offer(object sender,object recipient,
	string item_name,int item_index)
{
	object offer_key;
	object item;
	string token;
	if(!same_local_room(sender,recipient))
		return result(0,"not_local","赠送双方必须在同一房间");
	item=query_owned_item(sender,item_name,item_index);
	if(!transferable(item,1,sender,recipient) || recipient->if_over_load(item))
		return result(0,"invalid_item","物品不可赠送或接收者背包已满");
	offer_key=transfer_offer_lock->lock();
	prune_offers(gift_offers);
	token=new_transaction_id("gift_offer",sender,recipient);
	gift_offers[token]=(["sender":sender,"recipient":recipient,"item":item,
		"item_name":item_name,"item_index":item_index,
		"expires_at":time()+120]);
	destruct(offer_key);
	return (["ok":1,"code":"offered","message":"赠送请求已创建",
		"token":token]);
}

mapping(string:mixed) create_trade_offer(object seller,object buyer,
	string item_name,int item_index,int silver)
{
	object offer_key;
	object item;
	string token;
	if(silver<=0 || silver>=9999999)
		return result(0,"invalid_price","交易价格无效");
	if(!same_local_room(seller,buyer))
		return result(0,"not_local","交易双方必须在同一房间");
	item=query_owned_item(seller,item_name,item_index);
	if(!transferable(item,0,seller,buyer) || buyer->if_over_load(item))
		return result(0,"invalid_item","物品不可交易或买家背包已满");
	offer_key=transfer_offer_lock->lock();
	prune_offers(trade_offers);
	token=new_transaction_id("trade_offer",seller,buyer);
	trade_offers[token]=(["seller":seller,"buyer":buyer,"item":item,
		"item_name":item_name,"item_index":item_index,"silver":silver,
		"expires_at":time()+120]);
	destruct(offer_key);
	return (["ok":1,"code":"offered","message":"交易请求已创建",
		"token":token]);
}

private int consume_gift_offer(string token,object sender,object recipient,
	string item_name,int item_index)
{
	object offer_key;
	mapping offer;
	if(!token || token=="")
		return 0;
	offer_key=transfer_offer_lock->lock();
	prune_offers(gift_offers);
	offer=gift_offers[token];
	m_delete(gift_offers,token);
	int valid=mappingp(offer) && offer["sender"]==sender &&
		offer["recipient"]==recipient && offer["item_name"]==item_name &&
		(int)offer["item_index"]==item_index &&
		offer["item"]==query_owned_item(sender,item_name,item_index);
	destruct(offer_key);
	return valid;
}

int cancel_gift_offer(string token,object sender,object recipient)
{
	object offer_key;
	mapping offer;
	if(!token || token=="")
		return 0;
	offer_key=transfer_offer_lock->lock();
	prune_offers(gift_offers);
	offer=gift_offers[token];
	if(!mappingp(offer) || offer["sender"]!=sender ||
	   offer["recipient"]!=recipient){
		destruct(offer_key);
		return 0;
	}
	m_delete(gift_offers,token);
	destruct(offer_key);
	return 1;
}

private int consume_trade_offer(string token,object seller,object buyer,
	string item_name,int item_index,int silver)
{
	object offer_key;
	mapping offer;
	if(!token || token=="")
		return 0;
	offer_key=transfer_offer_lock->lock();
	prune_offers(trade_offers);
	offer=trade_offers[token];
	m_delete(trade_offers,token);
	int valid=mappingp(offer) && offer["seller"]==seller && offer["buyer"]==buyer &&
		offer["item_name"]==item_name && (int)offer["item_index"]==item_index &&
		(int)offer["silver"]==silver &&
		offer["item"]==query_owned_item(seller,item_name,item_index);
	destruct(offer_key);
	return valid;
}

int cancel_trade_offer(string token,object seller,object buyer)
{
	object offer_key;
	mapping offer;
	if(!token || token=="")
		return 0;
	offer_key=transfer_offer_lock->lock();
	prune_offers(trade_offers);
	offer=trade_offers[token];
	if(!mappingp(offer) || offer["seller"]!=seller || offer["buyer"]!=buyer){
		destruct(offer_key);
		return 0;
	}
	m_delete(trade_offers,token);
	destruct(offer_key);
	return 1;
}

mapping(string:mixed) execute_gift(object recipient,object sender,
	string item_name,int item_index,void|string offer_token)
{
	object lock_key;
	object item;
	string transaction_id;
	string item_path;
	int amount;
	int combine;
	int rollback_ok;
	if(!same_local_room(recipient,sender))
		return result(0,"not_local","赠送双方必须在同一房间");
	if(!offer_token || !consume_gift_offer(offer_token,sender,recipient,
	   item_name,item_index))
		return result(0,"offer_expired","赠送请求已失效，请重新发起");
	lock_key=try_counterparty_lock(recipient,sender);
	if(ACCOUNT_CHARACTERD->query_account_runtime_mutex(
	   (string)recipient->query_name())!=
	   ACCOUNT_CHARACTERD->query_account_runtime_mutex(
	   (string)sender->query_name()) && !lock_key)
		return result(0,"counterparty_busy","对方正在执行其他操作，请稍后重试");
	if(!same_local_room(recipient,sender)){
		if(lock_key) destruct(lock_key);
		return result(0,"not_local","赠送请求已经失效");
	}
	item=query_owned_item(sender,item_name,item_index);
	if(!transferable(item,1,recipient,sender) ||
	   recipient->if_over_load(item)){
		if(lock_key) destruct(lock_key);
		return result(0,"invalid_item","物品不可赠送或接收者背包已满");
	}
	combine=(int)item->is("combine_item");
	amount=combine ? (int)item->amount : 1;
	item_path=(file_name(item)/"#")[0];
	transaction_id=new_transaction_id("gift",sender,recipient);
	if(!move_to_recipient(item,recipient,amount)){
		restore_delivered_item(recipient,sender,item,item_name,item_path,
			amount,combine);
		if(lock_key) destruct(lock_key);
		return result(0,"delivery_failed","物品转移失败");
	}
	// 来源档案先落盘；崩溃最多造成待人工补发，不能让来源档案保留副本。
	if(!save_player(sender)){
		rollback_ok=restore_delivered_item(recipient,sender,item,item_name,
			item_path,amount,combine);
		audit(transaction_id,"gift","source_save_failed",sender,recipient,
			"rollback="+rollback_ok);
		if(lock_key) destruct(lock_key);
		return result(0,"source_save_failed","赠送保存失败，物品已退回");
	}
	if(!save_player(recipient)){
		rollback_ok=restore_delivered_item(recipient,sender,item,item_name,
			item_path,amount,combine);
		int restored=rollback_ok && save_player(sender);
		audit(transaction_id,"gift","target_save_failed",sender,recipient,
			"rollback="+rollback_ok+" restored="+restored);
		if(lock_key) destruct(lock_key);
		return result(0,"target_save_failed","赠送保存失败，物品已退回");
	}
	audit(transaction_id,"gift","committed",sender,recipient,
		"item="+item_name+" amount="+amount);
	if(lock_key) destruct(lock_key);
	return (["ok":1,"code":"committed","message":"赠送成功",
		"item_name":item_name,"amount":amount,
		"transaction_id":transaction_id]);
}

mapping(string:mixed) execute_trade(object buyer,object seller,
	string item_name,int item_index,int silver,void|string offer_token)
{
	object lock_key;
	object item;
	string transaction_id;
	string item_path;
	int amount;
	int combine;
	int rollback_ok;
	if(silver<=0 || silver>=9999999)
		return result(0,"invalid_price","交易价格无效");
	if(!same_local_room(buyer,seller))
		return result(0,"not_local","交易双方必须在同一房间");
	if(!offer_token || !consume_trade_offer(offer_token,seller,buyer,item_name,
	   item_index,silver))
		return result(0,"offer_expired","交易请求已失效，请重新发起");
	lock_key=try_counterparty_lock(buyer,seller);
	if(ACCOUNT_CHARACTERD->query_account_runtime_mutex(
	   (string)buyer->query_name())!=
	   ACCOUNT_CHARACTERD->query_account_runtime_mutex(
	   (string)seller->query_name()) && !lock_key)
		return result(0,"counterparty_busy","对方正在执行其他操作，请稍后重试");
	if(!same_local_room(buyer,seller)){
		if(lock_key) destruct(lock_key);
		return result(0,"not_local","交易请求已经失效");
	}
	item=query_owned_item(seller,item_name,item_index);
	if(!transferable(item,0,buyer,seller) || buyer->if_over_load(item)){
		if(lock_key) destruct(lock_key);
		return result(0,"invalid_item","物品不可交易或买家背包已满");
	}
	if((int)buyer->query_account()<silver){
		if(lock_key) destruct(lock_key);
		return result(0,"insufficient_money","买家银两不足");
	}
	combine=(int)item->is("combine_item");
	amount=combine ? (int)item->amount : 1;
	item_path=(file_name(item)/"#")[0];
	transaction_id=new_transaction_id("trade",seller,buyer);
	// 资金阶段：物品先进入本进程临时保管，买家银两先扣除。
	if(item->move(this_object())!=1 || environment(item)!=this_object() ||
	   !buyer->pay_money(silver)){
		if(item && environment(item)==this_object())
			item->move(seller);
		if(lock_key) destruct(lock_key);
		return result(0,"funding_failed","交易资金准备失败");
	}
	if(!save_player(seller)){
		buyer->add_account(silver);
		item->move(seller);
		audit(transaction_id,"trade","source_funding_save_failed",seller,
			buyer,"item="+item_name+" amount="+amount);
		if(lock_key) destruct(lock_key);
		return result(0,"source_save_failed","交易保存失败，未完成扣款");
	}
	if(!save_player(buyer)){
		buyer->add_account(silver);
		item->move(seller);
		rollback_ok=save_player(seller);
		audit(transaction_id,"trade","buyer_funding_save_failed",seller,
			buyer,"rollback="+rollback_ok);
		if(lock_key) destruct(lock_key);
		return result(0,"buyer_save_failed","交易保存失败，费用与物品已退回");
	}
	// 结算阶段：卖家收款、买家收物，再分别落盘。
	seller->add_account(silver);
	if(!move_to_recipient(item,buyer,amount)){
		seller->del_account(silver);
		rollback_ok=restore_delivered_item(buyer,seller,item,item_name,item_path,
			amount,combine);
		buyer->add_account(silver);
		int seller_restored=rollback_ok && save_player(seller);
		int buyer_restored=save_player(buyer);
		audit(transaction_id,"trade","delivery_failed",seller,buyer,
			"rollback="+rollback_ok+" seller_saved="+seller_restored+
			" buyer_saved="+buyer_restored);
		if(lock_key) destruct(lock_key);
		return result(0,"delivery_failed","交易发放失败，费用与物品已退回");
	}
	int seller_saved=save_player(seller);
	int buyer_saved=seller_saved && save_player(buyer);
	if(!seller_saved || !buyer_saved){
		seller->del_account(silver);
		rollback_ok=restore_delivered_item(buyer,seller,item,item_name,item_path,
			amount,combine);
		buyer->add_account(silver);
		int seller_restored=rollback_ok && save_player(seller);
		int buyer_restored=save_player(buyer);
		audit(transaction_id,"trade","commit_save_failed",seller,buyer,
			"rollback="+rollback_ok+" seller_saved="+seller_restored+
			" buyer_saved="+buyer_restored);
		if(lock_key) destruct(lock_key);
		return result(0,"commit_save_failed","交易保存失败，费用与物品已退回");
	}
	audit(transaction_id,"trade","committed",seller,buyer,
		"item="+item_name+" amount="+amount+" silver="+silver);
	if(lock_key) destruct(lock_key);
	return (["ok":1,"code":"committed","message":"交易成功",
		"item_name":item_name,"amount":amount,"silver":silver,
		"transaction_id":transaction_id]);
}
