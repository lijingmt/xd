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
#define ACCOUNT_CHARACTER_LIMIT 30
#define ACCOUNT_ONLINE_CONFIG ROOT "/gamelib/etc/account_characters.conf"
#define ACCOUNT_ONLINE_SAFE_DEFAULT 1
#define ACCOUNT_ONLINE_CONFIG_CHECK_INTERVAL 15
#define ACCOUNT_FORCED_LOGOUT_TTL 600

private Thread.Mutex account_character_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) account_cache = ([]);
private Thread.Mutex account_runtime_lock_table_lock = Thread.Mutex();
private mapping(string:object) account_runtime_locks =
	set_weak_flag(([]),Pike.WEAK_VALUES);
private Thread.Mutex account_online_state_lock = Thread.Mutex();
private mapping(string:array(object)) account_online_players = ([]);
private mapping(string:int) test_online_limit_overrides = ([]);
private mapping(string:mapping(string:mixed)) recent_forced_logouts = ([]);

private mapping(string:array(string)) valid_professions = ([
	"human":({"jianxian","yushi","zhuxian"}),
	"monst":({"kuangyao","wuyao","yinggui"}),
	"third":({"fangshi","zhenyue","tianxiang","lingyi","wuxiang","taiji"}),
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
	"wuxiang":"无相",
	"taiji":"太极",
]);

int query_character_limit()
{
	return ACCOUNT_CHARACTER_LIMIT;
}

// 隐藏职业按注册账号限量。这里使用现有职业ID：玩家口中的“无极”
// 对应当前最高隐藏职业 taiji（太极），不创建第二套职业身份。
int query_profession_account_limit(string profession_id)
{
	if(profession_id=="wuxiang")
		return 3;
	if(profession_id=="taiji")
		return 2;
	return 0;
}

mapping(string:mixed) query_profession_limit_from_summary(
	mapping(string:mixed) data,string profession_id,
	void|string excluded_character_id)
{
	int limit = query_profession_account_limit(profession_id);
	int count = 0;
	string excluded = (string)(excluded_character_id || "");
	if(limit<=0)
		return (["ok":1,"limited":0,"allowed":1,"count":0,"limit":0]);
	if(!data || (int)data["ok"]!=1 || !arrayp(data["characters"]))
		return (["ok":0,"limited":1,"allowed":0,"count":0,
			"limit":limit,"message":"账号人物档案暂时无法核验。"]);
	foreach((array)data["characters"],mapping summary){
		if(excluded!="" && (string)summary["id"]==excluded)
			continue;
		if((string)summary["profession_id"]==profession_id)
			count++;
	}
	string profession_name = profession_names[profession_id] || profession_id;
	return (["ok":1,"limited":1,"allowed":count<limit,
		"count":count,"limit":limit,
		"message":count<limit ? "" : "【"+profession_name+
			"·人物上限】同一注册账号最多创建"+limit+"个"+
			profession_name+"。"]);
}

mapping(string:mixed) query_profession_selection_permission(
	string requested_id,string profession_id)
{
	mapping(string:mixed) data = query_account_characters(requested_id);
	return query_profession_limit_from_summary(data,profession_id,
		requested_id);
}

// 无相解锁判定：账号下 10 个基础职业均至少有一个角色达到 120 级。
// 输入是 query_account_characters 的返回值，避免重复查询。
// 同一函数被 gamelib/d/init 的 query_wuxiang_unlocked_for 和
// create_character 共用，保证两条创建路径判定一致。
private array(string) wuxiang_required_professions = ({
	"jianxian","yushi","zhuxian",
	"kuangyao","wuyao","yinggui",
	"fangshi","zhenyue","tianxiang","lingyi",
});

int query_wuxiang_unlocked_from_summary(mapping(string:mixed) data)
{
	mapping(string:int) prof_max_level;
	array(mapping(string:mixed)) characters;
	if(!data || (int)data["ok"] != 1)
		return 0;
	characters = (array(mapping(string:mixed)))data["characters"];
	if(!characters || sizeof(characters) == 0)
		return 0;
	prof_max_level = ([]);
	foreach(characters, mapping entry){
		string prof = (string)entry["profession_id"];
		int lvl = (int)entry["level"];
		if(prof && lvl >= 120 &&
		   (!prof_max_level[prof] || lvl > prof_max_level[prof]))
			prof_max_level[prof] = lvl;
	}
	foreach(wuxiang_required_professions, string p)
		if(!prof_max_level[p])
			return 0;
	return 1;
}

