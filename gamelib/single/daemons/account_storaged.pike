/**
 * 注册账号共享仓库。
 *
 * 旧人物仓库 packaged_items 完整保留；只有玩家主动转移的条目进入账号
 * 级独立文件。每个条目使用永久随机ID，跨文件移动经过持久化中转事务，
 * 重复点击、并发请求和进程中断均不能让同一ID同时出现在两端。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ACCOUNT_STORAGE_VERSION 1
#define ACCOUNT_STORAGE_BASE_CAPACITY 20
#define ACCOUNT_STORAGE_MAX_CAPACITY 500
#define ACCOUNT_STORAGE_MAX_PENDING 32
#define ACCOUNT_STORAGE_MAX_FILE_SIZE (8*1024*1024)

private Thread.Mutex account_storage_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) account_storage_cache = ([]);

/** Authenticated map-worker ingress only: discard cross-process stale state. */
void invalidate_worker_account_cache(string account_id)
{
	object key;
	if(MAP_WORKERD->query_node_role()!="worker" ||
	   !valid_account_or_character_id(account_id))
		return;
	key = account_storage_lock->lock();
	m_delete(account_storage_cache,account_id);
	destruct(key);
}

private int valid_hex_id(string value)
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

private int valid_account_or_character_id(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>64)
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

private int valid_relative_item_path(string path)
{
	if(!path || sizeof(path)<1 || sizeof(path)>240 ||
	   path[0]=='/' || search(path,"..")!=-1)
		return 0;
	for(int i=0;i<sizeof(path);i++){
		int one = path[i];
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='/' || one=='_' ||
		   one=='-')
			continue;
		return 0;
	}
	return 1;
}

int valid_storage_filter_category(string category)
{
	return has_value(({"all","equip","book","material",
		"consumable","other"}),category);
}

private string storage_data_category(array data)
{
	string path;
	string root;
	if(!valid_personal_data(data))
		return "other";
	path = (string)data[3];
	root = sizeof(path/"/") ? (path/"/")[0] : path;
	if(has_value(({"weapon","armor","decorate","jewelry"}),root))
		return "equip";
	if(root=="book" || root=="peifang")
		return "book";
	if(has_value(({"material","duanzao","baoshi","yushi","feed",
	   "liandan"}),root))
		return "material";
	if(has_value(({"food","water","teyao","baoxiang","gift",
	   "zhongqiuyuebing","zongzi"}),root))
		return "consumable";
	return "other";
}

private int storage_data_matches_filter(array data,string category,
	string keyword)
{
	string haystack;
	if(!valid_personal_data(data) ||
	   !valid_storage_filter_category(category) || sizeof(keyword)>96)
		return 0;
	if(category!="all" && storage_data_category(data)!=category)
		return 0;
	if(keyword=="")
		return 1;
	haystack = lower_case((string)data[0]+" "+(string)data[1]+" "+
		(string)data[2]+" "+(string)data[3]);
	return search(haystack,lower_case(keyword))!=-1;
}

array query_filtered_storage_items(array source,string mode,
	string category,string keyword)
{
	array result = ({});
	if((mode!="put" && mode!="take") ||
	   !valid_storage_filter_category(category) || sizeof(keyword)>96)
		return result;
	for(int i=0;i<sizeof(source) && i<4096;i++){
		array data = ({});
		if(mode=="put" && arrayp(source[i]))
			data = (array)source[i];
		else if(mode=="take" && mappingp(source[i]) &&
		        arrayp(source[i]["data"]))
			data = (array)source[i]["data"];
		if(sizeof(data) &&
		   storage_data_matches_filter(data,category,keyword))
			result += ({copy_value(source[i])});
	}
	return result;
}

private string storage_file_path(string account_id)
{
	if(!valid_account_or_character_id(account_id))
		return "";
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".storage.json";
}

private mapping(string:mixed) empty_record(string account_id)
{
	return ([
		"version":ACCOUNT_STORAGE_VERSION,
		"account_id":account_id,
		"revision":0,
		"capacity":ACCOUNT_STORAGE_BASE_CAPACITY,
		"created_at":0,
		"updated_at":0,
		"items":({}),
		"pending":({}),
		"retired_ids":([]),
		"persisted":0,
	]);
}

