#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define DIFFICULTY_ROOT "/plus/personal_difficulty"
#define DIFFICULTY_MAX_LEVEL 7
#define DIFFICULTY_SWITCH_COOLDOWN 60
#define DIFFICULTY_SCOPE_CACHE "/tmp/personal_difficulty_scope"
#define DIFFICULTY_SCOPE_UNAVAILABLE "__unavailable"
#define DIFFICULTY_SCOPE_RETRY_AT "/tmp/personal_difficulty_scope_retry_at"
#define DIFFICULTY_SCOPE_RETRY_SECONDS 60

// 回收变态装备后的平衡重建：基础档怪物血量等效10%（输出1000%=
// 怪死快10倍）、承伤10%；问道恢复正常（输出100%+承伤100%）；
// 之后每档怪血翻倍（输出减半）；承伤改每档递增50，避免高档被秒。
private array(mapping(string:mixed)) difficulty_catalog=({
	(["id":"base","name":"基础","min_level":1,"kills":0,"bosses":0,
		"outgoing_percent":100,"incoming_percent":1,
		"set_drop_percent":100,"afk_cap_hours":24,
		"exp_percent":100,"rare_drop_percent":100]),
	(["id":"wendao","name":"问道","min_level":70,"kills":20000,"bosses":50,
		"outgoing_percent":100,"incoming_percent":100,
		"set_drop_percent":200,"afk_cap_hours":16,
		"exp_percent":200,"rare_drop_percent":200]),
	(["id":"ningzhen","name":"凝真","min_level":100,"kills":50000,"bosses":120,
		"outgoing_percent":50,"incoming_percent":150,
		"set_drop_percent":400,"afk_cap_hours":14,
		"exp_percent":400,"rare_drop_percent":400]),
	(["id":"pojing","name":"破境","min_level":130,"kills":100000,"bosses":250,
		"outgoing_percent":25,"incoming_percent":200,
		"set_drop_percent":800,"afk_cap_hours":12,
		"exp_percent":800,"rare_drop_percent":800]),
	(["id":"tongxuan","name":"通玄","min_level":160,"kills":180000,"bosses":450,
		"outgoing_percent":12,"incoming_percent":250,
		"set_drop_percent":1600,"afk_cap_hours":10,
		"exp_percent":1600,"rare_drop_percent":1600]),
	(["id":"dengxian","name":"登仙","min_level":190,"kills":280000,"bosses":700,
		"outgoing_percent":6,"incoming_percent":300,
		"set_drop_percent":3200,"afk_cap_hours":8,
		"exp_percent":3200,"rare_drop_percent":3200]),
	(["id":"lingxiao","name":"凌霄","min_level":220,"kills":400000,"bosses":1000,
		"outgoing_percent":3,"incoming_percent":350,
		"set_drop_percent":6400,"afk_cap_hours":6,
		"exp_percent":6400,"rare_drop_percent":6400]),
	(["id":"tianjie","name":"天劫","min_level":250,"kills":600000,"bosses":1500,
		"outgoing_percent":2,"incoming_percent":400,
		"set_drop_percent":12800,"afk_cap_hours":4,
		"exp_percent":12800,"rare_drop_percent":12800]),
});