string query_wuxiang_missing_from_summary(mapping(string:mixed) data)
{
	mapping(string:int) prof_max_level;
	array(mapping(string:mixed)) characters;
	array(string) missing = ({});
	mapping(string:string) cn_names = ([
		"jianxian":"剑仙","yushi":"羽士","zhuxian":"诛仙",
		"kuangyao":"狂妖","wuyao":"巫妖","yinggui":"影鬼",
		"fangshi":"方士","zhenyue":"镇越","tianxiang":"天象",
		"lingyi":"灵医",
	]);
	if(!data || (int)data["ok"] != 1)
		return "剑仙、羽士、诛仙、狂妖、巫妖、影鬼、方士、镇越、天象、灵医（账号查询失败）";
	characters = (array(mapping(string:mixed)))data["characters"];
	prof_max_level = ([]);
	if(characters)
		foreach(characters, mapping entry){
			string prof = (string)entry["profession_id"];
			int lvl = (int)entry["level"];
			if(prof && (!prof_max_level[prof] || lvl > prof_max_level[prof]))
				prof_max_level[prof] = lvl;
		}
	foreach(wuxiang_required_professions, string p){
		int lvl = prof_max_level[p];
		if(lvl >= 120)
			continue;
		if(lvl > 0)
			missing += ({ cn_names[p]+"（"+lvl+"/120）" });
		else
			missing += ({ cn_names[p]+"（未创建）" });
	}
	if(sizeof(missing) == 0)
		return "";
	return missing*"、";
}

// 太极解锁判定：账号下 10 个基础职业 + 无相，均至少有一个角色达到 200 级。
// 太极是无相之上的更高一阶隐藏职业，解锁门槛对应拔高到 200 级。
// 输入是 query_account_characters 的返回值，避免重复查询。
private array(string) taiji_required_professions = ({
	"jianxian","yushi","zhuxian",
	"kuangyao","wuyao","yinggui",
	"fangshi","zhenyue","tianxiang","lingyi",
	"wuxiang",
});

int query_taiji_unlocked_from_summary(mapping(string:mixed) data)
{
	mapping(string:int) prof_max_level;
	array(mapping(string:mixed)) characters;
	if(!data || (int)data["ok"] != 1)
		return 0;
	characters = (array(mapping(string:mixed)))data["characters"];
	if(!characters || sizeof(characters) == 0)
		return 0;
	prof_max_level = ([]);
	foreach(characters, mapping entry){
		string prof = (string)entry["profession_id"];
		int lvl = (int)entry["level"];
		if(prof && lvl >= 200 &&
		   (!prof_max_level[prof] || lvl > prof_max_level[prof]))
			prof_max_level[prof] = lvl;
	}
	foreach(taiji_required_professions, string p)
		if(!prof_max_level[p])
			return 0;
	return 1;
}

string query_taiji_missing_from_summary(mapping(string:mixed) data)
{
	mapping(string:int) prof_max_level;
	array(mapping(string:mixed)) characters;
	array(string) missing = ({});
	mapping(string:string) cn_names = ([
		"jianxian":"剑仙","yushi":"羽士","zhuxian":"诛仙",
		"kuangyao":"狂妖","wuyao":"巫妖","yinggui":"影鬼",
		"fangshi":"方士","zhenyue":"镇越","tianxiang":"天象",
		"lingyi":"灵医","wuxiang":"无相",
	]);
	if(!data || (int)data["ok"] != 1)
		return "剑仙、羽士、诛仙、狂妖、巫妖、影鬼、方士、镇越、天象、灵医、无相（账号查询失败）";
	characters = (array(mapping(string:mixed)))data["characters"];
	prof_max_level = ([]);
	if(characters)
		foreach(characters, mapping entry){
			string prof = (string)entry["profession_id"];
			int lvl = (int)entry["level"];
			if(prof && (!prof_max_level[prof] || lvl > prof_max_level[prof]))
				prof_max_level[prof] = lvl;
		}
	foreach(taiji_required_professions, string p){
		int lvl = prof_max_level[p];
		if(lvl >= 200)
			continue;
		if(lvl > 0)
			missing += ({ cn_names[p]+"（"+lvl+"/200）" });
		else
			missing += ({ cn_names[p]+"（未创建）" });
	}
	if(sizeof(missing) == 0)
		return "";
	return missing*"、";
}

/**
 * 从版本化配置读取同一注册账号可同时在线的人物数。配置缺失或非法时
 * 安全回退到单人物；每次人物登录重读，因此修改后无需重启进程。
 */
