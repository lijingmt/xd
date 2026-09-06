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
#define ACCOUNT_CHARACTER_VERSION 2
#define ACCOUNT_CHARACTER_LIMIT 60
#define ACCOUNT_ONLINE_CONFIG ROOT "/gamelib/etc/account_characters.conf"
#define ACCOUNT_ONLINE_SAFE_DEFAULT 1
#define ACCOUNT_ONLINE_CONFIG_CHECK_INTERVAL 15
#define ACCOUNT_FORCED_LOGOUT_TTL 600
#define ACCOUNT_CHARACTER_BOOKMARK_LIMIT 64
#define ACCOUNT_CHARACTER_BOOKMARK_PER_CHARACTER_LIMIT 8
#define DELETED_CHARACTER_DIR DATA_ROOT "deleted_characters"
#define WUXIANG_DONATION_UNLOCK_FEE 3000
#define TAIJI_DONATION_UNLOCK_FEE 10000
#define ILLUSION_EXTRA_SLOT_COST 100
#define ILLUSION_MULTI_UNLOCK_COST 500
#define ILLUSION_MAX_CHARACTER_SLOTS ACCOUNT_CHARACTER_LIMIT
#define S1_HIDDEN_PROFESSION "zhaoming"
#define S1_HIDDEN_REQUIRED_PROFESSIONS 5
#define S1_HIDDEN_REQUIRED_LEVEL 120
#define HIDDEN_PROFESSION_MAX_CHARACTERS 10
#define HIDDEN_PROFESSION_SLOT_BASE_COST 5000
#define HIDDEN_PROFESSION_SLOT_COST_STEP 5000
#define HIDDEN_PROFESSION_EXPANSION_REASON "profession_slot_expansion:"

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
	"third":({"fangshi","zhenyue","tianxiang","lingyi","wuxiang","taiji",
		"zhaoming","wuji","wuxin"}),
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
	"zhaoming":"照命",
	"wuji":"无极",
	"wuxin":"无心",
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

int query_profession_absolute_limit(string profession_id)
{
	return query_profession_account_limit(profession_id)>0 ?
		HIDDEN_PROFESSION_MAX_CHARACTERS : 0;
}

private int profession_expansion_expected_spent(int extra_slots)
{
	if(extra_slots<=0)
		return 0;
	return HIDDEN_PROFESSION_SLOT_BASE_COST*extra_slots+
		HIDDEN_PROFESSION_SLOT_COST_STEP*extra_slots*(extra_slots-1)/2;
}

private mapping(string:mixed) profession_limit_state_from_record(
	mapping(string:mixed) record,string profession_id,void|int count)
{
	int base_limit = query_profession_account_limit(profession_id);
	int extra_slots = 0;
	int current_limit;
	int next_cost;
	mapping expansions = mappingp(record["profession_slot_expansions"]) ?
		(mapping)record["profession_slot_expansions"] : ([]);
	mapping expansion = mappingp(expansions[profession_id]) ?
		(mapping)expansions[profession_id] : ([]);
	if(base_limit<=0)
		return (["limited":0,"count":count,"base_limit":0,
			"current_limit":0,"purchased_limit":0,"max_limit":0,
			"extra_slots":0,"spent_suiyu":0,"next_cost_suiyu":0,
			"can_expand":0]);
	extra_slots = (int)(expansion["extra_slots"] || 0);
	current_limit = min(HIDDEN_PROFESSION_MAX_CHARACTERS,
		base_limit+extra_slots);
	next_cost = current_limit<HIDDEN_PROFESSION_MAX_CHARACTERS ?
		HIDDEN_PROFESSION_SLOT_BASE_COST+
		HIDDEN_PROFESSION_SLOT_COST_STEP*extra_slots : 0;
	return (["limited":1,"count":count,"base_limit":base_limit,
		"current_limit":current_limit,"purchased_limit":current_limit,
		"max_limit":HIDDEN_PROFESSION_MAX_CHARACTERS,
		"extra_slots":extra_slots,
		"spent_suiyu":profession_expansion_expected_spent(extra_slots),
		"next_cost_suiyu":next_cost,
		"can_expand":current_limit<HIDDEN_PROFESSION_MAX_CHARACTERS]);
}

int query_hidden_profession_donation_threshold(string profession_id)
{
	if(profession_id=="wuxiang")
		return WUXIANG_DONATION_UNLOCK_FEE;
	if(profession_id=="taiji")
		return TAIJI_DONATION_UNLOCK_FEE;
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
	if(mappingp(data["hidden_profession_limits"]) &&
	   mappingp(data["hidden_profession_limits"][profession_id]))
		limit = (int)data["hidden_profession_limits"]
			[profession_id]["current_limit"];
	string profession_name = profession_names[profession_id] || profession_id;
	return (["ok":1,"limited":1,"allowed":count<limit,
		"count":count,"limit":limit,
		"max_limit":HIDDEN_PROFESSION_MAX_CHARACTERS,
		"message":count<limit ? "" : "【"+profession_name+
			"·人物上限】当前可创建上限为"+limit+"个（最高"+
			HIDDEN_PROFESSION_MAX_CHARACTERS+
			"个），可在人物中心购买下一格。"]);
}

mapping(string:mixed) query_profession_selection_permission(
	string requested_id,string profession_id)
{
	mapping(string:mixed) data = query_account_characters(requested_id);
	if(profession_id==S1_HIDDEN_PROFESSION){
		mapping current = ([]);
		foreach((array)(data["characters"] || ({})),mapping summary)
			if((string)summary["id"]==requested_id){
				current = summary;
				break;
			}
		if(!sizeof(current) ||
		   (string)current["realm_type"]!="illusion" ||
		   (string)current["illusion_state"]!="active")
			return (["ok":1,"limited":1,"allowed":0,
				"message":"【照命·幻境限定】只能为当期幻境人物选择该职业。"]) ;
		// API 建角时已把服务端批准的职业写进账号索引。不能把一个
		// 已付费创建为其它职业的待初始化栏位，用旧 JSP 命令改成照命。
		if((string)current["profession_id"]!=S1_HIDDEN_PROFESSION)
			return (["ok":1,"limited":1,"allowed":0,
				"message":"【照命·创建校验】请从人物中心选择照命并创建专属栏位。"]) ;
		mapping hidden = query_s1_hidden_unlock_from_summary(data,
			(string)current["illusion_id"]);
		if(!(int)hidden["unlocked"])
			return (["ok":1,"limited":1,"allowed":0,
				"message":(string)hidden["message"]]);
		foreach((array)data["characters"],mapping summary)
			if((string)summary["id"]!=requested_id &&
			   (string)summary["profession_id"]==S1_HIDDEN_PROFESSION &&
			   (string)summary["illusion_id"]==(string)current["illusion_id"])
				return (["ok":1,"limited":1,"allowed":0,
					"message":"【照命·人物上限】同一账号每期幻境只能创建一个照命。"]) ;
	}
	return query_profession_limit_from_summary(data,profession_id,
		requested_id);
}

/**
 * S1 隐藏职业资格只认同一账号、同一期幻境的真实 81 章完成凭证。
 * 同职业重复人物只计一次；完成故事后仍需把该人物练到 120 级。
 */
mapping(string:mixed) query_s1_hidden_unlock_from_summary(
	mapping(string:mixed) data,string illusion_id)
{
	multiset(string) completed = (<>);
	array(string) completed_names = ({});
	array(string) level_pending = ({});
	if(!data || (int)data["ok"]!=1 || !arrayp(data["characters"]) ||
	   illusion_id!="S1")
		return (["ok":0,"unlocked":0,"completed_count":0,
			"required_count":S1_HIDDEN_REQUIRED_PROFESSIONS,
			"required_level":S1_HIDDEN_REQUIRED_LEVEL,
			"message":"【照命·资格不可验证】账号幻境历程暂时无法核验。"]) ;
	foreach((array)data["characters"],mapping summary){
		string profession_id = (string)summary["profession_id"];
		if((string)summary["illusion_id"]!=illusion_id ||
		   (string)summary["realm_type"]!="illusion" ||
		   (string)summary["illusion_state"]!="active" ||
		   !profession_names[profession_id] ||
		   profession_id==S1_HIDDEN_PROFESSION ||
		   (int)summary["illusion_story_completed_at"]<=0 ||
		   (int)summary["illusion_story_completion_version"]!=1 ||
		   (string)summary["illusion_story_completed_profession"]!=
			profession_id || completed[profession_id])
			continue;
		if((int)summary["level"]<S1_HIDDEN_REQUIRED_LEVEL){
			level_pending += ({(profession_names[profession_id] ||
				profession_id)+"（"+(string)(int)summary["level"]+"/"+
				(string)S1_HIDDEN_REQUIRED_LEVEL+"）"});
			continue;
		}
		completed[profession_id] = 1;
		completed_names += ({profession_names[profession_id] || profession_id});
	}
	int count = sizeof(completed_names);
	int unlocked = count>=S1_HIDDEN_REQUIRED_PROFESSIONS;
	string message = unlocked ?
		"【照命·已解锁】本期已有"+(string)count+
		"个不同职业完成八十一章并达到120级。" :
		"【照命·未解锁】同一账号须在本期用5个不同职业各自完成八十一章并达到120级；当前"+
		(string)count+"/"+(string)S1_HIDDEN_REQUIRED_PROFESSIONS+
		(sizeof(level_pending) ? "，已通关但等级不足："+
			(level_pending*"、") : "")+"。";
	return (["ok":1,"unlocked":unlocked,"completed_count":count,
		"required_count":S1_HIDDEN_REQUIRED_PROFESSIONS,
		"required_level":S1_HIDDEN_REQUIRED_LEVEL,
		"completed_professions":completed_names,
		"level_pending":level_pending,"message":message]);
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

int query_wuxiang_unlocked_from_summary(mapping(string:mixed) data,
	void|int total_recharge_fee)
{
	mapping(string:int) prof_max_level;
	array(mapping(string:mixed)) characters;
	if((int)(total_recharge_fee || 0)>=WUXIANG_DONATION_UNLOCK_FEE)
		return 1;
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

int query_taiji_unlocked_from_summary(mapping(string:mixed) data,
	void|int total_recharge_fee)
{
	mapping(string:int) prof_max_level;
	array(mapping(string:mixed)) characters;
	if((int)(total_recharge_fee || 0)>=TAIJI_DONATION_UNLOCK_FEE)
		return 1;
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

// 无极解锁判定：账号下有照命角色达到300级，且该角色完成了天劫难度
// （LV250解锁的个人难度等级），创建无极角色另需10000碎玉。
// 无极是太极之上的终极隐藏职业，技能强度胜太极三成并附带群杀群奶。
#define WUJI_REQUIRED_LEVEL 300
#define WUJI_CREATION_COST 10000
#define WUXIN_CREATION_COST 20000

int query_wuji_unlocked_from_summary(mapping(string:mixed) data)
{
	array(mapping(string:mixed)) characters;
	int zhaoming_max_level = 0;
	if(!data || (int)data["ok"] != 1)
		return 0;
	characters = (array(mapping(string:mixed)))data["characters"];
	if(!characters || sizeof(characters) == 0)
		return 0;
	foreach(characters, mapping entry){
		if((string)entry["profession_id"]=="zhaoming"){
			int lvl = (int)entry["level"];
			if(lvl > zhaoming_max_level)
				zhaoming_max_level = lvl;
		}
	}
	return zhaoming_max_level>=WUJI_REQUIRED_LEVEL;
}

int query_wuji_creation_cost()
{
	return WUJI_CREATION_COST;
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
	// 调用方（登录准备/在线清退）可能已持有 online_state 锁，
	// 这里绝不能再拿同一把非递归锁（曾造成登录自死锁回归）；
	// 覆盖表只被TestUnit写入，无锁读取可接受。
	int test_limit = test_online_limit_overrides[account_id];
	if(test_limit>0)
		return test_limit;
	return query_account_online_capacity(account_id);
}

/** 在线扩容价格：基础20人；扩到第21人100碎玉，之后每多一人
 递增100（200/300/400…），扩到第30人时为1000，30以上每格1000。 */
int query_online_expansion_cost(int current_capacity)
{
	if(current_capacity<0)
		current_capacity = 0;
	if(current_capacity<20)
		return 100;
	if(current_capacity<30)
		return (current_capacity-19)*100;
	return 1000;
}

/** 账号实际在线上限：已购容量优先，未购买时用配置基线。 */
int query_account_online_capacity(string account_id)
{
	mapping(string:mixed)|zero record;
	int capacity;
	if(!valid_userid(account_id))
		return query_max_online_characters();
	record = load_persisted_record_unlocked(account_id);
	capacity = record ? (int)record["online_capacity"] : 0;
	if(capacity>0 && capacity<=ACCOUNT_CHARACTER_LIMIT)
		return capacity;
	return query_max_online_characters();
}

/** 付费扩充同账号同时在线人数：扣款成功后容量+1并原子落盘，
 失败全额回退。价格按扩容前容量分档（30以内100，以上1000碎玉）。 */
/* TestUnit钩子：为testunit账号伪造照命达标+资格状态。 */
void grant_test_wuji_state(string account_id,int zhaoming_level,
	int entitled)
{
	object key;
	mapping record;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id,1);
	if(!record){
		destruct(key);
		return;
	}
	array kept = ({});
	foreach(arrayp(record["characters"])?(array)record["characters"]:({}),
		mixed entry)
		if(mappingp(entry) &&
		   (string)entry["id"]!=account_id+"ctestwuji")
			kept += ({entry});
	kept += ({([
		"id":account_id+"ctestwuji",
		"slot":sizeof(kept)+1,
		"profession_id":"zhaoming",
		"level":zhaoming_level,
		"realm_type":"eternal",
		"created_at":time(),
	])});
	record["characters"] = kept;
	if(entitled)
		record["wuji_entitlement"] = (["unlocked":1,
			"cost_suiyu":WUJI_CREATION_COST,
			"request_id":"testunit","created_at":time()]);
	else if(mappingp(record["wuji_entitlement"]))
		m_delete(record["wuji_entitlement"],"unlocked");
	record["revision"] = (int)record["revision"]+1;
	save_record_unlocked(record);
	destruct(key);
}

/** 购买无极创建资格：照命>=300级后一次性支付，幂等不重复扣费。 */
mapping(string:mixed) purchase_wuji_entitlement(string account_id,
	string request_id,void|object payer)
{
	mapping(string:mixed) record;
	mapping(string:mixed) payment;
	object key;
	if(!valid_userid(account_id) || !valid_sha256_hex(request_id))
		return (["ok":0,"message":"无极资格购买请求无效。"]);
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0,"message":"账号索引暂不可用，本次未扣款。"]);
	}
	if(mappingp(record["wuji_entitlement"]) &&
	   (int)record["wuji_entitlement"]["unlocked"]==1){
		destruct(key);
		return (["ok":1,"already":1,
			"message":"已持有无极创建资格。"]);
	}
	{
		mapping summary = query_account_characters(account_id);
		if(!query_wuji_unlocked_from_summary(
			mappingp(summary) ? summary : (["ok":0]))){
			destruct(key);
			return (["ok":0,"message":"【无极·未解锁】需要照命角色达到"+
				WUJI_REQUIRED_LEVEL+"级后才能购买。"]);
		}
	}
	destruct(key);
	payment = YUSHID->pay_account_expansion(payer,account_id,
		WUJI_CREATION_COST,"无极人物创建资格",request_id);
	if(!(int)payment["ok"])
		return (["ok":0,"message":(string)payment["message"]]);
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id,1);
	if(mappingp(record["wuji_entitlement"]) &&
	   (int)record["wuji_entitlement"]["unlocked"]==1){
		destruct(key);
		if(!YUSHID->refund_account_expansion(payer,account_id,
			(int)payment["paid_wallet"],(int)payment["paid_physical"],
			"wuji_entitlement_duplicate",request_id))
			werror("[ACCOUNT_CHARACTERD] 无极资格重复退款异常: %s\n",
				account_id);
		return (["ok":1,"already":1,
			"message":"已持有资格，重复扣款已退回。"]);
	}
	if(!record){
		destruct(key);
		if(!YUSHID->refund_account_expansion(payer,account_id,
			(int)payment["paid_wallet"],(int)payment["paid_physical"],
			"wuji_entitlement_failed",request_id))
			werror("[ACCOUNT_CHARACTERD] 无极资格退款异常: %s\n",
				account_id);
		return (["ok":0,"message":"账号索引暂不可用，本次扣款已退回。"]);
	}
	record["wuji_entitlement"] = (["unlocked":1,
		"cost_suiyu":WUJI_CREATION_COST,
		"request_id":request_id,"created_at":time()]);
	record["revision"] = (int)record["revision"]+1;
	if(!save_record_unlocked(record)){
		destruct(key);
		if(!YUSHID->refund_account_expansion(payer,account_id,
			(int)payment["paid_wallet"],(int)payment["paid_physical"],
			"wuji_entitlement_save_failed",request_id))
			werror("[ACCOUNT_CHARACTERD] 无极资格保存退款异常: %s\n",
				account_id);
		return (["ok":0,"message":"资格保存失败，本次扣款已退回。"]);
	}
	destruct(key);
	return (["ok":1,
		"message":"已支付"+WUJI_CREATION_COST+"碎玉，获得无极创建资格。"]);
}