// 首领指引目录：永恒服中可稳定找到的首领级(_boss)NPC 及其位置。
// 计数规则：首领必须在永恒服击杀，且等级不低于人物等级-10；
// 普通挂机猎场不刷首领，必须按此目录前往首领所在地图。
private array(mapping(string:mixed)) boss_registry=({
	(["name":"残忍年兽","level":100,"location":"新年副本·破三之地"]),
	(["name":"万象妖皇","level":110,"location":"从贤镇·万象林"]),
	(["name":"归墟魔君","level":120,"location":"金鳌岛·归墟境"]),
	(["name":"霸王至尊","level":150,"location":"霸王堡·王者圣殿"]),
	(["name":"广成子","level":400,"location":"十二仙景·九仙山"]),
	(["name":"惧留孙","level":400,"location":"十二仙景·夹龙山"]),
	(["name":"道行天尊","level":400,"location":"十二仙景·金庭山"]),
	(["name":"灵宝大法师","level":400,"location":"十二仙景·崆峒山"]),
	(["name":"慈航道人","level":400,"location":"十二仙景·普陀山"]),
	(["name":"赤精子","level":400,"location":"十二仙景·太华山"]),
	(["name":"文殊广法天尊","level":400,"location":"十二仙景·五龙山"]),
	(["name":"黄龙真人","level":400,"location":"十二仙景·二仙山"]),
	(["name":"赵公明","level":400,"location":"金鳌岛·玉化村广场"]),
	(["name":"王天君","level":400,"location":"金鳌岛·十君殿"]),
	(["name":"福寿仙翁","level":400,"location":"昆仑山·玉虚宫"]),
	(["name":"太乙真人","level":400,"location":"昆仑山·玉虚宫后亭"]),
	(["name":"姬旦","level":400,"location":"牧野·会仙驿站"]),
	(["name":"董天君","level":400,"location":"牧野·栖贤驿站"]),
	(["name":"南海龙王","level":400,"location":"南海·南海龙宫"]),
	(["name":"南海王妃","level":400,"location":"南海·得宝偏厅"]),
	(["name":"龙须虎","level":400,"location":"北海·北海龙宫"]),
	(["name":"道德真君","level":400,"location":"从贤镇·从贤镇广场"]),
	(["name":"原始天尊","level":999,"location":"昆仑山·玉虚宫"]),
	(["name":"通天教主","level":999,"location":"金鳌岛·碧游宫"]),
});

/** 首领指引：按人物等级过滤出当前可计数的首领与位置。 */
string query_boss_guidance(object player)
{
	array(mapping(string:mixed)) eligible=({});
	string out;
	int min_level;
	if(!player || !functionp(player->query_level))
		return "";
	min_level=max(1,(int)player->query_level()-10);
	foreach(boss_registry,mapping(string:mixed) one)
		if((int)one["level"]>=min_level)
			eligible+=({one});
	if(!sizeof(eligible))
		return "";
	out="首领指引（普通挂机猎场不刷首领；只计永恒服中等级不低于"+
		"你人物等级-10的首领）：\n";
	foreach(eligible,mapping(string:mixed) one)
		out+="· "+(string)one["name"]+"（Lv"+(int)one["level"]+
			"）"+(string)one["location"]+"\n";
	return out;
}

private int valid_scope_id(string value)
{
	if(value=="eternal")
		return 1;
	if(!value || sizeof(value)<2 || sizeof(value)>16)
		return 0;
	foreach(value;int index;int one)
		if(!((one>='A' && one<='Z') || (one>='0' && one<='9') ||
		   one=='_'))
			return 0;
	return 1;
}

private int valid_cached_scope(string value)
{
	return value==DIFFICULTY_SCOPE_UNAVAILABLE || valid_scope_id(value);
}

private int bounded_level(int level)
{
	return level>=0 && level<=DIFFICULTY_MAX_LEVEL ? level : 0;
}

mapping(string:mixed) query_tier(int level)
{
	return copy_value(difficulty_catalog[bounded_level(level)]);
}

array(mapping(string:mixed)) query_catalog()
{
	return copy_value(difficulty_catalog);
}

/**
 * Difficulty belongs to one world progression, not to the whole account.
 * Eternal keeps the old top-level path for rollback compatibility; each
 * seasonal cycle writes below scopes/<cycle>.  The session cache prevents a
 * shared account-index read on every combat hit.
 */
