/**
 * 幻境区生命周期与人物隔离守护。
 *
 * 历史宏名 SEASONALD 保留给旧代码兼容；所有玩家界面统一称“幻境区”。
 * 幻境人物始终使用唯一的原 user .o 存档。回归只原子切换账号索引，
 * 不复制人物、不搬运背包，从存储模型上杜绝结算克隆装备。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ILLUSION_CONFIG ROOT "/gamelib/etc/illusion_realm.json"
#define ILLUSION_STATE_DIR DATA_ROOT "illusion_realm"
#define ILLUSION_STATE_FILE ILLUSION_STATE_DIR "/runtime.json"
#define ILLUSION_CONTROL_LOCK ILLUSION_STATE_DIR "/control.lock"
#define ILLUSION_HISTORY_DIR ILLUSION_STATE_DIR "/history"
#define ILLUSION_RANKING_DIR ILLUSION_STATE_DIR "/rankings"
#define ILLUSION_STATE_VERSION 1
#define ILLUSION_PROGRESS_ROOT "/plus/illusion_realm"
#define ILLUSION_PAYMENT_ROOT "/plus/illusion_entitlement_purchase"
#define ILLUSION_EXPANSION_PAYMENT_ROOT "/plus/illusion_character_expansion_purchase"
#define ILLUSION_LOG ROOT "/log/illusion_realm.log"
#define ILLUSION_AUTOMATION_INTERVAL 10
#define ILLUSION_MAX_DURATION_SECONDS (366*86400)
#define ILLUSION_RANKING_WEEK_SECONDS (7*86400)
#define ILLUSION_RANKING_CACHE_TTL 30

private Thread.Mutex runtime_lock = Thread.Mutex();
private mapping(string:mixed) illusion_config = ([]);
private mapping(string:mixed) runtime_cache = ([]);
private string runtime_source_cache = "";
private int config_valid;
private int runtime_valid = 1;
private int last_closed_reconcile_revision = -1;
private int closed_reconcile_until;
private mapping(string:mapping(string:mixed)) ranking_cache = ([]);

private mapping(string:string) ranking_names = ([
	"journey":"幻境征途榜","level":"境界榜","experience":"经验榜",
	"pk":"论剑榜","set":"新月套装榜","speed":"极速榜",
]);

private int valid_nonnegative(mapping one,string key,int maximum)
{
	return intp(one[key]) && (int)one[key]>=0 && (int)one[key]<=maximum;
}

private int valid_identifier(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>16)
		return 0;
	foreach(value;int index;int one){
		if((one>='A' && one<='Z') || (one>='0' && one<='9') ||
		   one=='_')
			continue;
		return 0;
	}
	return 1;
}

private int valid_sha256_hex(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	foreach(value;int index;int one){
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

private int valid_route_mark_id(string value)
{
	if(!value || sizeof(value)>32)
		return 0;
	foreach(value;int index;int one){
		if((one>='a' && one<='z') || (one>='0' && one<='9') || one=='_')
			continue;
		return 0;
	}
	return 1;
}

private int valid_room_path(string path)
{
	if(!path || sizeof(path)<12 || sizeof(path)>256 ||
	   !has_prefix(path,"/gamelib/d/") || search(path,"..")!=-1 ||
	   search(path,"#")!=-1)
		return 0;
	foreach(path;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='/' || one=='_' || one=='-' ||
		   one=='.')
			continue;
		return 0;
	}
	return 1;
}

private int valid_chapter(mapping chapter,string illusion_id)
{
	return mappingp(chapter) && stringp(chapter["id"]) &&
		has_prefix((string)chapter["id"],illusion_id+"-C") &&
		stringp(chapter["title"]) && sizeof((string)chapter["title"])>0 &&
		stringp(chapter["description"]) &&
		valid_nonnegative(chapter,"min_level",1000) &&
		valid_nonnegative(chapter,"kills",1000000) &&
		valid_nonnegative(chapter,"boss_kills",100000) &&
		valid_nonnegative(chapter,"visits",1000) &&
		valid_nonnegative(chapter,"reward_count",10) &&
		(int)chapter["reward_count"]>0;
}

private int valid_route_challenges(mapping routes,string illusion_id)
{
	array secrets;
	array bosses;
	string room_prefix = "/gamelib/d/illusion_"+
		lower_case(illusion_id)+"/";
	string npc_prefix = "/gamelib/clone/npc/illusion_"+
		lower_case(illusion_id)+"/";
	multiset(string) ids = (<>);
	multiset(string) paths = (<>);
	if(!mappingp(routes) || !arrayp(routes["pioneer_secrets"]) ||
	   !arrayp(routes["hunter_bosses"]) ||
	   !intp(routes["companion_team_kills"]) ||
	   (int)routes["companion_team_kills"]<1 ||
	   (int)routes["companion_team_kills"]>10000)
		return 0;
	secrets = routes["pioneer_secrets"];
	bosses = routes["hunter_bosses"];
	if(sizeof(secrets)!=3 || sizeof(bosses)!=3)
		return 0;
	foreach(secrets,mapping secret){
		string id = (string)secret["id"];
		string path = (string)secret["path"];
		if(!valid_room_path(path) || !has_prefix(path,room_prefix) ||
		   Stdio.file_size(ROOT+path)<=0 ||
		   !valid_route_mark_id(id) || ids[id] ||
		   paths[path] || !stringp(secret["message"]) ||
		   sizeof((string)secret["message"])<2 ||
		   sizeof((string)secret["message"])>256)
			return 0;
		ids[id] = 1;
		paths[path] = 1;
	}
	foreach(bosses,mapping boss){
		string id = (string)boss["id"];
		string path = (string)boss["path"];
		if(!path || sizeof(path)>256 ||
		   !has_prefix(path,npc_prefix) ||
		   !has_suffix(path,".pike") || search(path,"..")!=-1 ||
		   search(path,"#")!=-1 || Stdio.file_size(ROOT+path)<=0 ||
		   !valid_route_mark_id(id) || ids[id] ||
		   paths[path])
			return 0;
		foreach(path;int index;int one)
			if(!((one>='a' && one<='z') || (one>='A' && one<='Z') ||
			   (one>='0' && one<='9') || one=='/' || one=='_' ||
			   one=='-' || one=='.'))
				return 0;
		ids[id] = 1;
		paths[path] = 1;
	}
	return 1;
}

private int valid_config(mapping candidate)
{
	array chapters;
	int rewards;
	string illusion_id = (string)candidate["current_id"];
	string room_prefix = "/gamelib/d/illusion_"+
		lower_case(illusion_id)+"/";
	if(!mappingp(candidate) || (int)candidate["version"]!=1 ||
	   !valid_identifier((string)candidate["current_id"]) ||
	   !stringp(candidate["display_name"]) ||
	   sizeof((string)candidate["display_name"])<2 ||
	   !valid_nonnegative(candidate,"duration_days",366) ||
	   (int)candidate["duration_days"]<30 ||
	   !valid_nonnegative(candidate,"entitlement_cost_suiyu",1000000) ||
	   !valid_nonnegative(candidate,"extra_character_slot_cost_suiyu",1000000) ||
	   (int)candidate["extra_character_slot_cost_suiyu"]!=100 ||
	   !valid_nonnegative(candidate,"multi_character_unlock_cost_suiyu",1000000) ||
	   (int)candidate["multi_character_unlock_cost_suiyu"]!=500 ||
	   !valid_room_path((string)candidate["entry_room"]) ||
	   !has_prefix((string)candidate["entry_room"],room_prefix) ||
	   Stdio.file_size(ROOT+(string)candidate["entry_room"])<=0 ||
	   !valid_room_path((string)candidate["return_room"]) ||
	   has_prefix((string)candidate["return_room"],room_prefix) ||
	   Stdio.file_size(ROOT+(string)candidate["return_room"])<=0 ||
	   !valid_route_challenges(candidate["route_challenges"],illusion_id) ||
	   !arrayp(candidate["chapters"]))
		return 0;
	chapters = candidate["chapters"];
	if(sizeof(chapters)<1 || sizeof(chapters)>20)
		return 0;
	foreach(chapters;int index;mapping chapter){
		if(!valid_chapter(chapter,illusion_id) ||
		   (string)chapter["id"]!=illusion_id+"-C"+(string)(index+1))
			return 0;
		rewards += (int)chapter["reward_count"];
	}
	// 每期终章正好发完一个职业的十件新月底版套装。
	return rewards==10;
}

int reload_config()
{
	string source;
	mixed decoded = 0;
	mixed err;
	if(Stdio.file_size(ILLUSION_CONFIG)<=0 ||
	   Stdio.file_size(ILLUSION_CONFIG)>128*1024){
		config_valid = 0;
		illusion_config = ([]);
		werror("[ILLUSION_REALM] 配置缺失或过大，功能已安全关闭。\n");
		return 0;
	}
	source = Stdio.read_file(ILLUSION_CONFIG);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) || !valid_config((mapping)decoded)){
		config_valid = 0;
		illusion_config = ([]);
		werror("[ILLUSION_REALM] 配置校验失败，功能已安全关闭。\n");
		return 0;
	}
	illusion_config = copy_value(decoded);
	config_valid = 1;
	return 1;
}

private mapping(string:mixed) default_runtime_state()
{
	return ([
		"version":ILLUSION_STATE_VERSION,
		"current_id":(string)(illusion_config["current_id"] || "S1"),
		"phase":"draft",
		"revision":0,
		"starts_at":0,
		"ends_at":0,
		"updated_at":time(),
		"closed_ids":({}),
		"audit":({}),
	]);
}

private int valid_runtime_state_for_id(mapping state,string expected_id)
{
	string phase;
	if(!mappingp(state) ||
	   (int)state["version"]!=ILLUSION_STATE_VERSION ||
	   (string)state["current_id"]!=expected_id ||
	   !intp(state["revision"]) || (int)state["revision"]<0 ||
	   !intp(state["starts_at"]) || !intp(state["ends_at"]) ||
	   !intp(state["updated_at"]) || !arrayp(state["audit"]) ||
	   (state["closed_ids"] && !arrayp(state["closed_ids"])))
		return 0;
	array closed_ids = state["closed_ids"] || ({});
	if(sizeof(closed_ids)>64)
		return 0;
	multiset(string) seen_closed = (<>);
	foreach(closed_ids,mixed raw_id){
		string closed_id = (string)raw_id;
		if(!valid_identifier(closed_id) || closed_id==expected_id ||
		   seen_closed[closed_id])
			return 0;
		seen_closed[closed_id] = 1;
	}
	phase = (string)state["phase"];
	if(search(({"draft","registration","active","settling","closed"}),
	   phase)==-1 || sizeof((array)state["audit"])>2000)
		return 0;
	if((phase=="active" || phase=="settling" || phase=="closed") &&
	   ((int)state["starts_at"]<=0 ||
	    (int)state["ends_at"]<=(int)state["starts_at"]))
		return 0;
	return 1;
}

private int valid_runtime_state(mapping state)
{
	return valid_runtime_state_for_id(state,
		(string)illusion_config["current_id"]);
}

private mapping(string:mixed) load_runtime_state()
{
	string source;
	mixed decoded = 0;
	mixed err;
	object key = runtime_lock->lock();
	if(Stdio.file_size(ILLUSION_STATE_FILE)<=0){
		// 首次落地只能建立不可变的S1。后续编号必须从已关闭运行状态
		// 经过显式换期，不能靠删状态文件跳过归档和closed_ids。
		if((string)illusion_config["current_id"]!="S1"){
			runtime_valid = 0;
			werror("[ILLUSION_REALM] 非S1配置缺少旧运行状态，已拒绝隐式换期。\n");
			destruct(key);
			return ([]);
		}
		runtime_cache = default_runtime_state();
		runtime_source_cache = "";
		runtime_valid = 1;
		mapping result = copy_value(runtime_cache);
		destruct(key);
		return result;
	}
	if(Stdio.file_size(ILLUSION_STATE_FILE)>1024*1024){
		runtime_valid = 0;
		destruct(key);
		return ([]);
	}
	source = Stdio.read_file(ILLUSION_STATE_FILE);
	if(source==runtime_source_cache && sizeof(runtime_cache)){
		mapping result = copy_value(runtime_cache);
		destruct(key);
		return result;
	}
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) ||
	   !valid_runtime_state((mapping)decoded)){
		runtime_valid = 0;
		destruct(key);
		werror("[ILLUSION_REALM] 运行状态损坏，功能已安全关闭。\n");
		return ([]);
	}
	if(!arrayp(decoded["closed_ids"]))
		decoded["closed_ids"] = ({});
	runtime_cache = copy_value(decoded);
	runtime_source_cache = source;
	runtime_valid = 1;
	mapping result = copy_value(runtime_cache);
	destruct(key);
	return result;
}

private int acquire_control_lock()
{
	mkdir(ILLUSION_STATE_DIR);
	for(int attempt=0;attempt<200;attempt++){
		if(mkdir(ILLUSION_CONTROL_LOCK))
			return 1;
		Stdio.Stat stat = file_stat(ILLUSION_CONTROL_LOCK);
		if(stat && stat->isdir && time()-stat->mtime>30){
			rm(ILLUSION_CONTROL_LOCK);
			continue;
		}
		sleep(0.005);
	}
	return 0;
}

private void release_control_lock()
{
	rm(ILLUSION_CONTROL_LOCK);
}

private int save_runtime_state(mapping state)
{
	string temp_file;
	string backup_temp;
	string encoded;
	int live_size;
	int ok;
	mixed err;
	if(!valid_runtime_state(state))
		return 0;
	state["updated_at"] = time();
	encoded = Standards.JSON.encode(state);
	temp_file = ILLUSION_STATE_FILE+"."+
		String.string2hex(Crypto.Random.random_string(8))+".tmp";
	backup_temp = temp_file+".bak";
	err = catch{
		rm(temp_file);
		rm(backup_temp);
		if(Stdio.write_file(temp_file,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_file)==sizeof(encoded)){
			live_size = Stdio.file_size(ILLUSION_STATE_FILE);
			if(live_size>0){
				Stdio.cp(ILLUSION_STATE_FILE,backup_temp);
				if(Stdio.file_size(backup_temp)==live_size &&
				   mv(backup_temp,ILLUSION_STATE_FILE+".bak") &&
				   mv(temp_file,ILLUSION_STATE_FILE))
					ok = Stdio.file_size(ILLUSION_STATE_FILE)==sizeof(encoded);
			}
			else if(mv(temp_file,ILLUSION_STATE_FILE))
				ok = Stdio.file_size(ILLUSION_STATE_FILE)==sizeof(encoded);
		}
	};
	if(err)
		werror("[ILLUSION_REALM] 状态保存异常: %s\n",describe_error(err));
	if(!ok){
		rm(temp_file);
		rm(backup_temp);
		return 0;
	}
	object key = runtime_lock->lock();
	runtime_cache = copy_value(state);
	runtime_source_cache = encoded;
	runtime_valid = 1;
	destruct(key);
	return 1;
}

private string effective_phase(mapping state)
{
	string phase = (string)(state["phase"] || "disabled");
	if(phase=="active" && (int)state["ends_at"]>0 &&
	   time()>=(int)state["ends_at"])
		return "settling";
	return phase;
}

private string phase_name(string phase)
{
	if(phase=="draft") return "筹备中";
	if(phase=="registration") return "资格开放";
	if(phase=="active") return "进行中";
	if(phase=="settling") return "回归结算";
	if(phase=="closed") return "已关闭";
	return "不可用";
}

mapping(string:mixed) query_public_status()
{
	mapping state = config_valid ? load_runtime_state() : ([]);
	string phase = sizeof(state) ? effective_phase(state) : "disabled";
	return ([
		"ok":config_valid && runtime_valid && sizeof(state)>0,
		"illusion_id":(string)(illusion_config["current_id"] || "S1"),
		"display_name":(string)(illusion_config["display_name"] ||
			"新月幻境·S1"),
		"phase":phase,
		"phase_name":phase_name(phase),
		"revision":(int)state["revision"],
		"starts_at":(int)state["starts_at"],
		"ends_at":(int)state["ends_at"],
		"closed_ids":arrayp(state["closed_ids"]) ?
			((array)state["closed_ids"])+({}) : ({}),
		"duration_days":(int)illusion_config["duration_days"],
		"entitlement_cost_suiyu":
			(int)illusion_config["entitlement_cost_suiyu"],
		"extra_character_slot_cost_suiyu":
			(int)illusion_config["extra_character_slot_cost_suiyu"],
		"multi_character_unlock_cost_suiyu":
			(int)illusion_config["multi_character_unlock_cost_suiyu"],
		"creation_open":phase=="active",
		"entitlement_open":phase=="registration" || phase=="active",
		"entry_room":(string)(illusion_config["entry_room"] || ""),
		"return_room":(string)(illusion_config["return_room"] || ""),
		"rules":({
			"资格按注册账号永久生效；每期首名免费，100碎玉增加本期1格，本期累计500碎玉解锁多人物。",
			(string)illusion_config["current_id"]+
				"人物使用唯一原档案；回归永恒服时不复制人物或背包。",
			"幻境期间不开放家园，也不接入共享仓库、共享玉石、拍卖与跨世界交易。",
			"任务套装会随人物原档案回归永恒服。",
		}),
	]);
}

private mapping(string:mixed) read_runtime_for_rollover()
{
	string source;
	mixed decoded;
	mixed err;
	if(Stdio.file_size(ILLUSION_STATE_FILE)<=0 ||
	   Stdio.file_size(ILLUSION_STATE_FILE)>1024*1024)
		return ([]);
	source = Stdio.read_file(ILLUSION_STATE_FILE);
	err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) ||
	   !valid_identifier((string)decoded["current_id"]) ||
	   !valid_runtime_state_for_id(decoded,(string)decoded["current_id"]))
		return ([]);
	if(!arrayp(decoded["closed_ids"]))
		decoded["closed_ids"] = ({});
	return decoded;
}

private string rollover_digest(mapping old_state,string new_id)
{
	object hash = Crypto.SHA256();
	hash->update("rollover|"+(string)old_state["current_id"]+"|"+
		(string)(int)old_state["revision"]+"|"+
		(string)(int)old_state["updated_at"]+"|"+new_id);
	return lower_case(String.string2hex(hash->digest()));
}

mapping(string:mixed) preview_cycle_rollover()
{
	mapping old_state = read_runtime_for_rollover();
	string new_id = (string)illusion_config["current_id"];
	string old_id = (string)(old_state["current_id"] || "");
	mapping population = old_id!="" ?
		ACCOUNT_CHARACTERD->query_illusion_population(old_id) : ([]);
	int allowed = config_valid && sizeof(old_state) &&
		(string)old_state["phase"]=="closed" && old_id!=new_id &&
		(int)population["ok"];
	return ([
		"ok":allowed,"old_id":old_id,"new_id":new_id,
		"confirmation":allowed ? rollover_digest(old_state,new_id) : "",
		"population":population,
		"message":allowed ?
			"旧周期已关闭，可以建立新周期草稿。" :
			(!(int)population["ok"] && sizeof(old_state) ?
			 "账号索引审计未通过，修复异常索引后才能换期。" :
			 "只有旧周期关闭且配置已换成新编号后才能换期。"),
	]);
}

mapping(string:mixed) apply_cycle_rollover(string confirmation,
	string operator_id)
{
	mapping result = (["ok":0,"message":"幻境换期失败。"]) ;
	mapping old_state;
	mapping new_state;
	string old_id;
	string new_id = (string)illusion_config["current_id"];
	string archive_path;
	string archive_temp;
	int archive_ok;
	mapping population;
	if(!config_valid || !operator_id || operator_id=="" ||
	   !acquire_control_lock())
		return result;
	old_state = read_runtime_for_rollover();
	old_id = (string)(old_state["current_id"] || "");
	if(!sizeof(old_state) || (string)old_state["phase"]!="closed" ||
	   old_id==new_id)
		result["message"] = "旧周期尚未关闭，或新配置编号没有变化。";
	else if(confirmation!=rollover_digest(old_state,new_id))
		result["message"] = "换期预览已过期，请重新确认。";
	else{
		population = ACCOUNT_CHARACTERD->query_illusion_population(old_id);
		if(!(int)population["ok"]){
			result["message"] = "账号索引审计未通过，已拒绝换期。";
			release_control_lock();
			return result;
		}
		mkdir(ILLUSION_HISTORY_DIR);
		archive_path = ILLUSION_HISTORY_DIR+"/"+old_id+"-r"+
			(string)(int)old_state["revision"]+"-"+
			(string)(int)old_state["updated_at"]+".json";
		if(Stdio.file_size(archive_path)>0)
			archive_ok = Stdio.read_file(archive_path)==
				Stdio.read_file(ILLUSION_STATE_FILE);
		else{
			archive_temp = archive_path+"."+
				String.string2hex(Crypto.Random.random_string(8))+".tmp";
			rm(archive_temp);
			archive_ok = Stdio.cp(ILLUSION_STATE_FILE,archive_temp) &&
				Stdio.file_size(archive_temp)==
				Stdio.file_size(ILLUSION_STATE_FILE) &&
				mv(archive_temp,archive_path);
			if(!archive_ok)
				rm(archive_temp);
		}
		if(!archive_ok)
			result["message"] = "旧周期状态归档失败，未建立新周期。";
		else{
			new_state = default_runtime_state();
			array closed_ids = ((array)old_state["closed_ids"])+({old_id});
			if(sizeof(closed_ids)>64)
				closed_ids = closed_ids[sizeof(closed_ids)-64..];
			new_state["closed_ids"] = closed_ids;
			new_state["revision"] = 1;
			new_state["audit"] = ({(["at":time(),"operator":operator_id,
				"action":"rollover","from":old_id,"to":new_id,
				"revision":1])});
			if(save_runtime_state(new_state))
				result = (["ok":1,"message":"已建立"+new_id+
					"草稿；旧人物仍按原档案登录回归。",
					"status":query_public_status(),
					"population":ACCOUNT_CHARACTERD->
						query_illusion_population(old_id)]);
			else
				result["message"] = "新周期状态落盘失败，旧归档仍保留。";
		}
	}
	release_control_lock();
	return result;
}

private string transition_digest(string action,mapping state)
{
	object hash = Crypto.SHA256();
	hash->update((string)illusion_config["current_id"]+"|"+action+"|"+
		(string)(int)state["revision"]+"|"+(string)state["phase"]);
	return lower_case(String.string2hex(hash->digest()));
}

private string end_time_digest(mapping state,int ends_at)
{
	object hash = Crypto.SHA256();
	hash->update((string)state["current_id"]+"|end_time|"+
		(string)(int)state["revision"]+"|"+(string)ends_at);
	return lower_case(String.string2hex(hash->digest()));
}

private int valid_end_time_change(mapping state,string phase,int ends_at)
{
	return mappingp(state) && phase=="active" &&
		ends_at>(int)state["starts_at"] &&
		ends_at-(int)state["starts_at"]<=ILLUSION_MAX_DURATION_SECONDS;
}

int query_end_time_valid_for_test(mapping state,string phase,int ends_at)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return valid_end_time_change(state,phase,ends_at);
}

mapping(string:mixed) preview_end_time(int ends_at)
{
	mapping state = load_runtime_state();
	string phase = sizeof(state) ? effective_phase(state) : "disabled";
	int allowed = config_valid && runtime_valid &&
		valid_end_time_change(state,phase,ends_at);
	return (["ok":allowed,"ends_at":ends_at,
		"confirmation":allowed ? end_time_digest(state,ends_at) : ""]);
}

mapping(string:mixed) apply_end_time(int ends_at,string confirmation,
	string operator_id)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"结束时间修改失败。"]);
	mapping state;
	array audit;
	int old_ends_at;
	if(!config_valid || !runtime_valid || !operator_id || operator_id=="")
		return result;
	if(!acquire_control_lock()){
		result["message"] = "另一名管理员正在调整幻境配置。";
		return result;
	}
	{
		object key = runtime_lock->lock();
		runtime_source_cache = "__reload__";
		destruct(key);
	}
	state = load_runtime_state();
	if(!valid_end_time_change(state,effective_phase(state),ends_at) ||
	   confirmation!=end_time_digest(state,ends_at))
		result["message"] = "结束时间预览已过期，或当前周期已经进入结算。";
	else{
		old_ends_at = (int)state["ends_at"];
		state["ends_at"] = ends_at;
		state["revision"] = (int)state["revision"]+1;
		audit = state["audit"];
		audit += ({(["at":time(),"operator":operator_id,
			"action":"set_end_time","from":old_ends_at,"to":ends_at,
			"revision":(int)state["revision"]])});
		if(sizeof(audit)>2000)
			audit = audit[sizeof(audit)-2000..];
		state["audit"] = audit;
		if(save_runtime_state(state))
			result = (["ok":1,
				"message":ends_at<=time() ?
					"结束时间已更新，正在自动结算并关闭本期。" :
					"结束时间已更新。",
				"status":query_public_status()]);
	}
	release_control_lock();
	if((int)result["ok"] && ends_at<=time())
		call_out(run_lifecycle_automation_once,0);
	return result;
}

mapping(string:mixed) preview_lifecycle_transition(string action)
{
	mapping state = load_runtime_state();
	string phase = sizeof(state) ? effective_phase(state) : "disabled";
	string expected = ([
		"open_registration":"draft",
		"start":"registration",
		"settle":"active",
		"close":"settling",
	])[action];
	int allowed = config_valid && runtime_valid && expected && phase==expected;
	// 自然到期会把 active 视为 settling。预览摘要必须使用相同的
	// 有效阶段，否则管理员刚拿到的 close 确认码会在执行时失效。
	if(sizeof(state) && phase!=(string)state["phase"])
		state["phase"] = phase;
	return ([
		"ok":allowed,
		"action":action,
		"current_phase":phase,
		"expected_phase":expected || "",
		"confirmation":allowed ? transition_digest(action,state) : "",
		"status":query_public_status(),
	]);
}

mapping(string:mixed) apply_lifecycle_transition(string action,
	string confirmation,string operator_id)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"幻境生命周期切换失败。"]);
	mapping state;
	string phase;
	string next_phase;
	if(!config_valid || !runtime_valid || !operator_id || operator_id=="" ||
	   search(({"open_registration","start","settle","close"}),action)==-1)
		return result;
	if(!acquire_control_lock()){
		result["message"] = "另一名管理员正在调整幻境配置。";
		return result;
	}
	// 获得跨Worker文件锁后丢弃本进程缓存，读取唯一最新修订。
	{
		object key = runtime_lock->lock();
		runtime_source_cache = "__reload__";
		destruct(key);
	}
	state = load_runtime_state();
	phase = effective_phase(state);
	if(phase!=(string)state["phase"])
		state["phase"] = phase;
	if(confirmation!=transition_digest(action,state))
		result["message"] = "预览已过期，请重新确认当前修订。";
	else{
		next_phase = ([
			"open_registration":"registration",
			"start":"active",
			"settle":"settling",
			"close":"closed",
		])[action];
		if((phase=="draft" && action!="open_registration") ||
		   (phase=="registration" && action!="start") ||
		   (phase=="active" && action!="settle") ||
		   (phase=="settling" && action!="close") ||
		   phase=="closed")
			result["message"] = "当前阶段不允许执行该操作。";
		else{
			if(action=="start"){
				int starts_at = time();
				state["starts_at"] = starts_at;
				state["ends_at"] = starts_at+
					(int)illusion_config["duration_days"]*86400;
			}
			state["phase"] = next_phase;
			state["revision"] = (int)state["revision"]+1;
			array audit = state["audit"];
			audit += ({(["at":time(),"operator":operator_id,
				"action":action,"from":phase,"to":next_phase,
				"revision":(int)state["revision"]])});
			if(sizeof(audit)>2000)
				audit = audit[sizeof(audit)-2000..];
			state["audit"] = audit;
			if(save_runtime_state(state))
				result = (["ok":1,"message":"幻境阶段已切换为"+
					phase_name(next_phase)+"。","status":query_public_status()]);
			else
				result["message"] = "幻境状态落盘失败，未发布新修订。";
		}
	}
	release_control_lock();
	return result;
}

private string automatic_action(mapping state,int now_time)
{
	string phase = (string)state["phase"];
	if(phase=="active" && (int)state["ends_at"]>0 &&
	   now_time>=(int)state["ends_at"])
		return "auto_settle";
	if(phase=="settling")
		return "auto_close";
	return "";
}

string query_automatic_action_for_test(mapping state,int now_time)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !mappingp(state))
		return "";
	return automatic_action(state,now_time);
}

private mapping(string:mixed) apply_automatic_transition()
{
	mapping(string:mixed) result = (["ok":0,"action":""]);
	mapping state;
	string action;
	string from_phase;
	string to_phase;
	int now_time = time();
	array audit;
	if(!config_valid || !runtime_valid || !acquire_control_lock())
		return result;
	{
		object key = runtime_lock->lock();
		runtime_source_cache = "__reload__";
		destruct(key);
	}
	state = load_runtime_state();
	action = automatic_action(state,now_time);
	if(action==""){
		release_control_lock();
		return result;
	}
	from_phase = (string)state["phase"];
	if(action=="auto_settle"){
		state["phase"] = "settling";
		to_phase = "settling";
	}
	else if(action=="auto_close"){
		state["phase"] = "closed";
		to_phase = "closed";
	}
	state["revision"] = (int)state["revision"]+1;
	audit = state["audit"];
	audit += ({(["at":now_time,"operator":"system",
		"action":action,"from":from_phase,"to":to_phase,
		"revision":(int)state["revision"]])});
	if(sizeof(audit)>2000)
		audit = audit[sizeof(audit)-2000..];
	state["audit"] = audit;
	if(save_runtime_state(state)){
		Stdio.append_file(ILLUSION_LOG,sprintf(
			"%d|lifecycle|action=%s|cycle=%s|phase=%s|revision=%d\n",
			now_time,action,(string)state["current_id"],
			(string)state["phase"],(int)state["revision"]));
		result = (["ok":1,"action":action,
			"status":query_public_status()]);
	}
	release_control_lock();
	return result;
}

private mapping(string:int) reconcile_local_expired_players()
{
	mapping status = query_public_status();
	array(object) list = users(1);
	int active;
	int settled;
	int failed;
	for(int index=0;index<sizeof(list);index++){
		mapping realm;
		mapping result;
		if(!list[index])
			continue;
		realm = query_realm_for_player(list[index]);
		if(!(int)realm["ok"] ||
		   (string)realm["realm_type"]!="illusion" ||
		   (string)realm["illusion_state"]!="active")
			continue;
		if((string)realm["illusion_id"]==
		   (string)status["illusion_id"] &&
		   (string)status["phase"]=="active")
			continue;
		active++;
		result = settle_player(list[index]);
		if((int)result["ok"])
			settled++;
		else{
			failed++;
			werror("[ILLUSION_REALM] 在线人物自动回归失败 user=%s message=%s\n",
				(string)list[index]->query_name(),
				(string)result["message"]);
		}
	}
	return (["active":active,"settled":settled,"failed":failed]);
}

void run_lifecycle_automation_once()
{
	mapping transition;
	mapping reconciliation;
	for(int attempt=0;attempt<4;attempt++){
		transition = apply_automatic_transition();
		if(!(int)transition["ok"])
			break;
		if((string)transition["action"]=="auto_settle" ||
		   (string)transition["action"]=="auto_close")
			reconciliation = reconcile_local_expired_players();
	}
	{
		mapping status = query_public_status();
		if((string)status["phase"]=="settling")
			reconcile_local_expired_players();
		else if((string)status["phase"]=="closed"){
			// A handoff accepted just before close can arrive after this Worker's
			// first scan. Keep a bounded reconciliation window rather than scanning
			// every online player forever while the realm remains closed.
			if(last_closed_reconcile_revision!=(int)status["revision"]){
				last_closed_reconcile_revision = (int)status["revision"];
				closed_reconcile_until = time()+180;
			}
			if(time()<=closed_reconcile_until){
				reconciliation = reconcile_local_expired_players();
				if((int)reconciliation["failed"])
					closed_reconcile_until = max(closed_reconcile_until,
						time()+60);
			}
		}
	}
}

private void lifecycle_automation_tick()
{
	mixed err = catch{ run_lifecycle_automation_once(); };
	if(err)
		werror("[ILLUSION_REALM] 自动生命周期异常: %s\n",
			describe_error(err));
	call_out(lifecycle_automation_tick,ILLUSION_AUTOMATION_INTERVAL);
}

private mapping(string:mixed) query_realm_for_player(object player)
{
	if(!player || !functionp(player->query_name))
		return (["ok":0,"realm_type":"eternal"]);
	return ACCOUNT_CHARACTERD->query_character_realm(
		(string)player->query_name());
}

int is_active_illusion_character(object player)
{
	mapping realm = query_realm_for_player(player);
	return (int)realm["ok"] && (string)realm["realm_type"]=="illusion" &&
		(string)realm["illusion_state"]=="active";
}

/**
 * Return the current season's safe public grinding route.  Seasonal route
 * selection lives beside the season map contract so the generic AFK daemon
 * never guesses an Eternal-world destination for an isolated character.
 */