/** 无心解锁条件：账号下任一无极角色个人难度全部通关。
 * 难度进度存在人物存档里，由 record_wuxin_difficulty_maxed 在
 * 无极角色登录/达标时回填到账号索引（幂等），这里只读索引标志。 */
int query_wuxin_unlocked_from_summary(mapping(string:mixed) data)
{
	if(!data || (int)data["ok"] != 1)
		return 0;
	return (int)data["wuxin_difficulty_ready"]==1;
}

int query_wuxin_creation_cost()
{
	return WUXIN_CREATION_COST;
}

/** 无极角色难度通关达标回填（幂等，登录/切档后调用）。 */
mapping(string:mixed) record_wuxin_difficulty_maxed(string account_id)
{
	mapping(string:mixed) record;
	object key;
	if(!valid_userid(account_id))
		return (["ok":0]);
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0]);
	}
	if((int)record["wuxin_difficulty_ready"]==1){
		destruct(key);
		return (["ok":1,"already":1]);
	}
	record["wuxin_difficulty_ready"] = 1;
	record["wuxin_difficulty_at"] = time();
	record["revision"] = (int)record["revision"]+1;
	int saved = save_record_unlocked(record);
	destruct(key);
	return (["ok":saved?1:0]);
}

/** 无心300级解锁全账号400级上限：触发与查询（带内存缓存）。 */
private mapping(string:int) account_level_cap_400_cache = ([]);

int query_account_level_cap_400(string account_id)
{
	int cached;
	if(!valid_userid(account_id))
		return 0;
	cached = account_level_cap_400_cache[account_id];
	if(cached)
		return 1;
	{
		mapping record = load_persisted_record_unlocked(account_id);
		if(mappingp(record) && (int)record["level_cap_400"]==1){
			account_level_cap_400_cache[account_id] = 1;
			return 1;
		}
	}
	return 0;
}

mapping(string:mixed) record_account_level_cap_400(string account_id)
{
	mapping(string:mixed) record;
	object key;
	if(!valid_userid(account_id))
		return (["ok":0]);
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0]);
	}
	if((int)record["level_cap_400"]==1){
		destruct(key);
		account_level_cap_400_cache[account_id] = 1;
		return (["ok":1,"already":1]);
	}
	record["level_cap_400"] = 1;
	record["level_cap_400_at"] = time();
	record["revision"] = (int)record["revision"]+1;
	int saved = save_record_unlocked(record);
	destruct(key);
	if(saved)
		account_level_cap_400_cache[account_id] = 1;
	return (["ok":saved?1:0]);
}

void record_wuxin_entitlement_for_test(string account_id)
{
	object key;
	mapping record;
	if(search(account_id,"testunit")==-1)
		return;
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id,1);
	if(!record){
		destruct(key);
		return;
	}
	record["wuxin_entitlement"] = (["unlocked":1,
		"cost_suiyu":WUXIN_CREATION_COST,"test":1]);
	record["revision"] = (int)record["revision"]+1;
	save_record_unlocked(record);
	destruct(key);
}

/** 购买无心创建资格：无极全难度通关后一次性支付，幂等不重复扣费。 */
mapping(string:mixed) purchase_wuxin_entitlement(string account_id,
	string request_id,void|object payer)
{
	mapping(string:mixed) record;
	mapping(string:mixed) payment;
	object key;
	if(!valid_userid(account_id) || !valid_sha256_hex(request_id))
		return (["ok":0,"message":"无心资格购买请求无效。"]);
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0,"message":"账号索引暂不可用，本次未扣款。"]);
	}
	if(mappingp(record["wuxin_entitlement"]) &&
	   (int)record["wuxin_entitlement"]["unlocked"]==1){
		destruct(key);
		return (["ok":1,"already":1,
			"message":"已持有无心创建资格。"]);
	}
	if((int)record["wuxin_difficulty_ready"]!=1){
		destruct(key);
		return (["ok":0,"message":"【无心·未解锁】需要账号下无极角色通关全部个人挑战难度。"]);
	}
	destruct(key);
	payment = YUSHID->pay_account_expansion(payer,account_id,
		WUXIN_CREATION_COST,"无心人物创建资格",request_id);
	if(!(int)payment["ok"])
		return (["ok":0,"message":(string)payment["message"]]);
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id,1);
	if(mappingp(record["wuxin_entitlement"]) &&
	   (int)record["wuxin_entitlement"]["unlocked"]==1){
		destruct(key);
		if(!YUSHID->refund_account_expansion(payer,account_id,
			(int)payment["paid_wallet"],(int)payment["paid_physical"],
			"wuxin_entitlement_duplicate",request_id))
			werror("[ACCOUNT_CHARACTERD] 无心资格重复退款异常: %s\n",
				account_id);
		return (["ok":1,"already":1,
			"message":"已持有资格，重复扣款已退回。"]);
	}
	if(!record){
		destruct(key);
		if(!YUSHID->refund_account_expansion(payer,account_id,
			(int)payment["paid_wallet"],(int)payment["paid_physical"],
			"wuxin_entitlement_failed",request_id))
			werror("[ACCOUNT_CHARACTERD] 无心资格退款异常: %s\n",
				account_id);
		return (["ok":0,"message":"账号索引暂不可用，本次扣款已退回。"]);
	}
	if((int)record["wuxin_difficulty_ready"]!=1){
		destruct(key);
		if(!YUSHID->refund_account_expansion(payer,account_id,
			(int)payment["paid_wallet"],(int)payment["paid_physical"],
			"wuxin_entitlement_not_ready",request_id))
			werror("[ACCOUNT_CHARACTERD] 无心资格未解锁退款异常: %s\n",
				account_id);
		return (["ok":0,"message":"解锁条件已失效，本次扣款已退回。"]);
	}
	record["wuxin_entitlement"] = (["unlocked":1,
		"cost_suiyu":WUXIN_CREATION_COST,
		"request_id":request_id,"created_at":time()]);
	record["revision"] = (int)record["revision"]+1;
	if(!save_record_unlocked(record)){
		destruct(key);
		if(!YUSHID->refund_account_expansion(payer,account_id,
			(int)payment["paid_wallet"],(int)payment["paid_physical"],
			"wuxin_entitlement_save_failed",request_id))
			werror("[ACCOUNT_CHARACTERD] 无心资格保存退款异常: %s\n",
				account_id);
		return (["ok":0,"message":"资格保存失败，本次扣款已退回。"]);
	}
	destruct(key);
	return (["ok":1,
		"message":"已支付"+WUXIN_CREATION_COST+"碎玉，获得无心创建资格。"]);
}

mapping(string:mixed) purchase_online_capacity_expansion(
	string account_id,string request_id,void|object payer)
{
	mapping(string:mixed) record;
	mapping(string:mixed) payment;
	mapping debit;
	object key;
	int current;
	int cost;
	int saved;
	int paid_physical;
	if(!valid_userid(account_id) || !valid_sha256_hex(request_id))
		return (["ok":0,"message":"在线扩容请求无效。"]);
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0,"message":"账号索引暂不可用，本次未扣款。"]);
	}
	current = (int)record["online_capacity"]>0 ?
		(int)record["online_capacity"] : query_max_online_characters();
	if(current>=ACCOUNT_CHARACTER_LIMIT){
		destruct(key);
		return (["ok":0,"already":1,
			"message":"在线上限已达账号人物总数上限，不能再扩充。"]);
	}
	cost = query_online_expansion_cost(current);
	destruct(key);
	/* 默认扣账号共享碎玉；不足时用付款人物背包实体玉补足。 */
	if(payer){
		payment = YUSHID->pay_account_expansion(payer,account_id,cost,
			"在线人物上限扩容",request_id);
		if(!(int)payment["ok"])
			return (["ok":0,"message":(string)payment["message"]]);
		paid_physical = (int)payment["paid_physical"];
	}
	else{
		debit = ACCOUNT_WALLETD->debit_account_recharge_once(account_id,
			cost,"在线人物上限扩容",request_id);
		if(!(int)debit["ok"])
			return (["ok":0,"message":(string)(debit["message"] ||
				"账号共享余额扣款失败。")]);
	}
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id,1);
	current = record && (int)record["online_capacity"]>0 ?
		(int)record["online_capacity"] : query_max_online_characters();
	if(!record || current>=ACCOUNT_CHARACTER_LIMIT){
		destruct(key);
		ACCOUNT_WALLETD->forget_account_debit_recharge_once(
			account_id,request_id);
		if(paid_physical>0 && payer)
			YUSHID->give_yushi(payer,paid_physical);
		return (["ok":0,"already":1,
			"message":"在线上限已满，本次扣款已撤销。"]);
	}
	record["online_capacity"] = current+1;
	record["revision"] = (int)record["revision"]+1;
	saved = save_record_unlocked(record);
	destruct(key);
	if(!saved){
		ACCOUNT_WALLETD->forget_account_debit_recharge_once(
			account_id,request_id);
		if(paid_physical>0 && payer)
			YUSHID->give_yushi(payer,paid_physical);
		return (["ok":0,"message":"扩容保存失败，本次扣款已撤销。"]);
	}
	return (["ok":1,"capacity":current+1,"cost":cost,
		"paid_wallet":payer?(int)payment["paid_wallet"]:cost,
		"paid_physical":paid_physical,
		"message":"在线人物上限已扩充到"+(current+1)+
			"人（本次"+cost+"碎玉）。"]);
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