string refresh_player_scope(object player)
{
	string scope=DIFFICULTY_SCOPE_UNAVAILABLE;
	mapping realm=([]);
	mixed realm_err;
	if(!player || !functionp(player->query_name))
		return "eternal";
	// 世界归属是难度的附加作用域。账号索引瞬时异常或旧返回类型不能
	// 顺着普攻、技能、掉落与挂机额度查询进入核心链；失败时只把本次
	// 会话缓存为独立中性作用域，赛季隔离仍由 SEASONALD 独立校验。
	realm_err=catch{
		realm=ACCOUNT_CHARACTERD->query_character_realm(
			(string)player->query_name());
	};
	if(realm_err || !mappingp(realm)){
		werror("[PERSONAL_DIFFICULTY] 世界归属读取异常，难度回退基础作用域: user=%s error=%s\n",
			(string)player->query_name(),realm_err ?
			describe_error(realm_err) : "invalid realm result");
		// 不得伪装成永恒服，否则 S1 人物可能读取或累计永恒难度进度。
		// 独立中性作用域没有解锁记录，所有数值自然回到基础档。
		realm=([]);
	}
	// 只接受账号索引明确证明的两个世界。ok=0、security_blocked、
	// 未知类型、非active幻境或非法周期编号都保持中性，绝不猜成永恒服。
	else if((int)realm["ok"] && !(int)realm["security_blocked"] &&
	   (string)realm["realm_type"]=="eternal")
		scope="eternal";
	else if((int)realm["ok"] && !(int)realm["security_blocked"] &&
	   (string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active" &&
	   valid_scope_id((string)realm["illusion_id"]))
		scope=(string)realm["illusion_id"];
	player[DIFFICULTY_SCOPE_CACHE]=scope;
	player[DIFFICULTY_SCOPE_RETRY_AT]=
		scope==DIFFICULTY_SCOPE_UNAVAILABLE ? time() : 0;
	return scope;
}

string query_scope(object player)
{
	string cached;
	if(!player)
		return "eternal";
	cached=(string)(player[DIFFICULTY_SCOPE_CACHE] || "");
	// 临时故障不能把玩家永久钉在中性档；每分钟至多重查一次账号索引，
	// 避免战斗热路径反复访问共享档案或刷日志。
	if(cached==DIFFICULTY_SCOPE_UNAVAILABLE &&
	   time()-(int)player[DIFFICULTY_SCOPE_RETRY_AT]>=
		DIFFICULTY_SCOPE_RETRY_SECONDS)
		return refresh_player_scope(player);
	return valid_cached_scope(cached) ? cached : refresh_player_scope(player);
}

string query_scope_name(object player)
{
	string scope=query_scope(player);
	if(scope==DIFFICULTY_SCOPE_UNAVAILABLE)
		return "世界归属校验中";
	return scope=="eternal" ? "永恒服" : scope+"幻境";
}

private string difficulty_root_for(object player)
{
	string scope=query_scope(player);
	return scope=="eternal" ? DIFFICULTY_ROOT :
		DIFFICULTY_ROOT+"/scopes/"+scope;
}

private int claimed_season_chapters(object player,string scope)
{
	mapping progress;
	mapping claims;
	int claimed;
	if(!player || scope=="eternal")
		return 0;
	progress=player["/plus/illusion_realm/"+scope];
	claims=mappingp(progress) && mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	for(int chapter=1;chapter<=81;chapter++){
		if(!(int)claims[scope+"-C"+(string)chapter])
			break;
		claimed++;
	}
	return claimed;
}

private int claimed_season_mastery_chapters(object player,string scope,
	int difficulty_level)
{
	mapping progress;
	mapping claims;
	mapping mastery;
	int claimed;
	if(!player || scope=="eternal")
		return 0;
	progress=player["/plus/illusion_realm/"+scope];
	claims=mappingp(progress) && mappingp(progress["claims"]) ?
		(mapping)progress["claims"] : ([]);
	mastery=mappingp(progress) && mappingp(progress["difficulty_chapters"]) ?
		(mapping)progress["difficulty_chapters"] : ([]);
	// 上线前已完成章回的旧档没有逐章难度证据。只为基础档补认最多
	// 九章，让其可以解锁问道一次；绝不据此连续补开后续六档。
	if(!sizeof(mastery) && difficulty_level==0)
		return min(9,claimed_season_chapters(player,scope));
	for(int chapter=1;chapter<=81;chapter++){
		string chapter_id=scope+"-C"+(string)chapter;
		if(!(int)claims[chapter_id])
			break;
		if(has_index(mastery,chapter_id) &&
		   intp(mastery[chapter_id]) &&
		   (int)mastery[chapter_id]==difficulty_level)
			claimed++;
	}
	return claimed;
}

int set_scope_for_test(object player,string scope)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !player ||
	   !valid_scope_id(scope))
		return 0;
	player[DIFFICULTY_SCOPE_CACHE]=scope;
	return 1;
}

int query_current_level(object player)
{
	int current;
	int unlocked;
	string root;
	if(!player)
		return 0;
	root=difficulty_root_for(player);
	current=bounded_level((int)player[root+"/current"]);
	unlocked=bounded_level((int)player[root+"/unlocked"]);
	return current<=unlocked ? current : 0;
}

int query_unlocked_level(object player)
{
	if(!player)
		return 0;
	return bounded_level((int)player[difficulty_root_for(player)+"/unlocked"]);
}

