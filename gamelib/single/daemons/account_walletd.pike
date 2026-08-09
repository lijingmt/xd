/**
 * 注册账号共享充值钱包。
 *
 * 只承接今后的现金充值折算余额；旧人物背包玉石、任务和掉落奖励继续
 * 归具体人物，不做隐式迁移。钱包以碎玉为最小单位，所有变动保留
 * 有界事务流水，损坏时失败关闭，禁止从可能过期的备份复活余额。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ACCOUNT_WALLET_VERSION 1
#define ACCOUNT_WALLET_MAX_BALANCE 1000000000000
#define ACCOUNT_WALLET_MAX_TRANSACTIONS 200
#define ACCOUNT_WALLET_MAX_FILE_SIZE (512*1024)
#define ACCOUNT_WALLET_CACHE_LIMIT 1024
#define ACCOUNT_LEGACY_FEE_CACHE_TTL 300
#define ACCOUNT_WALLET_REQUEST_TTL 1800
#define ACCOUNT_WALLET_MAX_REQUESTS 256
#define ACCOUNT_WALLET_MAX_DEBIT_REQUESTS 64

private Thread.Mutex account_wallet_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) account_wallet_cache = ([]);
private mapping(string:mapping(string:int)) account_legacy_fee_cache = ([]);

/** Authenticated map-worker ingress only: discard cross-process stale state. */
void invalidate_worker_account_cache(string account_id)
{
	object key;
	if(MAP_WORKERD->query_node_role()!="worker" ||
	   !valid_wallet_userid(account_id))
		return;
	key = account_wallet_lock->lock();
	m_delete(account_wallet_cache,account_id);
	m_delete(account_legacy_fee_cache,account_id);
	destruct(key);
}

private void cache_wallet_unlocked(string account_id,mapping record)
{
	if(!account_wallet_cache[account_id] &&
	   sizeof(account_wallet_cache)>=ACCOUNT_WALLET_CACHE_LIMIT){
		array(string) cached_ids = indices(account_wallet_cache);
		if(sizeof(cached_ids))
			m_delete(account_wallet_cache,cached_ids[0]);
	}
	account_wallet_cache[account_id] = copy_value(record);
}

private int valid_wallet_userid(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>64 ||
	   search(value,"..")!=-1)
		return 0;
	for(int i=0;i<sizeof(value);i++){
		int one = value[i];
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9'))
			continue;
		return 0;
	}
	return 1;
}