private int valid_illusion_id(string illusion_id)
{
	if(!illusion_id || sizeof(illusion_id)<2 || sizeof(illusion_id)>16)
		return 0;
	foreach(illusion_id;int index;int one){
		if((one>='A' && one<='Z') || (one>='0' && one<='9') || one=='_')
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

private int valid_profession_slot_expansions(mixed raw)
{
	mapping expansions;
	if(!raw)
		return 1;
	if(!mappingp(raw))
		return 0;
	expansions = raw;
	if(sizeof(expansions)>2)
		return 0;
	foreach(indices(expansions),mixed raw_profession_id){
		string profession_id;
		mapping expansion;
		array requests;
		multiset(string) seen_requests = (<>);
		int extra_slots;
		int maximum_extra;
		if(!stringp(raw_profession_id))
			return 0;
		profession_id = (string)raw_profession_id;
		if(query_profession_account_limit(profession_id)<=0 ||
		   !mappingp(expansions[profession_id]))
			return 0;
		expansion = expansions[profession_id];
		extra_slots = (int)expansion["extra_slots"];
		maximum_extra = HIDDEN_PROFESSION_MAX_CHARACTERS-
			query_profession_account_limit(profession_id);
		requests = arrayp(expansion["requests"]) ?
			(array)expansion["requests"] : ({});
		if(extra_slots<=0 || extra_slots>maximum_extra ||
		   sizeof(requests)!=extra_slots ||
		   (int)expansion["spent_suiyu"]!=
			profession_expansion_expected_spent(extra_slots) ||
		   (int)expansion["updated_at"]<=0)
			return 0;
		foreach(requests,mixed raw_request){
			string request_id;
			if(!stringp(raw_request))
				return 0;
			request_id = (string)raw_request;
			if(!valid_sha256_hex(request_id) || seen_requests[request_id])
				return 0;
			seen_requests[request_id] = 1;
		}
	}
	return 1;
}

private mapping(string:mixed) default_illusion_expansion_state()
{
	return ([
		"version":2,"character_slots":0,"multi_character_unlocked":0,
		"expansion_spent_suiyu":0,"expansion_requests":({}),
	]);
}

private int valid_legacy_illusion_expansion_state(mapping state)
{
	int expansion_spent;
	int character_slots;
	int multi_unlocked;
	array expansion_requests;
	if(!mappingp(state))
		return 0;
	expansion_spent = (int)(state["expansion_spent_suiyu"] || 0);
	character_slots = (int)(state["character_slots"] || 1);
	multi_unlocked = (int)(state["multi_character_unlocked"] || 0);
	expansion_requests = arrayp(state["expansion_requests"]) ?
		(array)state["expansion_requests"] : ({});
	if(expansion_spent<0 || expansion_spent>ILLUSION_MULTI_UNLOCK_COST ||
	   expansion_spent%ILLUSION_EXTRA_SLOT_COST!=0 ||
	   character_slots<1 || character_slots>6 ||
	   (multi_unlocked!=0 && multi_unlocked!=1) ||
	   (multi_unlocked && expansion_spent!=ILLUSION_MULTI_UNLOCK_COST) ||
	   (!multi_unlocked && character_slots!=
		1+expansion_spent/ILLUSION_EXTRA_SLOT_COST) ||
	   (multi_unlocked && character_slots!=6) ||
	   sizeof(expansion_requests)>5 ||
	   (expansion_spent>0 && (int)state["expansion_updated_at"]<=0))
		return 0;
	multiset(string) seen_requests = (<>);
	foreach(expansion_requests,mixed raw_request){
		string one_request = (string)raw_request;
		if(!valid_sha256_hex(one_request) || seen_requests[one_request])
			return 0;
		seen_requests[one_request] = 1;
	}
	return 1;
}

private int valid_illusion_expansion_state(mapping state)
{
	int expansion_spent;
	int character_slots;
	int migrated;
	array expansion_requests;
	if(!mappingp(state) || (int)state["version"]!=2)
		return 0;
	expansion_spent=(int)(state["expansion_spent_suiyu"] || 0);
	character_slots=(int)(state["character_slots"] || 0);
	migrated=(int)(state["migrated_from_legacy"] || 0);
	expansion_requests=arrayp(state["expansion_requests"]) ?
		(array)state["expansion_requests"] : ({});
	if(expansion_spent<0 ||
	   expansion_spent>ILLUSION_MAX_CHARACTER_SLOTS*ILLUSION_EXTRA_SLOT_COST ||
	   expansion_spent%ILLUSION_EXTRA_SLOT_COST!=0 ||
	   character_slots<0 || character_slots>ILLUSION_MAX_CHARACTER_SLOTS ||
	   (migrated!=0 && migrated!=1) ||
	   (!migrated &&
	    character_slots!=expansion_spent/ILLUSION_EXTRA_SLOT_COST) ||
	   (migrated &&
	    character_slots<expansion_spent/ILLUSION_EXTRA_SLOT_COST) ||
	   (int)(state["multi_character_unlocked"] || 0)!=0 ||
	   sizeof(expansion_requests)>64 ||
	   (expansion_spent>0 && (int)state["expansion_updated_at"]<=0))
		return 0;
	multiset(string) seen_requests=(<>);
	foreach(expansion_requests,mixed raw_request){
		string one_request=(string)raw_request;
		if(!valid_sha256_hex(one_request) || seen_requests[one_request])
			return 0;
		seen_requests[one_request]=1;
	}
	return 1;
}

int validate_illusion_expansion_state_for_test(mapping state)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return 0;
	return valid_illusion_expansion_state(state);
}

/**
 * S1 shipped with expansion fields directly on the permanent entitlement.
 * Keep reading those fields as S1, while all new writes are keyed by season.
 */
private mapping(string:mixed) illusion_expansion_state(mapping entitlement,
	string illusion_id,int existing_count)
{
	mapping expansions;
	mapping raw;
	if(!mappingp(entitlement) || !valid_illusion_id(illusion_id))
		return default_illusion_expansion_state();
	expansions = mappingp(entitlement["season_expansions"]) ?
		(mapping)entitlement["season_expansions"] : ([]);
	if(mappingp(expansions[illusion_id]) &&
	   valid_illusion_expansion_state((mapping)expansions[illusion_id]))
		return copy_value((mapping)expansions[illusion_id]);
	if(mappingp(expansions[illusion_id]))
		raw=(mapping)expansions[illusion_id];
	if(illusion_id=="S1"){
		mapping legacy = ([
			"character_slots":(int)(entitlement["character_slots"] || 1),
			"multi_character_unlocked":
				(int)(entitlement["multi_character_unlocked"] || 0),
			"expansion_spent_suiyu":
				(int)(entitlement["expansion_spent_suiyu"] || 0),
			"expansion_requests":arrayp(entitlement["expansion_requests"]) ?
				copy_value((array)entitlement["expansion_requests"]) : ({}),
			"expansion_updated_at":
				(int)(entitlement["expansion_updated_at"] || 0),
		]);
		if(!mappingp(raw))
			raw=legacy;
	}
	if(mappingp(raw) && valid_legacy_illusion_expansion_state(raw)){
		int spent=(int)(raw["expansion_spent_suiyu"] || 0);
		int paid_slots=spent/ILLUSION_EXTRA_SLOT_COST;
		int grandfathered=existing_count>0 ? 1 : 0;
		return ([
			"version":2,
			"character_slots":min(ILLUSION_MAX_CHARACTER_SLOTS,
				max(existing_count,grandfathered+paid_slots)),
			"multi_character_unlocked":0,
			"expansion_spent_suiyu":spent,
			"expansion_requests":arrayp(raw["expansion_requests"]) ?
				copy_value((array)raw["expansion_requests"]) : ({}),
			"expansion_updated_at":(int)(raw["expansion_updated_at"] || 0),
			"migrated_from_legacy":1,
		]);
	}
	return default_illusion_expansion_state();
}

private int valid_illusion_season_entitlement(mixed raw)
{
	mapping entitlement;
	if(!mappingp(raw))
		return 0;
	entitlement = raw;
	if((int)entitlement["unlocked"]!=1 ||
	   (int)entitlement["unlocked_at"]<=0 ||
	   search(({"jade","admin","legacy","test","account_center"}),
		(string)entitlement["source"])==-1)
		return 0;
	if(entitlement["request_id"] &&
	   !valid_sha256_hex((string)entitlement["request_id"]))
		return 0;
	return 1;
}

/**
 * Return the permanent qualification for one exact cycle. Legacy accounts
 * created before cycle-keyed qualifications are treated as S1 only; they do
 * not silently inherit S2 or any later cycle.
 */
private mapping(string:mixed) illusion_entitlement_for_cycle(
	mapping entitlement,string illusion_id)
{
	mapping season_entitlements;
	string legacy_cycle_id;
	if(!mappingp(entitlement) || !valid_illusion_id(illusion_id))
		return ([]);
	season_entitlements = mappingp(entitlement["season_entitlements"]) ?
		(mapping)entitlement["season_entitlements"] : ([]);
	if(mappingp(season_entitlements[illusion_id]) &&
	   valid_illusion_season_entitlement(
		(mapping)season_entitlements[illusion_id]))
		return copy_value((mapping)season_entitlements[illusion_id]);
	legacy_cycle_id = (string)(entitlement["legacy_cycle_id"] || "S1");
	if(legacy_cycle_id==illusion_id &&
	   valid_illusion_season_entitlement(entitlement)){
		mapping legacy = ([
			"unlocked":1,
			"unlocked_at":(int)entitlement["unlocked_at"],
			"source":(string)entitlement["source"],
		]);
		if(entitlement["request_id"])
			legacy["request_id"] = (string)entitlement["request_id"];
		return legacy;
	}
	return ([]);
}

private int valid_illusion_entitlement(mixed raw)
{
	mapping entitlement;
	if(!raw)
		return 1;
	if(!mappingp(raw))
		return 0;
	entitlement = raw;
	if((int)entitlement["unlocked"]!=1 ||
	   (int)entitlement["unlocked_at"]<=0)
		return 0;
	if(search(({"jade","admin","legacy","test","account_center"}),
	   (string)entitlement["source"])==-1)
		return 0;
	if(entitlement["request_id"] &&
	   !valid_sha256_hex((string)entitlement["request_id"]))
		return 0;
	if(entitlement["legacy_cycle_id"] &&
	   !valid_illusion_id((string)entitlement["legacy_cycle_id"]))
		return 0;
	if(!valid_legacy_illusion_expansion_state(([
		"character_slots":(int)(entitlement["character_slots"] || 1),
		"multi_character_unlocked":
			(int)(entitlement["multi_character_unlocked"] || 0),
		"expansion_spent_suiyu":
			(int)(entitlement["expansion_spent_suiyu"] || 0),
		"expansion_requests":arrayp(entitlement["expansion_requests"]) ?
			(array)entitlement["expansion_requests"] : ({}),
		"expansion_updated_at":
			(int)(entitlement["expansion_updated_at"] || 0),
	])))
		return 0;
	if(has_index(entitlement,"season_expansions")){
		mapping expansions;
		if(!mappingp(entitlement["season_expansions"]))
			return 0;
		expansions = entitlement["season_expansions"];
		// 256个月度赛季约覆盖21年，同时仍对账号档案体积设上界。
		if(sizeof(expansions)>256)
			return 0;
		foreach(indices(expansions),mixed raw_id){
			string illusion_id = (string)raw_id;
			if(!stringp(raw_id) || !valid_illusion_id(illusion_id) ||
			   !mappingp(expansions[illusion_id]) ||
			   (!valid_illusion_expansion_state(expansions[illusion_id]) &&
			    !valid_legacy_illusion_expansion_state(
				(mapping)expansions[illusion_id])))
				return 0;
		}
	}
	if(has_index(entitlement,"season_entitlements")){
		mapping season_entitlements;
		if(!mappingp(entitlement["season_entitlements"]))
			return 0;
		season_entitlements = entitlement["season_entitlements"];
		if(sizeof(season_entitlements)>256)
			return 0;
		foreach(indices(season_entitlements),mixed raw_id){
			string illusion_id = (string)raw_id;
			if(!stringp(raw_id) || !valid_illusion_id(illusion_id) ||
			   !valid_illusion_season_entitlement(
				season_entitlements[illusion_id]))
				return 0;
		}
	}
	return 1;
}

private int valid_bookmark_hex(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	foreach(value;int index;int one)
		if(!((one>='0' && one<='9') || (one>='a' && one<='f')))
			return 0;
	return 1;
}

private string character_bookmark_digest(string token)
{
	object hash = Crypto.SHA256();
	hash->update("xiand-character-bookmark-v1\n"+(token || ""));
	return lower_case(String.string2hex(hash->digest()));
}

private string character_bookmark_auth_proof(string token,string password)
{
	object hash = Crypto.SHA256();
	hash->update("xiand-character-bookmark-auth-v1\n"+(token || "")+
		"\n"+(password || ""));
	return lower_case(String.string2hex(hash->digest()));
}

private int constant_time_bookmark_equal(string first,string second)
{
	int difference;
	if(!first || !second || sizeof(first)!=sizeof(second))
		return 0;
	for(int i=0;i<sizeof(first);i++)
		difference |= first[i]^second[i];
	return difference==0;
}

private int record_contains_character(mapping record,string character_id)
{
	if(!record || !arrayp(record["characters"]))
		return 0;
	foreach((array)record["characters"],mapping entry)
		if((string)entry["id"]==character_id)
			return 1;
	return 0;
}

private array(mapping(string:mixed)) normalized_character_bookmarks(
	mapping record)
{
	array(mapping(string:mixed)) result = ({});
	if(!record || !arrayp(record["character_bookmarks"]))
		return result;
	foreach((array)record["character_bookmarks"],mixed raw){
		mapping entry;
		if(!mappingp(raw))
			continue;
		entry = raw;
		if(!valid_userid((string)entry["character_id"]) ||
		   !record_contains_character(record,(string)entry["character_id"]) ||
		   !valid_bookmark_hex((string)entry["token_digest"]) ||
		   !valid_bookmark_hex((string)entry["auth_proof"]) ||
		   (int)entry["created_at"]<=0)
			continue;
		result += ({copy_value(entry)});
		if(sizeof(result)>=ACCOUNT_CHARACTER_BOOKMARK_LIMIT)
			break;
	}
	return result;
}

private array(mapping(string:mixed)) remove_character_bookmark_at(
	array(mapping(string:mixed)) bookmarks,int index)
{
	if(index<0 || index>=sizeof(bookmarks))
		return bookmarks;
	if(sizeof(bookmarks)==1)
		return ({});
	if(index==0)
		return bookmarks[1..];
	if(index==sizeof(bookmarks)-1)
		return bookmarks[..sizeof(bookmarks)-2];
	return bookmarks[..index-1]+bookmarks[index+1..];
}

private int oldest_character_bookmark_index(
	array(mapping(string:mixed)) bookmarks,void|string character_id)
{
	int oldest = -1;
	string wanted = (string)(character_id || "");
	for(int i=0;i<sizeof(bookmarks);i++){
		if(wanted!="" &&
		   (string)bookmarks[i]["character_id"]!=wanted)
			continue;
		if(oldest<0 || (int)bookmarks[i]["created_at"]<
		   (int)bookmarks[oldest]["created_at"])
			oldest = i;
	}
	return oldest;
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

private mapping(string:object)|zero acquire_account_file_lock(
	string account_id)
{
	string path=account_file_path(account_id);
	object file;
	object file_key;
	mixed lock_error;
	if(path=="")
		return 0;
	Stdio.mkdirhier(dirname(path));
	file=Stdio.File();
	if(!file->open(path+".lock","wca"))
		return 0;
	lock_error=catch{ file_key=file->lock(); };
	if(lock_error || !file_key){
		file->close();
		return 0;
	}
	return (["file":file,"key":file_key]);
}

private void release_account_file_lock(
	mapping(string:object)|zero lock_data)
{
	if(!lock_data)
		return;
	if(lock_data["key"])
		destruct(lock_data["key"]);
	if(lock_data["file"])
		lock_data["file"]->close();
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
		"revision":0,
		"persisted_revision":0,
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
	   !arrayp(record["characters"]) ||
	   (has_index(record,"revision") &&
	    (!intp(record["revision"]) || (int)record["revision"]<0)) ||
	   !valid_illusion_entitlement(record["illusion_entitlement"]) ||
	   !valid_profession_slot_expansions(
		record["profession_slot_expansions"]))
		return 0;
	characters = record["characters"];
	if(sizeof(characters)<1 || sizeof(characters)>ACCOUNT_CHARACTER_LIMIT)
		return 0;
	foreach(characters;int index;mixed raw){
		mapping one;
		string character_id;
		string desired_race;
		string desired_profession;
		string realm_type;
		string illusion_id;
		string illusion_state;
		int slot;
		if(!mappingp(raw))
			return 0;
		one = raw;
		character_id = (string)one["id"];
		slot = (int)one["slot"];
		desired_race = (string)(one["desired_race"] || "");
		desired_profession = (string)(one["desired_profession"] || "");
		realm_type = (string)(one["realm_type"] || "eternal");
		illusion_id = (string)(one["illusion_id"] || "");
		illusion_state = (string)(one["illusion_state"] || "");
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
		if(realm_type!="eternal" && realm_type!="illusion")
			return 0;
		if(realm_type=="illusion" &&
		   (!valid_illusion_id(illusion_id) || illusion_state!="active" ||
		    (int)one["illusion_joined_at"]<=0))
			return 0;
		if(realm_type=="eternal" && illusion_state!="" &&
		   illusion_state!="returned")
			return 0;
		if(realm_type=="eternal" && illusion_state=="" &&
		   illusion_id!="")
			return 0;
		if(illusion_state=="returned" &&
		   (!valid_illusion_id(illusion_id) || (int)one["settled_at"]<=0 ||
		    !valid_sha256_hex((string)one["settlement_receipt"])))
			return 0;
		if((int)one["illusion_story_completed_at"]>0){
			string completed_profession = (string)
				one["illusion_story_completed_profession"];
			if(!valid_illusion_id(illusion_id) ||
			   !valid_profession_pair(desired_race,completed_profession) ||
			   completed_profession==S1_HIDDEN_PROFESSION ||
			   completed_profession!=desired_profession ||
			   (int)one["illusion_story_completion_version"]!=1 ||
			   (int)one["illusion_story_completed_level"]<1 ||
			   (int)one["illusion_story_completed_level"]>MAX_LEVEL)
				return 0;
		}
		else if((string)(one["illusion_story_completed_profession"] || "")!="" ||
			(int)one["illusion_story_completion_version"]!=0 ||
			(int)one["illusion_story_completed_level"]!=0)
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
	string account_id,void|int force_disk)
{
	string path = account_file_path(account_id);
	mapping(string:mixed)|zero record;
	if(!force_disk && account_cache[account_id])
		return copy_value(account_cache[account_id]);
	record = decode_record_file(path,account_id);
	if(!record)
		record = decode_record_file(path+".bak",account_id);
	if(record){
		if(!intp(record["revision"]) || (int)record["revision"]<0)
			record["revision"] = 0;
		record["persisted_revision"] = (int)record["revision"];
		record["legacy_only"] = 0;
		account_cache[account_id] = copy_value(record);
		return copy_value(record);
	}
	return 0;
}

private mapping(string:mixed)|zero load_record_unlocked(string account_id,
	void|int force_disk)
{
	mapping(string:mixed)|zero record;
	string path;
	if(!valid_userid(account_id) || !user_file_exists(account_id))
		return 0;
	record = load_persisted_record_unlocked(account_id,force_disk);
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
	string temporary_suffix;
	string encoded;
	mapping(string:mixed) disk_record;
	mapping(string:mixed)|zero current_record;
	mapping(string:object)|zero file_lock;
	int expected_revision = (int)(record["persisted_revision"] || 0);
	int live_size;
	int backup_size;
	int revision_conflict;
	int ok = 0;
	mixed err;
	if(!valid_record(record,account_id) || path=="")
		return 0;
	dir = dirname(path);
	temporary_suffix = ".tmp."+
		String.string2hex(Crypto.Random.random_string(8));
	temp_path = path+temporary_suffix;
	backup_temp = path+".bak"+temporary_suffix;
	disk_record = copy_value(record);
	m_delete(disk_record,"persisted_revision");
	m_delete(disk_record,"legacy_only");
	disk_record["version"] = ACCOUNT_CHARACTER_VERSION;
	disk_record["revision"] = expected_revision+1;
	disk_record["updated_at"] = time();
	encoded = Standards.JSON.encode(disk_record);
	mkdir(ACCOUNT_CHARACTER_DIR);
	mkdir(dir);
	file_lock = acquire_account_file_lock(account_id);
	if(!file_lock){
		werror("[ACCOUNT_CHARACTERD][SAVE_LOCK_FAILED] account=%s revision=%d\n",
			account_id,expected_revision);
		return 0;
	}
	err = catch{
		rm(temp_path);
		rm(backup_temp);
		live_size = Stdio.file_size(path);
		if(live_size>0)
			current_record = decode_record_file(path,account_id);
		if(!current_record)
			current_record = decode_record_file(path+".bak",account_id);
		if(current_record &&
		   (int)(current_record["revision"] || 0)!=expected_revision)
			revision_conflict = 1;
		else if(!current_record && expected_revision!=0)
			revision_conflict = 1;
		if(!revision_conflict && Stdio.write_file(temp_path,encoded)>0 &&
		   Stdio.file_size(temp_path)==sizeof(encoded)){
			if(live_size>0 && decode_record_file(path,account_id)){
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
	release_account_file_lock(file_lock);
	if(revision_conflict){
		m_delete(account_cache,account_id);
		werror("[ACCOUNT_CHARACTERD][SAVE_REVISION_CONFLICT] account=%s expected=%d current=%d proposed=%d\n",
			account_id,expected_revision,
			current_record ? (int)(current_record["revision"] || 0) : -1,
			(int)disk_record["revision"]);
	}
	if(err)
		werror("[ACCOUNT_CHARACTERD][SAVE_EXCEPTION] account=%s revision=%d error=%s\n",
			account_id,(int)disk_record["revision"],describe_error(err));
	if(!ok){
		rm(temp_path);
		rm(backup_temp);
		return 0;
	}
	record["version"] = ACCOUNT_CHARACTER_VERSION;
	record["revision"] = (int)disk_record["revision"];
	record["persisted_revision"] = (int)disk_record["revision"];
	record["updated_at"] = (int)disk_record["updated_at"];
	record["legacy_only"] = 0;
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
		"realm_type":(string)(entry["realm_type"] || "eternal"),
		"illusion_id":(string)(entry["illusion_id"] || ""),
		"illusion_state":(string)(entry["illusion_state"] || ""),
		"illusion_joined_at":(int)entry["illusion_joined_at"],
		"settled_at":(int)entry["settled_at"],
		"illusion_story_completed_at":
			(int)entry["illusion_story_completed_at"],
		"illusion_story_completion_version":
			(int)entry["illusion_story_completion_version"],
		"illusion_story_completed_profession":(string)
			(entry["illusion_story_completed_profession"] || ""),
		"illusion_story_completed_level":
			(int)entry["illusion_story_completed_level"],
	]);
}

mapping(string:mixed) query_account_characters(string requested_id,
	void|string illusion_id)
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
	// 账号中心在协调器、资格/结算可能在地图Worker。这里是低频管理
	// 读取，必须绕过进程本地缓存看共享磁盘的最新世界身份。
	record = load_record_unlocked(account_id,1);
	if(record){
		array summaries = ({});
		mapping entitlement = mappingp(record["illusion_entitlement"]) ?
			(mapping)record["illusion_entitlement"] : ([]);
		string expansion_id = valid_illusion_id((string)illusion_id) ?
			(string)illusion_id : "S1";
		int existing_illusion_count=0;
		foreach((array)record["characters"],mapping existing_entry)
			if((string)existing_entry["illusion_id"]==expansion_id)
				existing_illusion_count++;
		mapping expansion = illusion_expansion_state(entitlement,
			expansion_id,existing_illusion_count);
		mapping cycle_entitlement = illusion_entitlement_for_cycle(
			entitlement,expansion_id);
		foreach((array)record["characters"],mapping entry)
			summaries += ({profile_summary_unlocked(account_id,entry)});
		mapping hidden_profession_limits = ([]);
		foreach(({"wuxiang","taiji"}),string hidden_profession_id){
			int hidden_profession_count = 0;
			foreach(summaries,mapping one_summary)
				if((string)one_summary["profession_id"]==
				   hidden_profession_id)
					hidden_profession_count++;
			hidden_profession_limits[hidden_profession_id] =
				profession_limit_state_from_record(record,
					hidden_profession_id,hidden_profession_count);
		}
		result = ([
			"ok":1,
			"message":"",
			"account_id":account_id,
			"characters":summaries,
			"limit":ACCOUNT_CHARACTER_LIMIT,
			"legacy_only":(int)record["legacy_only"],
			"illusion_entitled":sizeof(cycle_entitlement)>0,
			"illusion_entitlement":copy_value(entitlement),
			"illusion_entitlement_cycle":copy_value(cycle_entitlement),
			"illusion_entitlement_id":expansion_id,
			"illusion_expansion_id":expansion_id,
			"illusion_character_slots":(int)expansion["character_slots"],
			"illusion_multi_character_unlocked":
				(int)expansion["multi_character_unlocked"],
			"illusion_expansion_spent_suiyu":
				(int)expansion["expansion_spent_suiyu"],
			"illusion_expansion_requests":
				copy_value((array)(expansion["expansion_requests"] || ({}))),
			"hidden_profession_limits":
				copy_value(hidden_profession_limits),
			"illusion_extra_slot_cost_suiyu":ILLUSION_EXTRA_SLOT_COST,
			"illusion_multi_unlock_cost_suiyu":ILLUSION_MULTI_UNLOCK_COST,
		]);
		result["illusion_expansion_remaining_suiyu"] =
			ILLUSION_MULTI_UNLOCK_COST;
	}
	destruct(key);
	if((int)result["ok"]==1){
		// 必须先释放账号索引锁，再读取共享充值钱包。钱包兼容旧 all_fee
		// 时会反查人物索引，颠倒锁顺序会形成账号锁/钱包锁死锁。
		int total_recharge_fee = ACCOUNT_WALLETD->
			query_total_recharge_fee_for_account(account_id);
		result["donation_total"] = total_recharge_fee;
		result["wuxiang_unlocked"] =
			query_wuxiang_unlocked_from_summary(result,total_recharge_fee);
		result["taiji_unlocked"] =
			query_taiji_unlocked_from_summary(result,total_recharge_fee);
		result["wuxiang_unlock_by_donation"] =
			total_recharge_fee>=WUXIANG_DONATION_UNLOCK_FEE;
		result["taiji_unlock_by_donation"] =
			total_recharge_fee>=TAIJI_DONATION_UNLOCK_FEE;
		result["wuji_unlocked"] =
			query_wuji_unlocked_from_summary(result);
		result["wuji_entitled"] =
			mappingp(record["wuji_entitlement"]) &&
			(int)record["wuji_entitlement"]["unlocked"]==1;
		result["wuji_creation_cost"] = WUJI_CREATION_COST;
		result["wuxin_difficulty_ready"] =
			(int)record["wuxin_difficulty_ready"]==1;
		result["wuxin_entitled"] =
			mappingp(record["wuxin_entitlement"]) &&
			(int)record["wuxin_entitlement"]["unlocked"]==1;
		result["wuxin_creation_cost"] = WUXIN_CREATION_COST;
		result["level_cap_400"] = (int)record["level_cap_400"]==1;
		mapping s1_hidden = query_s1_hidden_unlock_from_summary(result,
			valid_illusion_id((string)illusion_id) ?
			(string)illusion_id : "S1");
		result["s1_hidden_profession"] = s1_hidden;
		result["zhaoming_unlocked"] = (int)s1_hidden["unlocked"];
	}
	return result;
}

/**
 * Persist one paid hidden-profession slot.  The request id is stored in the
 * account index before the wallet receipt is discarded, so a retry after a
 * process exit can only complete the same slot once.
 */
mapping(string:mixed) grant_profession_slot_expansion(string requested_id,
	string profession_id,string request_id,int paid_amount)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"职业人物上限写入失败。"]) ;
	string account_id = query_account_id_for_character(requested_id);
	mapping(string:mixed)|zero record;
	mapping expansions;
	mapping expansion;
	mapping state;
	array requests;
	int count;
	int expected_cost;
	object key;
	if(!valid_userid(account_id) ||
	   query_profession_account_limit(profession_id)<=0 ||
	   !valid_sha256_hex(request_id) || paid_amount<=0)
		return result;
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id,1);
	if(!record){
		destruct(key);
		return result;
	}
	expansions = mappingp(record["profession_slot_expansions"]) ?
		copy_value((mapping)record["profession_slot_expansions"]) : ([]);
	expansion = mappingp(expansions[profession_id]) ?
		copy_value((mapping)expansions[profession_id]) : ([]);
	requests = arrayp(expansion["requests"]) ?
		(array)expansion["requests"] : ({});
	state = profession_limit_state_from_record(record,profession_id);
	if(search(requests,request_id)!=-1){
		result = (["ok":1,"already":1,"same_request":1,
			"message":"本次职业人物上限已经扩充。",
			"account_id":account_id,"profession_id":profession_id,
			"state":copy_value(state)]);
		destruct(key);
		return result;
	}
	foreach((array)record["characters"],mapping existing_entry){
		mapping summary = profile_summary_unlocked(account_id,existing_entry);
		if((string)summary["profession_id"]==profession_id)
			count++;
	}
	state = profession_limit_state_from_record(record,profession_id,count);
	expected_cost = (int)state["next_cost_suiyu"];
	if(!(int)state["can_expand"]){
		result["message"] = "该职业已经达到10个人物的绝对上限。";
		destruct(key);
		return result;
	}
	if(count<(int)state["current_limit"]){
		result["message"] = "当前职业上限尚未用满，本次不会扣费。";
		destruct(key);
		return result;
	}
	if(paid_amount!=expected_cost){
		result["message"] = "职业人物上限价格已经变化，本次不会扣费。";
		result["expected_cost_suiyu"] = expected_cost;
		destruct(key);
		return result;
	}
	int extra_slots = (int)state["extra_slots"]+1;
	expansion = ([
		"extra_slots":extra_slots,
		"spent_suiyu":profession_expansion_expected_spent(extra_slots),
		"requests":requests+({request_id}),
		"updated_at":time(),
	]);
	expansions[profession_id] = expansion;
	record["profession_slot_expansions"] = expansions;
	if(save_record_unlocked(record)){
		state = profession_limit_state_from_record(record,profession_id,count);
		result = (["ok":1,"already":0,"same_request":0,
			"message":"职业人物上限已提升至"+
				(int)state["current_limit"]+"个（最高10个）。",
			"account_id":account_id,"profession_id":profession_id,
			"charged_suiyu":paid_amount,"state":copy_value(state)]);
	}
	destruct(key);
	return result;
}

