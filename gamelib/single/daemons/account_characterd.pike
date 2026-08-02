/**
 * 注册账号与多人物档案兼容索引。
 *
 * 没有索引文件的旧账号不写盘、不迁移，原人物ID就是默认人物和账号ID。
 * 只有新增第二人物时才建立索引；所有人物继续使用原有 user .o 存档。
 * 新人物先建立空白档案，再由原有 choice_profe 完成职业和新手流程。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ACCOUNT_CHARACTER_DIR DATA_ROOT "accounts"
#define ACCOUNT_CHARACTER_VERSION 1
#define ACCOUNT_CHARACTER_LIMIT 10

private Thread.Mutex account_character_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) account_cache = ([]);

private mapping(string:array(string)) valid_professions = ([
	"human":({"jianxian","yushi","zhuxian"}),
	"monst":({"kuangyao","wuyao","yinggui"}),
	"third":({"fangshi","zhenyue","tianxiang","lingyi"}),
]);

private mapping(string:string) race_names = ([
	"human":"人类",
	"monst":"妖魔",
	"third":"中立",
]);

private mapping(string:string) profession_names = ([
	"jianxian":"剑仙",
	"yushi":"羽士",
	"zhuxian":"诛仙",
	"kuangyao":"狂妖",
	"wuyao":"巫妖",
	"yinggui":"影鬼",
	"fangshi":"方士",
	"zhenyue":"镇越",
	"tianxiang":"天象",
	"lingyi":"灵医",
]);

int query_character_limit()
{
	return ACCOUNT_CHARACTER_LIMIT;
}

private int valid_userid(string userid)
{
	if(!userid || sizeof(userid)<2 || sizeof(userid)>64 ||
	   search(userid,"..")!=-1)
		return 0;
	foreach(userid;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9'))
			continue;
		return 0;
	}
	return 1;
}

private string user_file_path(string userid)
{
	if(!valid_userid(userid))
		return "";
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

private int user_file_exists(string userid)
{
	string path = user_file_path(userid);
	return path!="" && Stdio.file_size(path)>0;
}

private string account_file_path(string account_id)
{
	if(!valid_userid(account_id))
		return "";
	return ACCOUNT_CHARACTER_DIR+"/"+
		account_id[sizeof(account_id)-2..]+"/"+account_id+".json";
}

private string read_saved_string(string content,string field)
{
	string prefix = field+" \"";
	if(!content || !field)
		return "";
	foreach(content/"\n",string line){
		if(has_prefix(line,prefix) && sizeof(line)>sizeof(prefix)){
			string value = line[sizeof(prefix)..];
			if(sizeof(value) && value[sizeof(value)-1]=='\"')
				return value[0..sizeof(value)-2];
		}
	}
	return "";
}

private int read_saved_int(string content,string field,int default_value)
{
	string prefix = field+" ";
	int value;
	if(!content || !field)
		return default_value;
	foreach(content/"\n",string line){
		if(has_prefix(line,prefix) &&
		   sscanf(line[sizeof(prefix)..],"%d",value)==1)
			return value;
	}
	return default_value;
}

string query_account_id_for_character(string character_id)
{
	object player;
	string content;
	string account_id;
	if(!valid_userid(character_id))
		return "";
	player = find_player(character_id);
	if(player && functionp(player->query_account_owner)){
		account_id = player->query_account_owner();
		if(valid_userid(account_id))
			return account_id;
	}
	content = Stdio.read_file(user_file_path(character_id));
	account_id = read_saved_string(content,"account_owner");
	if(valid_userid(account_id))
		return account_id;
	return character_id;
}

private mapping(string:mixed) synthesize_legacy_record(string account_id)
{
	return ([
		"version":ACCOUNT_CHARACTER_VERSION,
		"account_id":account_id,
		"created_at":0,
		"updated_at":0,
		"legacy_only":1,
		"characters":({([
			"id":account_id,
			"slot":1,
			"created_at":0,
			"desired_race":"",
			"desired_profession":"",
		])}),
	]);
}

private int valid_record(mapping(string:mixed) record,string account_id)
{
	array characters;
	multiset(string) seen = (<>);
	multiset(int) seen_slots = (<>);
	if(!mappingp(record) || record["account_id"]!=account_id ||
	   !arrayp(record["characters"]))
		return 0;
	characters = record["characters"];
	if(sizeof(characters)<1 || sizeof(characters)>ACCOUNT_CHARACTER_LIMIT)
		return 0;
	foreach(characters;int index;mixed raw){
		mapping one;
		string character_id;
		string desired_race;
		string desired_profession;
		int slot;
		if(!mappingp(raw))
			return 0;
		one = raw;
		character_id = (string)one["id"];
		slot = (int)one["slot"];
		desired_race = (string)(one["desired_race"] || "");
		desired_profession = (string)(one["desired_profession"] || "");
		if(!valid_userid(character_id) || seen[character_id] ||
		   slot!=index+1 || seen_slots[slot])
			return 0;
		if((index==0 && character_id!=account_id) ||
		   (index>0 && character_id==account_id))
			return 0;
		if((desired_race!="" || desired_profession!="") &&
		   (!valid_professions[desired_race] ||
		    search(valid_professions[desired_race],desired_profession)==-1))
			return 0;
		seen[character_id] = 1;
		seen_slots[slot] = 1;
	}
	return seen[account_id] ? 1 : 0;
}

private mapping(string:mixed)|zero decode_record_file(string path,
	string account_id)
{
	string source;
	mixed decoded = 0;
	mixed err;
	if(!path || Stdio.file_size(path)<=0)
		return 0;
	source = Stdio.read_file(path);
	if(!source || sizeof(source)>1024*1024)
		return 0;
	err = catch{
		decoded = Standards.JSON.decode(source);
	};
	if(err || !mappingp(decoded) || !valid_record(decoded,account_id))
		return 0;
	return decoded;
}

private mapping(string:mixed)|zero load_persisted_record_unlocked(
	string account_id)
{
	string path = account_file_path(account_id);
	mapping(string:mixed)|zero record;
	if(account_cache[account_id])
		return copy_value(account_cache[account_id]);
	record = decode_record_file(path,account_id);
	if(!record)
		record = decode_record_file(path+".bak",account_id);
	if(record){
		record["legacy_only"] = 0;
		account_cache[account_id] = copy_value(record);
		return copy_value(record);
	}
	return 0;
}

private mapping(string:mixed)|zero load_record_unlocked(string account_id)
{
	mapping(string:mixed)|zero record;
	string path;
	if(!valid_userid(account_id) || !user_file_exists(account_id))
		return 0;
	record = load_persisted_record_unlocked(account_id);
	if(record)
		return record;
	path = account_file_path(account_id);
	// 索引物理存在却无法通过主文件/备份校验时必须失败关闭，不能把
	// 多人物账号误当成旧单人物账号并覆盖原索引。
	if(Stdio.file_size(path)>0 || Stdio.file_size(path+".bak")>0)
		return 0;
	return synthesize_legacy_record(account_id);
}

private int save_record_unlocked(mapping(string:mixed) record)
{
	string account_id = (string)record["account_id"];
	string path = account_file_path(account_id);
	string dir;
	string temp_path;
	string backup_temp;
	string encoded;
	int live_size;
	int backup_size;
	int live_valid;
	int ok = 0;
	mixed err;
	if(!valid_record(record,account_id) || path=="")
		return 0;
	dir = dirname(path);
	temp_path = path+".tmp";
	backup_temp = path+".bak.tmp";
	record["version"] = ACCOUNT_CHARACTER_VERSION;
	record["updated_at"] = time();
	record["legacy_only"] = 0;
	encoded = Standards.JSON.encode(record);
	mkdir(ACCOUNT_CHARACTER_DIR);
	mkdir(dir);
	err = catch{
		rm(temp_path);
		rm(backup_temp);
		if(Stdio.write_file(temp_path,encoded)>0 &&
		   Stdio.file_size(temp_path)==sizeof(encoded)){
			live_size = Stdio.file_size(path);
			live_valid = live_size>0 &&
				decode_record_file(path,account_id) ? 1 : 0;
			if(live_valid){
				Stdio.cp(path,backup_temp);
				backup_size = Stdio.file_size(backup_temp);
				if(backup_size==live_size &&
				   mv(backup_temp,path+".bak") && mv(temp_path,path))
					ok = Stdio.file_size(path)==sizeof(encoded);
			}
			// 主索引损坏、备份有效时直接替换主索引，必须保留好备份。
			else if(mv(temp_path,path))
				ok = Stdio.file_size(path)==sizeof(encoded);
		}
	};
	if(err)
		werror("[ACCOUNT_CHARACTERD] 账号索引保存异常: %s\n",
			describe_error(err));
	if(!ok){
		rm(temp_path);
		rm(backup_temp);
		return 0;
	}
	account_cache[account_id] = copy_value(record);
	return 1;
}

private mapping(string:mixed) profile_summary_unlocked(
	string account_id,mapping(string:mixed) entry)
{
	string character_id = (string)entry["id"];
	string content = Stdio.read_file(user_file_path(character_id));
	object player = find_player(character_id);
	string name_cn = "";
	string race_id = "";
	string profession_id = "";
	int level = 1;
	int ready = 0;
	if(player){
		if(functionp(player->query_name_cn))
			name_cn = player->query_name_cn(1);
		if(functionp(player->query_raceId))
			race_id = player->query_raceId() || "";
		if(functionp(player->query_profeId))
			profession_id = player->query_profeId() || "";
		if(functionp(player->query_level))
			level = player->query_level();
	}
	else if(content){
		name_cn = read_saved_string(content,"name_cn");
		race_id = read_saved_string(content,"raceId");
		profession_id = read_saved_string(content,"profeId");
		level = read_saved_int(content,"level",1);
	}
	if(profession_id && profession_id!="")
		ready = 1;
	// Pike 的空字符串不是所有上下文都等同于 0；空白新人物必须明确
	// 回退到索引里的待初始化职业，否则列表与重复职业校验会漏判。
	if(!race_id || race_id=="")
		race_id = (string)(entry["desired_race"] || "");
	if(!profession_id || profession_id=="")
		profession_id = (string)(entry["desired_profession"] || "");
	if(!name_cn || name_cn==""){
		if(profession_id && profession_names[profession_id])
			name_cn = "待命名"+profession_names[profession_id];
		else
			name_cn = "待创建人物";
	}
	return ([
		"id":character_id,
		"slot":(int)entry["slot"],
		"name_cn":name_cn,
		"level":level>0 ? level : 1,
		"race_id":race_id,
		"race_name":race_names[race_id] || "待选择",
		"profession_id":profession_id,
		"profession_name":profession_names[profession_id] || "待选择",
		"ready":ready,
		"available":(content || player) ? 1 : 0,
		"online":player ? 1 : 0,
		"is_default":character_id==account_id ? 1 : 0,
		"created_at":(int)entry["created_at"],
	]);
}

mapping(string:mixed) query_account_characters(string requested_id)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"账号档案不存在。",
		"account_id":"",
		"characters":({}),
		"limit":ACCOUNT_CHARACTER_LIMIT,
	]);
	string account_id = query_account_id_for_character(requested_id);
	mapping(string:mixed)|zero record;
	object key;
	if(!valid_userid(account_id))
		return result;
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record){
		array summaries = ({});
		foreach((array)record["characters"],mapping entry)
			summaries += ({profile_summary_unlocked(account_id,entry)});
		result = ([
			"ok":1,
			"message":"",
			"account_id":account_id,
			"characters":summaries,
			"limit":ACCOUNT_CHARACTER_LIMIT,
			"legacy_only":(int)record["legacy_only"],
		]);
	}
	destruct(key);
	return result;
}

int account_owns_character(string account_id,string character_id)
{
	mapping(string:mixed)|zero record;
	int found = 0;
	object key;
	if(!valid_userid(account_id) || !valid_userid(character_id))
		return 0;
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record){
		foreach((array)record["characters"],mapping entry){
			if(entry["id"]==character_id){
				string content = Stdio.read_file(
					user_file_path(character_id));
				string saved_owner = read_saved_string(content,
					"account_owner");
				found = content &&
					(character_id==account_id || saved_owner==account_id);
				break;
			}
		}
	}
	destruct(key);
	return found;
}

private int valid_profession_pair(string race_id,string profession_id)
{
	return valid_professions[race_id] &&
		search(valid_professions[race_id],profession_id)!=-1;
}

private string generate_character_id_unlocked(string account_id,int slot)
{
	for(int attempt=0;attempt<30;attempt++){
		string suffix = String.string2hex(Crypto.Random.random_string(4));
		string candidate = account_id+"c"+slot+suffix;
		if(sizeof(candidate)<=64 && !user_file_exists(candidate))
			return candidate;
	}
	return "";
}

private string query_saved_password_unlocked(string userid)
{
	object player = find_player(userid);
	string content;
	if(player && functionp(player->query_password))
		return player->query_password() || "";
	content = Stdio.read_file(user_file_path(userid));
	return read_saved_string(content,"password");
}

private int create_empty_character_unlocked(string account_id,
	string character_id,string password)
{
	object player;
	int saved = 0;
	mixed err = catch{
		player = clone(GAMELIB_USER);
		player->set_name(character_id);
		player->set_password(password);
		player->set_project("gamelib");
		player->set_userip("account-character");
		player->set_account_owner(account_id);
		player->sid = "account-character";
		// user->save() 是兼容旧调用方的 void 包装；需要结果时必须走
		// 游戏现有的 save_with_result()，否则成功写盘也会被当成失败。
		saved = player->save_with_result();
	};
	if(player)
		destruct(player);
	if(err){
		werror("[ACCOUNT_CHARACTERD] 新人物存档创建异常: %s\n",
			describe_error(err));
		return 0;
	}
	return saved && user_file_exists(character_id);
}

mapping(string:mixed) create_character(string requested_id,
	string race_id,string profession_id)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"创建人物失败。",
	]);
	string account_id = query_account_id_for_character(requested_id);
	mapping(string:mixed)|zero record;
	string character_id;
	string password;
	int slot;
	object key;
	if(!valid_profession_pair(race_id,profession_id)){
		result["message"] = "阵营与职业组合无效。";
		return result;
	}
	if(!valid_userid(account_id)){
		result["message"] = "账号无效。";
		return result;
	}
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(!record)
		result["message"] = "原账号人物档案不存在。";
	else if(sizeof((array)record["characters"])>=ACCOUNT_CHARACTER_LIMIT)
		result["message"] = "人物档案已达到"+
			ACCOUNT_CHARACTER_LIMIT+"个上限。";
	else{
		int duplicate = 0;
		int unfinished = 0;
		foreach((array)record["characters"],mapping entry){
			mapping summary = profile_summary_unlocked(account_id,entry);
			if(summary["profession_id"]==profession_id){
				duplicate = 1;
				break;
			}
			if(!(int)summary["ready"])
				unfinished = 1;
		}
		if(duplicate)
			result["message"] = "该账号已经拥有"+
				(profession_names[profession_id] || profession_id)+"人物。";
		else if(unfinished)
			result["message"] =
				"请先进入并完成已有待创建人物的职业初始化。";
		else{
			slot = sizeof((array)record["characters"])+1;
			character_id = generate_character_id_unlocked(account_id,slot);
			password = query_saved_password_unlocked(account_id);
			if(character_id=="" || password=="")
				result["message"] = "无法生成安全的人物档案。";
			else if(!create_empty_character_unlocked(account_id,
				character_id,password))
				result["message"] = "人物物理存档创建失败。";
			else{
				mapping entry = ([
					"id":character_id,
					"slot":slot,
					"created_at":time(),
					"desired_race":race_id,
					"desired_profession":profession_id,
				]);
				if((int)record["created_at"]<=0)
					record["created_at"] = time();
				record["characters"] += ({entry});
				if(save_record_unlocked(record)){
					result = ([
						"ok":1,
						"message":"人物档案创建成功。",
						"account_id":account_id,
						"character":profile_summary_unlocked(
							account_id,entry),
						"bootstrap_command":"choice_profe "+
							race_id+"/"+profession_id,
					]);
				}
				else{
					string path = user_file_path(character_id);
					rm(path);
					rm(path+".tmp");
					rm(path+".bak");
					result["message"] =
						"账号索引保存失败，已回滚新人物。";
				}
			}
		}
	}
	destruct(key);
	return result;
}

string query_bootstrap_command(string account_id,string character_id)
{
	mapping(string:mixed)|zero record;
	string result = "";
	object key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record){
		foreach((array)record["characters"],mapping entry){
			if(entry["id"]==character_id){
				string content = Stdio.read_file(
					user_file_path(character_id));
				string race_id = (string)(entry["desired_race"] || "");
				string profession_id = (string)(
					entry["desired_profession"] || "");
				if(read_saved_string(content,"profeId")=="" &&
				   valid_profession_pair(race_id,profession_id))
					result = "choice_profe "+race_id+"/"+profession_id;
				break;
			}
		}
	}
	destruct(key);
	return result;
}

array(string) query_character_ids(string account_id)
{
	array(string) result = ({});
	mapping(string:mixed)|zero record;
	object key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record){
		foreach((array)record["characters"],mapping entry)
			result += ({(string)entry["id"]});
	}
	destruct(key);
	return result;
}

private string prepare_password_temp_unlocked(string userid,
	string new_password)
{
	string path = user_file_path(userid);
	string temp_path = path+".password.tmp";
	string content = Stdio.read_file(path);
	array(string) lines;
	int replaced = 0;
	string encoded;
	if(!content || content=="")
		return "";
	lines = content/"\n";
	for(int i=0;i<sizeof(lines);i++){
		if(has_prefix(lines[i],"password ")){
			if(replaced)
				return "";
			lines[i] = "password \""+new_password+"\"";
			replaced = 1;
		}
	}
	if(!replaced)
		return "";
	encoded = lines*"\n";
	rm(temp_path);
	if(Stdio.write_file(temp_path,encoded)<=0 ||
	   Stdio.file_size(temp_path)!=sizeof(encoded)){
		rm(temp_path);
		return "";
	}
	return temp_path;
}

private int commit_password_temp_unlocked(string userid,string temp_path)
{
	string path = user_file_path(userid);
	string backup_temp = path+".password.bak.tmp";
	string restore_temp = path+".password.restore.tmp";
	int live_size = Stdio.file_size(path);
	int backup_size;
	int expected_size = Stdio.file_size(temp_path);
	if(live_size<=0 || expected_size<=0)
		return 0;
	rm(backup_temp);
	Stdio.cp(path,backup_temp);
	backup_size = Stdio.file_size(backup_temp);
	if(backup_size!=live_size){
		rm(backup_temp);
		return 0;
	}
	if(!mv(backup_temp,path+".bak"))
		return 0;
	if(mv(temp_path,path) && Stdio.file_size(path)==expected_size)
		return 1;
	// 当前文件替换失败时立即恢复本人物，避免出现短暂的缺档窗口。
	rm(restore_temp);
	Stdio.cp(path+".bak",restore_temp);
	if(Stdio.file_size(restore_temp)==Stdio.file_size(path+".bak"))
		mv(restore_temp,path);
	else
		rm(restore_temp);
	return 0;
}

private void rollback_password_files_unlocked(array(string) committed)
{
	foreach(committed,string userid){
		string path = user_file_path(userid);
		string restore_temp = path+".password.restore.tmp";
		if(Stdio.file_size(path+".bak")<=0)
			continue;
		rm(restore_temp);
		Stdio.cp(path+".bak",restore_temp);
		if(Stdio.file_size(restore_temp)==Stdio.file_size(path+".bak"))
			mv(restore_temp,path);
		else
			rm(restore_temp);
	}
}

private void refresh_password_backup_unlocked(string userid)
{
	string path = user_file_path(userid);
	string backup_temp = path+".password.backup.tmp";
	int live_size = Stdio.file_size(path);
	int copied_size;
	rm(backup_temp);
	if(live_size>0)
		Stdio.cp(path,backup_temp);
	copied_size = Stdio.file_size(backup_temp);
	if(copied_size==live_size && mv(backup_temp,path+".bak"))
		return;
	// 旧密码不能留在自动恢复备份中；主档仍是完整的新密码档案，后续
	// 正常存档会重新生成备份。
	rm(backup_temp);
	rm(path+".bak");
	werror("[ACCOUNT_CHARACTERD] 密码备份刷新失败，已移除旧备份: %s\n",
		userid);
}

/**
 * 游戏内“修改密码”保持账号级语义：先保存所有在线人物，再为全部人物
 * 准备临时文件，全部准备成功后才替换，最后同步在线对象。
 */