string query_current_name(object player)
{
	return (string)difficulty_catalog[query_current_level(player)]["name"];
}

int query_afk_cap_hours(object player)
{
	return (int)difficulty_catalog[query_current_level(player)]
		["afk_cap_hours"];
}

int scale_afk_daily_seconds(object player,int base_seconds)
{
	int cap_hours;
	int tier_seconds;
	if(base_seconds<=0)
		return 0;
	cap_hours=query_afk_cap_hours(player);
	tier_seconds=cap_hours*3600;
	// 挂机额度 = min(VIP额度, 难度上限)。VIP8基础20小时，
	// 不会因切难度获得超出该难度的额度；低VIP也不会被放大。
	if(base_seconds>tier_seconds)
		return tier_seconds;
	return base_seconds;
}

int query_outgoing_percent(object player)
{
	return (int)difficulty_catalog[query_current_level(player)]
		["outgoing_percent"];
}

int query_incoming_percent(object player)
{
	return (int)difficulty_catalog[query_current_level(player)]
		["incoming_percent"];
}

int query_set_drop_percent(object player)
{
	return (int)difficulty_catalog[query_current_level(player)]
		["set_drop_percent"];
}

int query_set_drop_percent_for_level(int level)
{
	return (int)difficulty_catalog[bounded_level(level)]["set_drop_percent"];
}

int query_exp_percent(object player)
{
	return (int)difficulty_catalog[query_current_level(player)]
		["exp_percent"];
}

int query_rare_drop_percent(object player)
{
	return (int)difficulty_catalog[query_current_level(player)]
		["rare_drop_percent"];
}

int query_rare_drop_percent_for_level(int level)
{
	return (int)difficulty_catalog[bounded_level(level)]
		["rare_drop_percent"];
}

/**
 * 契印是 S1 的可选附加系统，任何旧档、坏档或守护进程异常都必须回到
 * 中性倍率，不能中断全服共用的物理/法术伤害主链。正常合法值逐字传回，
 * 因而不改变既有难度或契印数值。
 */
private mapping(string:int) safe_pact_combat_modifiers(object player)
{
	mapping result=([]);
	mixed err=catch{
		result=ILLUSION_JOURNEYD->query_pact_combat_modifiers(player);
	};
	if(err || !mappingp(result) ||
	   !intp(result["outgoing_percent"]) ||
	   !intp(result["incoming_percent"]) ||
	   (int)result["outgoing_percent"]<85 ||
	   (int)result["outgoing_percent"]>115 ||
	   (int)result["incoming_percent"]<85 ||
	   (int)result["incoming_percent"]>120)
		return (["outgoing_percent":100,"incoming_percent":100]);
	return (["outgoing_percent":(int)result["outgoing_percent"],
		"incoming_percent":(int)result["incoming_percent"]]);
}

int scale_pve_damage(object attacker,object target,int damage)
{
	object credit_owner;
	mapping pact;
	int scaled;
	if(damage<=0 || !attacker || !target ||
	   !functionp(attacker->is) || !functionp(target->is))
		return damage;
	credit_owner=attacker;
	if(attacker->is("npc") && functionp(SUMMOND->query_combat_credit_owner))
		credit_owner=SUMMOND->query_combat_credit_owner(attacker) || attacker;
	if(credit_owner && functionp(credit_owner->is) &&
	   credit_owner->is("player") && target->is("npc")){
		scaled = max(1,damage*query_outgoing_percent(credit_owner)/100);
		if(query_scope(credit_owner)=="S1"){
			pact = safe_pact_combat_modifiers(credit_owner);
			scaled = max(1,scaled*(int)pact["outgoing_percent"]/100);
		}
		return scaled;
	}
	if(attacker->is("npc") && target->is("player")){
		scaled = max(1,damage*query_incoming_percent(target)/100);
		if(query_scope(target)=="S1"){
			pact = safe_pact_combat_modifiers(target);
			scaled = max(1,scaled*(int)pact["incoming_percent"]/100);
		}
		// 平衡过渡期：直接读JSON（Worker不预加载守护进程）。
		mixed transition_err=catch{
			string raw=Stdio.read_file(ROOT+
				"/data_xiand/balance_transition.json");
			int attack_percent=100;
			if(raw && sizeof(raw)){
				mapping record=Standards.JSON.decode(raw);
				if(mappingp(record)){
					attack_percent=(int)record["attack_percent"];
				}
			}
			if(attack_percent>=10 && attack_percent<=200)
				scaled=max(1,scaled*attack_percent/100);
		};
		if(transition_err)
			werror("[BALANCE_TRANSITION] attack scale failed\n");
		return scaled;
	}
	// 玩家互斗、召唤物PVP与NPC互斗全部保持原公式。
	return damage;
}