mapping(string:mixed) reconcile_profession_slot_expansions(
	string requested_id)
{
	string account_id = query_account_id_for_character(requested_id);
	mapping(string:mixed) summary = (["ok":1,"recovered":0,
		"refunded":0,"pending":0]);
	array(mapping(string:mixed)) receipts;
	if(!valid_userid(account_id))
		return (["ok":0,"recovered":0,"refunded":0,"pending":0]);
	receipts = ACCOUNT_WALLETD->query_account_debit_requests(account_id,
		HIDDEN_PROFESSION_EXPANSION_REASON);
	foreach(receipts,mapping receipt){
		string reason = (string)(receipt["reason"] || "");
		string profession_id = "";
		string request_id = (string)(receipt["request_id"] || "");
		int amount = (int)receipt["amount"];
		mapping grant = ([]);
		if(sscanf(reason,HIDDEN_PROFESSION_EXPANSION_REASON+"%s",
		   profession_id)==1 &&
		   query_profession_account_limit(profession_id)>0 &&
		   valid_sha256_hex(request_id) && amount>=5000 && amount<=40000 &&
		   amount%5000==0)
			grant = grant_profession_slot_expansion(account_id,
				profession_id,request_id,amount);
		if((int)grant["ok"] &&
		   (!(int)grant["already"] || (int)grant["same_request"])){
			if(ACCOUNT_WALLETD->forget_account_debit_recharge_once(
			   account_id,request_id))
				summary["recovered"] = (int)summary["recovered"]+1;
			else{
				summary["ok"] = 0;
				summary["pending"] = (int)summary["pending"]+1;
			}
		}
		else if(ACCOUNT_WALLETD->rollback_account_debit_recharge_once(
		   account_id,request_id,"profession_slot_expansion_recovery"))
			summary["refunded"] = (int)summary["refunded"]+1;
		else{
			summary["ok"] = 0;
			summary["pending"] = (int)summary["pending"]+1;
		}
	}
	return summary;
}