mapping(string:mixed) query_autofight_route(object player)
{
	string illusion_id;
	string path;
	string name;
	int level;
	int target_level;
	if(!player || !is_active_illusion_character(player))
		return ([]);
	illusion_id = (string)illusion_config["current_id"];
	level = player->query_level();
	if(illusion_id!="S1")
		return ([]);
	if(level<10){
		path = "illusion_s1/silver_path";
		name = "银痕初猎";
		target_level = 8;
	}
	else if(level<20){
		path = "illusion_s1/fog_forest";
		name = "雾林寻星";
		target_level = 18;
	}
	else if(level<30){
		path = "illusion_s1/mirror_lake";
		name = "镜湖逆潮";
		target_level = 28;
	}
	else if(level<40){
		path = "illusion_s1/broken_observatory";
		name = "折星破阵";
		target_level = 38;
	}
	else if(level<50){
		path = "illusion_s1/echo_ruins";
		name = "古城回声";
		target_level = 45;
	}
	else{
		path = "illusion_s1/abyss_garden";
		name = "深渊同辉";
		target_level = 58;
	}
	return ([
		"max":69,
		"level":target_level,
		"name":name,
		"path":path,
		"paths":({path}),
		"target_min":target_level,
		"target_max":target_level,
		"disable_overflow":1,
		"illusion_id":illusion_id,
	]);
}