private mapping(string:int) query_progress_mapping(object player)
{
	mapping progress;
	string root;
	if(!player)
		return ([]);
	root=difficulty_root_for(player);
	progress=player[root+"/progress"];
	if(!mappingp(progress)){
		progress=(["kills":0,"bosses":0]);
		player[root+"/progress"]=progress;
	}
	return progress;
}

mapping(string:mixed) query_unlock_progress(object player)
{
	string scope=query_scope(player);
	if(scope==DIFFICULTY_SCOPE_UNAVAILABLE)
		return (["complete":0,"maxed":0,"unavailable":1,
			"scope":scope,"scope_name":"世界归属校验中",
			"mode":"unavailable","next_level":-1,
			"message":"世界归属暂不可验证，难度进度保持原样，请稍后重试。"]);
	int unlocked=query_unlocked_level(player);
	int next=unlocked+1;
	mapping progress=query_progress_mapping(player);
	if(next>DIFFICULTY_MAX_LEVEL)
		return (["complete":1,"maxed":1,"next_level":-1,
			"scope":scope,"scope_name":query_scope_name(player),
			"kills":(int)progress["kills"],
			"bosses":(int)progress["bosses"]]);
	mapping tier=difficulty_catalog[next];
	int level=player && functionp(player->query_level) ?
		(int)player->query_level() : 0;
	if(scope!="eternal"){
		int chapters=claimed_season_chapters(player,scope);
		int mastery_chapters=claimed_season_mastery_chapters(player,scope,
			unlocked);
		return ([
			"complete":mastery_chapters>=9,"maxed":0,
			"scope":scope,"scope_name":query_scope_name(player),
			"mode":"season_mastery","next_level":next,
			"next_name":tier["name"],"chapters":chapters,
			"mastery_level":unlocked,
			"mastery_name":difficulty_catalog[unlocked]["name"],
			"mastery_chapters":mastery_chapters,"mastery_required":9,
		]);
	}
	return ([
		"complete":level>=(int)tier["min_level"] &&
			(int)progress["kills"]>=(int)tier["kills"] &&
			(int)progress["bosses"]>=(int)tier["bosses"],
		"maxed":0,"scope":scope,"scope_name":query_scope_name(player),
		"mode":"kills","next_level":next,"next_name":tier["name"],
		"level":level,"min_level":tier["min_level"],
		"kills":(int)progress["kills"],"kills_required":tier["kills"],
		"bosses":(int)progress["bosses"],"bosses_required":tier["bosses"],
	]);
}

void record_npc_kill(object player,object npc)
{
	int unlocked;
	int next;
	mapping progress;
	mapping tier;
	if(!player || !npc || !player->is("player") || !npc->is("npc") ||
	   query_scope(player)!="eternal")
		return;
	unlocked=query_unlocked_level(player);
	next=unlocked+1;
	if(next>DIFFICULTY_MAX_LEVEL || query_current_level(player)!=unlocked)
		return;
	tier=difficulty_catalog[next];
	if(player->query_level()<(int)tier["min_level"] ||
	   npc->query_level()<max(1,player->query_level()-10) ||
	   player->get_cur_life()<=0)
		return;
	progress=query_progress_mapping(player);
	if((int)progress["kills"]<(int)tier["kills"])
		progress["kills"]=(int)progress["kills"]+1;
	if(npc->_boss && (int)progress["bosses"]<(int)tier["bosses"])
		progress["bosses"]=(int)progress["bosses"]+1;
}