private int valid_wallet_txid(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	for(int i=0;i<sizeof(value);i++){
		int one = value[i];
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

private int valid_wallet_text(string value,int max_size)
{
	if(!stringp(value) || sizeof(value)>max_size ||
	   search(value,"\n")!=-1 || search(value,"\r")!=-1)
		return 0;
	return 1;
}

private string wallet_file_path(string account_id)
{
	if(!valid_wallet_userid(account_id))
		return "";
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".wallet.json";
}

private mapping(string:mixed) empty_wallet(string account_id)
{
	return ([
		"version":ACCOUNT_WALLET_VERSION,
		"account_id":account_id,
		"revision":0,
		"balance":0,
		"total_recharge_fee":0,
		"created_at":0,
		"updated_at":0,
		"transactions":({}),
		"recharge_requests":([]),
		"debit_requests":([]),
		"persisted":0,
	]);
}

private int valid_debit_receipt(string request_id,mapping receipt)
{
	if(!valid_wallet_txid(request_id) || !mappingp(receipt) ||
	   !valid_wallet_userid((string)receipt["character_id"]) ||
	   !intp(receipt["amount"]) || (int)receipt["amount"]<=0 ||
	   (int)receipt["amount"]>ACCOUNT_WALLET_MAX_BALANCE ||
	   !intp(receipt["created_at"]) ||
	   (int)receipt["created_at"]<=0 ||
	   !valid_wallet_text((string)(receipt["reason"] || ""),128))
		return 0;
	return 1;
}

private int valid_recharge_receipt(string request_id,mapping receipt)
{
	if(!valid_wallet_txid(request_id) || !mappingp(receipt) ||
	   !valid_wallet_userid((string)receipt["character_id"]) ||
	   !intp(receipt["fee"]) || (int)receipt["fee"]<=0 ||
	   (int)receipt["fee"]>100000000 ||
	   !intp(receipt["amount"]) ||
	   (int)receipt["amount"]!=(int)receipt["fee"]*10 ||
	   !intp(receipt["created_at"]) ||
	   (int)receipt["created_at"]<=0 ||
	   !valid_wallet_text((string)(receipt["operator"] || ""),64))
		return 0;
	return 1;
}

private int valid_wallet_transaction(mapping transaction)
{
	string type;
	string request_id;
	if(!mappingp(transaction) ||
	   !valid_wallet_txid((string)transaction["txid"]) ||
	   !valid_wallet_userid((string)transaction["character_id"]) ||
	   !intp(transaction["amount"]) ||
	   (int)transaction["amount"]<=0 ||
	   (int)transaction["amount"]>ACCOUNT_WALLET_MAX_BALANCE ||
	   !intp(transaction["balance_after"]) ||
	   (int)transaction["balance_after"]<0 ||
	   (int)transaction["balance_after"]>ACCOUNT_WALLET_MAX_BALANCE ||
	   !intp(transaction["created_at"]) ||
	   (int)transaction["created_at"]<=0 ||
	   !intp(transaction["fee"]) || (int)transaction["fee"]<0 ||
	   (int)transaction["fee"]>ACCOUNT_WALLET_MAX_BALANCE ||
	   !valid_wallet_text((string)(transaction["operator"] || ""),64) ||
	   !valid_wallet_text((string)(transaction["reason"] || ""),128))
		return 0;
	type = (string)transaction["type"];
	request_id = (string)(transaction["request_id"] || "");
	if(request_id!="" && !valid_wallet_txid(request_id))
		return 0;
	if(type=="recharge")
		return (int)transaction["fee"]>0 && request_id!="";
	return (type=="spend" || type=="refund") &&
		(int)transaction["fee"]==0;
}

private int valid_wallet_record(mapping record,string account_id)
{
	array transactions;
	mapping recharge_requests;
	mapping debit_requests;
	if(!mappingp(record) || record["account_id"]!=account_id ||
	   (int)record["version"]!=ACCOUNT_WALLET_VERSION ||
	   !intp(record["revision"]) || (int)record["revision"]<0 ||
	   !intp(record["balance"]) || (int)record["balance"]<0 ||
	   (int)record["balance"]>ACCOUNT_WALLET_MAX_BALANCE ||
	   !intp(record["total_recharge_fee"]) ||
	   (int)record["total_recharge_fee"]<0 ||
	   (int)record["total_recharge_fee"]>ACCOUNT_WALLET_MAX_BALANCE ||
	   !arrayp(record["transactions"]) ||
	   !mappingp(record["recharge_requests"]) ||
	   !mappingp(record["debit_requests"]))
		return 0;
	transactions = record["transactions"];
	recharge_requests = record["recharge_requests"];
	debit_requests = record["debit_requests"];
	if(sizeof(transactions)>ACCOUNT_WALLET_MAX_TRANSACTIONS)
		return 0;
	if(sizeof(recharge_requests)>ACCOUNT_WALLET_MAX_REQUESTS)
		return 0;
	if(sizeof(debit_requests)>ACCOUNT_WALLET_MAX_DEBIT_REQUESTS)
		return 0;
	foreach(transactions,mixed one)
		if(!mappingp(one) || !valid_wallet_transaction((mapping)one))
			return 0;
	foreach(indices(recharge_requests),string request_id)
		if(!mappingp(recharge_requests[request_id]) ||
		   !valid_recharge_receipt(request_id,
			(mapping)recharge_requests[request_id]))
			return 0;
	foreach(indices(debit_requests),string request_id)
		if(!mappingp(debit_requests[request_id]) ||
		   !valid_debit_receipt(request_id,
			(mapping)debit_requests[request_id]))
			return 0;
	return 1;
}

private mapping(string:mixed)|zero decode_wallet_file(string path,
	string account_id)
{
	string source;
	mixed decoded = 0;
	mixed err;
	if(Stdio.file_size(path)<=0 ||
	   Stdio.file_size(path)>ACCOUNT_WALLET_MAX_FILE_SIZE)
		return 0;
	source = Stdio.read_file(path);
	err = catch{ decoded = Standards.JSON.decode(source); };
	// v1 早期钱包没有幂等消费凭据；缺字段等价于空集合。
	if(!err && mappingp(decoded) && !mappingp(decoded["debit_requests"]))
		decoded["debit_requests"] = ([]);
	if(err || !mappingp(decoded) ||
	   !valid_wallet_record((mapping)decoded,account_id))
		return 0;
	decoded["persisted"] = 1;
	return decoded;
}

private mapping(string:mixed)|zero load_wallet_unlocked(string account_id)
{
	string path = wallet_file_path(account_id);
	mapping(string:mixed)|zero record;
	if(account_wallet_cache[account_id])
		return copy_value(account_wallet_cache[account_id]);
	record = decode_wallet_file(path,account_id);
	if(record){
		cache_wallet_unlocked(account_id,record);
		return copy_value(record);
	}
	// 余额备份可能落后于消费流水，绝不自动回退到旧备份。
	if(Stdio.file_size(path)>0 || Stdio.file_size(path+".bak")>0 ||
	   Stdio.file_size(path+".tmp")>0)
		return 0;
	return empty_wallet(account_id);
}

private int save_wallet_unlocked(mapping(string:mixed) record)
{
	string account_id = (string)record["account_id"];
	string path = wallet_file_path(account_id);
	string temp_path = path+".tmp";
	string backup_temp = path+".bak.tmp";
	mapping disk_record;
	string encoded;
	int live_size;
	int ok = 0;
	mixed err;
	if(path=="" || !valid_wallet_record(record,account_id))
		return 0;
	disk_record = copy_value(record);
	m_delete(disk_record,"persisted");
	disk_record["version"] = ACCOUNT_WALLET_VERSION;
	disk_record["updated_at"] = time();
	if((int)disk_record["created_at"]<=0)
		disk_record["created_at"] = time();
	encoded = Standards.JSON.encode(disk_record);
	mkdir(DATA_ROOT+"accounts");
	mkdir(dirname(path));
	err = catch{
		rm(temp_path);
		rm(backup_temp);
		if(Stdio.write_file(temp_path,encoded)>0 &&
		   Stdio.file_size(temp_path)==sizeof(encoded)){
			live_size = Stdio.file_size(path);
			if(live_size>0 && decode_wallet_file(path,account_id)){
				Stdio.cp(path,backup_temp);
				if(Stdio.file_size(backup_temp)==live_size &&
				   mv(backup_temp,path+".bak") &&
				   mv(temp_path,path))
					ok = Stdio.file_size(path)==sizeof(encoded);
			}
			else if(live_size<=0 && mv(temp_path,path))
				ok = Stdio.file_size(path)==sizeof(encoded);
		}
	};
	if(err)
		werror("[ACCOUNT_WALLETD] 共享充值钱包保存异常: %s\n",
			describe_error(err));
	if(!ok){
		rm(temp_path);
		rm(backup_temp);
		return 0;
	}
	record["persisted"] = 1;
	record["created_at"] = disk_record["created_at"];
	record["updated_at"] = disk_record["updated_at"];
	cache_wallet_unlocked(account_id,record);
	return 1;
}

private string resolve_player_account(object player)
{
	string character_id;
	string account_id;
	if(!player || !functionp(player->query_name) ||
	   !functionp(player->query_account_owner))
		return "";
	character_id = player->query_name();
	account_id = player->query_account_owner();
	if(!valid_wallet_userid(character_id) ||
	   !valid_wallet_userid(account_id) ||
	   !ACCOUNT_CHARACTERD->account_owns_character(
		account_id,character_id))
		return "";
	return account_id;
}

// 仅供已经完成登录校验的只读权益热路径使用。充值、消费和退款继续
// 使用上面的严格归属检查，不能以此入口改变钱包余额。
private string resolve_player_account_for_entitlement(object player)
{
	string character_id;
	string account_id;
	if(!player || !functionp(player->query_name) ||
	   !functionp(player->query_account_owner))
		return "";
	character_id=(string)player->query_name();
	account_id=(string)player->query_account_owner();
	if(!valid_wallet_userid(character_id) ||
	   !valid_wallet_userid(account_id))
		return "";
	return account_id;
}

string new_recharge_request_id()
{
	return sprintf("%010d",time())+
		String.string2hex(Crypto.Random.random_string(27));
}

private int recharge_request_is_fresh(string request_id)
{
	int issued_at;
	if(!valid_wallet_txid(request_id) ||
	   sscanf(request_id[0..9],"%d",issued_at)!=1)
		return 0;
	return issued_at<=time()+60 &&
		time()-issued_at<=ACCOUNT_WALLET_REQUEST_TTL;
}

private void prune_recharge_requests(mapping record)
{
	mapping requests = record["recharge_requests"];
	int cutoff = time()-ACCOUNT_WALLET_REQUEST_TTL;
	foreach(indices(requests),string request_id){
		mapping receipt = requests[request_id];
		if(!mappingp(receipt) || (int)receipt["created_at"]<cutoff)
			m_delete(requests,request_id);
	}
	record["recharge_requests"] = requests;
}

private string new_wallet_txid()
{
	return new_recharge_request_id();
}

private void append_transaction(mapping record,string type,
	string character_id,int amount,int fee,string operator,string reason,
	string request_id)
{
	array transactions = record["transactions"];
	transactions += ({([
		"txid":new_wallet_txid(),
		"type":type,
		"character_id":character_id,
		"amount":amount,
		"fee":fee,
		"request_id":request_id || "",
		"operator":operator || "system",
		"reason":reason || "",
		"balance_after":(int)record["balance"],
		"created_at":time(),
	])});
	if(sizeof(transactions)>ACCOUNT_WALLET_MAX_TRANSACTIONS)
		transactions = transactions[
			sizeof(transactions)-ACCOUNT_WALLET_MAX_TRANSACTIONS..];
	record["transactions"] = transactions;
}

private int read_saved_all_fee(string character_id)
{
	string path;
	string source;
	int result = 0;
	if(!valid_wallet_userid(character_id))
		return 0;
	path = DATA_ROOT+"u/"+character_id[sizeof(character_id)-2..]+
		"/"+character_id+".o";
	source = Stdio.read_file(path);
	if(!source)
		return 0;
	foreach(source/"\n",string line){
		int value;
		if(sscanf(line,"all_fee %d",value)==1 && value>result)
			result = value;
	}
	return result;
}

private int query_existing_account_fee(string account_id)
{
	int result = 0;
	foreach(ACCOUNT_CHARACTERD->query_character_ids(account_id),
		string character_id){
		object player = find_player(character_id);
		int value = player && functionp(player->query_all_fee) ?
			(int)player->query_all_fee() :
			read_saved_all_fee(character_id);
		if(value>result)
			result = value;
	}
	return result;
}

// 调用方已持有 account_wallet_lock。
private int query_legacy_account_fee_unlocked(string account_id)
{
	mapping(string:int)|zero cached_fee=
		account_legacy_fee_cache[account_id];
	if(cached_fee && (int)cached_fee["expires_at"]>time())
		return (int)cached_fee["fee"];
	int legacy_fee=query_existing_account_fee(account_id);
	if(!account_legacy_fee_cache[account_id] &&
	   sizeof(account_legacy_fee_cache)>=ACCOUNT_WALLET_CACHE_LIMIT){
		array(string) cached_ids=indices(account_legacy_fee_cache);
		if(sizeof(cached_ids))
			m_delete(account_legacy_fee_cache,cached_ids[0]);
	}
	account_legacy_fee_cache[account_id]=(["fee":legacy_fee,
		"expires_at":time()+ACCOUNT_LEGACY_FEE_CACHE_TTL]);
	return legacy_fee;
}

private void sync_online_recharge_total(object target,string account_id,
	int total_fee)
{
	array(object) players = ({});
	if(target)
		players += ({target});
	foreach(ACCOUNT_CHARACTERD->query_character_ids(account_id),
		string character_id){
		object player = find_player(character_id);
		if(player && search(players,player)==-1)
			players += ({player});
	}
	foreach(players,object player){
		if(!functionp(player->query_all_fee) ||
		   !functionp(player->set_all_fee))
			continue;
		if((int)player->query_all_fee()<total_fee)
			player->set_all_fee(total_fee);
		if(functionp(player->save_with_result))
			player->save_with_result();
	}
}

private void log_wallet(string account_id,string character_id,string type,
	int amount,int balance,string operator)
{
	string now = ctime(time());
	Stdio.append_file(ROOT+"/log/account_wallet.log",
		now[0..sizeof(now)-2]+" account="+account_id+
		" character="+character_id+" type="+type+
		" amount="+amount+" balance="+balance+
		" operator="+(operator || "system")+"\n");
}

mapping(string:mixed) query_wallet(object player)
{
	string account_id = resolve_player_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return (["ok":0,"message":"账号归属无效","balance":0]);
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(record)
		record = copy_value(record);
	destruct(key);
	if(!record)
		return (["ok":0,"message":"共享充值钱包数据异常","balance":0]);
	record["ok"] = 1;
	record["message"] = "";
	return record;
}

mapping(string:mixed) query_account_wallet(string account_id)
{
	mapping(string:mixed)|zero record;
	object key;
	if(!valid_wallet_userid(account_id))
		return (["ok":0,"message":"注册账号无效","balance":0]);
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(record)
		record = copy_value(record);
	destruct(key);
	if(!record)
		return (["ok":0,"message":"共享充值钱包数据异常","balance":0]);
	record["ok"] = 1;
	record["message"] = "";
	return record;
}

int query_balance(object player)
{
	mapping status = query_wallet(player);
	return status["ok"] ? (int)status["balance"] : 0;
}

// 打怪热路径只读取已缓存/已持久化的账号累计充值；钱包不存在或损坏
// 时安全回退到人物自身 all_fee，不改变旧单人物账号语义。
int query_total_recharge_fee(object player)
{
	string account_id;
	int personal_fee = 0;
	int total_fee;
	int legacy_fee;
	mapping(string:mixed)|zero record;
	mapping(string:int)|zero cached_fee;
	object key;
	if(player && functionp(player->query_all_fee))
		personal_fee = (int)player->query_all_fee();
	account_id = resolve_player_account_for_entitlement(player);
	if(account_id=="")
		return personal_fee;
	key = account_wallet_lock->lock();
	// 热路径不复制最多 200 条钱包流水。已缓存钱包只读累计值；没有
	// 钱包的旧账号则直接命中短期历史权益缓存，避免每次击杀 stat 文件。
	if(account_wallet_cache[account_id])
		total_fee=(int)account_wallet_cache[account_id][
			"total_recharge_fee"];
	else{
		cached_fee=account_legacy_fee_cache[account_id];
		if(cached_fee && (int)cached_fee["expires_at"]>time()){
			total_fee=(int)cached_fee["fee"];
			destruct(key);
			return total_fee>personal_fee ? total_fee : personal_fee;
		}
		record = load_wallet_unlocked(account_id);
		if(record)
			total_fee = (int)record["total_recharge_fee"];
	}
	if(total_fee<=0 && (record || account_wallet_cache[account_id])){
		// 旧账号在共享钱包上线前只有各人物档案中的 all_fee。
		// 钱包尚无累计值时低频聚合一次账号人物，避免在打怪热路径
		// 每次扫描磁盘，同时确保副职业继承主职业的历史捐赠权益。
		legacy_fee=query_legacy_account_fee_unlocked(account_id);
		if(legacy_fee>total_fee)
			total_fee = legacy_fee;
	}
	destruct(key);
	if(total_fee>personal_fee)
		return total_fee;
	return personal_fee;
}

mapping(string:mixed) credit_recharge_once(object player,int fee,
	string operator,string request_id)
{
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	int amount;
	int total_fee;
	object key;
	if(account_id=="" || fee<=0 || fee>100000000 ||
	   !valid_wallet_txid(request_id) ||
	   !valid_wallet_text(operator || "system",64))
		return (["ok":0,"message":"充值账号或金额无效"]);
	amount = fee*10;
	character_id = player->query_name();
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0,"message":"共享充值钱包数据异常，已停止入账"]);
	}
	mapping receipt = record["recharge_requests"][request_id];
	if(receipt){
		if(receipt["character_id"]!=character_id ||
		   (int)receipt["amount"]!=amount ||
		   (int)receipt["fee"]!=fee ||
		   (string)receipt["operator"]!=(operator || "system")){
			destruct(key);
			return (["ok":0,"message":"充值请求编号冲突，已停止入账"]);
		}
		mapping duplicate_result = ([
			"ok":1,
			"duplicate":1,
			"message":"本次充值请求已经处理，请勿重复提交",
			"account_id":account_id,
			"character_id":character_id,
			"amount":amount,
			"balance":(int)record["balance"],
			"total_recharge_fee":(int)record["total_recharge_fee"],
			"revision":(int)record["revision"],
		]);
		destruct(key);
		return duplicate_result;
	}
	if(!recharge_request_is_fresh(request_id)){
		destruct(key);
		return (["ok":0,"message":"充值确认已过期，请返回重新确认"]);
	}
	prune_recharge_requests(record);
	if(sizeof((mapping)record["recharge_requests"])>=
	   ACCOUNT_WALLET_MAX_REQUESTS){
		destruct(key);
		return (["ok":0,"message":"该账号短时充值请求过多，请稍后再试"]);
	}
	if((int)record["balance"]>ACCOUNT_WALLET_MAX_BALANCE-amount){
		destruct(key);
		return (["ok":0,"message":"共享充值钱包已达到安全上限"]);
	}
	total_fee = max((int)record["total_recharge_fee"],
		query_existing_account_fee(account_id));
	if(total_fee>ACCOUNT_WALLET_MAX_BALANCE-fee){
		destruct(key);
		return (["ok":0,"message":"账号累计充值已达到安全上限"]);
	}
	total_fee += fee;
	record["balance"] = (int)record["balance"]+amount;
	record["total_recharge_fee"] = total_fee;
	record["revision"] = (int)record["revision"]+1;
	record["recharge_requests"][request_id] = ([
		"character_id":character_id,
		"fee":fee,
		"amount":amount,
		"operator":operator || "system",
		"created_at":time(),
	]);
	append_transaction(record,"recharge",character_id,amount,fee,
		operator,"admin_recharge",request_id);
	if(!save_wallet_unlocked(record)){
		destruct(key);
		return (["ok":0,"message":"共享充值钱包保存失败，本次未入账"]);
	}
	mapping result = ([
		"ok":1,
		"duplicate":0,
		"message":"",
		"account_id":account_id,
		"character_id":character_id,
		"amount":amount,
		"balance":(int)record["balance"],
		"total_recharge_fee":total_fee,
		"revision":(int)record["revision"],
	]);
	destruct(key);
	sync_online_recharge_total(player,account_id,total_fee);
	log_wallet(account_id,character_id,"recharge",amount,
		(int)result["balance"],operator);
	return result;
}