private int valid_personal_data(array data)
{
	if(!arrayp(data) || sizeof(data)<7 ||
	   sizeof(data)>9 ||
	   !stringp(data[0]) || !stringp(data[1]) ||
	   !stringp(data[2]) || !stringp(data[3]) ||
	   !valid_relative_item_path((string)data[3]))
		return 0;
	if(sizeof(data)>7){
		if(!stringp(data[7]))
			return 0;
		string item_id = (string)data[7];
		if(item_id!="" && !valid_hex_id(item_id))
			return 0;
	}
	if(sizeof(data)>8){
		mapping snapshot;
		if(!mappingp(data[8]))
			return 0;
		snapshot = data[8];
		if(sizeof(snapshot)!=4 || (int)snapshot["version"]!=1)
			return 0;
		foreach(({"red","blue","yellow"}),string color){
			mapping one = snapshot[color];
			array gems;
			int free_count;
			int max_count;
			if(!mappingp(one) || sizeof(one)!=3 || !intp(one["free"]) ||
			   !intp(one["max"]) || !arrayp(one["gems"]))
				return 0;
			free_count = (int)one["free"];
			max_count = (int)one["max"];
			gems = one["gems"];
			if(max_count<0 || max_count>64 || free_count<0 ||
			   free_count>max_count || sizeof(gems)!=max_count-free_count)
				return 0;
			foreach(gems,mixed gem_path)
				if(!stringp(gem_path) ||
				   !valid_relative_item_path((string)gem_path))
					return 0;
		}
	}
	return 1;
}

private int valid_shared_item(mapping item)
{
	array data;
	if(!mappingp(item) || !arrayp(item["data"]) ||
	   !valid_hex_id((string)item["id"]))
		return 0;
	data = item["data"];
	if(sizeof(data)<8 || !valid_personal_data(data))
		return 0;
	if((string)data[7]!=(string)item["id"])
		return 0;
	return 1;
}

private int valid_pending(mapping pending)
{
	string direction;
	if(!mappingp(pending) ||
	   !valid_hex_id((string)pending["txid"]) ||
	   !mappingp(pending["item"]) ||
	   !valid_shared_item(pending["item"]) ||
	   !valid_account_or_character_id((string)pending["character_id"]))
		return 0;
	direction = (string)pending["direction"];
	return direction=="personal_to_shared" ||
		direction=="shared_to_personal";
}

private int valid_record(mapping record,string account_id)
{
	array items;
	array pending;
	mapping retired;
	multiset(string) active_ids = (<>);
	if(!mappingp(record) || record["account_id"]!=account_id ||
	   !arrayp(record["items"]) || !arrayp(record["pending"]) ||
	   !mappingp(record["retired_ids"]))
		return 0;
	if((int)record["version"]!=ACCOUNT_STORAGE_VERSION ||
	   (int)record["capacity"]<ACCOUNT_STORAGE_BASE_CAPACITY ||
	   (int)record["capacity"]>ACCOUNT_STORAGE_MAX_CAPACITY)
		return 0;
	items = record["items"];
	pending = record["pending"];
	retired = record["retired_ids"];
	if(sizeof(items)>(int)record["capacity"] ||
	   sizeof(pending)>ACCOUNT_STORAGE_MAX_PENDING)
		return 0;
	for(int i=0;i<sizeof(items);i++){
		string item_id;
		if(!valid_shared_item(items[i]))
			return 0;
		item_id = (string)items[i]["id"];
		if(active_ids[item_id])
			return 0;
		active_ids[item_id] = 1;
	}
	for(int i=0;i<sizeof(pending);i++){
		string item_id;
		string character_id;
		if(!valid_pending(pending[i]))
			return 0;
		character_id = (string)pending[i]["character_id"];
		if(!ACCOUNT_CHARACTERD->account_owns_character(
		   account_id,character_id))
			return 0;
		item_id = (string)pending[i]["item"]["id"];
		if(active_ids[item_id])
			return 0;
		active_ids[item_id] = 1;
	}
	foreach(indices(retired),string retired_id){
		if(!valid_hex_id(retired_id) || !intp(retired[retired_id]))
			return 0;
	}
	return 1;
}