/** Return qge74hye's relative path for the current season's safe bedroom. */
string query_autofight_rest_room(object player)
{
	string room;
	string prefix = "/gamelib/d/";
	if(!player || !is_active_illusion_character(player))
		return "";
	room = (string)(illusion_config["entry_room"] || "");
	if(!has_prefix(room,prefix))
		return "";
	room = room[sizeof(prefix)..];
	if(has_suffix(room,".pike"))
		room = room[..sizeof(room)-6];
	return room;
}

// 登录落点修复必须与世界身份使用同一份账号索引判断。否则一个仍在
// 幻境中的人物若保存了已删除的S1房间，通用修复会把他送往永恒主城，
// 随后又被跨世界守卫拒绝，最终表现为登录后卡住。
string query_login_fallback_room(object player)
{
	mapping realm = query_realm_for_player(player);
	if(!(int)realm["ok"] || (int)realm["security_blocked"] ||
	   (string)realm["realm_type"]!="illusion" ||
	   (string)realm["illusion_state"]!="active" ||
	   (string)realm["illusion_id"]!=(string)illusion_config["current_id"])
		return "";
	return (string)(illusion_config["entry_room"] || "");
}

string query_character_group(string user_id)
{
	mapping realm = ACCOUNT_CHARACTERD->query_character_realm(user_id);
	if((int)realm["security_blocked"])
		return "realm-unavailable:"+user_id;
	if((int)realm["ok"] && (string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active")
		return "illusion:"+(string)realm["illusion_id"];
	return "";
}

int shared_account_assets_blocked(object player)
{
	mapping realm = query_realm_for_player(player);
	return (int)realm["security_blocked"] ||
		((int)realm["ok"] && (string)realm["realm_type"]=="illusion" &&
		 (string)realm["illusion_state"]=="active");
}

private string normalized_destination_path(mixed destination)
{
	string path = "";
	if(objectp(destination))
		path = file_name(destination);
	else if(stringp(destination))
		path = (string)destination;
	if(has_prefix(path,ROOT))
		path = path[sizeof(ROOT)..];
	if(search(path,"#")!=-1)
		path = (path/"#")[0];
	return path;
}

private int is_illusion_room_path(string path)
{
	string entry = (string)(illusion_config["entry_room"] || "");
	string prefix = entry!="" ? dirname(entry)+"/" : "";
	return path!="" && prefix!="" && has_prefix(path,prefix);
}

// 返回0表示允许；非0分别表示阶段冻结、幻境人物越界、永恒人物闯入。
// 守卫与TestUnit共用这一纯策略，避免测试为改变生命周期去写运行状态。
private int move_policy(mapping realm,string target,string phase)
{
	if((int)realm["security_blocked"])
		return 4;
	if((string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active"){
		if((string)realm["illusion_id"]!=
		   (string)illusion_config["current_id"])
			return 1;
		if(phase!="active")
			return 1;
		return is_illusion_room_path(target) ? 0 : 2;
	}
	return is_illusion_room_path(target) ? 3 : 0;
}

int query_move_policy_for_test(mapping realm,string target,string phase)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return move_policy(realm,normalized_destination_path(target),phase);
}

int guard_player_move(object player,mixed destination)
{
	string target;
	string current;
	mapping realm;
	int policy;
	if(!player || player["/tmp/illusion_move_bypass"])
		return 0;
	target = normalized_destination_path(destination);
	current = normalized_destination_path(environment(player));
	// The per-session entrance is outside both Eternal and S1 worlds. Only a
	// freshly restored object that is not yet in /gamelib/d may enter it; an
	// active character cannot use this exception to escape a real world room.
	if(target=="/gamelib/d/init" &&
	   !has_prefix(current,"/gamelib/d/"))
		return 0;
	realm = query_realm_for_player(player);
	policy = move_policy(realm,target,(string)query_public_status()["phase"]);
	if(policy==1){
		tell_object(player,(string)illusion_config["display_name"]+
			"已进入回归结算，请使用“幻境区”完成安全回归。\n");
		return 1;
	}
	if(policy==2){
		tell_object(player,"幻境人物暂不能离开新月幻境；任务与装备会在期满结算后随原档案回归。\n");
		return 1;
	}
	if(policy==3){
		tell_object(player,"这里是"+(string)illusion_config["display_name"]+
			"，仅本期幻境人物可以进入。\n");
		return 1;
	}
	if(policy==4){
		tell_object(player,"账号世界索引暂不可验证，已冻结移动以保护人物与装备，请联系管理员。\n");
		return 1;
	}
	return 0;
}

private mapping player_progress(object player,int create_if_missing)
{
	return player_progress_for_id(player,
		(string)illusion_config["current_id"],create_if_missing);
}

private mapping player_progress_for_id(object player,string illusion_id,
	int create_if_missing)
{
	mapping all_progress = player[ILLUSION_PROGRESS_ROOT];
	mapping progress;
	if(!mappingp(all_progress))
		all_progress = ([]);
	progress = all_progress[illusion_id];
	if(!mappingp(progress) && create_if_missing){
		mapping public_status = query_public_status();
		int starts_at = (int)public_status["starts_at"];
		if(starts_at<=0 || starts_at>time())
			starts_at = time();
		progress = ([
			"version":1,"joined_at":time(),"kills":0,"boss_kills":0,
			"team_kills":0,"visited":([]),"path":"","route_marks":([]),
			"claims":([]),"season_starts_at":starts_at,
			"ranking_weeks":([]),"ranking_titles":({}),
			"ranking_reward_claims":([]),"pvp_honor":0,"pvp_wins":0,
			"ranking_level":0,"ranking_experience_start":-1,
			"ranking_experience_latest":0,
		]);
		all_progress[illusion_id] = progress;
		player[ILLUSION_PROGRESS_ROOT] = all_progress;
	}
	return mappingp(progress) ? progress : ([]);
}

private int ranking_week_index(mapping progress,int timestamp)
{
	int starts_at = (int)progress["season_starts_at"];
	if(starts_at<=0){
		starts_at = (int)progress["joined_at"];
		if(starts_at<=0)
			starts_at = timestamp;
		progress["season_starts_at"] = starts_at;
	}
	if(timestamp<starts_at)
		return 1;
	return min(60,1+(timestamp-starts_at)/ILLUSION_RANKING_WEEK_SECONDS);
}

private mapping ranking_week_state(mapping progress,int timestamp,
	int create_if_missing)
{
	mapping weeks = mappingp(progress["ranking_weeks"]) ?
		(mapping)progress["ranking_weeks"] : ([]);
	string key = (string)ranking_week_index(progress,timestamp);
	mapping state = mappingp(weeks[key]) ? (mapping)weeks[key] : ([]);
	if(!sizeof(state) && create_if_missing){
		state = ([
			"kills":0,"boss_kills":0,"team_kills":0,"visits":0,
			"route_marks":0,"chapter_claims":0,"set_parts":0,
			"pvp_honor":0,"pvp_wins":0,"level":0,
			"experience_start":-1,"experience_latest":0,
			"completed_at":0,
		]);
		weeks[key] = state;
		progress["ranking_weeks"] = weeks;
	}
	return state;
}

private int claimed_set_parts(mapping progress)
{
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	int parts;
	foreach((array)illusion_config["chapters"],mapping chapter)
		if((int)claims[(string)chapter["id"]])
			parts += (int)chapter["reward_count"];
	return min(10,max(0,parts));
}

private int final_completion_at(mapping progress)
{
	mapping claims = mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	array chapters = (array)illusion_config["chapters"];
	if(!sizeof(chapters))
		return 0;
	return (int)claims[(string)chapters[-1]["id"]];
}

private void update_ranking_snapshot(object player,mapping progress,
	void|int timestamp)
{
	int now = timestamp || time();
	mapping week;
	int experience;
	if(!player || !mappingp(progress))
		return;
	week = ranking_week_state(progress,now,1);
	experience = max(0,(int)player->exp);
	if((int)week["experience_start"]<0)
		week["experience_start"] = experience;
	week["experience_latest"] = max((int)week["experience_latest"],
		experience);
	week["level"] = max((int)week["level"],(int)player->query_level());
	if(!has_index(progress,"ranking_experience_start") ||
	   (int)progress["ranking_experience_start"]<0)
		progress["ranking_experience_start"] = experience;
	progress["ranking_experience_latest"] = max(
		(int)progress["ranking_experience_latest"],experience);
	progress["ranking_level"] = max((int)progress["ranking_level"],
		(int)player->query_level());
	progress["set_parts"] = claimed_set_parts(progress);
	progress["completed_at"] = final_completion_at(progress);
}

private void invalidate_ranking_cache(string illusion_id)
{
	foreach(indices(ranking_cache),string key)
		if(has_prefix(key,illusion_id+"|"))
			m_delete(ranking_cache,key);
}

private int progress_visit_count(mapping progress)
{
	return mappingp(progress["visited"]) ?
		sizeof((mapping)progress["visited"]) : 0;
}

private int is_test_illusion_player(object player)
{
	return getenv("XIAND_RUN_TESTUNIT")=="1" && player &&
		functionp(player->query_name) &&
		has_prefix((string)player->query_name(),"xd99testunitillusion");
}

private int is_illusion_progress_checkpoint(mapping progress,
	int boss_kill,int route_mark_added,int previous_team_kills)
{
	int kills = (int)progress["kills"];
	if(boss_kill || route_mark_added || kills%25==0)
		return 1;
	foreach((array)illusion_config["chapters"],mapping chapter)
		if(kills==(int)chapter["kills"])
			return 1;
	if(previous_team_kills<
	   (int)illusion_config["route_challenges"]["companion_team_kills"] &&
	   (int)progress["team_kills"]>=
	   (int)illusion_config["route_challenges"]["companion_team_kills"])
		return 1;
	return 0;
}

void record_room_visit(object player,object room)
{
	string path;
	mapping progress;
	mapping old_progress;
	mapping visited;
	if(!is_active_illusion_character(player) || !room)
		return;
	path = normalized_destination_path(room);
	if(!is_illusion_room_path(path))
		return;
	progress = player_progress(player,1);
	visited = mappingp(progress["visited"]) ? progress["visited"] : ([]);
	if((int)visited[path])
		return;
	old_progress = copy_value(progress);
	visited[path] = 1;
	progress["visited"] = visited;
	mapping visit_week = ranking_week_state(progress,time(),1);
	visit_week["visits"] = (int)visit_week["visits"]+1;
	update_ranking_snapshot(player,progress);
	if(!player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+
			(string)illusion_config["current_id"]] = old_progress;
		werror("[ILLUSION_REALM] 首次到访进度存档失败并已回滚: %s %s\n",
			(string)player->query_name(),path);
	}
	else{
		if(!persist_ranking_snapshot(player,progress,
		   (string)illusion_config["current_id"]))
			werror("[ILLUSION_RANKING] 首次到访快照待后续补写: %s\n",
				(string)player->query_name());
		invalidate_ranking_cache((string)illusion_config["current_id"]);
	}
}

void record_npc_kill(object player,object npc,void|int team_count)
{
	mapping progress;
	mapping old_progress;
	mapping marks;
	object env;
	string npc_path;
	string npc_prefix;
	int boss_kill;
	int route_mark_added;
	int previous_team_kills;
	if(!is_active_illusion_character(player) || !npc)
		return;
	env = environment(player);
	npc_path = normalized_destination_path(npc);
	npc_prefix = "/gamelib/clone/npc/illusion_"+
		lower_case((string)illusion_config["current_id"])+"/";
	if(!env || environment(npc)!=env ||
	   !is_illusion_room_path(normalized_destination_path(env)) ||
	   !has_prefix(npc_path,npc_prefix) || !has_suffix(npc_path,".pike"))
		return;
	progress = player_progress(player,1);
	old_progress = copy_value(progress);
	previous_team_kills = (int)progress["team_kills"];
	boss_kill = (int)npc->_boss>0;
	progress["kills"] = (int)progress["kills"]+1;
	if((int)(team_count || 0)>1)
		progress["team_kills"] = (int)progress["team_kills"]+1;
	if(boss_kill)
		progress["boss_kills"] = (int)progress["boss_kills"]+1;
	mapping kill_week = ranking_week_state(progress,time(),1);
	kill_week["kills"] = (int)kill_week["kills"]+1;
	if((int)(team_count || 0)>1)
		kill_week["team_kills"] = (int)kill_week["team_kills"]+1;
	if(boss_kill)
		kill_week["boss_kills"] = (int)kill_week["boss_kills"]+1;
	// 破阵路线要求真正击败三名不同守关首领，重复刷同一名不计新印。
	if((string)progress["path"]=="hunter"){
		foreach((array)illusion_config["route_challenges"]["hunter_bosses"],
		   mapping boss)
			if((string)boss["path"]==npc_path){
				marks = mappingp(progress["route_marks"]) ?
					progress["route_marks"] : ([]);
				if(!(int)marks[(string)boss["id"]]){
					marks[(string)boss["id"]] = 1;
					route_mark_added = 1;
					kill_week["route_marks"] =
						(int)kill_week["route_marks"]+1;
				}
				progress["route_marks"] = marks;
				break;
			}
	}
	update_ranking_snapshot(player,progress);
	if(is_illusion_progress_checkpoint(progress,boss_kill,
	   route_mark_added,previous_team_kills)){
		if(!player->save_with_result()){
			player[ILLUSION_PROGRESS_ROOT+"/"+
				(string)illusion_config["current_id"]] = old_progress;
			werror("[ILLUSION_REALM] 击杀进度检查点存档失败并已回滚: %s kills=%d\n",
				(string)player->query_name(),(int)progress["kills"]);
			return;
		}
		if(!persist_ranking_snapshot(player,progress,
		   (string)illusion_config["current_id"]))
			werror("[ILLUSION_RANKING] 击杀快照待后续补写: %s\n",
				(string)player->query_name());
	}
	invalidate_ranking_cache((string)illusion_config["current_id"]);
}

private string path_name(string path)
{
	if(path=="pioneer") return "寻星";
	if(path=="hunter") return "破阵";
	if(path=="companion") return "同心";
	return "未选择";
}

private mapping(string:mixed) choose_player_path_internal(object player,
	string path,int test_bypass_phase)
{
	mapping progress;
	if(!is_active_illusion_character(player) ||
	   (!test_bypass_phase &&
	    (string)query_public_status()["phase"]!="active") ||
	   search(({"pioneer","hunter","companion"}),path)==-1)
		return (["ok":0,"message":"幻境路线无效。"]) ;
	progress = player_progress(player,1);
	if((string)progress["path"]!="")
		return (["ok":0,"message":(string)illusion_config["current_id"]+
			"路线已经选择，不能重复改变。"]) ;
	progress["path"] = path;
	if(!player->save_with_result()){
		progress["path"] = "";
		return (["ok":0,"message":"路线保存失败，请稍后重试。"]) ;
	}
	return (["ok":1,"message":"已选择“"+path_name(path)+
		"”路线，本期不可更改。"]);
}

mapping(string:mixed) choose_player_path(object player,string path)
{
	return choose_player_path_internal(player,path,0);
}

mapping(string:mixed) choose_player_path_for_test(object player,string path)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	return choose_player_path_internal(player,path,1);
}