int query_max_online_characters()
{
	string source = Stdio.read_file(ACCOUNT_ONLINE_CONFIG);
	if(!source)
		return ACCOUNT_ONLINE_SAFE_DEFAULT;
	foreach(source/"\n",string raw_line){
		string line = String.trim_all_whites(raw_line);
		array(string) fields;
		string raw_value;
		int configured;
		if(line=="" || line[0]=='#')
			continue;
		fields = line/"=";
		if(sizeof(fields)!=2 ||
		   String.trim_all_whites(fields[0])!="max_online_characters")
			continue;
		raw_value = String.trim_all_whites(fields[1]);
		if(raw_value=="")
			return ACCOUNT_ONLINE_SAFE_DEFAULT;
		for(int i=0;i<sizeof(raw_value);i++){
			if(raw_value[i]<'0' || raw_value[i]>'9')
				return ACCOUNT_ONLINE_SAFE_DEFAULT;
		}
		configured = (int)raw_value;
		if(configured<1 || configured>ACCOUNT_CHARACTER_LIMIT)
			return ACCOUNT_ONLINE_SAFE_DEFAULT;
		return configured;
	}
	return ACCOUNT_ONLINE_SAFE_DEFAULT;
}

private int query_account_online_limit(string account_id)
{
	int test_limit;
	object key = account_online_state_lock->lock();
	test_limit = test_online_limit_overrides[account_id];
	destruct(key);
	if(test_limit>0)
		return test_limit;
	return query_max_online_characters();
}

/** 立即按当前配置清理所有已登记账号的超额人物，返回成功退出数量。 */
int enforce_online_limit_now()
{
	array(string) account_ids;
	int evicted = 0;
	object state_key = account_online_state_lock->lock();
	account_ids = indices(account_online_players);
	destruct(state_key);
	foreach(account_ids,string account_id){
		array(object) players = ({});
		int online_limit;
		object runtime_key = query_account_runtime_mutex(account_id)->lock();
		state_key = account_online_state_lock->lock();
		foreach(account_online_players[account_id] || ({}),object player){
			if(objectp(player) && !object_in_array(players,player))
				players += ({player});
		}
		destruct(state_key);
		online_limit = query_account_online_limit(account_id);
		while(sizeof(players)>online_limit){
			object oldest = players[0];
			if(!disconnect_online_character(oldest,"配置上限"))
				break;
			players -= ({oldest});
			evicted++;
		}
		state_key = account_online_state_lock->lock();
		if(sizeof(players))
			account_online_players[account_id] = players;
		else
			m_delete(account_online_players,account_id);
		destruct(state_key);
		destruct(runtime_key);
	}
	return evicted;
}

private void check_online_limit_config()
{
	int now = time();
	object key;
	enforce_online_limit_now();
	key = account_online_state_lock->lock();
	foreach(indices(recent_forced_logouts),string character_id){
		mapping forced = recent_forced_logouts[character_id];
		if(!mappingp(forced) ||
		   now-(int)forced["timestamp"]>ACCOUNT_FORCED_LOGOUT_TTL)
			m_delete(recent_forced_logouts,character_id);
	}
	destruct(key);
	call_out(check_online_limit_config,
		ACCOUNT_ONLINE_CONFIG_CHECK_INTERVAL);
}

protected void create()
{
	call_out(check_online_limit_config,
		ACCOUNT_ONLINE_CONFIG_CHECK_INTERVAL);
}

/**
 * 同一注册账号的所有人物共用运行时锁。HTTP线程、Socket登录切换和
 * 账号共享仓库都以该锁为最外层边界，避免不同人物并发修改账号资源。
 */
object query_account_runtime_mutex(string requested_id)
{
	string account_id = query_account_id_for_character(requested_id);
	object table_key;
	object mutex;
	if(!valid_userid(account_id))
		account_id = requested_id;
	if(!valid_userid(account_id))
		account_id = "_invalid_account";
	else
		account_id = String.trim_all_whites(account_id);
	table_key = account_runtime_lock_table_lock->lock();
	if(!objectp(account_runtime_locks[account_id]))
		account_runtime_locks[account_id] = Thread.Mutex();
	mutex = account_runtime_locks[account_id];
	destruct(table_key);
	return mutex;
}