private mapping(string:mixed) query_profession_slot_expansion_request(
	string account_id,string profession_id,string request_id)
{
	mapping(string:mixed) result = (["processed":0]);
	mapping(string:mixed)|zero record;
	object key = account_character_lock->lock();
	record = load_record_unlocked(account_id,1);
	if(record){
		mapping expansions = mappingp(record["profession_slot_expansions"]) ?
			(mapping)record["profession_slot_expansions"] : ([]);
		mapping expansion = mappingp(expansions[profession_id]) ?
			(mapping)expansions[profession_id] : ([]);
		array requests = arrayp(expansion["requests"]) ?
			(array)expansion["requests"] : ({});
		if(search(requests,request_id)!=-1){
			int count = 0;
			foreach((array)record["characters"],mapping existing_entry){
				mapping summary = profile_summary_unlocked(account_id,
					existing_entry);
				if((string)summary["profession_id"]==profession_id)
					count++;
			}
			result = (["processed":1,
				"state":profession_limit_state_from_record(record,
					profession_id,count)]);
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) purchase_profession_slot_expansion(
	string requested_id,string profession_id,string request_id,
	void|object payer)
{
	string account_id = query_account_id_for_character(requested_id);
	mapping account_data;
	mapping state;
	mapping(string:mixed) payment;
	mapping debit;
	mapping grant;
	mapping processed;
	string reason;
	int cost;
	int cleanup_ok;
	int paid_physical;
	if(!valid_userid(account_id) ||
	   query_profession_account_limit(profession_id)<=0 ||
	   !valid_sha256_hex(request_id))
		return (["ok":0,"message":"职业人物上限扩充请求无效。"]) ;
	reconcile_profession_slot_expansions(account_id);
	processed = query_profession_slot_expansion_request(account_id,
		profession_id,request_id);
	if((int)processed["processed"])
		return (["ok":1,"already":1,
			"message":"本次职业人物上限已经扩充，请继续创建人物。",
			"profession_id":profession_id,
			"state":copy_value((mapping)processed["state"])]);
	account_data = query_account_characters(account_id);
	if(!(int)account_data["ok"] ||
	   !mappingp(account_data["hidden_profession_limits"]) ||
	   !mappingp(account_data["hidden_profession_limits"][profession_id]))
		return (["ok":0,
			"message":"账号职业人物上限暂不可验证，本次未扣费。"]) ;
	state = account_data["hidden_profession_limits"][profession_id];
	if(!(int)state["can_expand"])
		return (["ok":0,"message":"该职业已经达到10个人物的绝对上限。"]) ;
	if((int)state["count"]<(int)state["current_limit"])
		return (["ok":0,"message":"当前职业上限尚未用满，无需购买。"]) ;
	cost = (int)state["next_cost_suiyu"];
	if(cost<5000 || cost>40000 || cost%5000!=0)
		return (["ok":0,"message":"职业人物上限价格异常，本次未扣费。"]) ;
	reason = HIDDEN_PROFESSION_EXPANSION_REASON+profession_id;
	/* 默认扣账号共享碎玉；不足时用付款人物背包实体玉补足。 */
	if(payer){
		payment = YUSHID->pay_account_expansion(payer,account_id,cost,
			reason,request_id);
		if(!(int)payment["ok"])
			return (["ok":0,"message":(string)payment["message"]]);
		paid_physical = (int)payment["paid_physical"];
	}
	else{
		debit = ACCOUNT_WALLETD->debit_account_recharge_once(account_id,cost,
			reason,request_id);
		if(!(int)debit["ok"])
			return (["ok":0,"message":(string)(debit["message"] ||
				"账号共享充值余额扣款失败。")]);
	}
	grant = grant_profession_slot_expansion(account_id,profession_id,
		request_id,cost);
	if(!(int)grant["ok"] ||
	   ((int)grant["already"] && !(int)grant["same_request"])){
		int refunded = ACCOUNT_WALLETD->rollback_account_debit_recharge_once(
			account_id,request_id,"profession_slot_expansion_failed");
		if(paid_physical>0 && payer && !YUSHID->give_yushi(payer,
			paid_physical))
			refunded = 0;
		return (["ok":0,"message":refunded ?
			"职业上限状态已经变化，本次扣款已原路退回。" :
			"职业上限写入及退款异常，请立即联系管理员。"]) ;
	}
	cleanup_ok = ACCOUNT_WALLETD->forget_account_debit_recharge_once(
		account_id,request_id);
	return (["ok":1,"already":(int)debit["duplicate"],
		"message":(string)grant["message"]+" 已支付"+cost+"碎玉。",
		"cleanup_pending":!cleanup_ok,"charged_suiyu":cost,
		"profession_id":profession_id,
		"state":copy_value((mapping)grant["state"])]);
}

mapping(string:mixed) query_character_realm(string character_id)
{
	mapping(string:mixed) result = ([
		"ok":0,"realm_type":"eternal","illusion_id":"",
		"illusion_state":"","security_blocked":0,
	]);
	string account_id = query_account_id_for_character(character_id);
	mapping(string:mixed)|zero record;
	object key;
	if(!valid_userid(account_id) || !valid_userid(character_id))
		return result;
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record){
		foreach((array)record["characters"],mapping entry){
			if((string)entry["id"]!=character_id)
				continue;
			result = ([
				"ok":1,
				"account_id":account_id,
				"character_id":character_id,
				"realm_type":(string)(entry["realm_type"] || "eternal"),
				"illusion_id":(string)(entry["illusion_id"] || ""),
				"illusion_state":(string)(entry["illusion_state"] || ""),
				"illusion_joined_at":(int)entry["illusion_joined_at"],
				"settled_at":(int)entry["settled_at"],
			]);
			break;
		}
	}
	else{
		string index_path = account_file_path(account_id);
		// 账号索引存在却无法通过主/备份校验时不能把人物当作永恒服
		// 旧账号。直接失败关闭，避免损坏索引让幻境人物绕过隔离。
		if(index_path!="" &&
		   (Stdio.file_size(index_path)>0 ||
		    Stdio.file_size(index_path+".bak")>0))
			result = ([
				"ok":0,"account_id":account_id,
				"character_id":character_id,"realm_type":"unavailable",
				"illusion_id":"","illusion_state":"",
				"security_blocked":1,
			]);
	}
	destruct(key);
	return result;
}

/** Rare lifecycle audit: scan immutable account indexes without loading users. */
mapping(string:mixed) query_illusion_population(string illusion_id)
{
	mapping(string:mixed) result = ([
		"ok":0,"illusion_id":illusion_id,"active":0,"returned":0,
		"accounts":0,"corrupt_indexes":0,
	]);
	array(string) buckets;
	if(!valid_illusion_id(illusion_id))
		return result;
	buckets = get_dir(ACCOUNT_CHARACTER_DIR) || ({});
	foreach(buckets,string bucket){
		string bucket_path = ACCOUNT_CHARACTER_DIR+"/"+bucket;
		Stdio.Stat bucket_stat = file_stat(bucket_path);
		if(!bucket_stat || !bucket_stat->isdir)
			continue;
		foreach(get_dir(bucket_path) || ({}),string filename){
			string account_id;
			mapping record;
			if(!has_suffix(filename,".json"))
				continue;
			account_id = filename[..sizeof(filename)-6];
			// wallet/pet/storage JSON 含点号，不能误算作人物索引。
			if(!valid_userid(account_id))
				continue;
			record = decode_record_file(bucket_path+"/"+filename,
				account_id) || decode_record_file(
					bucket_path+"/"+filename+".bak",account_id);
			if(!record){
				result["corrupt_indexes"] =
					(int)result["corrupt_indexes"]+1;
				continue;
			}
			result["accounts"] = (int)result["accounts"]+1;
			foreach((array)record["characters"],mapping entry){
				if((string)entry["illusion_id"]!=illusion_id)
					continue;
				if((string)entry["realm_type"]=="illusion" &&
				   (string)entry["illusion_state"]=="active")
					result["active"] = (int)result["active"]+1;
				else if((string)entry["realm_type"]=="eternal" &&
				   (string)entry["illusion_state"]=="returned")
					result["returned"] = (int)result["returned"]+1;
			}
		}
	}
	result["ok"] = (int)result["corrupt_indexes"]==0;
	return result;
}

mapping(string:mixed) grant_illusion_entitlement(string requested_id,
	string source,void|string request_id,void|string requested_illusion_id)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"幻境资格写入失败。"]);
	string account_id = query_account_id_for_character(requested_id);
	string illusion_id = (string)(requested_illusion_id || "S1");
	mapping(string:mixed)|zero record;
	mapping entitlement;
	mapping season_entitlements;
	mapping cycle_entitlement;
	mapping legacy_entitlement;
	string legacy_cycle_id;
	object key;
	if(!valid_userid(account_id) || !valid_illusion_id(illusion_id) ||
	   search(({"jade","admin","legacy","test","account_center"}),source)==-1 ||
	   (request_id && !valid_sha256_hex((string)request_id)))
		return result;
	key = account_character_lock->lock();
	// 资格可能由另一个Worker刚写入；持有网关账号锁时仍需绕过本地旧缓存。
	record = load_record_unlocked(account_id,1);
	if(record){
		entitlement = mappingp(record["illusion_entitlement"]) ?
			(mapping)record["illusion_entitlement"] : ([]);
		cycle_entitlement = illusion_entitlement_for_cycle(entitlement,
			illusion_id);
		if(sizeof(cycle_entitlement))
			result = (["ok":1,"already":1,
				"message":"账号已登记"+illusion_id+"赛季资格。",
				"account_id":account_id,"illusion_id":illusion_id,
				"cycle_entitlement":copy_value(cycle_entitlement),
				"entitlement":copy_value(entitlement)]);
		else{
			if(!sizeof(entitlement)){
				entitlement = ([
					"unlocked":1,"unlocked_at":time(),"source":source,
					"legacy_cycle_id":illusion_id,
					"character_slots":1,"multi_character_unlocked":0,
					"expansion_spent_suiyu":0,"expansion_requests":({}),
					"season_expansions":([]),"season_entitlements":([]),
				]);
				if(request_id)
					entitlement["request_id"] = request_id;
			}
			season_entitlements = mappingp(entitlement["season_entitlements"]) ?
				copy_value((mapping)entitlement["season_entitlements"]) : ([]);
			// Preserve a pre-cycle-keyed qualification as one explicit cycle
			// before adding a later cycle to the same account container.
			legacy_cycle_id = (string)(
				entitlement["legacy_cycle_id"] || "S1");
			legacy_entitlement = illusion_entitlement_for_cycle(entitlement,
				legacy_cycle_id);
			if(sizeof(legacy_entitlement) &&
			   !mappingp(season_entitlements[legacy_cycle_id]))
				season_entitlements[legacy_cycle_id] =
					copy_value(legacy_entitlement);
			cycle_entitlement = ([
				"unlocked":1,"unlocked_at":time(),"source":source,
			]);
			if(request_id)
				cycle_entitlement["request_id"] = request_id;
			season_entitlements[illusion_id] =
				copy_value(cycle_entitlement);
			entitlement["season_entitlements"] = season_entitlements;
			record["illusion_entitlement"] = entitlement;
			if(save_record_unlocked(record))
				result = (["ok":1,"already":0,
					"message":"账号已登记"+illusion_id+"赛季资格。",
					"account_id":account_id,"illusion_id":illusion_id,
					"cycle_entitlement":copy_value(cycle_entitlement),
					"entitlement":copy_value(entitlement)]);
		}
	}
	destruct(key);
	return result;
}