private int route_final_ready(mapping progress)
{
	string path = (string)progress["path"];
	mapping marks = mappingp(progress["route_marks"]) ?
		progress["route_marks"] : ([]);
	mapping routes = illusion_config["route_challenges"];
	if(path=="pioneer"){
		foreach((array)routes["pioneer_secrets"],mapping secret)
			if(!(int)marks[(string)secret["id"]])
				return 0;
		return 1;
	}
	if(path=="hunter"){
		foreach((array)routes["hunter_bosses"],mapping boss)
			if(!(int)marks[(string)boss["id"]])
				return 0;
		return 1;
	}
	if(path=="companion")
		return (int)progress["team_kills"]>=
			(int)routes["companion_team_kills"];
	return 0;
}

private int route_target(string path)
{
	mapping routes = illusion_config["route_challenges"];
	if(path=="pioneer")
		return sizeof((array)routes["pioneer_secrets"]);
	if(path=="hunter")
		return sizeof((array)routes["hunter_bosses"]);
	if(path=="companion")
		return (int)routes["companion_team_kills"];
	return 0;
}

int query_route_final_ready_for_test(mapping progress)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return route_final_ready(progress);
}

private mapping(string:mixed) discover_route_secret_internal(object player,
	int test_bypass_phase)
{
	mapping progress;
	mapping old_progress;
	mapping marks;
	string room_path;
	mapping secret = ([]);
	if(!player || !is_active_illusion_character(player) ||
	   (!test_bypass_phase &&
	    (string)query_public_status()["phase"]!="active"))
		return (["ok":0,"message":"当前不能探寻"+
			(string)illusion_config["current_id"]+"隐藏月印。"]);
	progress = player_progress(player,1);
	if((string)progress["path"]!="pioneer")
		return (["ok":0,"message":"只有选择寻星路线的人物能辨认隐藏月印。"]);
	room_path = normalized_destination_path(environment(player));
	foreach((array)illusion_config["route_challenges"]["pioneer_secrets"],
	   mapping candidate)
		if((string)candidate["path"]==room_path){
			secret = candidate;
			break;
		}
	if(!sizeof(secret))
		return (["ok":0,"message":"这里没有可辨认的隐藏月印。"]);
	marks = mappingp(progress["route_marks"]) ?
		progress["route_marks"] : ([]);
	if((int)marks[(string)secret["id"]])
		return (["ok":1,"already":1,"message":"这枚月印已经收入你的"+
			(string)illusion_config["current_id"]+"历程。"]);
	old_progress = copy_value(progress);
	marks[(string)secret["id"]] = 1;
	progress["route_marks"] = marks;
	mapping secret_week = ranking_week_state(progress,time(),1);
	secret_week["route_marks"] = (int)secret_week["route_marks"]+1;
	update_ranking_snapshot(player,progress);
	if(!player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+
			(string)illusion_config["current_id"]] = old_progress;
		return (["ok":0,"message":"月印记录保存失败，请稍后重试。"]);
	}
	if(!persist_ranking_snapshot(player,progress,
	   (string)illusion_config["current_id"]))
		werror("[ILLUSION_RANKING] 月印快照待后续补写: %s\n",
			(string)player->query_name());
	invalidate_ranking_cache((string)illusion_config["current_id"]);
	return (["ok":1,"already":0,"message":(string)secret["message"],
		"route_mark_count":sizeof(marks)]);
}

mapping(string:mixed) discover_route_secret(object player)
{
	return discover_route_secret_internal(player,0);
}

mapping(string:mixed) discover_route_secret_for_test(object player)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]);
	return discover_route_secret_internal(player,1);
}

private mapping chapter_status(object player,mapping progress,
	mapping chapter,int index)
{
	mapping claims = mappingp(progress["claims"]) ? progress["claims"] : ([]);
	int previous_claimed = index==0 ||
		(int)claims[(string)((array)illusion_config["chapters"])[index-1]["id"]];
	int base_ready = (int)player->query_level()>=(int)chapter["min_level"] &&
		(int)progress["kills"]>=(int)chapter["kills"] &&
		(int)progress["boss_kills"]>=(int)chapter["boss_kills"] &&
		progress_visit_count(progress)>=(int)chapter["visits"];
	if(index>=2 && (string)progress["path"]=="")
		base_ready = 0;
	if(index==sizeof((array)illusion_config["chapters"])-1 &&
	   !route_final_ready(progress))
		base_ready = 0;
	return ([
		"id":(string)chapter["id"],
		"title":(string)chapter["title"],
		"description":(string)chapter["description"],
		"min_level":(int)chapter["min_level"],
		"kills":(int)chapter["kills"],
		"boss_kills":(int)chapter["boss_kills"],
		"visits":(int)chapter["visits"],
		"reward_count":(int)chapter["reward_count"],
		"claimed":(int)claims[(string)chapter["id"]],
		"ready":base_ready && previous_claimed,
	]);
}

mapping(string:mixed) query_player_progress(object player)
{
	mapping progress;
	array chapter_rows = ({});
	if(!player || !is_active_illusion_character(player))
		return (["ok":0,"message":"当前人物不是"+
			(string)illusion_config["current_id"]+"幻境人物。"]) ;
	progress = player_progress(player,1);
	foreach((array)illusion_config["chapters"];int index;mapping chapter)
		chapter_rows += ({chapter_status(player,progress,chapter,index)});
	return ([
		"ok":1,"illusion_id":(string)illusion_config["current_id"],
		"display_name":(string)illusion_config["display_name"],
		"level":(int)player->query_level(),
		"kills":(int)progress["kills"],
		"boss_kills":(int)progress["boss_kills"],
		"team_kills":(int)progress["team_kills"],
		"visits":progress_visit_count(progress),
		"route_mark_count":mappingp(progress["route_marks"]) ?
			sizeof((mapping)progress["route_marks"]) : 0,
		"path":(string)progress["path"],
		"path_name":path_name((string)progress["path"]),
		"route_target":route_target((string)progress["path"]),
		"pvp_honor":(int)progress["pvp_honor"],
		"pvp_wins":(int)progress["pvp_wins"],
		"ranking_week":ranking_week_index(progress,time()),
		"ranking_titles":arrayp(progress["ranking_titles"]) ?
			copy_value((array)progress["ranking_titles"]) : ({}),
		"chapters":chapter_rows,
	]);
}

