#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define DIFFICULTY_ROOT "/plus/personal_difficulty"
#define DIFFICULTY_MAX_LEVEL 7
#define DIFFICULTY_SWITCH_COOLDOWN 60

// 基础模式逐项保持线上公式。七档挑战只通过统一边界应用增量倍率，
// 任何非法或旧存档值都会失败关闭到基础模式。
private array(mapping(string:mixed)) difficulty_catalog=({
	(["id":"base","name":"基础","min_level":1,"kills":0,"bosses":0,
		"outgoing_percent":100,"incoming_percent":100,
		"set_drop_percent":100,"afk_cap_hours":24]),
	(["id":"wendao","name":"问道","min_level":70,"kills":100,"bosses":3,
		"outgoing_percent":95,"incoming_percent":110,
		"set_drop_percent":115,"afk_cap_hours":16]),
	(["id":"ningzhen","name":"凝真","min_level":100,"kills":150,"bosses":5,
		"outgoing_percent":90,"incoming_percent":120,
		"set_drop_percent":130,"afk_cap_hours":14]),
	(["id":"pojing","name":"破境","min_level":130,"kills":200,"bosses":8,
		"outgoing_percent":85,"incoming_percent":135,
		"set_drop_percent":150,"afk_cap_hours":12]),
	(["id":"tongxuan","name":"通玄","min_level":160,"kills":300,"bosses":12,
		"outgoing_percent":80,"incoming_percent":150,
		"set_drop_percent":175,"afk_cap_hours":10]),
	(["id":"dengxian","name":"登仙","min_level":190,"kills":400,"bosses":16,
		"outgoing_percent":75,"incoming_percent":170,
		"set_drop_percent":205,"afk_cap_hours":8]),
	(["id":"lingxiao","name":"凌霄","min_level":220,"kills":600,"bosses":20,
		"outgoing_percent":70,"incoming_percent":190,
		"set_drop_percent":240,"afk_cap_hours":6]),
	(["id":"tianjie","name":"天劫","min_level":250,"kills":800,"bosses":30,
		"outgoing_percent":65,"incoming_percent":220,
		"set_drop_percent":280,"afk_cap_hours":4]),
});

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

int query_current_level(object player)
{
	int current;
	int unlocked;
	if(!player)
		return 0;
	current=bounded_level((int)player[DIFFICULTY_ROOT+"/current"]);
	unlocked=bounded_level((int)player[DIFFICULTY_ROOT+"/unlocked"]);
	return current<=unlocked ? current : 0;
}

int query_unlocked_level(object player)
{
	if(!player)
		return 0;
	return bounded_level((int)player[DIFFICULTY_ROOT+"/unlocked"]);
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
	if(!player)
		return ([]);
	progress=player[DIFFICULTY_ROOT+"/progress"];
	if(!mappingp(progress)){
		progress=(["kills":0,"bosses":0]);
		player[DIFFICULTY_ROOT+"/progress"]=progress;
	}
	return progress;
}

mapping(string:mixed) query_unlock_progress(object player)
{
	int unlocked=query_unlocked_level(player);
	int next=unlocked+1;
	mapping progress=query_progress_mapping(player);
	if(next>DIFFICULTY_MAX_LEVEL)
		return (["complete":1,"maxed":1,"next_level":-1,
			"kills":(int)progress["kills"],"bosses":(int)progress["bosses"]]);
	mapping tier=difficulty_catalog[next];
	int level=player && functionp(player->query_level) ?
		(int)player->query_level() : 0;
	return ([
		"complete":level>=(int)tier["min_level"] &&
			(int)progress["kills"]>=(int)tier["kills"] &&
			(int)progress["bosses"]>=(int)tier["bosses"],
		"maxed":0,"next_level":next,"next_name":tier["name"],
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
	if(!player || !npc || !player->is("player") || !npc->is("npc"))
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
	if(!player || (int)progress["maxed"])
		return (["ok":0,"message":"你已经解锁全部个人挑战难度。"]);
	if(!(int)progress["complete"])
		return (["ok":0,"message":"破界试炼尚未完成。"]);
	old_unlocked=query_unlocked_level(player);
	old_progress=copy_value(query_progress_mapping(player));
	player[DIFFICULTY_ROOT+"/unlocked"]=(int)progress["next_level"];
	player[DIFFICULTY_ROOT+"/progress"]=(["kills":0,"bosses":0]);
	if(!player->save_with_result()){
		player[DIFFICULTY_ROOT+"/unlocked"]=old_unlocked;
		player[DIFFICULTY_ROOT+"/progress"]=old_progress;
		return (["ok":0,"message":"难度解锁保存失败，请稍后重试。"]);
	}
	return (["ok":1,"level":(int)progress["next_level"],
		"message":"已永久解锁【"+(string)progress["next_name"]+"】难度。"]);
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
	if(!player || target_level<0 || target_level>DIFFICULTY_MAX_LEVEL)
		return (["ok":0,"message":"无效的挑战难度。"]);
	if(target_level>query_unlocked_level(player))
		return (["ok":0,"message":"该难度尚未通过破界试炼解锁。"]);
	if(player->in_combat)
		return (["ok":0,"message":"战斗中不能切换个人挑战难度。"]);
	if(functionp(player->query_autofight) &&
	   player->query_autofight()=="enable")
		return (["ok":0,"message":"请先停止自动挂机再切换难度。"]);
	if(!is_safe_switch_room(player))
		return (["ok":0,"message":"只能在主城或幻境集结入口切换难度。"]);
	last_switch=(int)player[DIFFICULTY_ROOT+"/last_switch"];
	if(last_switch>0 && time()-last_switch<DIFFICULTY_SWITCH_COOLDOWN)
		return (["ok":0,"message":"难度契约正在稳定，请稍后再切换。"]);
	old_level=query_current_level(player);
	old_last_switch=(int)player[DIFFICULTY_ROOT+"/last_switch"];
	if(old_level==target_level)
		return (["ok":1,"already":1,"level":old_level,
			"message":"当前已经是【"+query_current_name(player)+"】难度。"]);
	player[DIFFICULTY_ROOT+"/current"]=target_level;
	player[DIFFICULTY_ROOT+"/last_switch"]=time();
	if(!player->save_with_result()){
		player[DIFFICULTY_ROOT+"/current"]=old_level;
		player[DIFFICULTY_ROOT+"/last_switch"]=old_last_switch;
		return (["ok":0,"message":"难度切换保存失败，原设置保持不变。"]);
	}
	return (["ok":1,"level":target_level,
		"message":"个人挑战难度已切换为【"+
			(string)difficulty_catalog[target_level]["name"]+"】。"]);
}

mapping(string:mixed) query_status(object player)
{
	int current=query_current_level(player);
	int unlocked=query_unlocked_level(player);
	return (["current_level":current,"unlocked_level":unlocked,
		"current":query_tier(current),"progress":query_unlock_progress(player)]);
}