/**
 * Atomically grant one paid character-slot expansion or the cumulative
 * multi-character unlock for one specific season. Qualification and paid
 * slots are both cycle-keyed and never leak into a later season. Request ids
 * make crash recovery and cross-Worker retries idempotent.
 */
mapping(string:mixed) grant_illusion_character_expansion(string requested_id,
	string illusion_id,string option,string request_id,int paid_amount)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"幻境人物栏位写入失败。"]);
	string account_id = query_account_id_for_character(requested_id);
	mapping(string:mixed)|zero record;
	mapping entitlement;
	mapping expansions;
	mapping expansion;
	array requests;
	int spent;
	int expected;
	int existing_count;
	int added_slots;
	object key;
	if(!valid_userid(account_id) || !valid_illusion_id(illusion_id) ||
	   search(({"one","all"}),option)==-1 ||
	   !valid_sha256_hex(request_id) || paid_amount<=0)
		return result;
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id,1);
	if(!record || !mappingp(record["illusion_entitlement"]) ||
	   !sizeof(illusion_entitlement_for_cycle(
		(mapping)record["illusion_entitlement"],illusion_id))){
		result["message"] = "账号尚未激活"+illusion_id+"人物资格。";
		destruct(key);
		return result;
	}
	entitlement = record["illusion_entitlement"];
	foreach((array)record["characters"],mapping existing_entry)
		if((string)existing_entry["illusion_id"]==illusion_id)
			existing_count++;
	expansions = mappingp(entitlement["season_expansions"]) ?
		copy_value((mapping)entitlement["season_expansions"]) : ([]);
	expansion = illusion_expansion_state(entitlement,illusion_id,
		existing_count);
	requests = arrayp(expansion["expansion_requests"]) ?
		(array)expansion["expansion_requests"] : ({});
	if(search(requests,request_id)!=-1){
		result = (["ok":1,"already":1,"same_request":1,
			"message":"本次幻境人物栏位已成功写入。",
			"account_id":account_id,"illusion_id":illusion_id,
			"entitlement":copy_value(entitlement),
			"expansion":copy_value(expansion)]);
		destruct(key);
		return result;
	}
	spent = (int)(expansion["expansion_spent_suiyu"] || 0);
	added_slots=option=="one" ? 1 :
		ILLUSION_MULTI_UNLOCK_COST/ILLUSION_EXTRA_SLOT_COST;
	expected=added_slots*ILLUSION_EXTRA_SLOT_COST;
	if(spent<0 || spent%ILLUSION_EXTRA_SLOT_COST!=0 ||
	   paid_amount!=expected){
		result["message"] = "幻境人物栏位价格状态已变化。";
		result["expected_cost_suiyu"] = expected;
		destruct(key);
		return result;
	}
	if((int)expansion["character_slots"]+added_slots>
	   ILLUSION_MAX_CHARACTER_SLOTS){
		result["message"] = "购买后会超过账号30个人物总上限，本次未扣费。";
		destruct(key);
		return result;
	}
	spent += paid_amount;
	expansion["expansion_spent_suiyu"] = spent;
	expansion["expansion_updated_at"] = time();
	expansion["expansion_requests"] = requests+({request_id});
	expansion["version"] = 2;
	expansion["multi_character_unlocked"] = 0;
	expansion["character_slots"] =
		(int)expansion["character_slots"]+added_slots;
	expansions[illusion_id] = copy_value(expansion);
	entitlement["season_expansions"] = expansions;
	// Mirror S1 into the original legacy schema so an emergency rollback to a
	// pre-season-keyed binary can still start.  That schema inherently means
	// “one free + at most five paid slots”; exact v2 capacity remains solely in
	// season_expansions and may exceed what an old binary can represent.
	if(illusion_id=="S1"){
		int legacy_spent=min(spent,ILLUSION_MULTI_UNLOCK_COST);
		array legacy_requests=(array)expansion["expansion_requests"];
		if(sizeof(legacy_requests)>5)
			legacy_requests=legacy_requests[sizeof(legacy_requests)-5..];
		entitlement["expansion_spent_suiyu"] = legacy_spent;
		entitlement["expansion_updated_at"] =
			(int)expansion["expansion_updated_at"];
		entitlement["expansion_requests"] =
			copy_value(legacy_requests);
		entitlement["multi_character_unlocked"] =
			legacy_spent==ILLUSION_MULTI_UNLOCK_COST;
		entitlement["character_slots"] =
			1+legacy_spent/ILLUSION_EXTRA_SLOT_COST;
	}
	if(save_record_unlocked(record))
		result = (["ok":1,"already":0,"same_request":0,
			"message":"已增加"+(string)added_slots+
				"个本期幻境人物栏位。",
			"account_id":account_id,"illusion_id":illusion_id,
			"charged_suiyu":paid_amount,
			"entitlement":copy_value(entitlement),
			"expansion":copy_value(expansion)]);
	destruct(key);
	return result;
}

mapping(string:mixed) settle_illusion_character(string character_id,
	string illusion_id,string receipt_hash)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"幻境人物回归失败。"]);
	string account_id = query_account_id_for_character(character_id);
	mapping(string:mixed)|zero record;
	object key;
	if(!valid_userid(account_id) || !valid_userid(character_id) ||
	   !valid_illusion_id(illusion_id) || !receipt_hash ||
	   !valid_sha256_hex(receipt_hash))
		return result;
	key = account_character_lock->lock();
	// 回归是账号世界身份的唯一写入口，写前必须读取共享磁盘最新修订。
	record = load_record_unlocked(account_id,1);
	if(record){
		foreach((array)record["characters"],mapping entry){
			if((string)entry["id"]!=character_id)
				continue;
			if((string)(entry["realm_type"] || "eternal")=="eternal" &&
			   (string)entry["illusion_id"]==illusion_id &&
			   (string)entry["illusion_state"]=="returned"){
				if((string)entry["settlement_receipt"]==receipt_hash)
					result = (["ok":1,"already":1,
						"message":"该幻境人物已经回归永恒服。"]);
				else
					result["message"] = "回归收据不匹配，已拒绝重复结算。";
			}
			else if((string)entry["realm_type"]=="illusion" &&
			   (string)entry["illusion_id"]==illusion_id &&
			   (string)entry["illusion_state"]=="active"){
				entry["realm_type"] = "eternal";
				entry["illusion_state"] = "returned";
				entry["settled_at"] = time();
				entry["settlement_receipt"] = receipt_hash;
				if(save_record_unlocked(record))
					result = (["ok":1,"already":0,
						"message":"幻境人物已回归永恒服。"]);
			}
			break;
		}
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

private string deleted_character_archive_dir(string account_id,
	string receipt_hash)
{
	if(!valid_userid(account_id) || !valid_sha256_hex(receipt_hash))
		return "";
	return DELETED_CHARACTER_DIR+"/"+
		account_id[sizeof(account_id)-2..]+"/"+account_id+"/"+receipt_hash;
}

private int write_deleted_character_manifest(string archive_dir,
	mapping manifest)
{
	string path = archive_dir+"/manifest.json";
	string temporary = path+".tmp";
	string encoded = Standards.JSON.encode(manifest);
	if(archive_dir=="" || !mappingp(manifest) || sizeof(encoded)>64*1024)
		return 0;
	Stdio.mkdirhier(archive_dir);
	chmod(archive_dir,0700);
	rm(temporary);
	if(Stdio.write_file(temporary,encoded)!=sizeof(encoded) ||
	   Stdio.file_size(temporary)!=sizeof(encoded) || !mv(temporary,path)){
		rm(temporary);
		return 0;
	}
	chmod(path,0600);
	return 1;
}

private int character_is_locally_online(string account_id,
	string character_id)
{
	int online = find_player(character_id) ? 1 : 0;
	object state_key;
	if(online)
		return 1;
	state_key = account_online_state_lock->lock();
	foreach(account_online_players[account_id] || ({}),object player)
		if(objectp(player) && functionp(player->query_name) &&
		   (string)player->query_name()==character_id){
			online = 1;
			break;
		}
	destruct(state_key);
	return online;
}

/**
 * Remove a non-default, offline character from the active account index while
 * moving its physical save files into a restricted recovery archive.  No
 * player data is unlinked; an administrator can restore the receipt manually.
 */
/**
 * 整账号删除（Apple 5.1.1(v) 应用内删除账号要求）：
 * 归档全部人物（含默认人物，凭allow_root放行一次），再删除账号
 * 索引记录。调用方必须已完成账号令牌+密码+输入账号ID三重确认。
 * 返回 (["ok":1,"archived":N]) 或 (["ok":0,"message":...])，
 * 失败时已完成归档的人物保持已归档状态（安全方向：宁可多归档）。
 */
mapping(string:mixed) retire_entire_account(string account_id,
	string receipt_hash)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"账号删除失败，账号保持不变。"]);
	mapping(string:mixed)|zero record;
	array(mapping(string:string)) characters;
	int archived = 0;
	object key;

	if(!valid_userid(account_id) || !valid_sha256_hex(receipt_hash))
		return result;
	/* 在线人物先安全下线（保存并断开），否则retire会失败关闭。 */
	{
		array online = ({});
		object state_key = account_online_state_lock->lock();
		foreach(account_online_players[account_id] || ({}),object p)
			if(objectp(p) && !object_in_array(online,p))
				online += ({p});
		destruct(state_key);
		foreach(online,object p)
			disconnect_online_character(p,"账号删除");
	}
	key = account_character_lock->lock();
	record = load_persisted_record_unlocked(account_id);
	characters = ({});
	/* 老式/新注册账号可能只有默认人物、尚无账号索引记录：
	 * 视为零子人物继续（默认人物档案仍会被归档）。 */
	if(record && arrayp(record["characters"])){
		foreach((array)record["characters"],mapping entry){
			if(mappingp(entry) && stringp(entry["id"]))
				characters += ({entry});
		}
	}
	destruct(key);

	/* 先删非默认人物，最后删默认人物；任一失败立即中止，
	 * 账号记录仍在，玩家可重试（幂等：已归档人物会被跳过）。 */
	foreach(characters,mapping entry){
		string cid = (string)entry["id"];
		if(cid==account_id)
			continue;
		mapping one = retire_account_character(account_id,cid,
			String.string2hex(Crypto.SHA256.hash(
				receipt_hash+":"+cid)));
		if(!(int)one["ok"]){
			return (["ok":0,"message":(string)(
				one["message"] || "人物归档失败，账号保持不变。")]);
		}
		archived += 1;
	}
	/* 默认人物不走单人物归档（记录校验要求账号至少保留一个人物，
	 * 空记录会保存失败并回滚）：这里直接归档其物理档案并写清单，
	 * 随后整条账号记录将被删除，无需再维护人物索引。 */
	{
		string root_receipt = String.string2hex(Crypto.SHA256.hash(
			receipt_hash+":root"));
		string root_archive = deleted_character_archive_dir(
			account_id,root_receipt);
		string root_source = user_file_path(account_id);
		mapping root_manifest = ([
			"version":1,"state":"archived",
			"account_id":account_id,
			"character_id":account_id,
			"receipt_hash":root_receipt,
			"requested_at":time(),
			"root_character":1,
		]);
		if(root_archive==""){
			return (["ok":0,
				"message":"默认人物归档路径无效，账号保持不变。"]);
		}
		if(Stdio.file_size(root_source)>0){
			if(!write_deleted_character_manifest(root_archive,
				root_manifest)){
				return (["ok":0,
					"message":"默认人物归档清单写入失败，账号保持不变。"]);
			}
			foreach(({"",".bak",".tmp",".bak.tmp"}),string suffix){
				string one = root_source+suffix;
				if(Stdio.file_size(one)>0 &&
				   !mv(one,root_archive+"/profile.o"+suffix))
					return (["ok":0,
						"message":"默认人物档案移动失败，账号保持不变。"]);
			}
			archived += 1;
		}
	}

	/* 无条件删除账号级文件：不能在此加载记录（带修复标志的加载会
	 * 从默认人物.o重建记录并回存，导致记录复活与.o重现）。钱包与
	 * 共享仓库一并归档进root回执目录后移除（Apple要求彻底删除）。 */
	key = account_character_lock->lock();
	rm(account_file_path(account_id));
	rm(account_file_path(account_id)+".bak");
	rm(account_file_path(account_id)+".tmp");
	m_delete(account_cache,account_id);
	destruct(key);
	invalidate_worker_account_cache(account_id);
	{
		string acct_prefix = DATA_ROOT+"accounts/"+
			account_id[sizeof(account_id)-2..]+"/"+account_id;
		string root_receipt2 = String.string2hex(Crypto.SHA256.hash(
			receipt_hash+":root"));
		string root_archive2 = deleted_character_archive_dir(
			account_id,root_receipt2);
		foreach(({".wallet.json",".storage.json"}),
			string acct_suffix){
			string one = acct_prefix+acct_suffix;
			if(Stdio.file_size(one)>0 && root_archive2!="")
				mv(one,root_archive2+"/account"+acct_suffix);
			rm(one+".bak");
			rm(one+".tmp");
		}
	}
	return (["ok":1,"archived":archived]);
}