private mapping(string:mixed) claim_chapter_reward_internal(object player,
	int chapter_number,int test_bypass_phase)
{
	mapping progress;
	mapping old_progress;
	mapping chapter;
	mapping status;
	array(string) templates;
	array(object) granted = ({});
	array(string) names = ({});
	int reward_start;
	string profession_id;
	if(!player || !is_active_illusion_character(player) ||
	   (!test_bypass_phase &&
	    (string)query_public_status()["phase"]!="active"))
		return (["ok":0,"message":"当前不能领取"+
			(string)illusion_config["current_id"]+"章节奖励。"]) ;
	if(chapter_number<1 ||
	   chapter_number>sizeof((array)illusion_config["chapters"]))
		return (["ok":0,"message":"章节编号无效。"]) ;
	progress = player_progress(player,1);
	old_progress = copy_value(progress);
	chapter = ((array)illusion_config["chapters"])[chapter_number-1];
	status = chapter_status(player,progress,chapter,chapter_number-1);
	if((int)status["claimed"])
		return (["ok":1,"already":1,"message":"该章节奖励已经领取。"]) ;
	if(!(int)status["ready"])
		return (["ok":0,"message":"章节目标尚未完成，或前一章尚未领取。"]) ;
	profession_id = (string)player->query_profeId();
	templates = ITEMSD->query_newmoon_base_templates_for_profession(
		profession_id);
	if(sizeof(templates)!=10)
		return (["ok":0,"message":"本职业"+
			(string)illusion_config["current_id"]+
			"套装模板校验失败，未发放奖励。"]) ;
	for(int index=0;index<chapter_number-1;index++)
		reward_start += (int)((array)illusion_config["chapters"])[index]["reward_count"];
	for(int offset=0;offset<(int)chapter["reward_count"];offset++){
		object item;
		mixed err = catch{ item=clone(ITEM_PATH+templates[reward_start+offset]); };
		if(err || !item ||
		   ITEMSD->bind_newmoon_item_to_player(item,player,"choice")<1 ||
		   item->move(player)!=1 || environment(item)!=player){
			if(item)
				destruct(item);
			foreach(granted,object old_item)
				if(old_item) destruct(old_item);
			player[ILLUSION_PROGRESS_ROOT+"/"+
				(string)illusion_config["current_id"]] = old_progress;
			return (["ok":0,"message":"奖励发放失败，背包与领取状态均未改变。"]) ;
		}
		granted += ({item});
		names += ({(string)item->query_name_cn()});
	}
	if(!mappingp(progress["claims"]))
		progress["claims"] = ([]);
	progress["claims"][(string)chapter["id"]] = time();
	mapping claim_week = ranking_week_state(progress,time(),1);
	claim_week["chapter_claims"] = (int)claim_week["chapter_claims"]+1;
	claim_week["set_parts"] = min(10,(int)claim_week["set_parts"]+
		(int)chapter["reward_count"]);
	if(chapter_number==sizeof((array)illusion_config["chapters"]))
		claim_week["completed_at"] = time();
	update_ranking_snapshot(player,progress);
	if(!player->save_with_result()){
		foreach(granted,object item)
			if(item) destruct(item);
		player[ILLUSION_PROGRESS_ROOT+"/"+
			(string)illusion_config["current_id"]] = old_progress;
		return (["ok":0,"message":"人物存档失败，奖励与领取状态已回滚。"]) ;
	}
	Stdio.append_file(ILLUSION_LOG,sprintf("%d|claim|illusion=%s|user=%s|chapter=%s|items=%d\n",
		time(),(string)illusion_config["current_id"],
		(string)player->query_name(),(string)chapter["id"],sizeof(granted)));
	if(!persist_ranking_snapshot(player,progress,
	   (string)illusion_config["current_id"]))
		werror("[ILLUSION_RANKING] 章节快照待后续补写: %s\n",
			(string)player->query_name());
	invalidate_ranking_cache((string)illusion_config["current_id"]);
	return (["ok":1,"message":"领取成功："+(names*"、"),"items":names]);
}

mapping(string:mixed) claim_chapter_reward(object player,int chapter_number)
{
	return claim_chapter_reward_internal(player,chapter_number,0);
}

mapping(string:mixed) claim_chapter_reward_for_test(object player,
	int chapter_number)
{
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	return claim_chapter_reward_internal(player,chapter_number,1);
}

private string ranking_duration_text(int seconds)
{
	int days;
	int hours;
	int minutes;
	if(seconds<0)
		seconds = 0;
	days = seconds/86400;
	hours = (seconds%86400)/3600;
	minutes = (seconds%3600)/60;
	if(days>0)
		return sprintf("%d天%02d小时",days,hours);
	if(hours>0)
		return sprintf("%d小时%02d分",hours,minutes);
	return sprintf("%d分%02d秒",minutes,seconds%60);
}

private int valid_ranking_period(string period)
{
	int week;
	return period=="overall" ||
		(sscanf(period,"week:%d",week)==1 && week>=1 && week<=60 &&
		 period=="week:"+(string)week);
}

private string ranking_progress_validation_error(mapping progress)
{
	array(string) nonnegative_fields = ({
		"joined_at","season_starts_at","kills","boss_kills","team_kills",
		"visited_count","claims_count","route_marks_count",
		"pvp_honor","pvp_wins","ranking_level",
		"ranking_experience_latest","set_parts","completed_at",
	});
	if(!mappingp(progress) || sizeof(progress)>80)
		return "root";
	foreach(nonnegative_fields,string field)
		if(has_index(progress,field) &&
		   (!intp(progress[field]) || (int)progress[field]<0 ||
		    (int)progress[field]>2000000000))
			return "field:"+field;
	if(has_index(progress,"ranking_experience_start") &&
	   (!intp(progress["ranking_experience_start"]) ||
	    (int)progress["ranking_experience_start"] < -1 ||
	    (int)progress["ranking_experience_start"] > 2000000000))
		return "field:ranking_experience_start";
	foreach(({({"visited",4096}),({"claims",64}),({"route_marks",64}),
		({"pvp_opponents",512}),({"ranking_reward_claims",400})}),
	   array spec)
		if(has_index(progress,(string)spec[0]) &&
		   (!mappingp(progress[(string)spec[0]]) ||
		    sizeof((mapping)progress[(string)spec[0]])>(int)spec[1]))
			return "mapping:"+(string)spec[0];
	if(has_index(progress,"ranking_titles") &&
	   (!arrayp(progress["ranking_titles"]) ||
	    sizeof((array)progress["ranking_titles"])>64))
		return "ranking_titles";
	if(mappingp(progress["ranking_weeks"])){
		mapping weeks = (mapping)progress["ranking_weeks"];
		if(sizeof(weeks)>60)
			return "ranking_weeks:size";
		foreach(indices(weeks),mixed week_key){
			int week;
			if(!stringp(week_key) ||
			   sscanf((string)week_key,"%d",week)!=1 || week<1 || week>60 ||
			   (string)week_key!=(string)week || !mappingp(weeks[week_key]) ||
			   sizeof((mapping)weeks[week_key])>24)
				return "ranking_weeks:key_or_state";
		}
	}
	else if(has_index(progress,"ranking_weeks"))
		return "ranking_weeks:type";
	return "";
}

private int valid_ranking_progress(mapping progress)
{
	return ranking_progress_validation_error(progress)=="";
}

private int valid_ranking_character_id(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>64)
		return 0;
	foreach(value;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='_' || one=='-')
			continue;
		return 0;
	}
	return 1;
}

private int compact_ranking_int(mapping progress,string field,int fallback)
{
	return has_index(progress,field) && intp(progress[field]) ?
		(int)progress[field] : (int)fallback;
}

private mapping compact_ranking_progress(mapping progress)
{
	return ([
		"joined_at":compact_ranking_int(progress,"joined_at",0),
		"season_starts_at":compact_ranking_int(progress,
			"season_starts_at",0),
		"kills":compact_ranking_int(progress,"kills",0),
		"boss_kills":compact_ranking_int(progress,"boss_kills",0),
		"team_kills":compact_ranking_int(progress,"team_kills",0),
		"visited_count":progress_visit_count(progress),
		"claims_count":mappingp(progress["claims"]) ?
			sizeof((mapping)progress["claims"]) : 0,
		"route_marks_count":mappingp(progress["route_marks"]) ?
			sizeof((mapping)progress["route_marks"]) : 0,
		"pvp_honor":compact_ranking_int(progress,"pvp_honor",0),
		"pvp_wins":compact_ranking_int(progress,"pvp_wins",0),
		"ranking_level":compact_ranking_int(progress,"ranking_level",0),
		"ranking_experience_start":
			compact_ranking_int(progress,"ranking_experience_start",-1),
		"ranking_experience_latest":
			compact_ranking_int(progress,"ranking_experience_latest",0),
		"set_parts":compact_ranking_int(progress,"set_parts",0),
		"completed_at":compact_ranking_int(progress,"completed_at",0),
		"ranking_weeks":mappingp(progress["ranking_weeks"]) ?
			copy_value((mapping)progress["ranking_weeks"]) : ([]),
	]);
}

private int persist_ranking_snapshot(object player,mapping progress,
	string illusion_id)
{
	string character_id;
	string directory;
	string path;
	string temp_path;
	string encoded;
	string name_cn;
	string profession_id;
	string profession_name;
	mapping compact;
	mapping snapshot;
	int ok;
	mixed err;
	if(!player || !valid_identifier(illusion_id) ||
	   !valid_ranking_progress(progress))
		return 0;
	character_id = (string)player->query_name();
	if(!valid_ranking_character_id(character_id))
		return 0;
	name_cn = functionp(player->query_name_cn) ?
		(string)player->query_name_cn(1) : character_id;
	if(name_cn=="" || sizeof(name_cn)>96)
		name_cn = character_id;
	profession_id = functionp(player->query_profeId) ?
		(string)player->query_profeId() : "";
	profession_name = (string)TASKD->
		query_growth_task_profession_name(profession_id);
	if(profession_name=="" || sizeof(profession_name)>32)
		profession_name = profession_id!="" ? profession_id : "未知职业";
	compact = compact_ranking_progress(progress);
	if(!valid_ranking_progress(compact))
		return 0;
	snapshot = ([
		"version":1,"illusion_id":illusion_id,
		"character_id":character_id,"name_cn":name_cn,
		"profession_id":profession_id,
		"profession_name":profession_name,
		"level":max(1,(int)compact["ranking_level"]),
		"illusion_progress":compact,"updated_at":time(),
	]);
	encoded = Standards.JSON.encode(snapshot);
	directory = ILLUSION_RANKING_DIR+"/"+illusion_id;
	path = directory+"/"+character_id+".json";
	temp_path = path+"."+
		String.string2hex(Crypto.Random.random_string(8))+".tmp";
	err = catch{
		Stdio.mkdirhier(directory);
		if(Stdio.write_file(temp_path,encoded)==sizeof(encoded) &&
		   Stdio.file_size(temp_path)==sizeof(encoded) &&
		   mv(temp_path,path) && Stdio.file_size(path)==sizeof(encoded))
			ok = 1;
	};
	if(err)
		werror("[ILLUSION_RANKING] 快照保存异常 user=%s error=%s\n",
			character_id,describe_error(err));
	if(!ok)
		rm(temp_path);
	return ok;
}

private mapping(string:mixed) query_ranking_snapshots(string illusion_id)
{
	mapping result = (["ok":0,"characters":({}),"corrupt":0,
		"truncated":0]);
	string directory = ILLUSION_RANKING_DIR+"/"+illusion_id;
	array candidates = ({});
	if(!valid_identifier(illusion_id))
		return result;
	foreach(get_dir(directory) || ({}),string filename){
		string character_id;
		string content;
		string invalid_reason = "";
		mixed decoded;
		mixed err;
		if(!has_suffix(filename,".json"))
			continue;
		character_id = filename[..sizeof(filename)-6];
		if(!valid_ranking_character_id(character_id)){
			result["corrupt"] = (int)result["corrupt"]+1;
			continue;
		}
		if(sizeof(candidates)>=5000){
			result["truncated"] = 1;
			continue;
		}
		content = Stdio.read_file(directory+"/"+filename) || "";
		err = catch { decoded=Standards.JSON.decode(content); };
		if(err)
			invalid_reason = "json_decode";
		else if(!mappingp(decoded))
			invalid_reason = "root_not_mapping";
		else if((int)decoded["version"]!=1)
			invalid_reason = "version";
		else if((string)decoded["illusion_id"]!=illusion_id)
			invalid_reason = "illusion_id";
		else if((string)decoded["character_id"]!=character_id)
			invalid_reason = "character_id";
		else if(!stringp(decoded["name_cn"]) ||
		   sizeof((string)decoded["name_cn"])>96)
			invalid_reason = "name_cn";
		else if(!stringp(decoded["profession_name"]) ||
		   sizeof((string)decoded["profession_name"])>32)
			invalid_reason = "profession_name";
		else if(!mappingp(decoded["illusion_progress"]))
			invalid_reason = "progress_type";
		else if(!valid_ranking_progress(
		   (mapping)decoded["illusion_progress"]))
			invalid_reason = "progress_"+
				ranking_progress_validation_error(
					(mapping)decoded["illusion_progress"]);
		if(invalid_reason!=""){
			mixed invalid_value = 0;
			if(has_prefix(invalid_reason,"progress_field:") &&
			   mappingp(decoded) &&
			   mappingp(decoded["illusion_progress"])){
				string invalid_field = invalid_reason[
					sizeof("progress_field:")..];
				invalid_value =
					((mapping)decoded["illusion_progress"])[invalid_field];
			}
			werror("[ILLUSION_RANKING] 拒绝损坏快照 file=%s reason=%s value=%O bytes=%d\n",
				filename,invalid_reason,invalid_value,sizeof(content));
			result["corrupt"] = (int)result["corrupt"]+1;
			continue;
		}
		candidates += ({([
			"id":character_id,"name_cn":(string)decoded["name_cn"],
			"profession_name":(string)decoded["profession_name"],
			"level":max(1,(int)decoded["level"]),
			"illusion_state":"snapshot",
			"illusion_progress":copy_value(
				(mapping)decoded["illusion_progress"]),
		])});
	}
	result["characters"] = candidates;
	result["ok"] = !(int)result["corrupt"] &&
		!(int)result["truncated"];
	return result;
}