mapping(string:mixed) credit_recharge(object player,int fee,
	string operator)
{
	return credit_recharge_once(player,fee,operator,
		new_recharge_request_id());
}

int debit_recharge(object player,int amount,string reason)
{
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || amount<0)
		return 0;
	if(amount==0)
		return 1;
	character_id = player->query_name();
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(!record || (int)record["balance"]<amount){
		destruct(key);
		return 0;
	}
	record["balance"] = (int)record["balance"]-amount;
	record["revision"] = (int)record["revision"]+1;
	append_transaction(record,"spend",character_id,amount,0,"system",reason,"");
	if(!save_wallet_unlocked(record)){
		destruct(key);
		return 0;
	}
	int balance = (int)record["balance"];
	destruct(key);
	log_wallet(account_id,character_id,"spend",amount,balance,"system");
	return 1;
}

// 跨人物/家园等多存档事务使用的幂等扣款。相同 request_id 只扣一次，
// 调用方完成自己的持久化后再 forget；失败回滚则使用 rollback。
mapping(string:mixed) debit_recharge_once(object player,int amount,
	string reason,string request_id)
{
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	mapping receipt;
	object key;
	if(account_id=="" || amount<=0 ||
	   !valid_wallet_txid(request_id) ||
	   !valid_wallet_text(reason || "",128))
		return (["ok":0,"message":"共享充值扣款参数无效"]);
	character_id = player->query_name();
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0,"message":"共享充值钱包数据异常"]);
	}
	receipt = record["debit_requests"][request_id];
	if(receipt){
		int matched = receipt["character_id"]==character_id &&
			(int)receipt["amount"]==amount && receipt["reason"]==reason;
		mapping result = ([
			"ok":matched,
			"duplicate":matched,
			"amount":matched ? amount : 0,
			"balance":(int)record["balance"],
			"message":matched ? "" : "共享充值扣款请求编号冲突",
		]);
		destruct(key);
		return result;
	}
	if(sizeof((mapping)record["debit_requests"])>=
	   ACCOUNT_WALLET_MAX_DEBIT_REQUESTS){
		destruct(key);
		return (["ok":0,"message":"账号待确认扣款过多，请稍后重试"]);
	}
	if((int)record["balance"]<amount){
		destruct(key);
		return (["ok":0,"message":"共享充值余额不足"]);
	}
	record["balance"] = (int)record["balance"]-amount;
	record["revision"] = (int)record["revision"]+1;
	record["debit_requests"][request_id] = ([
		"character_id":character_id,
		"amount":amount,
		"reason":reason,
		"created_at":time(),
	]);
	append_transaction(record,"spend",character_id,amount,0,"system",
		reason,request_id);
	if(!save_wallet_unlocked(record)){
		destruct(key);
		return (["ok":0,"message":"共享充值钱包保存失败，本次未扣款"]);
	}
	int balance = (int)record["balance"];
	destruct(key);
	log_wallet(account_id,character_id,"spend_once",amount,balance,"system");
	return (["ok":1,"duplicate":0,"amount":amount,
		"balance":balance,"message":""]);
}