int query_account_runtime_lock_count()
{
	int count;
	object key = account_runtime_lock_table_lock->lock();
	count = sizeof(account_runtime_locks);
	destruct(key);
	return count;
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
	string sex = "";
	string avatar_id = "";
	int level = 1;
	int ready = 0;
	if(player){
		if(functionp(player->have_name_cn))
			name_cn = player->have_name_cn() || "";
		else if(functionp(player->query_name_cn))
			name_cn = player->query_name_cn(1) || "";
		if(functionp(player->query_raceId))
			race_id = player->query_raceId() || "";
		if(functionp(player->query_profeId))
			profession_id = player->query_profeId() || "";
		if(functionp(player->query_level))
			level = player->query_level();
		sex = (string)(player->sex || "");
		avatar_id = (string)(player->user_pic || "");
	}
	else if(content){
		name_cn = read_saved_string(content,"name_cn");
		race_id = read_saved_string(content,"raceId");
		profession_id = read_saved_string(content,"profeId");
		sex = read_saved_string(content,"sex");
		avatar_id = read_saved_string(content,"user_pic");
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
	int profile_needs_name = !name_cn || name_cn=="" ||
		has_prefix(name_cn,"无名");
	int profile_needs_sex = sex!="male" && sex!="female";
	int profile_needs_avatar = !avatar_id || avatar_id=="";
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
		"sex":sex,
		"avatar_id":avatar_id,
		"profile_needs_name":profile_needs_name,
		"profile_needs_sex":profile_needs_sex,
		"profile_needs_avatar":profile_needs_avatar,
		"profile_complete":!(profile_needs_name || profile_needs_sex ||
			profile_needs_avatar),
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
		// 给前端用于隐藏未解锁的隐藏职业入口（无相），避免玩家点击后才报错。
		result["wuxiang_unlocked"] = query_wuxiang_unlocked_from_summary(result);
		result["taiji_unlocked"] = query_taiji_unlocked_from_summary(result);
	}
	destruct(key);
	return result;
}

int account_owns_character(string account_id,string character_id)
{
	mapping(string:mixed)|zero record;
	int found = 0;
	object key;
	string path;
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
	else if(character_id==account_id && !user_file_exists(account_id)){
		// 新注册默认人物首次setup时物理.o尚未写入；只在账号索引也完全
		// 不存在时允许。已有但损坏的索引必须继续失败关闭。
		path = account_file_path(account_id);
		if(Stdio.file_size(path)<=0 && Stdio.file_size(path+".bak")<=0)
			found = 1;
	}
	destruct(key);
	return found;
}

private int valid_profession_pair(string race_id,string profession_id)
{
	return valid_professions[race_id] &&
		search(valid_professions[race_id],profession_id)!=-1;
}

array(string) query_creation_avatar_choices(string race_id,
	string profession_id,string sex)
{
	array(string) choices = ({});
	string prefix = "";
	int maximum = 0;
	if(!valid_profession_pair(race_id,profession_id) ||
	   (sex!="male" && sex!="female"))
		return choices;
	if(race_id=="human" || race_id=="third"){
		if(race_id=="third" &&
		   has_value(({"zhenyue","tianxiang","lingyi","wuxiang","taiji"}),
			profession_id))
			choices += ({profession_id+"_"+sex});
		prefix = sex=="male" ? "h_male" : "h_female";
		maximum = sex=="male" ? 11 : 12;
	}
	else if(race_id=="monst"){
		prefix = sex=="male" ? "m_male" : "m_female";
		maximum = sex=="male" ? 12 : 11;
	}
	for(int index=1;index<=maximum;index++)
		choices += ({prefix+index});
	return choices;
}