private mapping(string:mixed) ranking_score_for_profile(string board,
	mapping profile,string period,string illusion_id)
{
	mapping progress = mappingp(profile["illusion_progress"]) ?
		(mapping)profile["illusion_progress"] : ([]);
	mapping source = progress;
	int score;
	int tie;
	int completed_at;
	int joined_at = (int)progress["joined_at"];
	int week_number;
	if(!sizeof(progress) || !valid_ranking_progress(progress) ||
	   !ranking_names[board] ||
	   !valid_ranking_period(period))
		return (["eligible":0]);
	if(period!="overall"){
		sscanf(period,"week:%d",week_number);
		mapping weeks = mappingp(progress["ranking_weeks"]) ?
			(mapping)progress["ranking_weeks"] : ([]);
		if(!mappingp(weeks[(string)week_number]))
			return (["eligible":0]);
		source = (mapping)weeks[(string)week_number];
	}
	switch(board){
	case "journey":
		if(period=="overall")
			score = (has_index(progress,"claims_count") ?
				(int)progress["claims_count"] :
				(mappingp(progress["claims"]) ?
				sizeof((mapping)progress["claims"]) : 0))*10000+
				(has_index(progress,"route_marks_count") ?
				(int)progress["route_marks_count"] :
				(mappingp(progress["route_marks"]) ?
				sizeof((mapping)progress["route_marks"]) : 0))*1000+
				(int)progress["boss_kills"]*100+
				(has_index(progress,"visited_count") ?
				(int)progress["visited_count"] :
				progress_visit_count(progress))*20+
				(int)progress["team_kills"]*10+(int)progress["kills"];
		else
			score = (int)source["chapter_claims"]*10000+
				(int)source["route_marks"]*1000+
				(int)source["boss_kills"]*100+
				(int)source["visits"]*20+
				(int)source["team_kills"]*10+(int)source["kills"];
		tie = period=="overall" ? (int)progress["ranking_level"] :
			(int)source["level"];
		break;
	case "level":
		score = period=="overall" ? (int)progress["ranking_level"] :
			(int)source["level"];
		if((string)profile["illusion_state"]=="active" &&
		   (period=="overall" || week_number==
		    ranking_week_index(progress,time())))
			score = max(score,(int)profile["level"]);
		tie = max(0,(int)progress["ranking_experience_latest"]-
			(int)progress["ranking_experience_start"]);
		break;
	case "experience":
		if(period=="overall"){
			int start = (int)progress["ranking_experience_start"];
			int latest = (int)progress["ranking_experience_latest"];
			if(start<0 && (string)profile["illusion_state"]=="active")
				start = 0;
			if((string)profile["illusion_state"]=="active")
				latest = max(latest,(int)profile["experience"]);
			score = max(0,latest-start);
			tie = (int)progress["ranking_level"];
		}
		else{
			int weekly_latest = (int)source["experience_latest"];
			if((string)profile["illusion_state"]=="active" &&
			   week_number==ranking_week_index(progress,time()))
				weekly_latest = max(weekly_latest,(int)profile["experience"]);
			score = max(0,weekly_latest-
				(int)source["experience_start"]);
			tie = (int)source["level"];
		}
		break;
	case "pk":
		score = period=="overall" ? (int)progress["pvp_honor"] :
			(int)source["pvp_honor"];
		tie = period=="overall" ? (int)progress["pvp_wins"] :
			(int)source["pvp_wins"];
		break;
	case "set":
		score = period=="overall" ? (int)progress["set_parts"] :
			(int)source["set_parts"];
		if(score<=0 && period=="overall" &&
		   illusion_id==(string)illusion_config["current_id"])
			score = claimed_set_parts(progress);
		completed_at = period=="overall" ? (int)progress["completed_at"] :
			(int)source["completed_at"];
		tie = completed_at>0 ? 2000000000-completed_at :
			(int)progress["ranking_level"];
		break;
	case "speed":
		completed_at = period=="overall" ? (int)progress["completed_at"] :
			(int)source["completed_at"];
		if(completed_at<=0 || joined_at<=0 || completed_at<joined_at)
			return (["eligible":0]);
		score = completed_at-joined_at;
		tie = period=="overall" ? (int)progress["ranking_level"] :
			(int)source["level"];
		break;
	}
	if(score<=0 && board!="level")
		return (["eligible":0]);
	return (["eligible":score>0,"score":score,"tie":tie]);
}

private int ranking_entry_before(mapping left,mapping right,string board)
{
	if((int)left["score"]!=(int)right["score"])
		return board=="speed" ?
			(int)left["score"]<(int)right["score"] :
			(int)left["score"]>(int)right["score"];
	if((int)left["tie"]!=(int)right["tie"])
		return (int)left["tie"]>(int)right["tie"];
	return (string)left["character_id"]<(string)right["character_id"];
}

private array(mapping(string:mixed)) insert_ranking_entry(
	array(mapping(string:mixed)) rows,mapping(string:mixed) entry,
	string board)
{
	array(mapping(string:mixed)) result = ({});
	int inserted;
	foreach(rows,mapping row){
		if(!inserted && ranking_entry_before(entry,row,board)){
			result += ({entry});
			inserted = 1;
		}
		result += ({row});
	}
	if(!inserted)
		result += ({entry});
	if(sizeof(result)>100)
		result = result[..99];
	return result;
}

mapping(string:mixed) query_illusion_leaderboard(string illusion_id,
	string board,string period,void|int requested_limit)
{
	int limit = min(50,max(1,(int)(requested_limit || 20)));
	string cache_key = illusion_id+"|"+board+"|"+period;
	mapping cached = ranking_cache[cache_key];
	mapping candidate_result;
	array(mapping(string:mixed)) rows = ({});
	if(!valid_identifier(illusion_id) || !ranking_names[board] ||
	   !valid_ranking_period(period))
		return (["ok":0,"message":"排行榜参数无效。","rows":({})]);
	if(mappingp(cached) && time()-(int)cached["created_at"]<=
	   ILLUSION_RANKING_CACHE_TTL){
		mapping cached_result = copy_value((mapping)cached["result"]);
		cached_result["rows"] = ((array)cached_result["rows"])[..limit-1];
		return cached_result;
	}
	candidate_result = query_ranking_snapshots(illusion_id);
	if(!(int)candidate_result["ok"])
		return (["ok":0,"message":"排行榜快照未能完整校验，已拒绝显示不完整榜单。",
			"rows":({}),"corrupt":(int)candidate_result["corrupt"],
			"truncated":(int)candidate_result["truncated"]]);
	foreach((array)candidate_result["characters"],mapping profile){
		if(sizeof((mapping)(profile["illusion_progress"] || ([]))) &&
		   !valid_ranking_progress((mapping)profile["illusion_progress"]))
			return (["ok":0,"message":"发现损坏的幻境历程，已拒绝显示可能错误的榜单。",
				"rows":({}),"character_id":(string)profile["id"]]);
		mapping scored = ranking_score_for_profile(board,profile,period,
			illusion_id);
		if(!(int)scored["eligible"])
			continue;
		mapping entry = ([
			"character_id":(string)profile["id"],
			"name_cn":(string)profile["name_cn"],
			"profession_name":(string)profile["profession_name"],
			"level":(int)profile["level"],
			"score":(int)scored["score"],"tie":(int)scored["tie"],
		]);
		if(board=="speed")
			entry["score_text"] = ranking_duration_text((int)entry["score"]);
		else if(board=="level")
			entry["score_text"] = "Lv"+(string)(int)entry["score"];
		else if(board=="set")
			entry["score_text"] = (string)(int)entry["score"]+"件";
		else if(board=="pk")
			entry["score_text"] = (string)(int)entry["score"]+"荣誉";
		else
			entry["score_text"] = (string)(int)entry["score"]+"点";
		rows = insert_ranking_entry(rows,entry,board);
	}
	for(int index=0;index<sizeof(rows);index++)
		rows[index]["rank"] = index+1;
	mapping result = ([
		"ok":1,"illusion_id":illusion_id,"board":board,
		"board_name":ranking_names[board],"period":period,
		"rows":rows,"generated_at":time(),
	]);
	ranking_cache[cache_key] = (["created_at":time(),
		"result":copy_value(result)]);
	result = copy_value(result);
	result["rows"] = ((array)result["rows"])[..limit-1];
	return result;
}

private int pvp_honor_points(int winner_level,int loser_level,
	int same_account,int prior_wins)
{
	int points;
	if(same_account || winner_level<1 || loser_level<1 || prior_wins<0 ||
	   winner_level-loser_level>max(10,loser_level/5))
		return 0;
	if(prior_wins==0) points = 100;
	else if(prior_wins==1) points = 50;
	else if(prior_wins==2) points = 20;
	else return 0;
	if(winner_level<loser_level)
		points += min(50,(loser_level-winner_level)*2);
	return points;
}

private int ranking_beijing_day_index(int timestamp)
{
	// 幻境活动与玩家规则均以北京时间展示，日防刷也必须在
	// 北京时间00:00重置，不能误用UTC日界线（北京时间08:00）。
	return (timestamp+8*3600)/86400;
}

mapping(string:mixed) record_pvp_victory(object winner,object loser)
{
	mapping winner_realm;
	mapping loser_realm;
	mapping progress;
	mapping old_progress;
	mapping opponents;
	string opponent_account;
	int today = ranking_beijing_day_index(time());
	int prior_wins;
	int points;
	if(!winner || !loser || !is_active_illusion_character(winner) ||
	   !is_active_illusion_character(loser))
		return (["ok":1,"points":0,"message":"非幻境论剑，不计幻境荣誉。"]);
	winner_realm = query_realm_for_player(winner);
	loser_realm = query_realm_for_player(loser);
	if((string)winner_realm["illusion_id"]!=
	   (string)loser_realm["illusion_id"] ||
	   (string)winner_realm["illusion_id"]!=
	   (string)illusion_config["current_id"])
		return (["ok":1,"points":0,"message":"双方不在同一期幻境，不计荣誉。"]);
	if((string)winner_realm["account_id"]==
	   (string)loser_realm["account_id"])
		return (["ok":1,"points":0,"message":"同一注册账号切磋不计论剑荣誉。"]);
	progress = player_progress(winner,1);
	old_progress = copy_value(progress);
	if((int)progress["pvp_day"]!=today){
		progress["pvp_day"] = today;
		progress["pvp_opponents"] = ([]);
	}
	opponents = mappingp(progress["pvp_opponents"]) ?
		(mapping)progress["pvp_opponents"] : ([]);
	opponent_account = (string)loser_realm["account_id"];
	prior_wins = (int)opponents[opponent_account];
	points = pvp_honor_points((int)winner->query_level(),
		(int)loser->query_level(),0,prior_wins);
	if(points<=0)
		return (["ok":1,"points":0,"message":prior_wins>=3 ?
			"今日对同一对手的前三次荣誉已经结算。" :
			"等级差距过大，本场不计论剑荣誉。"]);
	if(sizeof(opponents)>=512 && !has_index(opponents,opponent_account))
		return (["ok":0,"points":0,"message":"今日对手记录已达安全上限，本场不计荣誉。"]);
	opponents[opponent_account] = prior_wins+1;
	progress["pvp_opponents"] = opponents;
	progress["pvp_honor"] = (int)progress["pvp_honor"]+points;
	progress["pvp_wins"] = (int)progress["pvp_wins"]+1;
	mapping pvp_week = ranking_week_state(progress,time(),1);
	pvp_week["pvp_honor"] = (int)pvp_week["pvp_honor"]+points;
	pvp_week["pvp_wins"] = (int)pvp_week["pvp_wins"]+1;
	update_ranking_snapshot(winner,progress);
	if(!winner->save_with_result()){
		winner[ILLUSION_PROGRESS_ROOT+"/"+
			(string)illusion_config["current_id"]] = old_progress;
		return (["ok":0,"points":0,"message":"论剑荣誉保存失败，本场不计分。"]);
	}
	if(!persist_ranking_snapshot(winner,progress,
	   (string)illusion_config["current_id"]))
		werror("[ILLUSION_RANKING] 论剑快照待后续补写: %s\n",
			(string)winner->query_name());
	invalidate_ranking_cache((string)illusion_config["current_id"]);
	Stdio.append_file(ILLUSION_LOG,sprintf("%d|pvp_honor|illusion=%s|winner=%s|loser=%s|points=%d|repeat=%d\n",
		time(),(string)illusion_config["current_id"],
		(string)winner->query_name(),(string)loser->query_name(),points,
		prior_wins));
	return (["ok":1,"points":points,"message":"本场获得"+
		(string)points+"点幻境论剑荣誉。"]);
}