mapping(string:mixed) claim_next_tier(object player)
{
	mapping progress=query_unlock_progress(player);
	mapping old_progress;
	int old_unlocked;
	string root;
	if(!player)
		return (["ok":0,"message":"当前人物无效，不能解锁难度。"]) ;
	if((int)progress["unavailable"])
		return (["ok":0,"message":(string)progress["message"]]);
	if((int)progress["maxed"])
		return (["ok":0,"message":"你已经解锁全部个人挑战难度。"]);
	if(query_current_level(player)!=query_unlocked_level(player))
		return (["ok":0,"message":"请先切回当前已解锁的最高难度，再完成并领取破界试炼。"]);
	if(!(int)progress["complete"])
		return (["ok":0,"message":"破界试炼尚未完成。"]);
	old_unlocked=query_unlocked_level(player);
	old_progress=copy_value(query_progress_mapping(player));
	root=difficulty_root_for(player);
	player[root+"/unlocked"]=(int)progress["next_level"];
	player[root+"/progress"]=([]);
	if(!player->save_with_result()){
		player[root+"/unlocked"]=old_unlocked;
		player[root+"/progress"]=old_progress;
		return (["ok":0,"message":"难度解锁保存失败，请稍后重试。"]);
	}
	return (["ok":1,"level":(int)progress["next_level"],
		"message":"已为"+(string)progress["scope_name"]+
			"永久解锁【"+(string)progress["next_name"]+"】难度。"]);
}

private int is_safe_switch_room(object player)
{
	object room;
	string path;
	if(!player || !(room=environment(player)))
		return 0;
	path=(file_name(room)/"#")[0];
	if(functionp(room->query_room_type) && room->query_room_type()=="city")
		return 1;
	return search(({
		ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang",
		ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang",
		ROOT+"/gamelib/d/jadhuanjingwaicheng/yuhuacunguangchang",
		ROOT+"/gamelib/d/illusion_s1/moon_gate.pike",
		ROOT+"/gamelib/d/illusion_s1/moon_gate",
	}),path)!=-1;
}

mapping(string:mixed) switch_tier(object player,int target_level)
{
	int old_level;
	int old_last_switch;
	int last_switch;
	string root;
	if(!player || target_level<0 || target_level>DIFFICULTY_MAX_LEVEL)
		return (["ok":0,"message":"无效的挑战难度。"]);
	if(query_scope(player)==DIFFICULTY_SCOPE_UNAVAILABLE)
		return (["ok":0,"message":"世界归属暂不可验证，原难度保持不变，请稍后重试。"]) ;
	if(target_level>query_unlocked_level(player))
		return (["ok":0,"message":"该难度尚未通过破界试炼解锁。"]);
	old_level=query_current_level(player);
	if(old_level==target_level)
		return (["ok":1,"already":1,"level":old_level,
			"message":"当前已经是【"+query_current_name(player)+"】难度。"]);
	// in_combat 是战斗继承层的私有字段；跨对象直读在不同编译路径下
	// 可能得到未定义值。只使用公开查询接口，确保所有职业真实交战时
	// 都不能切换倍率、掉率和挂机上限。
	if(functionp(player->query_in_combat) && player->query_in_combat())
		return (["ok":0,"message":"战斗中不能切换个人挑战难度。"]);
	if(functionp(player->query_autofight) &&
	   player->query_autofight()=="enable")
		return (["ok":0,"message":"请先停止自动挂机再切换难度。"]);
	if(!is_safe_switch_room(player))
		return (["ok":0,"message":"只能在主城或幻境集结入口切换难度。"]);
	root=difficulty_root_for(player);
	last_switch=(int)player[root+"/last_switch"];
	if(last_switch>0 && time()-last_switch<DIFFICULTY_SWITCH_COOLDOWN)
		return (["ok":0,"message":"难度契约正在稳定，请稍后再切换。"]);
	old_last_switch=(int)player[root+"/last_switch"];
	player[root+"/current"]=target_level;
	player[root+"/last_switch"]=time();
	if(!player->save_with_result()){
		player[root+"/current"]=old_level;
		player[root+"/last_switch"]=old_last_switch;
		return (["ok":0,"message":"难度切换保存失败，原设置保持不变。"]);
	}
	return (["ok":1,"level":target_level,
		"message":query_scope_name(player)+"个人挑战难度已切换为【"+
			(string)difficulty_catalog[target_level]["name"]+"】。"]);
}

mapping(string:mixed) query_status(object player)
{
	int current=query_current_level(player);
	int unlocked=query_unlocked_level(player);
	return (["scope":query_scope(player),
		"scope_name":query_scope_name(player),
		"current_level":current,"unlocked_level":unlocked,
		"current":query_tier(current),"progress":query_unlock_progress(player)]);
}