int rollback_debit_recharge_once(object player,string request_id,
	string reason)
{
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	mapping receipt;
	object key;
	if(account_id=="" || !valid_wallet_txid(request_id) ||
	   !valid_wallet_text(reason || "",128))
		return 0;
	character_id = player->query_name();
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(!record){
		destruct(key);
		return 0;
	}
	receipt = record["debit_requests"][request_id];
	if(!receipt){
		destruct(key);
		return 1;
	}
	if(receipt["character_id"]!=character_id ||
	   (int)record["balance"]>ACCOUNT_WALLET_MAX_BALANCE-
	   (int)receipt["amount"]){
		destruct(key);
		return 0;
	}
	int amount = (int)receipt["amount"];
	record["balance"] = (int)record["balance"]+amount;
	record["revision"] = (int)record["revision"]+1;
	m_delete(record["debit_requests"],request_id);
	append_transaction(record,"refund",character_id,amount,0,"system",
		reason,request_id);
	if(!save_wallet_unlocked(record)){
		destruct(key);
		return 0;
	}
	int balance = (int)record["balance"];
	destruct(key);
	log_wallet(account_id,character_id,"rollback_once",amount,balance,
		"system");
	return 1;
}

int forget_debit_recharge_once(object player,string request_id)
{
	string account_id = resolve_player_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || !valid_wallet_txid(request_id))
		return 0;
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(!record){
		destruct(key);
		return 0;
	}
	if(!record["debit_requests"][request_id]){
		destruct(key);
		return 1;
	}
	m_delete(record["debit_requests"],request_id);
	if(!save_wallet_unlocked(record)){
		destruct(key);
		return 0;
	}
	destruct(key);
	return 1;
}