mapping(string:mixed) claim_illusion_ranking_reward(object player,
	string board,string period)
{
	mapping status = query_public_status();
	string illusion_id = (string)status["illusion_id"];
	mapping progress;
	mapping old_progress;
	mapping leaderboard;
	mapping claims;
	array titles;
	string claim_key;
	string title;
	int week;
	int current_week;
	int rank;
	if(!player || !ranking_names[board] || !valid_ranking_period(period))
		return (["ok":0,"message":"排行榜奖励参数无效。"]);
	progress = player_progress_for_id(player,illusion_id,0);
	if(!sizeof(progress))
		return (["ok":0,"message":"当前人物没有本期幻境历程。"]);
	current_week = ranking_week_index(progress,time());
	if(period=="overall"){
		if((string)status["phase"]!="settling" &&
		   (string)status["phase"]!="closed")
			return (["ok":0,"message":"幻境总榜将在本期结束后结算。"]);
	}
	else{
		sscanf(period,"week:%d",week);
		if((string)status["phase"]=="active" && week>=current_week)
			return (["ok":0,"message":"本周榜尚未结算。"]);
		if(week>current_week)
			return (["ok":0,"message":"该周尚未开始。"]);
	}
	claim_key = period+"|"+board;
	claims = mappingp(progress["ranking_reward_claims"]) ?
		(mapping)progress["ranking_reward_claims"] : ([]);
	if(mappingp(claims[claim_key]))
		return (["ok":1,"already":1,"message":"该榜荣誉已经领取："+
			(string)claims[claim_key]["title"]]);
	leaderboard = query_illusion_leaderboard(illusion_id,board,period,10);
	if(!(int)leaderboard["ok"])
		return (["ok":0,"message":(string)leaderboard["message"]]);
	foreach((array)leaderboard["rows"],mapping row)
		if((string)row["character_id"]==(string)player->query_name()){
			rank = (int)row["rank"];
			break;
		}
	if(rank<1 || rank>10)
		return (["ok":0,"message":"当前人物不在该榜前十，暂无可领取荣誉。"]);
	title = illusion_id+"·"+(period=="overall" ? "终榜" :
		"周"+(string)week)+"·"+(rank==1 ? "魁首" :
		(rank<=3 ? "三甲" : "十强"))+"·"+(string)ranking_names[board];
	old_progress = copy_value(progress);
	claims[claim_key] = (["claimed_at":time(),"rank":rank,"title":title]);
	progress["ranking_reward_claims"] = claims;
	titles = arrayp(progress["ranking_titles"]) ?
		(array)progress["ranking_titles"] : ({});
	titles += ({title});
	if(sizeof(titles)>64)
		titles = titles[sizeof(titles)-64..];
	progress["ranking_titles"] = titles;
	if(!player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+illusion_id] = old_progress;
		return (["ok":0,"message":"排行榜荣誉保存失败，本次仍可重试。"]);
	}
	Stdio.append_file(ILLUSION_LOG,sprintf("%d|ranking_reward|illusion=%s|user=%s|board=%s|period=%s|rank=%d\n",
		time(),illusion_id,(string)player->query_name(),board,period,rank));
	return (["ok":1,"rank":rank,"title":title,
		"message":"已获得幻境荣誉称号："+title+"（仅展示收藏，不增加战斗属性）。"]);
}

mapping(string:mixed) query_ranking_score_for_test(string board,
	mapping profile,string period,string illusion_id)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return (["eligible":0]);
	return ranking_score_for_profile(board,profile,period,illusion_id);
}

int query_pvp_honor_points_for_test(int winner_level,int loser_level,
	int same_account,int prior_wins)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return pvp_honor_points(winner_level,loser_level,same_account,prior_wins);
}

int query_ranking_beijing_day_for_test(int timestamp)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return -1;
	return ranking_beijing_day_index(timestamp);
}

mapping(string:mixed) purchase_entitlement(object player)
{
	mapping status = query_public_status();
	mapping account_data;
	mapping grant;
	string account_id;
	int cost;
	int before_wallet;
	int before_physical;
	string request_id;
	string success_message;
	if(!player || !(int)status["ok"] || !(int)status["entitlement_open"])
		return (["ok":0,"message":"当前未开放幻境资格购买。"]) ;
	account_id = (string)player->query_account_owner();
	account_data = ACCOUNT_CHARACTERD->query_account_characters(account_id,
		(string)status["illusion_id"]);
	if(!(int)account_data["ok"]){
		return (["ok":0,
			"message":"账号索引暂不可验证，本次未扣除碎玉。"]) ;
	}
	if((int)account_data["illusion_entitled"]){
		return (["ok":1,"already":1,
			"message":"账号已永久解锁"+
				(string)status["illusion_id"]+"人物资格。"]) ;
	}
	cost = (int)status["entitlement_cost_suiyu"];
	before_wallet = ACCOUNT_WALLETD->query_balance(player);
	before_physical = YUSHID->query_physical_all_num(player);
	if(mappingp(player[ILLUSION_PAYMENT_ROOT]) &&
	   sizeof((mapping)player[ILLUSION_PAYMENT_ROOT])){
		return (["ok":0,
			"message":"上一笔幻境资格购买仍在恢复，请重新登录后再试。"]);
	}
	{
		object request_hash = Crypto.SHA256();
		request_hash->update(account_id+"|"+(string)player->query_name()+"|"+
			(string)time()+"|"+String.string2hex(
				Crypto.Random.random_string(16)));
		request_id = lower_case(String.string2hex(request_hash->digest()));
	}
	player[ILLUSION_PAYMENT_ROOT] = ([
		"version":1,"phase":"prepared","request_id":request_id,
		"account_id":account_id,
		"illusion_id":(string)illusion_config["current_id"],
		"cost":cost,"before_wallet":before_wallet,
		"before_physical":before_physical,"created_at":time(),
	]);
	if(!player->save_with_result()){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		return (["ok":0,"message":"购买凭据保存失败，本次未扣除碎玉。"]) ;
	}
	if(cost>0 && !YUSHID->pay_yushi(player,cost)){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return (["ok":0,"message":"碎玉不足或扣款失败，未解锁资格。"]) ;
	}
	player[ILLUSION_PAYMENT_ROOT]["phase"] = "charged";
	if(!player->save_with_result()){
		int refunded = YUSHID->rollback_yushi_payment(player,before_wallet,
			before_physical,"illusion_entitlement_charge_save_failed");
		if(refunded){
			player[ILLUSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"扣款存档失败，碎玉已原路退回。" :
			"扣款存档与退款异常，请立即联系管理员。"]);
	}
	grant = ACCOUNT_CHARACTERD->grant_illusion_entitlement(account_id,
		"jade",request_id,(string)status["illusion_id"]);
	if(!(int)grant["ok"]){
		int refunded = cost<=0 || YUSHID->rollback_yushi_payment(player,
			before_wallet,before_physical,"illusion_entitlement_failed");
		if(refunded){
			player[ILLUSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"资格写入失败，碎玉已原路退回。" :
			"资格写入及退款异常，请立即联系管理员。"]) ;
	}
	if((int)grant["already"]){
		// 账号可能在本次扣款期间由另一请求或管理员完成了解锁。
		// 本请求没有取得资格写入权，必须退回自己的这一笔扣款。
		int refunded = cost<=0 || YUSHID->rollback_yushi_payment(player,
			before_wallet,before_physical,
			"illusion_entitlement_duplicate_charge");
		if(refunded){
			player[ILLUSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":refunded,"already":refunded,
			"message":refunded ?
			"账号已永久解锁"+(string)status["illusion_id"]+
				"人物资格；本次重复扣款已原路退回。" :
			"检测到重复扣款但退款仍需重试，请重新登录或联系管理员。"]) ;
	}
	// 资格索引已经持久化。这里即使清理凭据失败，登录恢复也只会
	// 清凭据而不会退款，不能让已解锁账号重复获得碎玉。
	player[ILLUSION_PAYMENT_ROOT]["phase"] = "committed";
	player->save_with_result();
	player[ILLUSION_PAYMENT_ROOT] = ([]);
	int cleanup_saved = player->save_with_result();
	Stdio.append_file(ILLUSION_LOG,sprintf("%d|entitlement|illusion=%s|account=%s|character=%s|cost=%d|request=%s|cleanup=%d\n",
		time(),(string)status["illusion_id"],account_id,
		(string)player->query_name(),cost,request_id,
		cleanup_saved));
	if(cost>0)
		success_message = "已支付"+(string)cost+"碎玉并永久激活"+
			(string)status["illusion_id"]+"人物资格；额外栏位仅对本期生效。";
	else
		success_message = "已免费永久激活"+(string)status["illusion_id"]+
			"人物资格；本期首名人物免费，额外栏位仅对本期生效。";
	return (["ok":1,"already":0,"message":success_message]) ;
}

/**
 * The account centre has no live character object and therefore cannot use
 * the jade transaction flow.  It may activate an entitlement only while the
 * configured price is exactly zero.  A future paid season fails closed and
 * must continue through the character-bound payment credential above.
 */
mapping(string:mixed) activate_free_account_entitlement(string requested_id)
{
	mapping status = query_public_status();
	object request_hash;
	string request_id;
	if(!requested_id || !(int)status["ok"])
		return (["ok":0,"message":"幻境资格当前不可用。"]);
	if((int)status["entitlement_cost_suiyu"]!=0)
		return (["ok":0,
			"message":"当前资格不是免费项目，请进入人物内完成安全支付。"]);
	request_hash = Crypto.SHA256();
	request_hash->update(requested_id+"|account_center|"+(string)time()+
		"|"+String.string2hex(Crypto.Random.random_string(16)));
	request_id = lower_case(String.string2hex(request_hash->digest()));
	return ACCOUNT_CHARACTERD->grant_illusion_entitlement(requested_id,
		"account_center",request_id,(string)status["illusion_id"]);
}

mapping(string:mixed) purchase_character_expansion(object player,string option)
{
	mapping status = query_public_status();
	mapping account_data;
	mapping grant;
	mapping entitlement;
	string account_id;
	string request_id;
	int spent;
	int cost;
	int before_wallet;
	int before_physical;
	if(!player || !(int)status["ok"] || !(int)status["entitlement_open"])
		return (["ok":0,"message":"当前未开放幻境人物栏位扩充。"]) ;
	if(search(({"one","all"}),option)==-1)
		return (["ok":0,"message":"请选择增加1格或解锁多人物。"]) ;
	account_id = (string)player->query_account_owner();
	account_data = ACCOUNT_CHARACTERD->query_account_characters(account_id,
		(string)status["illusion_id"]);
	if(!(int)account_data["ok"])
		return (["ok":0,
			"message":"账号索引暂不可验证，本次未扣除碎玉。"]) ;
	if(!(int)account_data["illusion_entitled"])
		return (["ok":0,"message":"请先免费激活"+
			(string)status["illusion_id"]+"人物资格。"]) ;
	if((int)account_data["illusion_multi_character_unlocked"])
		return (["ok":1,"already":1,
			"message":"本期已解锁幻境多人物，无需再次付费。"]) ;
	spent = (int)account_data["illusion_expansion_spent_suiyu"];
	cost = option=="one" ?
		(int)status["extra_character_slot_cost_suiyu"] :
		(int)status["multi_character_unlock_cost_suiyu"]-spent;
	if(spent<0 || spent>=500 || spent%100!=0 || cost<=0 || cost>500)
		return (["ok":0,
			"message":"幻境栏位累计抵扣状态异常，本次未扣款。"]) ;
	if((mappingp(player[ILLUSION_PAYMENT_ROOT]) &&
	   sizeof((mapping)player[ILLUSION_PAYMENT_ROOT])) ||
	   (mappingp(player[ILLUSION_EXPANSION_PAYMENT_ROOT]) &&
	   sizeof((mapping)player[ILLUSION_EXPANSION_PAYMENT_ROOT])))
		return (["ok":0,
			"message":"上一笔幻境交易仍在恢复，请重新登录后再试。"]) ;
	before_wallet = ACCOUNT_WALLETD->query_balance(player);
	before_physical = YUSHID->query_physical_all_num(player);
	{
		object request_hash = Crypto.SHA256();
		request_hash->update(account_id+"|"+(string)player->query_name()+"|"+
			option+"|"+(string)time()+"|"+String.string2hex(
				Crypto.Random.random_string(16)));
		request_id = lower_case(String.string2hex(request_hash->digest()));
	}
	player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([
		"version":1,"phase":"prepared","request_id":request_id,
		"account_id":account_id,
		"illusion_id":(string)illusion_config["current_id"],
		"option":option,"cost":cost,"before_wallet":before_wallet,
		"before_physical":before_physical,"created_at":time(),
	]);
	if(!player->save_with_result()){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		return (["ok":0,"message":"扩容凭据保存失败，本次未扣除碎玉。"]) ;
	}
	if(!YUSHID->pay_yushi(player,cost)){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return (["ok":0,"message":"碎玉不足或扣款失败，幻境栏位未改变。"]) ;
	}
	player[ILLUSION_EXPANSION_PAYMENT_ROOT]["phase"] = "charged";
	if(!player->save_with_result()){
		int refunded = YUSHID->rollback_yushi_payment(player,before_wallet,
			before_physical,"illusion_expansion_charge_save_failed");
		if(refunded){
			player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"扣款存档失败，碎玉已原路退回。" :
			"扣款存档与退款异常，请立即联系管理员。"]) ;
	}
	grant = ACCOUNT_CHARACTERD->grant_illusion_character_expansion(
		account_id,(string)status["illusion_id"],option,request_id,cost);
	if(!(int)grant["ok"] ||
	   ((int)grant["already"] && !(int)grant["same_request"])){
		int refunded = YUSHID->rollback_yushi_payment(player,before_wallet,
			before_physical,"illusion_expansion_failed");
		if(refunded){
			player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
			player->save_with_result();
		}
		return (["ok":0,"message":refunded ?
			"栏位状态已变化，本次碎玉已原路退回。" :
			"栏位写入及退款异常，请立即联系管理员。"]) ;
	}
	entitlement = mappingp(grant["expansion"]) ?
		(mapping)grant["expansion"] : ([]);
	player[ILLUSION_EXPANSION_PAYMENT_ROOT]["phase"] = "committed";
	player->save_with_result();
	player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
	int cleanup_saved = player->save_with_result();
	Stdio.append_file(ILLUSION_LOG,sprintf("%d|character_expansion|account=%s|character=%s|option=%s|cost=%d|spent=%d|slots=%d|multi=%d|request=%s|cleanup=%d\n",
		time(),account_id,(string)player->query_name(),option,cost,
		(int)entitlement["expansion_spent_suiyu"],
		(int)entitlement["character_slots"],
		(int)entitlement["multi_character_unlocked"],request_id,
		cleanup_saved));
	return (["ok":1,"already":0,
		"message":(string)grant["message"]+" 本次支付"+cost+
			"碎玉，累计已计入"+
			(int)entitlement["expansion_spent_suiyu"]+"碎玉。",
		"entitlement":copy_value(entitlement)]);
}