private mapping(string:mixed)|zero decode_record_file(string path,
	string account_id)
{
	string source;
	mixed decoded = 0;
	mixed err;
	if(Stdio.file_size(path)<=0 ||
	   Stdio.file_size(path)>ACCOUNT_STORAGE_MAX_FILE_SIZE)
		return 0;
	source = Stdio.read_file(path);
	err = catch{
		decoded = Standards.JSON.decode(source);
	};
	if(err || !mappingp(decoded) || !valid_record(decoded,account_id))
		return 0;
	decoded["persisted"] = 1;
	return decoded;
}

private mapping(string:mixed)|zero load_record_unlocked(string account_id)
{
	string path = storage_file_path(account_id);
	mapping(string:mixed)|zero record;
	if(account_storage_cache[account_id])
		return copy_value(account_storage_cache[account_id]);
	record = decode_record_file(path,account_id);
	if(record){
		account_storage_cache[account_id] = copy_value(record);
		return copy_value(record);
	}
	// 仓库备份可能比人物存档旧，自动恢复会复活已取出的装备。
	// 任一物理代文件存在但主文件无效时必须失败关闭，由审计工具恢复。
	if(Stdio.file_size(path)>0 || Stdio.file_size(path+".bak")>0 ||
	   Stdio.file_size(path+".tmp")>0)
		return 0;
	return empty_record(account_id);
}