int refund_recharge(object player,int amount,string reason)
{
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || amount<=0)
		return 0;
	character_id = player->query_name();
	key = account_wallet_lock->lock();
	record = load_wallet_unlocked(account_id);
	if(!record ||
	   (int)record["balance"]>ACCOUNT_WALLET_MAX_BALANCE-amount){
		destruct(key);
		return 0;
	}
	record["balance"] = (int)record["balance"]+amount;
	record["revision"] = (int)record["revision"]+1;
	append_transaction(record,"refund",character_id,amount,0,"system",reason,"");
	if(!save_wallet_unlocked(record)){
		destruct(key);
		return 0;
	}
	int balance = (int)record["balance"];
	destruct(key);
	log_wallet(account_id,character_id,"refund",amount,balance,"system");
	return 1;
}

int reconcile_player_login(object player)
{
	mapping status = query_wallet(player);
	int total_fee;
	if(!status["ok"]){
		if(status["message"]=="账号归属无效")
			return 1;
		werror("[ACCOUNT_WALLETD] 玩家登录时共享钱包不可用: %s\n",
			player && functionp(player->query_name) ?
			player->query_name() : "unknown");
		// 钱包损坏时仅禁用共享余额，不应连带阻止人物登录。
		return 1;
	}
	total_fee = (int)status["total_recharge_fee"];
	if(total_fee>0 && functionp(player->query_all_fee) &&
	   functionp(player->set_all_fee) &&
	   (int)player->query_all_fee()<total_fee)
		player->set_all_fee(total_fee);
	return 1;
}

void drop_test_cache(string account_id)
{
	object key;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_wallet_lock->lock();
	m_delete(account_wallet_cache,account_id);
	m_delete(account_legacy_fee_cache,account_id);
	destruct(key);
}

void remove_test_wallet(string account_id)
{
	string path;
	object key;
	if(search(account_id,"testunit")==-1)
		return;
	path = wallet_file_path(account_id);
	key = account_wallet_lock->lock();
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
	m_delete(account_wallet_cache,account_id);
	m_delete(account_legacy_fee_cache,account_id);
	destruct(key);
}