mapping(string:mixed) retire_account_character(string account_id,
	string character_id,string receipt_hash,void|int allow_root)
{
	mapping(string:mixed) result = (["ok":0,
		"message":"人物安全归档失败，原人物保持不变。"]) ;
	mapping(string:mixed)|zero record;
	mapping target_entry = ([]);
	array(mapping(string:string)) moved_files = ({});
	array(mapping(string:mixed)) kept_characters = ({});
	array(mapping(string:mixed)) kept_bookmarks = ({});
	string archive_dir;
	string manifest_path;
	string source_path;
	int target_slot;
	mapping existing_manifest = ([]);
	mapping manifest = ([]);
	int resumable_manifest;
	int resuming_after_move;
	object key;
	if(!valid_userid(account_id) || !valid_userid(character_id) ||
	   !valid_sha256_hex(receipt_hash)){
		return result;
	}
	if(character_id==account_id && !allow_root){
		result["message"] = "注册账号的默认人物不能删除。";
		return result;
	}
	archive_dir = deleted_character_archive_dir(account_id,receipt_hash);
	manifest_path = archive_dir+"/manifest.json";
	if(Stdio.file_size(manifest_path)>0){
		mixed decode_error = catch {
			existing_manifest = Standards.JSON.decode(
				Stdio.read_file(manifest_path));
		};
		if(!decode_error && mappingp(existing_manifest) &&
		   (string)existing_manifest["account_id"]==account_id &&
		   (string)existing_manifest["character_id"]==character_id &&
		   (string)existing_manifest["receipt_hash"]==receipt_hash &&
		   (string)existing_manifest["state"]=="archived")
			return (["ok":1,"already":1,
				"message":"该人物已经安全归档。",
				"character_id":character_id,"receipt_hash":receipt_hash]);
		resumable_manifest = !decode_error && mappingp(existing_manifest) &&
			(string)existing_manifest["account_id"]==account_id &&
			(string)existing_manifest["character_id"]==character_id &&
			(string)existing_manifest["receipt_hash"]==receipt_hash;
		if(!resumable_manifest)
			return result;
	}
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id,1);
	if(!record){
		destruct(key);
		return result;
	}
	foreach((array)record["characters"],mapping entry){
		if((string)entry["id"]==character_id){
			target_entry = copy_value(entry);
			target_slot = (int)entry["slot"];
			continue;
		}
		mapping kept_entry = copy_value(entry);
		kept_entry["slot"] = sizeof(kept_characters)+1;
		kept_characters += ({kept_entry});
	}
	if(!sizeof(target_entry)){
		// 索引已提交、最终manifest刚好遇到进程中断时，
		// 同一回执可以从受限归档中证明已完成，不让玩家
		// 陷入“人物已没了但接口一直失败”的不确定状态。
		if(resumable_manifest &&
		   Stdio.file_size(archive_dir+"/profile.o")>0){
			existing_manifest["state"] = "archived";
			existing_manifest["archived_at"] =
				(int)(existing_manifest["archived_at"] || time());
			existing_manifest["recovered_after_interruption"] = 1;
			write_deleted_character_manifest(archive_dir,
				existing_manifest);
			result = (["ok":1,"already":1,
				"message":"该人物已经安全归档。",
				"character_id":character_id,
				"receipt_hash":receipt_hash,"refund_suiyu":0]);
			destruct(key);
			return result;
		}
		result["message"] = "人物不属于当前账号或已经删除。";
		destruct(key);
		return result;
	}
	if(character_is_locally_online(account_id,character_id)){
		result["message"] = "人物仍然在线，请先退出该人物后再删除。";
		destruct(key);
		return result;
	}
	source_path = user_file_path(character_id);
	if(resumable_manifest){
		// 进程可能在主档已mv、账号索引尚未提交时
		// 中断。只有“原主档已消失+归档主档完整”才
		// 继续同一回执；任何双份或缺失状态都留给管理员。
		if(Stdio.file_size(source_path)<0 &&
		   Stdio.file_size(archive_dir+"/profile.o")>0){
			manifest = copy_value(existing_manifest);
			resuming_after_move = 1;
		}
		else{
			result["message"] = "上次安全归档未完成，原人物仍保留；请联系管理员检查回执。";
			destruct(key);
			return result;
		}
	}
	else if(Stdio.file_size(source_path)<=0){
		result["message"] = "人物物理存档不可用，已拒绝删除。";
		destruct(key);
		return result;
	}
	if(!resuming_after_move){
		manifest = ([
			"version":1,"state":"pending","account_id":account_id,
			"character_id":character_id,"receipt_hash":receipt_hash,
			"requested_at":time(),"original_slot":target_slot,
			"entry":copy_value(target_entry),
		]);
		if(!write_deleted_character_manifest(archive_dir,manifest)){
			destruct(key);
			return result;
		}
	}
	foreach(({"",".bak",".tmp",".bak.tmp"}),string suffix){
		string one_source = source_path+suffix;
		string archive_name = suffix=="" ? "profile.o" :
			"profile.o"+suffix;
		string one_target = archive_dir+"/"+archive_name;
		if(Stdio.file_size(one_target)>=0){
			if(Stdio.file_size(one_source)>=0){
				result["message"] = "安全归档发现冲突副本，已停止并保留现状。";
				destruct(key);
				return result;
			}
			continue;
		}
		if(Stdio.file_size(one_source)<0)
			continue;
		if(!mv(one_source,one_target)){
			for(int rollback_index=sizeof(moved_files)-1;
				rollback_index>=0;rollback_index--)
				mv(moved_files[rollback_index]["target"],
					moved_files[rollback_index]["source"]);
			manifest["state"] = "move_failed";
			write_deleted_character_manifest(archive_dir,manifest);
			destruct(key);
			return result;
		}
		moved_files += ({(["source":one_source,"target":one_target])});
	}
	foreach(normalized_character_bookmarks(record),mapping bookmark)
		if((string)bookmark["character_id"]!=character_id)
			kept_bookmarks += ({bookmark});
	record["characters"] = kept_characters;
	record["character_bookmarks"] = kept_bookmarks;
	if(!save_record_unlocked(record)){
		for(int rollback_index=sizeof(moved_files)-1;
			rollback_index>=0;rollback_index--)
			mv(moved_files[rollback_index]["target"],
				moved_files[rollback_index]["source"]);
		manifest["state"] = "index_save_failed";
		write_deleted_character_manifest(archive_dir,manifest);
		destruct(key);
		return result;
	}
	manifest["state"] = "archived";
	manifest["archived_at"] = time();
	manifest["active_characters_after"] = sizeof(kept_characters);
	if(resuming_after_move)
		manifest["resumed_after_interruption"] = 1;
	if(!write_deleted_character_manifest(archive_dir,manifest))
		werror("[ACCOUNT_CHARACTERD][DELETE_MANIFEST_FINALIZE_FAILED] account=%s character=%s receipt=%s\n",
			account_id,character_id,receipt_hash);
	result = (["ok":1,"already":0,
		"message":"人物已移入安全归档；账号人物栏位已经释放。",
		"character_id":character_id,"receipt_hash":receipt_hash,
		"freed_slot":target_slot,"active_characters":sizeof(kept_characters),
		"refund_suiyu":0]);
	destruct(key);
	return result;
}

/**
 * 把人物真实完成 S1 八十一章的事实原子写入账号索引。这里只盖完成章，
 * 解锁时仍读取人物当前等级，避免完成故事后靠旧快照永久冻结等级状态。
 */
mapping(string:mixed) record_illusion_story_completion(object player,
	string illusion_id)
{
	mapping(string:mixed) result = (["ok":0,"already":0,
		"message":"幻境职业完成凭证保存失败。"]) ;
	string character_id;
	string account_id;
	string profession_id;
	int completed_level;
	int test_bypass;
	mapping(string:mixed)|zero record;
	object key;
	if(!player || illusion_id!="S1" ||
	   !functionp(player->query_name) ||
	   !functionp(player->query_profeId) ||
	   !functionp(player->query_level))
		return result;
	character_id = (string)player->query_name();
	account_id = functionp(player->query_account_owner) ?
		(string)player->query_account_owner() : character_id;
	profession_id = (string)player->query_profeId();
	completed_level = (int)player->query_level();
	if(!valid_userid(account_id) || !valid_userid(character_id) ||
	   profession_id==S1_HIDDEN_PROFESSION || completed_level<1)
		return result;
	test_bypass=getenv("XIAND_RUN_TESTUNIT")=="1" &&
		has_prefix(character_id,"xd99testunitzhgate") &&
		(int)player["/tmp/zhaoming_story_completion_test_ready"];
	if(!test_bypass){
		mapping story=SEASONALD->query_player_progress(player);
		if(!(int)story["ok"] || (int)story["chapter_claimed"]<81){
			result["message"] = "人物尚未真实领取完S1八十一章奖励。";
			return result;
		}
	}
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id,1);
	if(record){
		foreach((array)record["characters"],mapping entry){
			if((string)entry["id"]!=character_id)
				continue;
			if((string)entry["illusion_id"]!=illusion_id ||
			   (string)entry["illusion_state"]!="active" ||
			   (string)entry["desired_profession"]!=profession_id){
				result["message"] = "人物世界、职业与完成凭证不一致。";
				break;
			}
			if((int)entry["illusion_story_completed_at"]>0){
				if((string)entry["illusion_story_completed_profession"]==
				   profession_id)
					result = (["ok":1,"already":1,
						"message":"该人物的幻境职业完成凭证已经存在。"]) ;
				else
					result["message"] = "已有完成凭证与当前职业不一致。";
				break;
			}
			entry["illusion_story_completion_version"] = 1;
			entry["illusion_story_completed_at"] = time();
			entry["illusion_story_completed_profession"] = profession_id;
			entry["illusion_story_completed_level"] = completed_level;
			if(save_record_unlocked(record))
				result = (["ok":1,"already":0,
					"message":"本期幻境职业完成凭证已保存。"]) ;
			break;
		}
	}
	destruct(key);
	if((int)result["ok"] && !(int)result["already"]){
		int appended;
		mixed story_completion_log_err=catch{
			appended=Stdio.append_file(
				ROOT+"/log/illusion_hidden_profession.log",
				sprintf("%d|story_completion|illusion=%s|account=%s|character=%s|profession=%s|level=%d\n",
					time(),illusion_id,account_id,character_id,profession_id,
					completed_level));
		};
		// 账号索引已成功提交，审计文件只是附加证据；绝不能因目录只读
		// 或轮转竞争把成功结果翻成异常并阻断终章页面/下次登录。
		if(story_completion_log_err || !appended)
			werror("[ILLUSION_HIDDEN] 职业完成凭证已提交但审计日志写入失败: character=%s error=%s\n",
				character_id,story_completion_log_err ?
				describe_error(story_completion_log_err) :
				"append returned false");
	}
	return result;
}

/**
 * 为账号下指定人物签发一个可跨浏览器使用的长期直达书签。
 *
 * 磁盘只保存随机令牌摘要，以及令牌与当前账号密码共同生成的证明；既不
 * 保存原始令牌，也不保存可直接用于登录的TXD。修改账号密码会令旧证明
 * 自动失效。旧令牌在玩家明确撤销前继续可用，重复点击不会弄坏已收藏的
 * 老链接。
 */