private int save_record_unlocked(mapping(string:mixed) record)
{
	string account_id = (string)record["account_id"];
	string path = storage_file_path(account_id);
	string dir = dirname(path);
	string temp_path = path+".tmp";
	string backup_temp = path+".bak.tmp";
	string encoded;
	mapping disk_record;
	int live_size;
	int ok = 0;
	mixed err;
	if(path=="" || !valid_record(record,account_id))
		return 0;
	disk_record = copy_value(record);
	m_delete(disk_record,"persisted");
	disk_record["version"] = ACCOUNT_STORAGE_VERSION;
	disk_record["updated_at"] = time();
	if((int)disk_record["created_at"]<=0)
		disk_record["created_at"] = time();
	encoded = Standards.JSON.encode(disk_record);
	mkdir(DATA_ROOT+"accounts");
	mkdir(dir);
	err = catch{
		rm(temp_path);
		rm(backup_temp);
		if(Stdio.write_file(temp_path,encoded)>0 &&
		   Stdio.file_size(temp_path)==sizeof(encoded)){
			live_size = Stdio.file_size(path);
			if(live_size>0 && decode_record_file(path,account_id)){
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
		werror("[ACCOUNT_STORAGED] 账号共享仓库保存异常: %s\n",
			describe_error(err));
	if(!ok){
		rm(temp_path);
		rm(backup_temp);
		return 0;
	}
	record["persisted"] = 1;
	record["updated_at"] = disk_record["updated_at"];
	record["created_at"] = disk_record["created_at"];
	account_storage_cache[account_id] = copy_value(record);
	return 1;
}

private string new_unique_id(multiset(string) used)
{
	for(int attempt=0;attempt<30;attempt++){
		string candidate = String.string2hex(
			Crypto.Random.random_string(32));
		if(!used[candidate])
			return candidate;
	}
	return "";
}

private string personal_item_id(array data)
{
	if(arrayp(data) && sizeof(data)>7 &&
	   valid_hex_id((string)data[7]))
		return (string)data[7];
	return "";
}

private int saved_personal_contains(string character_id,string item_id)
{
	string path;
	string content;
	mixed decoded = 0;
	mixed err;
	if(!character_id || sizeof(character_id)<2 || !valid_hex_id(item_id))
		return -1;
	path = DATA_ROOT+"u/"+character_id[sizeof(character_id)-2..]+
		"/"+character_id+".o";
	content = Stdio.read_file(path);
	if(!content)
		return -1;
	foreach(content/"\n",string line){
		if(!has_prefix(line,"packaged_items "))
			continue;
		err = catch{
			decoded = pikenv_decode_value(
				line[sizeof("packaged_items ")..]);
		};
		if(err || !arrayp(decoded))
			return -1;
		foreach((array)decoded,array personal){
			if(personal_item_id(personal)==item_id)
				return 1;
		}
		return 0;
	}
	return -1;
}

private int find_shared_index(array items,string item_id)
{
	for(int i=0;i<sizeof(items);i++){
		if(mappingp(items[i]) && items[i]["id"]==item_id)
			return i;
	}
	return -1;
}

private int find_pending_index(array pending,string txid)
{
	for(int i=0;i<sizeof(pending);i++){
		if(mappingp(pending[i]) && pending[i]["txid"]==txid)
			return i;
	}
	return -1;
}

private array remove_array_index(array source,int index)
{
	array result = source+({});
	if(index<0 || index>=sizeof(result))
		return result;
	result[index] = result[0];
	return result[1..sizeof(result)-1];
}

private void log_transfer(string account_id,string character_id,
	string direction,string item_id,string txid,string result)
{
	string now = ctime(time());
	Stdio.append_file(ROOT+"/log/account_storage.log",
		now[0..sizeof(now)-2]+" account="+account_id+
		" character="+character_id+" direction="+direction+
		" item="+item_id+" tx="+txid+" result="+result+"\n");
}

private int recover_pending_unlocked(mapping(string:mixed) record)
{
	array pending = record["pending"];
	array items = record["items"];
	array recovered = ({});
	int changed = 0;
	for(int i=0;i<sizeof(pending);i++){
		mapping one = pending[i];
		mapping item = one["item"];
		string item_id = (string)item["id"];
		string character_id = (string)one["character_id"];
		string direction = (string)one["direction"];
		int in_personal = saved_personal_contains(character_id,item_id);
		if(in_personal<0){
			recovered += ({one});
			continue;
		}
		if(direction=="personal_to_shared"){
			if(!in_personal && find_shared_index(items,item_id)==-1)
				items += ({item});
			changed = 1;
			log_transfer((string)record["account_id"],character_id,
				direction,item_id,(string)one["txid"],
				in_personal ? "recovered_rollback" :
				"recovered_commit");
		}
		else if(direction=="shared_to_personal"){
			if(!in_personal && find_shared_index(items,item_id)==-1)
				items += ({item});
			if(in_personal)
				record["retired_ids"][item_id] = time();
			changed = 1;
			log_transfer((string)record["account_id"],character_id,
				direction,item_id,(string)one["txid"],
				in_personal ? "recovered_commit" :
				"recovered_rollback");
		}
		else
			recovered += ({one});
	}
	if(!changed)
		return 1;
	record["items"] = items;
	record["pending"] = recovered;
	record["revision"] = (int)record["revision"]+1;
	return save_record_unlocked(record);
}

private mapping(string:mixed)|zero load_ready_record_unlocked(
	string account_id)
{
	mapping(string:mixed)|zero record = load_record_unlocked(account_id);
	if(!record)
		return 0;
	if(sizeof((array)record["pending"]) &&
	   !recover_pending_unlocked(record))
		return 0;
	return record;
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
	if(!account_id || !ACCOUNT_CHARACTERD->account_owns_character(
	   account_id,character_id))
		return "";
	return account_id;
}

private string resolve_login_account(object player)
{
	string character_id;
	string account_id;
	array(string) character_ids;
	if(!player || !functionp(player->query_name) ||
	   !functionp(player->query_account_owner))
		return "";
	character_id = player->query_name();
	account_id = player->query_account_owner();
	if(!character_id || !account_id)
		return "";
	character_ids = ACCOUNT_CHARACTERD->query_character_ids(account_id);
	if(!sizeof(character_ids) && character_id==account_id)
		return account_id;
	for(int i=0;i<sizeof(character_ids);i++){
		if(character_ids[i]==character_id)
			return account_id;
	}
	return "";
}

private int ensure_personal_ids_unlocked(object player,
	mapping(string:mixed) record)
{
	array original;
	array updated;
	multiset(string) used = (<>);
	int changed = 0;
	if(!arrayp(player->packaged_items))
		player->packaged_items = ({});
	original = copy_value(player->packaged_items);
	updated = copy_value(original);
	foreach((array)record["items"],mapping item)
		used[(string)item["id"]] = 1;
	foreach((array)record["pending"],mapping pending)
		used[(string)pending["item"]["id"]] = 1;
	for(int i=0;i<sizeof(updated);i++){
		string item_id;
		if(!valid_personal_data(updated[i]))
			return 0;
		item_id = personal_item_id(updated[i]);
		if(item_id!=""){
			if(used[item_id])
				return 0;
			used[item_id] = 1;
			continue;
		}
		item_id = new_unique_id(used);
		if(item_id=="")
			return 0;
		if(sizeof(updated[i])>7)
			updated[i][7] = item_id;
		else
			updated[i] += ({item_id});
		used[item_id] = 1;
		changed = 1;
	}
	if(!changed)
		return 1;
	player->packaged_items = updated;
	if(!functionp(player->save_with_result) ||
	   !player->save_with_result()){
		player->packaged_items = original;
		return 0;
	}
	return 1;
}

/**
 * 角色登录时检查旧个人存档备份是否复活了已经转入共享仓库的ID。
 * 账号共享仓库是该ID的权威所有者，发现重复时只删除角色仓库影子并立即
 * 保存；共享文件异常则保持不可访问，但不阻断人物正常登录。
 */
int reconcile_player_login(object player)
{
	string account_id = resolve_login_account(player);
	mapping(string:mixed)|zero record;
	array original;
	array cleaned = ({});
	multiset(string) shared_ids = (<>);
	multiset(string) personal_ids = (<>);
	object key;
	int changed = 0;
	if(account_id=="" || !arrayp(player->packaged_items))
		return 1;
	key = account_storage_lock->lock();
	record = load_ready_record_unlocked(account_id);
	if(!record){
		destruct(key);
		return 1;
	}
	foreach((array)record["items"],mapping item)
		shared_ids[(string)item["id"]] = 1;
	original = copy_value(player->packaged_items);
	for(int i=0;i<sizeof(original);i++){
		string item_id = personal_item_id(original[i]);
		if(item_id!="" && (shared_ids[item_id] || personal_ids[item_id])){
			changed = 1;
			continue;
		}
		if(item_id!="")
			personal_ids[item_id] = 1;
		cleaned += ({original[i]});
	}
	if(changed){
		string now;
		player->packaged_items = cleaned;
		if(!functionp(player->save_with_result) ||
		   !player->save_with_result()){
			player->packaged_items = original;
			destruct(key);
			return 0;
		}
		now = ctime(time());
		Stdio.append_file(ROOT+"/log/account_storage.log",
			now[0..sizeof(now)-2]+
			" account="+account_id+" character="+
			player->query_name()+
			" result=reconciled_stale_personal_duplicate\n");
	}
	destruct(key);
	return 1;
}

mapping(string:mixed) query_storage(object player)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"账号共享仓库暂不可用。",
	]);
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	object storage_key;
	if(account_id=="")
		return result;
	character_id = player->query_name();
	storage_key = account_storage_lock->lock();
	record = load_ready_record_unlocked(account_id);
	if(!record)
		result["message"] = "账号共享仓库数据校验失败，已停止存取以保护装备。";
	else if(!ensure_personal_ids_unlocked(player,record))
		result["message"] = "当前角色仓库存在重复或异常物品标识，已停止操作。";
	else{
		result = ([
			"ok":1,
			"message":"",
			"account_id":account_id,
			"character_id":character_id,
			"capacity":(int)record["capacity"],
			"used":sizeof((array)record["items"]),
			"items":copy_value(record["items"]),
			"personal_items":copy_value(player->packaged_items),
			"personal_capacity":player->query_cangku_size(),
			"personal_used":sizeof(player->packaged_items),
			"revision":(int)record["revision"],
			"persisted":(int)record["persisted"],
		]);
	}
	destruct(storage_key);
	return result;
}

