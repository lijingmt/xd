#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define DIFFICULTY_ROOT "/plus/personal_difficulty"
#define DIFFICULTY_MAX_LEVEL 7
#define DIFFICULTY_SWITCH_COOLDOWN 60
#define DIFFICULTY_SCOPE_CACHE "/tmp/personal_difficulty_scope"

// 基础模式逐项保持线上公式。七档挑战只通过统一边界应用增量倍率，
// 任何非法或旧存档值都会失败关闭到基础模式。
private array(mapping(string:mixed)) difficulty_catalog=({
	(["id":"base","name":"基础","min_level":1,"kills":0,"bosses":0,
		"outgoing_percent":100,"incoming_percent":100,
		"set_drop_percent":100,"afk_cap_hours":24]),
	(["id":"wendao","name":"问道","min_level":70,"kills":100,"bosses":3,
		"outgoing_percent":95,"incoming_percent":108,
		"set_drop_percent":112,"afk_cap_hours":16]),
	(["id":"ningzhen","name":"凝真","min_level":100,"kills":150,"bosses":5,
		"outgoing_percent":90,"incoming_percent":118,
		"set_drop_percent":125,"afk_cap_hours":14]),
	(["id":"pojing","name":"破境","min_level":130,"kills":200,"bosses":8,
		"outgoing_percent":85,"incoming_percent":130,
		"set_drop_percent":140,"afk_cap_hours":12]),
	(["id":"tongxuan","name":"通玄","min_level":160,"kills":300,"bosses":12,
		"outgoing_percent":80,"incoming_percent":145,
		"set_drop_percent":160,"afk_cap_hours":10]),
	(["id":"dengxian","name":"登仙","min_level":190,"kills":400,"bosses":16,
		"outgoing_percent":75,"incoming_percent":162,
		"set_drop_percent":185,"afk_cap_hours":8]),
	(["id":"lingxiao","name":"凌霄","min_level":220,"kills":600,"bosses":20,
		"outgoing_percent":70,"incoming_percent":182,
		"set_drop_percent":215,"afk_cap_hours":6]),
	(["id":"tianjie","name":"天劫","min_level":250,"kills":800,"bosses":30,
		"outgoing_percent":65,"incoming_percent":205,
		"set_drop_percent":250,"afk_cap_hours":4]),
});

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
	string scope="eternal";
	if(!player || !functionp(player->query_name))
		return scope;
	mapping realm=ACCOUNT_CHARACTERD->query_character_realm(
		(string)player->query_name());
	if((int)realm["ok"] && !(int)realm["security_blocked"] &&
	   (string)realm["realm_type"]=="illusion" &&
	   (string)realm["illusion_state"]=="active" &&
	   valid_scope_id((string)realm["illusion_id"]))
		scope=(string)realm["illusion_id"];
	player[DIFFICULTY_SCOPE_CACHE]=scope;
	return scope;
}

private string query_scope(object player)
{
	string cached;
	if(!player)
		return "eternal";
	cached=(string)(player[DIFFICULTY_SCOPE_CACHE] || "");
	return valid_scope_id(cached) ? cached : refresh_player_scope(player);
}

string query_scope_name(object player)
{
	string scope=query_scope(player);
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
	if(base_seconds<=0)
		return 0;
	cap_hours=query_afk_cap_hours(player);
	// 以VIP8的24小时为100%同比缩放，低VIP不会因切难度获得额度。
	return base_seconds*cap_hours/24;
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

int scale_pve_damage(object attacker,object target,int damage)
{
	object credit_owner;
	if(damage<=0 || !attacker || !target ||
	   !functionp(attacker->is) || !functionp(target->is))
		return damage;
	credit_owner=attacker;
	if(attacker->is("npc") && functionp(SUMMOND->query_combat_credit_owner))
		credit_owner=SUMMOND->query_combat_credit_owner(attacker) || attacker;
	if(credit_owner && functionp(credit_owner->is) &&
	   credit_owner->is("player") && target->is("npc"))
		return max(1,damage*query_outgoing_percent(credit_owner)/100);
	if(attacker->is("npc") && target->is("player"))
		return max(1,damage*query_incoming_percent(target)/100);
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
	int unlocked=query_unlocked_level(player);
	int next=unlocked+1;
	mapping progress=query_progress_mapping(player);
	string scope=query_scope(player);
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
		int required=next*9;
		return ([
			"complete":chapters>=required,"maxed":0,
			"scope":scope,"scope_name":query_scope_name(player),
			"mode":"chapters","next_level":next,"next_name":tier["name"],
			"chapters":chapters,"chapters_required":required,
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
	if(!player || (int)progress["maxed"])
		return (["ok":0,"message":"你已经解锁全部个人挑战难度。"]);
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
	if(target_level>query_unlocked_level(player))
		return (["ok":0,"message":"该难度尚未通过破界试炼解锁。"]);
	old_level=query_current_level(player);
	if(old_level==target_level)
		return (["ok":1,"already":1,"level":old_level,
			"message":"当前已经是【"+query_current_name(player)+"】难度。"]);
	if(player->in_combat)
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