private void reconcile_entitlement_purchase(object player)
{
	mapping payment;
	mapping account_data;
	int refunded;
	if(!player)
		return;
	payment = player[ILLUSION_PAYMENT_ROOT];
	if(!mappingp(payment) || !sizeof(payment))
		return;
	if((int)payment["version"]!=1 ||
	   (string)payment["account_id"]!=(string)player->query_account_owner() ||
	   search(({"prepared","charged","committed"}),
		(string)payment["phase"])==-1 ||
	   !valid_sha256_hex((string)payment["request_id"]) ||
	   !valid_identifier((string)payment["illusion_id"]) ||
	   (int)payment["cost"]<0 || (int)payment["cost"]>1000000 ||
	   (int)payment["created_at"]<=0 ||
	   (int)payment["created_at"]>time()+300 ||
	   (int)payment["before_wallet"]<0 ||
	   (int)payment["before_wallet"]>1000000000000 ||
	   (int)payment["before_physical"]<0){
		werror("[ILLUSION_REALM] 无效购买恢复凭据，已失败关闭: %s\n",
			(string)player->query_name());
		return;
	}
	account_data = ACCOUNT_CHARACTERD->query_account_characters(
		(string)player->query_account_owner(),
		(string)payment["illusion_id"]);
	if(!(int)account_data["ok"]){
		werror("[ILLUSION_REALM] 购买恢复等待账号索引修复: %s\n",
			(string)player->query_name());
		return;
	}
	if((int)account_data["illusion_entitled"] &&
	   mappingp(account_data["illusion_entitlement_cycle"]) &&
	   (string)account_data["illusion_entitlement_cycle"]["request_id"]==
		(string)payment["request_id"]){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return;
	}
	refunded = YUSHID->rollback_yushi_payment(player,
		(int)payment["before_wallet"],(int)payment["before_physical"],
		"illusion_entitlement_crash_recovery");
	if(refunded){
		player[ILLUSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		Stdio.append_file(ILLUSION_LOG,sprintf("%d|entitlement_recovery|illusion=%s|account=%s|character=%s|result=refunded\n",
			time(),(string)payment["illusion_id"],
			(string)payment["account_id"],
			(string)player->query_name()));
	}
	else
		werror("[ILLUSION_REALM] 资格购买崩溃退款仍需重试: %s\n",
			(string)player->query_name());
}

private void reconcile_character_expansion_purchase(object player)
{
	mapping payment;
	mapping account_data;
	array requests;
	int refunded;
	if(!player)
		return;
	payment = player[ILLUSION_EXPANSION_PAYMENT_ROOT];
	if(!mappingp(payment) || !sizeof(payment))
		return;
	if((int)payment["version"]!=1 ||
	   (string)payment["account_id"]!=(string)player->query_account_owner() ||
	   search(({"prepared","charged","committed"}),
		(string)payment["phase"])==-1 ||
	   search(({"one","all"}),(string)payment["option"])==-1 ||
	   !valid_sha256_hex((string)payment["request_id"]) ||
	   !valid_identifier((string)payment["illusion_id"]) ||
	   (int)payment["cost"]<=0 || (int)payment["cost"]>500 ||
	   (int)payment["cost"]%100!=0 ||
	   (int)payment["created_at"]<=0 ||
	   (int)payment["created_at"]>time()+300 ||
	   (int)payment["before_wallet"]<0 ||
	   (int)payment["before_wallet"]>1000000000000 ||
	   (int)payment["before_physical"]<0){
		werror("[ILLUSION_REALM] 无效扩容恢复凭据，已失败关闭: %s\n",
			(string)player->query_name());
		return;
	}
	account_data = ACCOUNT_CHARACTERD->query_account_characters(
		(string)player->query_account_owner(),
		(string)payment["illusion_id"]);
	if(!(int)account_data["ok"]){
		werror("[ILLUSION_REALM] 扩容恢复等待账号索引修复: %s\n",
			(string)player->query_name());
		return;
	}
	requests = arrayp(account_data["illusion_expansion_requests"]) ?
		(array)account_data["illusion_expansion_requests"] : ({});
	if(search(requests,(string)payment["request_id"])!=-1){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		return;
	}
	refunded = YUSHID->rollback_yushi_payment(player,
		(int)payment["before_wallet"],(int)payment["before_physical"],
		"illusion_expansion_crash_recovery");
	if(refunded){
		player[ILLUSION_EXPANSION_PAYMENT_ROOT] = ([]);
		player->save_with_result();
		Stdio.append_file(ILLUSION_LOG,sprintf("%d|character_expansion_recovery|account=%s|character=%s|result=refunded\n",
			time(),(string)payment["account_id"],
			(string)player->query_name()));
	}
	else
		werror("[ILLUSION_REALM] 栏位扩容崩溃退款仍需重试: %s\n",
			(string)player->query_name());
}

private mapping(string:mixed) create_illusion_character_internal(
	string account_id,
	string race_id,string profession_id,string name_cn,string sex,
	string avatar_id,int test_bypass_phase)
{
	mapping status = query_public_status();
	mapping result;
	if(!config_valid || (!test_bypass_phase &&
	   (!(int)status["ok"] || !(int)status["creation_open"])))
		return (["ok":0,"message":(string)status["display_name"]+
			"当前不能创建人物。"]) ;
	result = ACCOUNT_CHARACTERD->create_character(account_id,race_id,
		profession_id,name_cn,sex,avatar_id,"illusion",
		(string)illusion_config["current_id"]);
	if((int)result["ok"]){
		result["realm_type"] = "illusion";
		result["illusion_id"] = (string)illusion_config["current_id"];
		result["message"] = (string)status["display_name"]+"人物创建成功。";
		Stdio.append_file(ILLUSION_LOG,sprintf("%d|create|illusion=%s|account=%s|character=%s\n",
			time(),(string)illusion_config["current_id"],account_id,
			(string)result["character"]["id"]));
	}
	return result;
}

mapping(string:mixed) create_illusion_character(string account_id,
	string race_id,string profession_id,string name_cn,string sex,
	string avatar_id)
{
	return create_illusion_character_internal(account_id,race_id,
		profession_id,name_cn,sex,avatar_id,0);
}

mapping(string:mixed) create_illusion_character_for_test(string account_id,
	string race_id,string profession_id,string name_cn,string sex,
	string avatar_id)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !account_id ||
	   !has_prefix(account_id,"xd99testunitillusion"))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	return create_illusion_character_internal(account_id,race_id,
		profession_id,name_cn,sex,avatar_id,1);
}

void prepare_new_character(object player)
{
	mapping realm = query_realm_for_player(player);
	mapping progress;
	mapping old_progress;
	int needs_initial_snapshot;
	if(!player || !is_active_illusion_character(player) ||
	   (string)realm["illusion_id"]!=(string)illusion_config["current_id"])
		return;
	progress = player_progress(player,1);
	old_progress = copy_value(progress);
	needs_initial_snapshot = !has_index(progress,"ranking_experience_start") ||
		(int)progress["ranking_experience_start"]<0;
	update_ranking_snapshot(player,progress);
	if(needs_initial_snapshot && !player->save_with_result()){
		player[ILLUSION_PROGRESS_ROOT+"/"+
			(string)illusion_config["current_id"]] = old_progress;
		werror("[ILLUSION_REALM] 初始排行榜快照保存失败并已回滚: %s\n",
			(string)player->query_name());
	}
	else if(!persist_ranking_snapshot(player,progress,
	   (string)illusion_config["current_id"]))
		werror("[ILLUSION_RANKING] 登录快照待后续补写: %s\n",
			(string)player->query_name());
	if(!is_illusion_room_path((string)player->last_pos))
		player->last_pos = (string)illusion_config["entry_room"];
	if(!is_illusion_room_path((string)player->relife))
		player->relife = (string)illusion_config["entry_room"];
}

private int route_player(object player,string room_path)
{
	object room;
	int moved;
	mixed err = catch{ room=(object)(ROOT+room_path); };
	if(err || !room)
		return 0;
	player["/tmp/illusion_move_bypass"] = 1;
	err = catch{ moved=player->move(room); };
	player->m_delete_foruser("/tmp/illusion_move_bypass");
	return !err && moved;
}

private string settlement_receipt(object player,mapping realm)
{
	array(string) inventory = ({});
	object hash = Crypto.SHA256();
	foreach(all_inventory(player),object item)
		if(item)
			inventory += ({(file_name(item)/"#")[0]});
	sort(inventory);
	hash->update((string)player->query_name()+"|"+
		(string)realm["illusion_id"]+"|"+
		(string)(int)realm["illusion_joined_at"]+"|"+(inventory*"\n"));
	return lower_case(String.string2hex(hash->digest()));
}

/** Caller owns the account runtime mutex for the entire receipt/index change. */
private mapping(string:mixed) settle_player_locked(object player,
	void|int test_bypass_phase)
{
	mapping realm = query_realm_for_player(player);
	mapping public_status = query_public_status();
	mapping result;
	mapping progress;
	string return_room;
	string receipt;
	int current_cycle;
	int prior_cycle_closed;
	if(!player || (string)realm["realm_type"]!="illusion" ||
	   (string)realm["illusion_state"]!="active")
		return (["ok":1,"already":1,"message":"当前人物无需回归。"]) ;
	current_cycle = (string)realm["illusion_id"]==
		(string)public_status["illusion_id"];
	prior_cycle_closed = search((array)public_status["closed_ids"],
		(string)realm["illusion_id"])!=-1;
	if(!test_bypass_phase && !prior_cycle_closed && (!current_cycle ||
	   ((string)public_status["phase"]!="settling" &&
	    (string)public_status["phase"]!="closed")))
		return (["ok":0,"message":(string)realm["illusion_id"]+
			"尚未进入回归结算。"]) ;
	return_room = (string)illusion_config["return_room"];
	receipt = settlement_receipt(player,realm);
	progress = player_progress_for_id(player,
		(string)realm["illusion_id"],1);
	update_ranking_snapshot(player,progress);
	progress["settlement_prepared_at"] = time();
	progress["settlement_receipt"] = receipt;
	player->last_pos = return_room;
	if(!player->save_with_result())
		return (["ok":0,"message":"回归前人物存档失败，未切换世界。"]) ;
	if(!persist_ranking_snapshot(player,progress,
	   (string)realm["illusion_id"]))
		werror("[ILLUSION_RANKING] 回归快照待后续补写: %s\n",
			(string)player->query_name());
	result = ACCOUNT_CHARACTERD->settle_illusion_character(
		(string)player->query_name(),(string)realm["illusion_id"],receipt);
	if(!(int)result["ok"])
		return result;
	progress["returned_at"] = time();
	player->save_with_result();
	route_player(player,return_room);
	Stdio.append_file(ILLUSION_LOG,sprintf("%d|settle|illusion=%s|account=%s|character=%s|receipt=%s\n",
		time(),(string)realm["illusion_id"],(string)realm["account_id"],
		(string)player->query_name(),receipt));
	return (["ok":1,"message":(string)realm["illusion_id"]+
		"人物与可携装备已随唯一原档案安全回归永恒服。",
		"receipt":receipt]);
}

mapping(string:mixed) settle_player(object player)
{
	object account_key;
	mapping result;
	if(!player || !functionp(player->query_name))
		return (["ok":0,"message":"幻境人物对象无效。"]);
	account_key = ACCOUNT_CHARACTERD->query_account_runtime_mutex(
		(string)player->query_name())->lock();
	result = settle_player_locked(player);
	destruct(account_key);
	return result;
}

mapping(string:mixed) settle_player_for_test(object player)
{
	object account_key;
	mapping result;
	if(!is_test_illusion_player(player))
		return (["ok":0,"message":"测试入口不可用。"]) ;
	account_key = ACCOUNT_CHARACTERD->query_account_runtime_mutex(
		(string)player->query_name())->lock();
	result = settle_player_locked(player,1);
	destruct(account_key);
	return result;
}

int reconcile_player_login(object player,void|int account_lock_held)
{
	mapping realm;
	mapping status;
	mapping result;
	string current_path;
	object account_key;
	int ready = 1;
	if(!player)
		return 0;
	if(!account_lock_held)
		account_key = ACCOUNT_CHARACTERD->query_account_runtime_mutex(
			(string)player->query_name())->lock();
	reconcile_entitlement_purchase(player);
	reconcile_character_expansion_purchase(player);
	realm = query_realm_for_player(player);
	if((int)realm["security_blocked"])
		ready = 0;
	status = query_public_status();
	current_path = normalized_destination_path(environment(player));
	if(ready && (string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active"){
		if((string)realm["illusion_id"]!=
		   (string)status["illusion_id"]){
			if(search((array)status["closed_ids"],
			   (string)realm["illusion_id"])!=-1){
				result = settle_player_locked(player);
				if(!(int)result["ok"])
					ready = 0;
			}
			else{
				werror("[ILLUSION_REALM] 未归档的旧幻境人物被冻结: %s %s\n",
					(string)player->query_name(),
					(string)realm["illusion_id"]);
				ready = 0;
			}
		}
		else if((string)status["phase"]=="active"){
			prepare_new_character(player);
			// 真登录稍后仍会按 last_pos 进入房间；这里不能抢先把合法
			// 的上次位置覆盖为营地。跨Worker到达本身不重复登录流程。
			if(is_illusion_room_path(current_path))
				record_room_visit(player,environment(player));
		}
		else if((string)status["phase"]=="settling" ||
		   (string)status["phase"]=="closed"){
			result = settle_player_locked(player);
			if(!(int)result["ok"])
				ready = 0;
		}
	}
	else if(ready && is_illusion_room_path((string)player->last_pos))
		player->last_pos = (string)illusion_config["return_room"];
	if(account_key)
		destruct(account_key);
	return ready;
}

// 兼容旧方士调用；方士现已免费开放，与幻境资格无关。
int is_fangshi_unlocked(string account) { return account!=""; }
int unlock_fangshi(string account) { return account!="" ? 2 : 0; }
int can_create_fangshi(object player) { return player ? 0 : 1; }
int get_unlock_cost_jade_level() { return 0; }
string get_unlock_cost_desc() { return "免费"; }

protected void create()
{
	reload_config();
	load_runtime_state();
	call_out(lifecycle_automation_tick,2);
}