private mapping shared_item_from_personal(array personal,string character_id)
{
	return ([
		"id":(string)personal[7],
		"data":copy_value(personal),
		"source_character":character_id,
		"created_at":time(),
	]);
}

mapping(string:mixed) transfer_to_shared(object player,string item_id,
	string|void test_failpoint)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"将物品放入账号共享仓库失败。",
	]);
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	array original_personal;
	array personal;
	mapping item;
	mapping pending;
	string txid;
	multiset(string) used = (<>);
	object storage_key;
	int personal_index = -1;
	if(account_id=="" || !valid_hex_id(item_id))
		return result;
	character_id = player->query_name();
	storage_key = account_storage_lock->lock();
	record = load_ready_record_unlocked(account_id);
	if(!record)
		result["message"] = "账号共享仓库数据异常，已停止存取。";
	else if(!ensure_personal_ids_unlocked(player,record))
		result["message"] = "当前角色仓库物品标识异常，已停止转移。";
	else if(sizeof((array)record["items"])>=(int)record["capacity"])
		result["message"] = "账号共享仓库已满。";
	else{
		personal = player->packaged_items;
		for(int i=0;i<sizeof(personal);i++){
			if(personal_item_id(personal[i])==item_id){
				personal_index = i;
				break;
			}
		}
		if(personal_index<0)
			result["message"] = "当前角色仓库中已没有这件物品，请刷新后重试。";
		else if(find_shared_index((array)record["items"],item_id)!=-1)
			result["message"] = "检测到重复物品标识，已停止转移。";
		else{
			foreach((array)record["items"],mapping shared)
				used[(string)shared["id"]] = 1;
			foreach((array)record["pending"],mapping one)
				used[(string)one["txid"]] = 1;
			txid = new_unique_id(used);
			item = shared_item_from_personal(
				personal[personal_index],character_id);
			pending = ([
				"txid":txid,
				"direction":"personal_to_shared",
				"character_id":character_id,
				"item":item,
				"created_at":time(),
			]);
			if(txid=="" || !valid_shared_item(item))
				result["message"] = "无法生成安全的物品转移编号。";
			else{
				record["pending"] += ({pending});
				record["revision"] = (int)record["revision"]+1;
				if(!save_record_unlocked(record))
					result["message"] = "账号共享仓库事务准备失败，物品未移动。";
				else{
					original_personal = copy_value(player->packaged_items);
					player->packaged_items = remove_array_index(
						player->packaged_items,personal_index);
					if(!functionp(player->save_with_result) ||
					   !player->save_with_result()){
						player->packaged_items = original_personal;
						record["pending"] = remove_array_index(
							record["pending"],find_pending_index(
								record["pending"],txid));
						save_record_unlocked(record);
						result["message"] = "当前角色仓库保存失败，物品未移动。";
					}
					else if(test_failpoint=="after_personal_save" &&
					        search(account_id,"testunit")!=-1){
						result["message"] = "测试中断点已保留待恢复事务。";
						result["pending"] = 1;
					}
					else{
						record["pending"] = remove_array_index(
							record["pending"],find_pending_index(
								record["pending"],txid));
						record["items"] += ({item});
						m_delete(record["retired_ids"],item_id);
						record["revision"] = (int)record["revision"]+1;
						if(save_record_unlocked(record)){
							result = ([
								"ok":1,
								"message":"物品已安全放入账号共享仓库。",
								"item_id":item_id,
								"txid":txid,
							]);
							log_transfer(account_id,character_id,
								"personal_to_shared",item_id,txid,
								"committed");
						}
						else{
							result["message"] =
								"人物已保存，转移事务将在重新打开宝库时自动完成。";
							result["pending"] = 1;
						}
					}
				}
			}
		}
	}
	destruct(storage_key);
	return result;
}