int valid_creation_avatar(string race_id,string profession_id,
	string sex,string avatar_id)
{
	return has_value(query_creation_avatar_choices(race_id,
		profession_id,sex),avatar_id);
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
	string character_id,string password,void|string name_cn,
	void|string sex,void|string avatar_id)
{
	object player;
	int saved = 0;
	int save_capability;
	mixed err = catch{
		player = clone(GAMELIB_USER);
		player->set_name(character_id);
		player->set_password(password);
		player->set_project("gamelib");
		player->set_userip("account-character");
		player->set_account_owner(account_id);
		player->sid = "account-character";
		if(name_cn && name_cn!=""){
			player->name_cn = name_cn;
			if(functionp(player->set_original_name_cn))
				player->set_original_name_cn(name_cn);
			player->sex = sex;
			player->user_pic = avatar_id;
			player->set_pic_ok = 1;
		}
		if(MAP_WORKERD->query_node_role()=="worker"){
			mapping capability = MAP_WORKERD->
				prepare_local_account_character_save(account_id,character_id);
			if(!(int)capability["ok"])
				error("account character save capability rejected: "+
					(string)(capability["code"] || "unknown")+"\n");
			save_capability = 1;
		}
		// user->save() 是兼容旧调用方的 void 包装；需要结果时必须走
		// 游戏现有的 save_with_result()，否则成功写盘也会被当成失败。
		saved = player->save_with_result();
	};
	if(save_capability)
		MAP_WORKERD->clear_local_account_character_save(account_id,
			character_id);
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
	string race_id,string profession_id,void|string requested_name,
	void|string requested_sex,void|string requested_avatar)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"创建人物失败。",
	]);
	string account_id = query_account_id_for_character(requested_id);
	mapping(string:mixed)|zero record;
	string character_id;
	string password;
	string profile_name = (string)(requested_name || "");
	string profile_sex = (string)(requested_sex || "");
	string profile_avatar = (string)(requested_avatar || "");
	string reservation_token = "";
	int profile_requested = profile_name!="" || profile_sex!="" ||
		profile_avatar!="";
	int slot;
	object key;
	if(!valid_profession_pair(race_id,profession_id)){
		result["message"] = "阵营与职业组合无效。";
		return result;
	}
	if(profile_requested){
		if(profile_name=="" || profile_sex=="" || profile_avatar==""){
			result["message"] = "请完整选择人物姓名、性别和头像。";
			return result;
		}
		mapping name_validation = NAMESD->validate_profile_name(profile_name);
		if(!(int)name_validation["ok"]){
			result["message"] = name_validation["message"];
			return result;
		}
		profile_name = (string)name_validation["name"];
		if(!valid_creation_avatar(race_id,profession_id,
			profile_sex,profile_avatar)){
			result["message"] = "头像与人物阵营、职业或性别不匹配。";
			return result;
		}
	}
	// 无相是隐藏职业：除了阵营/职业组合合法，还要求账号下 10 个基础职业
	// 均至少有一个角色达到 120 级。未达标时返回具体缺口，方便前端展示。
	if(profession_id=="wuxiang" && account_id!=""){
		mapping wu_data = query_account_characters(account_id);
		if(!(int)wu_data["ok"] || !query_wuxiang_unlocked_from_summary(wu_data)){
			string missing = query_wuxiang_missing_from_summary(wu_data);
			result["message"] = "【无相·未解锁】需要账号下 10 个职业均达到 120 级。当前缺口："+missing;
			return result;
		}
	}
	// 太极是无相之上的隐藏职业：账号下 10 个基础职业 + 无相，均需达到 200 级。
	if(profession_id=="taiji" && account_id!=""){
		mapping tj_data = query_account_characters(account_id);
		if(!(int)tj_data["ok"] || !query_taiji_unlocked_from_summary(tj_data)){
			string missing = query_taiji_missing_from_summary(tj_data);
			result["message"] = "【太极·未解锁】需要账号下 10 职业与无相均达到 200 级。当前缺口："+missing;
			return result;
		}
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
		int profession_limit = query_profession_account_limit(profession_id);
		int profession_count = 0;
		if(profession_limit>0){
			foreach((array)record["characters"],mapping existing_entry){
				mapping existing_summary = profile_summary_unlocked(
					account_id,existing_entry);
				if((string)existing_summary["profession_id"]==profession_id)
					profession_count++;
			}
		}
		if(profession_limit>0 && profession_count>=profession_limit){
			string profession_name = profession_names[profession_id] ||
				profession_id;
			result["message"] = "【"+profession_name+
				"·人物上限】同一注册账号最多创建"+
				profession_limit+"个"+profession_name+"。";
			destruct(key);
			return result;
		}
		int unfinished = 0;
		foreach((array)record["characters"],mapping entry){
			mapping summary = profile_summary_unlocked(account_id,entry);
			if(!(int)summary["ready"]){
				unfinished = 1;
				break;
			}
		}
		if(unfinished)
			result["message"] =
				"请先进入并完成已有待创建人物的职业初始化。";
		else{
			slot = sizeof((array)record["characters"])+1;
			character_id = generate_character_id_unlocked(account_id,slot);
			password = query_saved_password_unlocked(account_id);
			if(character_id=="" || password=="")
				result["message"] = "无法生成安全的人物档案。";
			else{
				mapping reservation = ([]);
				if(profile_requested){
					reservation = NAMESD->reserve_profile_name(profile_name);
					if(!(int)reservation["ok"])
						result["message"] = reservation["message"];
					else{
						profile_name = (string)reservation["name"];
						reservation_token = (string)reservation["token"];
					}
				}
				if(!profile_requested || reservation_token!=""){
					if(!create_empty_character_unlocked(account_id,
						character_id,password,profile_name,profile_sex,
						profile_avatar)){
						string failed_path = user_file_path(character_id);
						rm(failed_path);
						rm(failed_path+".tmp");
						rm(failed_path+".bak");
						rm(failed_path+".bak.tmp");
						result["message"] = "人物物理存档创建失败。";
					}
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
				if(reservation_token!=""){
					if((int)result["ok"])
						NAMESD->commit_profile_name(profile_name,
							reservation_token);
					else
						NAMESD->release_profile_name(profile_name,
							reservation_token);
				}
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) query_character_profile_status(object player)
{
	string stored_name = "";
	string display_name = "";
	string race_id = "";
	string profession_id = "";
	string sex = "";
	string avatar_id = "";
	if(!player)
		return (["profile_complete":0,"profile_needs_name":1,
			"profile_needs_sex":1,"profile_needs_avatar":1]);
	if(functionp(player->have_name_cn))
		stored_name = (string)(player->have_name_cn() || "");
	if(functionp(player->query_name_cn))
		display_name = (string)(player->query_name_cn(1) || "");
	if(functionp(player->query_raceId))
		race_id = (string)(player->query_raceId() || "");
	if(functionp(player->query_profeId))
		profession_id = (string)(player->query_profeId() || "");
	sex = (string)(player->sex || "");
	avatar_id = (string)(player->user_pic || "");
	int needs_name = stored_name=="" || has_prefix(stored_name,"无名");
	int needs_sex = sex!="male" && sex!="female";
	int needs_avatar = avatar_id=="";
	return ([
		"profile_complete":!(needs_name || needs_sex || needs_avatar),
		"profile_needs_name":needs_name,
		"profile_needs_sex":needs_sex,
		"profile_needs_avatar":needs_avatar,
		"profile_name":needs_name ? "" : (stored_name || display_name),
		"sex":sex,
		"avatar_id":avatar_id,
		"race_id":race_id,
		"profession_id":profession_id,
		"avatar_choices":query_creation_avatar_choices(race_id,
			profession_id,sex=="female" ? "female" : "male"),
	]);
}

/** 在线人物资料补全：只允许补缺失/无名字段，不能借接口改已有姓名或头像。 */
mapping(string:mixed) complete_character_profile(object player,
	string requested_name,string requested_sex,string requested_avatar)
{
	mapping status = query_character_profile_status(player);
	mapping result = (["ok":0,"message":"人物资料补全失败。"]);
	string stored_name;
	string final_name;
	string final_sex;
	string final_avatar;
	string reservation_token = "";
	int old_pic_ok;
	if(!player || !functionp(player->save_with_result))
		return result;
	if((int)status["profile_complete"])
		return (["ok":1,"message":"人物资料已经完整。",
			"profile":status]);
	stored_name = functionp(player->have_name_cn) ?
		(string)(player->have_name_cn() || "") : "";
	final_name = stored_name;
	final_sex = (string)status["sex"];
	final_avatar = (string)status["avatar_id"];
	if((int)status["profile_needs_name"]){
		mapping reservation = NAMESD->reserve_profile_name(requested_name);
		if(!(int)reservation["ok"]){
			result["message"] = reservation["message"];
			return result;
		}
		final_name = (string)reservation["name"];
		reservation_token = (string)reservation["token"];
	}
	if((int)status["profile_needs_sex"])
		final_sex = requested_sex;
	else if(requested_sex!="" && requested_sex!=final_sex){
		result["message"] = "已经选定的性别不能通过资料补全修改。";
		if(reservation_token!="")
			NAMESD->release_profile_name(final_name,reservation_token);
		return result;
	}
	if(final_sex!="male" && final_sex!="female"){
		result["message"] = "请选择人物性别。";
		if(reservation_token!="")
			NAMESD->release_profile_name(final_name,reservation_token);
		return result;
	}
	if((int)status["profile_needs_avatar"])
		final_avatar = requested_avatar;
	else if(requested_avatar!="" && requested_avatar!=final_avatar){
		result["message"] = "已经选定的头像不能通过资料补全修改。";
		if(reservation_token!="")
			NAMESD->release_profile_name(final_name,reservation_token);
		return result;
	}
	if(((int)status["profile_needs_avatar"] ||
	    (int)status["profile_needs_sex"]) &&
	   !valid_creation_avatar((string)status["race_id"],
		(string)status["profession_id"],final_sex,final_avatar)){
		result["message"] = "头像与当前人物职业或性别不匹配。";
		if(reservation_token!="")
			NAMESD->release_profile_name(final_name,reservation_token);
		return result;
	}
	string old_name = stored_name;
	string old_sex = (string)(player->sex || "");
	string old_avatar = (string)(player->user_pic || "");
	old_pic_ok = (int)player->set_pic_ok;
	player->name_cn = final_name;
	if(functionp(player->set_original_name_cn))
		player->set_original_name_cn(final_name);
	player->sex = final_sex;
	player->user_pic = final_avatar;
	player->set_pic_ok = 1;
	if(!player->save_with_result()){
		player->name_cn = old_name;
		if(functionp(player->set_original_name_cn))
			player->set_original_name_cn(old_name);
		player->sex = old_sex;
		player->user_pic = old_avatar;
		player->set_pic_ok = old_pic_ok;
		if(reservation_token!="")
			NAMESD->release_profile_name(final_name,reservation_token);
		result["message"] = "人物存档保存失败，资料没有修改。";
		return result;
	}
	if(reservation_token!="")
		NAMESD->commit_profile_name(final_name,reservation_token);
	status = query_character_profile_status(player);
	return (["ok":1,"message":"人物姓名与头像已保存。",
		"profile":status]);
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

private int disconnect_online_character(object player,string incoming_id)
{
	string player_id;
	string account_id;
	object http_api;
	object connd;
	object connection;
	int saved = 0;
	int online_limit = 1;
	mixed err;
	if(!player || !functionp(player->query_name))
		return 1;
	player_id = player->query_name();
	if(!player_id)
		return 1;
	account_id = functionp(player->query_account_owner) ?
		player->query_account_owner() : player_id;
	if(valid_userid(account_id))
		online_limit = query_account_online_limit(account_id);
	err = catch{
		if(functionp(player->save_with_result))
			saved = player->save_with_result();
	};
	if(err || !saved){
		werror("[ACCOUNT_CHARACTERD] 同账号人物切换保存失败: %s\n",
			player_id);
		return 0;
	}
	// 同一人物重连属于会话替换，不设拦截标记；只有被账号在线上限
	// 清退的人物才阻止旧标签页凭缓存TXD自动登录，避免多个职业轮流互踢。
	if(player_id!=incoming_id){
		string marker_id = String.trim_all_whites(player_id);
		mapping(string:mixed) forced = ([
			"error":incoming_id=="配置上限" ?
				"账号同时在线上限已调整，当前人物已安全退出，请重新选择人物。" :
				"同账号在线人物已达到上限，当前人物已安全退出，请重新选择人物。",
			"forced_logout":1,
			"reason":incoming_id=="配置上限" ?
				"online_limit_changed" : "online_limit_reached",
			"incoming_character":incoming_id=="配置上限" ? "" : incoming_id,
			"online_limit":online_limit,
			"timestamp":time(),
		]);
		object state_key = account_online_state_lock->lock();
		recent_forced_logouts[marker_id] = forced;
		destruct(state_key);
	}
	catch{
		if(functionp(player->receive))
			player->receive(incoming_id=="配置上限" ?
				"\n账号同时在线上限已调整，当前人物已保存并安全退出。\n" :
				"\n同一人物重新登录或账号在线人数已满，当前人物已安全退出。\n");
	};
	http_api = find_object(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	if(http_api && functionp(http_api->remove_virtual_connection))
		http_api->remove_virtual_connection(player_id);
	connd = find_object(SROOT+"/connd.pike");
	if(connd && functionp(connd->query_conn))
		connection = connd->query_conn(player);
	if(connd && functionp(connd->erase_user))
		connd->erase_user(player);
	err = catch{
		player->remove();
	};
	if(connection && functionp(connection->set_user))
		connection->set_user(0);
	if(connection && functionp(connection->close))
		connection->close();
	if(err){
		werror("[ACCOUNT_CHARACTERD] 同账号旧人物退出异常: %s\n",
			describe_error(err));
		return 0;
	}
	Stdio.append_file(ROOT+"/log/account_character_login.log",
		ctime(time())[0..sizeof(ctime(time()))-2]+" account switch "+
		player_id+" -> "+incoming_id+"\n");
	return 1;
}

/**
 * 返回人物最近一次因账号在线上限被清退的原因。标记只在短时间内存在，
 * 用于阻断旧浏览器标签页的自动重登；玩家从人物中心明确选择后会清除。
 */
mapping(string:mixed) query_recent_forced_logout(string character_id)
{
	mapping(string:mixed) result = ([]);
	object key;
	if(!valid_userid(character_id))
		return result;
	character_id = String.trim_all_whites(character_id);
	key = account_online_state_lock->lock();
	if(mappingp(recent_forced_logouts[character_id])){
		mapping(string:mixed) forced = recent_forced_logouts[character_id];
		if(time()-(int)forced["timestamp"]>ACCOUNT_FORCED_LOGOUT_TTL)
			m_delete(recent_forced_logouts,character_id);
		else
			result = copy_value(forced);
	}
	destruct(key);
	return result;
}

void clear_recent_forced_logout(string character_id)
{
	object key;
	if(!valid_userid(character_id))
		return;
	character_id = String.trim_all_whites(character_id);
	key = account_online_state_lock->lock();
	m_delete(recent_forced_logouts,character_id);
	destruct(key);
}

private int object_in_array(array(object) players,object player)
{
	for(int i=0;i<sizeof(players);i++){
		if(players[i]==player)
			return 1;
	}
	return 0;
}

/**
 * 调用方必须已经持有 query_account_runtime_mutex() 返回的账号锁。
 * 同一人物ID永远只保留一个对象；不同人物可在配置上限内同时在线。
 * 超过上限时按本daemon记录的登录顺序安全保存并退出最早人物。
 */
int prepare_character_login_locked(object incoming)
{
	string character_id;
	string account_id;
	array(string) character_ids;
	array(object) tracked = ({});
	array(object) active = ({});
	object state_key;
	int belongs = 0;
	int online_limit;
	if(!incoming || !functionp(incoming->query_name) ||
	   !functionp(incoming->query_account_owner))
		return 0;
	character_id = incoming->query_name();
	account_id = incoming->query_account_owner();
	// 内部TestUnit/NPC辅助对象历史上会使用下划线名称，它们不属于
	// 可登录注册账号。真实登录入口本身只接受字母数字，因此直接绕过。
	if(!valid_userid(character_id) || !valid_userid(account_id))
		return 1;
	belongs = account_owns_character(account_id,character_id);
	if(!belongs)
		return 0;
	character_ids = query_character_ids(account_id);
	state_key = account_online_state_lock->lock();
	foreach(account_online_players[account_id] || ({}),object player){
		if(objectp(player) && player!=incoming &&
		   !object_in_array(tracked,player))
			tracked += ({player});
	}
	destruct(state_key);
	// daemon重载前已在线的人物可能尚未登记，从living表补齐。
	for(int i=0;i<sizeof(character_ids);i++){
		object sibling;
		sibling = find_player(character_ids[i]);
		if(sibling && sibling!=incoming &&
		   !object_in_array(tracked,sibling))
			tracked += ({sibling});
	}
	// 相同人物共用同一个.o文件，无论配置上限多大都禁止双对象在线。
	for(int i=0;i<sizeof(tracked);i++){
		object player = tracked[i];
		if(functionp(player->query_name) &&
		   player->query_name()==character_id){
			if(!disconnect_online_character(player,character_id))
				return 0;
		}
		else if(objectp(player))
			active += ({player});
	}
	online_limit = query_account_online_limit(account_id);
	while(sizeof(active)>=online_limit){
		object oldest = active[0];
		if(!disconnect_online_character(oldest,character_id))
			return 0;
		active -= ({oldest});
	}
	active += ({incoming});
	state_key = account_online_state_lock->lock();
	account_online_players[account_id] = active;
	destruct(state_key);
	return 1;
}

array(string) query_active_characters(string requested_id)
{
	string account_id = query_account_id_for_character(requested_id);
	array(string) character_ids = ({});
	array(object) valid_players = ({});
	object key = account_online_state_lock->lock();
	foreach(account_online_players[account_id] || ({}),object player){
		if(player && objectp(player) && functionp(player->query_name)){
			valid_players += ({player});
			character_ids += ({(string)player->query_name()});
		}
	}
	if(sizeof(valid_players))
		account_online_players[account_id] = valid_players;
	else
		m_delete(account_online_players,account_id);
	destruct(key);
	return character_ids;
}

// 兼容旧调用：多人物在线时返回最近进入的那一个。
string query_active_character(string requested_id)
{
	array(string) character_ids = query_active_characters(requested_id);
	if(!sizeof(character_ids))
		return "";
	return character_ids[sizeof(character_ids)-1];
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

/** Authenticated map-worker ingress only: discard cross-process stale state. */
void invalidate_worker_account_cache(string account_id)
{
	object key;
	if(MAP_WORKERD->query_node_role()!="worker" || !valid_userid(account_id))
		return;
	key = account_character_lock->lock();
	m_delete(account_cache,account_id);
	destruct(key);
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

//只供TestUnit验证配置在单开/多开之间切换，不对游戏命令或HTTP开放。
void set_test_online_limit(string account_id,int limit)
{
	object key;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_online_state_lock->lock();
	if(limit>=1 && limit<=ACCOUNT_CHARACTER_LIMIT)
		test_online_limit_overrides[account_id] = limit;
	else
		m_delete(test_online_limit_overrides,account_id);
	destruct(key);
}

//只供测试清理测试账号索引，不对游戏命令或HTTP API开放。
void remove_test_account(string account_id)
{
	string path;
	mapping(string:mixed)|zero record;
	object key;
	object state_key;
	object table_key;
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
	state_key = account_online_state_lock->lock();
	if(record){
		foreach((array)record["characters"],mapping entry)
			m_delete(recent_forced_logouts,(string)entry["id"]);
	}
	else
		m_delete(recent_forced_logouts,account_id);
	m_delete(account_online_players,account_id);
	m_delete(test_online_limit_overrides,account_id);
	destruct(state_key);
	table_key = account_runtime_lock_table_lock->lock();
	m_delete(account_runtime_locks,account_id);
	destruct(table_key);
}