mapping(string:mixed) change_account_password(object current,
	string new_password)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"账号密码修改失败。",
	]);
	string account_id;
	array(string) character_ids;
	mapping(string:string) temp_files = ([]);
	array(string) committed = ({});
	array(object) live_players = ({});
	object key;
	if(!current || !new_password || sizeof(new_password)<2 ||
	   sizeof(new_password)>=12)
		return result;
	foreach(new_password;int index;int one){
		if(!((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		     (one>='0' && one<='9'))){
			result["message"] = "密码只能包含英文或数字。";
			return result;
		}
	}
	account_id = current->query_account_owner();
	if(!valid_userid(account_id))
		return result;
	key = account_character_lock->lock();
	mapping record = load_record_unlocked(account_id);
	if(!record)
		result["message"] = "账号档案不存在。";
	else{
		character_ids = ({});
		foreach((array)record["characters"],mapping entry)
			character_ids += ({(string)entry["id"]});
		int prepared = 1;
		foreach(character_ids,string character_id){
			object player = current->query_name()==character_id ?
				current : find_player(character_id);
			if(player){
				// 与安全关服、管理员改等级保持同一套可验证存档接口。
				if(!functionp(player->save_with_result) ||
				   !player->save_with_result()){
					prepared = 0;
					break;
				}
				live_players += ({player});
			}
			string temp_path = prepare_password_temp_unlocked(
				character_id,new_password);
			if(temp_path==""){
				prepared = 0;
				break;
			}
			temp_files[character_id] = temp_path;
		}
		if(!prepared){
			foreach(values(temp_files),string temp_path)
				rm(temp_path);
			result["message"] = "人物档案预保存失败，密码未修改。";
		}
		else{
			int committed_all = 1;
			foreach(character_ids,string character_id){
				if(!commit_password_temp_unlocked(character_id,
					temp_files[character_id])){
					committed_all = 0;
					break;
				}
				committed += ({character_id});
			}
			if(!committed_all){
				rollback_password_files_unlocked(committed);
				foreach(values(temp_files),string temp_path)
					rm(temp_path);
				result["message"] = "人物档案替换失败，已恢复原密码。";
			}
			else{
				foreach(live_players,object player)
					player->set_password(new_password);
				foreach(character_ids,string character_id)
					refresh_password_backup_unlocked(character_id);
				object http_api = find_object(ROOT+
					"/gamelib/single/daemons/http_api_daemon.pike");
				if(http_api && functionp(
					http_api->invalidate_user_password_cache)){
					foreach(character_ids,string character_id)
						http_api->invalidate_user_password_cache(character_id);
				}
				if(http_api && functionp(
					http_api->revoke_account_sessions_for))
					http_api->revoke_account_sessions_for(account_id);
				result = ([
					"ok":1,
					"message":sizeof(character_ids)>1 ?
						"账号下全部人物密码已同步修改。" :
						"密码设置成功。",
					"updated":sizeof(character_ids),
				]);
			}
		}
	}
	destruct(key);
	return result;
}

//只供测试模拟进程重载后的磁盘读取，不对游戏命令或HTTP API开放。
void drop_test_account_cache(string account_id)
{
	object key;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_character_lock->lock();
	m_delete(account_cache,account_id);
	destruct(key);
}

//只供测试清理测试账号索引，不对游戏命令或HTTP API开放。
void remove_test_account(string account_id)
{
	string path;
	mapping(string:mixed)|zero record;
	object key;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_character_lock->lock();
	path = account_file_path(account_id);
	record = load_persisted_record_unlocked(account_id);
	if(record){
		foreach((array)record["characters"],mapping entry){
			string character_id = (string)entry["id"];
			string user_path;
			if(character_id==account_id)
				continue;
			user_path = user_file_path(character_id);
			rm(user_path);
			rm(user_path+".tmp");
			rm(user_path+".bak");
			rm(user_path+".bak.tmp");
			rm(user_path+".password.tmp");
			rm(user_path+".password.bak.tmp");
			rm(user_path+".password.restore.tmp");
			rm(user_path+".password.backup.tmp");
		}
	}
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
	m_delete(account_cache,account_id);
	destruct(key);
}