mapping(string:mixed) transfer_to_personal(object player,string item_id,
	string|void test_failpoint)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"将物品取到当前角色仓库失败。",
	]);
	string account_id = resolve_player_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	array original_personal;
	mapping item;
	mapping pending;
	string txid;
	multiset(string) used = (<>);
	object storage_key;
	int shared_index;
	if(account_id=="" || !valid_hex_id(item_id))
		return result;
	character_id = player->query_name();
	storage_key = account_storage_lock->lock();
	record = load_ready_record_unlocked(account_id);
	if(!record)
		result["message"] = "账号共享仓库数据异常，已停止存取。";
	else if(!ensure_personal_ids_unlocked(player,record))
		result["message"] = "当前角色仓库物品标识异常，已停止转移。";
	else if(sizeof(player->packaged_items)>=player->query_cangku_size())
		result["message"] = "当前角色仓库已满。";
	else{
		shared_index = find_shared_index((array)record["items"],item_id);
		if(shared_index<0)
			result["message"] = "账号共享仓库中已没有这件物品，请刷新后重试。";
		else{
			int duplicate = 0;
			for(int i=0;i<sizeof(player->packaged_items);i++){
				if(personal_item_id(player->packaged_items[i])==item_id){
					duplicate = 1;
					break;
				}
			}
			if(duplicate)
				result["message"] = "检测到重复物品标识，已停止转移。";
			else{
				foreach((array)record["items"],mapping shared)
					used[(string)shared["id"]] = 1;
				foreach((array)record["pending"],mapping one)
					used[(string)one["txid"]] = 1;
				txid = new_unique_id(used);
				item = record["items"][shared_index];
				pending = ([
					"txid":txid,
					"direction":"shared_to_personal",
					"character_id":character_id,
					"item":item,
					"created_at":time(),
				]);
				if(txid=="")
					result["message"] = "无法生成安全的物品转移编号。";
				else{
					record["items"] = remove_array_index(
						record["items"],shared_index);
					record["pending"] += ({pending});
					record["revision"] = (int)record["revision"]+1;
					if(!save_record_unlocked(record))
						result["message"] = "账号共享仓库事务准备失败，物品未移动。";
					else{
						original_personal = copy_value(player->packaged_items);
						player->packaged_items += ({copy_value(item["data"])});
						if(!functionp(player->save_with_result) ||
						   !player->save_with_result()){
							player->packaged_items = original_personal;
							record["pending"] = remove_array_index(
								record["pending"],find_pending_index(
									record["pending"],txid));
							record["items"] += ({item});
							save_record_unlocked(record);
							result["message"] = "当前角色仓库保存失败，物品仍在账号共享仓库。";
						}
						else if(test_failpoint=="after_personal_save" &&
						        search(account_id,"testunit")!=-1){
							result["message"] = "测试中断点已保留待恢复事务。";
							result["pending"] = 1;
						}
						else{
							record["pending"] = remove_array_index(
								record["pending"],find_pending_index(
									record["pending"],txid));
							record["retired_ids"][item_id] = time();
							record["revision"] = (int)record["revision"]+1;
							if(save_record_unlocked(record)){
								result = ([
									"ok":1,
									"message":"物品已安全取到当前角色仓库。",
									"item_id":item_id,
									"txid":txid,
								]);
								log_transfer(account_id,character_id,
									"shared_to_personal",item_id,txid,
									"committed");
							}
							else{
								result["message"] =
									"人物已保存，转移事务将在重新打开宝库时自动确认。";
								result["pending"] = 1;
							}
						}
					}
				}
			}
		}
	}
	destruct(storage_key);
	return result;
}

mapping(string:mixed) query_storage_health(string requested_id)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"account_id":"",
		"used":0,
		"capacity":0,
		"pending":0,
		"revision":0,
	]);
	string account_id = ACCOUNT_CHARACTERD->
		query_account_id_for_character(requested_id);
	mapping(string:mixed)|zero record;
	object key;
	if(!account_id)
		return result;
	key = account_storage_lock->lock();
	record = load_ready_record_unlocked(account_id);
	if(record)
		result = ([
			"ok":1,
			"account_id":account_id,
			"used":sizeof((array)record["items"]),
			"capacity":(int)record["capacity"],
			"pending":sizeof((array)record["pending"]),
			"revision":(int)record["revision"],
		]);
	destruct(key);
	return result;
}

void drop_test_cache(string account_id)
{
	object key;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_storage_lock->lock();
	m_delete(account_storage_cache,account_id);
	destruct(key);
}

void remove_test_storage(string account_id)
{
	string path;
	object key;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_storage_lock->lock();
	path = storage_file_path(account_id);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
	m_delete(account_storage_cache,account_id);
	destruct(key);
}