mapping(string:mixed) create_character_bookmark(string account_id,
	string character_id,string account_password)
{
	mapping(string:mixed) result = ([
		"ok":0,"message":"直达书签创建失败。",
	]);
	mapping(string:mixed)|zero record;
	array(mapping(string:mixed)) bookmarks;
	string token = "";
	string token_digest = "";
	object key;
	if(!valid_userid(account_id) || !valid_userid(character_id) ||
	   !account_password || account_password=="" ||
	   !account_owns_character(account_id,character_id)){
		result["message"] = "人物不属于当前账号。";
		return result;
	}
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record && record_contains_character(record,character_id)){
		bookmarks = normalized_character_bookmarks(record);
		int same_character_count = 0;
		foreach(bookmarks,mapping entry)
			if((string)entry["character_id"]==character_id)
				same_character_count++;
		while(same_character_count>=
		      ACCOUNT_CHARACTER_BOOKMARK_PER_CHARACTER_LIMIT){
			int oldest = oldest_character_bookmark_index(bookmarks,
				character_id);
			if(oldest<0)
				break;
			bookmarks = remove_character_bookmark_at(bookmarks,oldest);
			same_character_count--;
		}
		while(sizeof(bookmarks)>=ACCOUNT_CHARACTER_BOOKMARK_LIMIT){
			int oldest = oldest_character_bookmark_index(bookmarks);
			if(oldest<0)
				break;
			bookmarks = remove_character_bookmark_at(bookmarks,oldest);
		}
		for(int attempt=0;attempt<10;attempt++){
			token = lower_case(String.string2hex(
				Crypto.Random.random_string(32)));
			token_digest = character_bookmark_digest(token);
			int duplicate = 0;
			foreach(bookmarks,mapping entry)
				if(constant_time_bookmark_equal(
				   (string)entry["token_digest"],token_digest)){
					duplicate = 1;
					break;
				}
			if(!duplicate)
				break;
			token = "";
		}
		if(token!=""){
			bookmarks += ({([
				"character_id":character_id,
				"token_digest":token_digest,
				"auth_proof":character_bookmark_auth_proof(
					token,account_password),
				"created_at":time(),
			])});
			record["character_bookmarks"] = bookmarks;
			if(save_record_unlocked(record))
				result = ([
					"ok":1,
					"message":"直达书签已创建。",
					"account_id":account_id,
					"character_id":character_id,
					"bookmark_token":token,
				]);
			else
				result["message"] = "账号书签保存失败，请稍后重试。";
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) verify_character_bookmark(string account_id,
	string character_id,string token,string account_password)
{
	mapping(string:mixed) result = ([
		"ok":0,"message":"直达书签无效或已撤销。",
	]);
	mapping(string:mixed)|zero record;
	string normalized_token = lower_case(token || "");
	string token_digest;
	string auth_proof;
	object key;
	if(!valid_userid(account_id) || !valid_userid(character_id) ||
	   !valid_bookmark_hex(normalized_token) ||
	   !account_password || account_password=="")
		return result;
	token_digest = character_bookmark_digest(normalized_token);
	auth_proof = character_bookmark_auth_proof(normalized_token,
		account_password);
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record && record_contains_character(record,character_id)){
		foreach(normalized_character_bookmarks(record),mapping entry){
			if((string)entry["character_id"]==character_id &&
			   constant_time_bookmark_equal(
				(string)entry["token_digest"],token_digest) &&
			   constant_time_bookmark_equal(
				(string)entry["auth_proof"],auth_proof)){
				result = ([
					"ok":1,
					"message":"",
					"account_id":account_id,
					"character_id":character_id,
				]);
				break;
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) revoke_character_bookmarks(string account_id,
	string character_id)
{
	mapping(string:mixed) result = ([
		"ok":0,"message":"直达书签撤销失败。","revoked":0,
	]);
	mapping(string:mixed)|zero record;
	array(mapping(string:mixed)) kept = ({});
	int revoked;
	object key;
	if(!valid_userid(account_id) || !valid_userid(character_id) ||
	   !account_owns_character(account_id,character_id)){
		result["message"] = "人物不属于当前账号。";
		return result;
	}
	key = account_character_lock->lock();
	record = load_record_unlocked(account_id);
	if(record && record_contains_character(record,character_id)){
		foreach(normalized_character_bookmarks(record),mapping entry){
			if((string)entry["character_id"]==character_id)
				revoked++;
			else
				kept += ({entry});
		}
		record["character_bookmarks"] = kept;
		if(!revoked || save_record_unlocked(record))
			result = ([
				"ok":1,"message":revoked ? "该人物的直达书签已全部撤销。" :
					"该人物当前没有可撤销的直达书签。",
				"revoked":revoked,
			]);
		else
			result["message"] = "账号书签保存失败，未执行撤销。";
	}
	destruct(key);
	return result;
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
		   has_value(({"zhenyue","tianxiang","lingyi","wuxiang","taiji",
			"wuji","wuxin"}),
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
	void|string requested_sex,void|string requested_avatar,
	void|string requested_realm_type,void|string requested_illusion_id)
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
	string realm_type = (string)(requested_realm_type || "eternal");
	string illusion_id = (string)(requested_illusion_id || "");
	string hidden_unlock_source = "";
	int hidden_unlock_fee = 0;
	int profile_requested = profile_name!="" || profile_sex!="" ||
		profile_avatar!="";
	int slot;
	object key;
	if(realm_type!="eternal" && realm_type!="illusion"){
		result["message"] = "人物世界类型无效。";
		return result;
	}
	if((realm_type=="illusion" && !valid_illusion_id(illusion_id)) ||
	   (realm_type=="eternal" && illusion_id!="")){
		result["message"] = "幻境编号无效。";
		return result;
	}
	if(!valid_profession_pair(race_id,profession_id)){
		result["message"] = "阵营与职业组合无效。";
		return result;
	}
	if(profession_id==S1_HIDDEN_PROFESSION && realm_type!="illusion"){
		result["message"] = "【照命·幻境限定】该职业只能在当期幻境中创建。";
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
		if(!(int)wu_data["ok"] || !(int)wu_data["wuxiang_unlocked"]){
			string missing = query_wuxiang_missing_from_summary(wu_data);
			result["message"] = "【无相·未解锁】需要账号下 10 个职业均达到 120 级，或共享账号累计捐赠达到"+
				WUXIANG_DONATION_UNLOCK_FEE+"元。当前成长缺口："+missing+
				"；当前累计捐赠："+(int)wu_data["donation_total"]+"元。";
			return result;
		}
		if((int)wu_data["wuxiang_unlock_by_donation"] &&
		   !query_wuxiang_unlocked_from_summary(wu_data)){
			hidden_unlock_source = "donation";
			hidden_unlock_fee = (int)wu_data["donation_total"];
		}
	}
	// 太极是无相之上的隐藏职业：账号下 10 个基础职业 + 无相，均需达到 200 级。
	if(profession_id=="taiji" && account_id!=""){
		mapping tj_data = query_account_characters(account_id);
		if(!(int)tj_data["ok"] || !(int)tj_data["taiji_unlocked"]){
			string missing = query_taiji_missing_from_summary(tj_data);
			result["message"] = "【太极·未解锁】需要账号下 10 职业与无相均达到 200 级，或共享账号累计捐赠达到"+
				TAIJI_DONATION_UNLOCK_FEE+"元。当前成长缺口："+missing+
				"；当前累计捐赠："+(int)tj_data["donation_total"]+"元。";
			return result;
		}
		if((int)tj_data["taiji_unlock_by_donation"] &&
		   !query_taiji_unlocked_from_summary(tj_data)){
			hidden_unlock_source = "donation";
			hidden_unlock_fee = (int)tj_data["donation_total"];
		}
	}
	// 无极是终极隐藏职业：须照命>=300级且已购买创建资格。
	if(profession_id=="wuji" && account_id!=""){
		mapping wj_data = query_account_characters(account_id);
		if(!query_wuji_unlocked_from_summary(
			mappingp(wj_data) ? wj_data : (["ok":0]))){
			result["message"] = "【无极·未解锁】需要账号下照命角色达到"+
				WUJI_REQUIRED_LEVEL+"级。";
			return result;
		}
		if(!(int)wj_data["wuji_entitled"]){
			result["message"] = "【无极·未付费】创建无极需先支付"+
				WUJI_CREATION_COST+"碎玉购买创建资格。";
			return result;
		}
	}
	// 无心是账号终极隐藏职业：无极全难度通关且已购买创建资格。
	if(profession_id=="wuxin" && account_id!=""){
		mapping xn_data = query_account_characters(account_id);
		if(!query_wuxin_unlocked_from_summary(
			mappingp(xn_data) ? xn_data : (["ok":0]))){
			result["message"] = "【无心·未解锁】需要账号下无极角色通关全部个人挑战难度。";
			return result;
		}
		if(!(int)xn_data["wuxin_entitled"]){
			result["message"] = "【无心·未付费】创建无心需先支付"+
				WUXIN_CREATION_COST+"碎玉购买创建资格。";
			return result;
		}
	}
	if(profession_id==S1_HIDDEN_PROFESSION && account_id!=""){
		mapping hidden_data = query_account_characters(account_id,illusion_id);
		mapping hidden_status = query_s1_hidden_unlock_from_summary(
			hidden_data,illusion_id);
		if(!(int)hidden_status["unlocked"]){
			result["message"] = (string)hidden_status["message"];
			return result;
		}
	}
	if(!valid_userid(account_id)){
		result["message"] = "账号无效。";
		return result;
	}
	key = account_character_lock->lock();
	// 建角由协调器处理，但资格可能刚由地图Worker写入。
	record = load_record_unlocked(account_id,1);
	if(!record)
		result["message"] = "原账号人物档案不存在。";
	else if(sizeof((array)record["characters"])>=ACCOUNT_CHARACTER_LIMIT)
		result["message"] = "人物档案已达到"+
			ACCOUNT_CHARACTER_LIMIT+"个上限。";
	else{
		if(realm_type=="illusion"){
			if(!mappingp(record["illusion_entitlement"]) ||
			   !sizeof(illusion_entitlement_for_cycle(
				(mapping)record["illusion_entitlement"],illusion_id))){
				result["message"] = "账号尚未登记"+
					illusion_id+"赛季资格。";
				destruct(key);
				return result;
			}
			int illusion_count = 0;
			foreach((array)record["characters"],mapping existing_entry)
				if((string)existing_entry["illusion_id"]==illusion_id)
					illusion_count++;
			mapping entitlement = record["illusion_entitlement"];
			mapping expansion = illusion_expansion_state(entitlement,
				illusion_id,illusion_count);
			int illusion_capacity=(int)expansion["character_slots"];
			if(illusion_capacity<0 || illusion_capacity>ACCOUNT_CHARACTER_LIMIT ||
			   illusion_count>=illusion_capacity){
				result["message"] = "本期幻境人物栏位已用完（"+
					illusion_count+"/"+illusion_capacity+
					"）；每个赛季人物都需要100碎玉栏位，也可一次购买5格。";
				destruct(key);
				return result;
			}
		}
		if(profession_id==S1_HIDDEN_PROFESSION){
			array hidden_summaries = ({});
			int hidden_count = 0;
			foreach((array)record["characters"],mapping existing_entry){
				mapping one_summary = profile_summary_unlocked(account_id,
					existing_entry);
				hidden_summaries += ({one_summary});
				if((string)one_summary["profession_id"]==
				   S1_HIDDEN_PROFESSION &&
				   (string)one_summary["illusion_id"]==illusion_id)
					hidden_count++;
			}
			mapping locked_hidden = query_s1_hidden_unlock_from_summary(([
				"ok":1,"characters":hidden_summaries,
			]),illusion_id);
			if(!(int)locked_hidden["unlocked"] || hidden_count>0){
				result["message"] = hidden_count>0 ?
					"【照命·人物上限】同一账号每期幻境只能创建一个照命。" :
					(string)locked_hidden["message"];
				destruct(key);
				return result;
			}
		}
		mapping profession_limit_state =
			profession_limit_state_from_record(record,profession_id);
		int profession_limit =
			(int)profession_limit_state["current_limit"];
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
				"·人物上限】已创建"+profession_count+"个，当前可创建上限"+
				profession_limit+"个（最高"+
				HIDDEN_PROFESSION_MAX_CHARACTERS+
				"个）；请先在人物中心购买下一格。";
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
							"realm_type":realm_type,
						]);
						if(realm_type=="illusion"){
							entry["illusion_id"] = illusion_id;
							entry["illusion_state"] = "active";
							entry["illusion_joined_at"] = time();
						}
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
	if((int)result["ok"] && hidden_unlock_source=="donation"){
		string now = ctime(time());
		int threshold = query_hidden_profession_donation_threshold(
			profession_id);
		Stdio.append_file(ROOT+"/log/hidden_profession_unlock.log",
			now[0..sizeof(now)-2]+" account="+account_id+
			" character="+character_id+" profession="+profession_id+
			" source=donation total_fee="+hidden_unlock_fee+
			" threshold="+threshold+"\n");
		result["unlock_source"] = "donation";
		result["donation_total"] = hidden_unlock_fee;
	}
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
				"\n同一人物重新登录或账号在线人数已满，当前人物已安全退出。\n"+
				"如需更多同时在线人物，可用[online_expand]付费扩充在线上限。\n");
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
	if(search(account_id,"testunit")==-1 || !valid_userid(account_id))
		return;
	key = account_character_lock->lock();
	m_delete(account_cache,account_id);
	destruct(key);
}

// 只供 TestUnit 模拟两个 Worker 同时持有同一账号旧快照。
mapping(string:mixed) test_account_revision_conflict_guard(string account_id)
{
	mapping(string:mixed) result = ([
		"first_saved":0,"stale_rejected":0,"marker":"","revision":-1,
	]);
	mapping(string:mixed)|zero first;
	mapping(string:mixed)|zero stale;
	mapping(string:mixed)|zero final_record;
	object key;
	if(getenv("XIAND_RUN_TESTUNIT")!="1" ||
	   search(account_id,"testunit")==-1)
		return result;
	key = account_character_lock->lock();
	first = load_persisted_record_unlocked(account_id,1);
	if(first){
		stale = copy_value(first);
		first["test_revision_marker"] = "first";
		result["first_saved"] = save_record_unlocked(first);
		if((int)result["first_saved"] && stale){
			stale["test_revision_marker"] = "stale";
			result["stale_rejected"] = !save_record_unlocked(stale);
			final_record = load_persisted_record_unlocked(account_id,1);
		}
	}
	if(final_record){
		result["marker"] = (string)final_record["test_revision_marker"];
		result["revision"] = (int)final_record["revision"];
	}
	destruct(key);
	return result;
}

//只供TestUnit验证配置在单开/多开之间切换，不对游戏命令或HTTP开放。
void set_test_online_limit(string account_id,int limit)
{
	object key;
	if(search(account_id,"testunit")==-1 || !valid_userid(account_id))
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
	string file_base;
	mapping(string:mixed)|zero record;
	object key;
	object state_key;
	object table_key;
	if(search(account_id,"testunit")==-1 || !valid_userid(account_id))
		return;
	Stdio.recursive_rm(DELETED_CHARACTER_DIR+"/"+
		account_id[sizeof(account_id)-2..]+"/"+account_id);
	key = account_character_lock->lock();
	path = account_file_path(account_id);
	file_base = (path/"/")[-1];
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
	rm(path+".lock");
	foreach(get_dir(dirname(path)) || ({}),string filename)
		if(has_prefix(filename,file_base+".tmp.") ||
		   has_prefix(filename,file_base+".bak.tmp."))
			rm(dirname(path)+"/"+filename);
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
