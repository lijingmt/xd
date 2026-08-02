/**
 * 方士/镇越/天象/灵医职业会员助手。
 *
 * 会员只提供自动化、配置槽、统计报告和纯外观；职业技能、召唤上限、
 * 技能强度、冷却、消耗、装备、掉落以及手动操作始终不受会员限制。
 */
#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define PROFESSION_VIP_VERSION 1
#define PROFESSION_TRIAL_SECONDS 259200
#define PROFESSION_TRIAL_LEVEL 2
#define PROFESSION_STRATEGY_HOLD 60
#define PROFESSION_PASS_COST 240

private array(string) supported_professions = ({"fangshi","zhenyue","tianxiang","lingyi"});

int is_supported_profession(string profe)
{
	return profe && search(supported_professions,profe) != -1;
}

string query_assistant_name(string profe)
{
	if(profe == "fangshi")
		return "灵契助手";
	if(profe == "zhenyue")
		return "山河守御助手";
	if(profe == "tianxiang")
		return "观星助手";
	if(profe == "lingyi")
		return "百草助手";
	return "职业助手";
}

string query_assistant_level_label(int level)
{
	if(level <= 0)
		return "未启用";
	if(level == 1)
		return "水晶·基础辅助";
	if(level == 2)
		return "黄金·智能执行";
	if(level == 3)
		return "白金·团队协同";
	return "钻石·全自动策略";
}

int query_slot_limit_for_level(int level)
{
	if(level < 1)
		return 0;
	if(level > 4)
		level = 4;
	return level;
}

private string query_default_strategy(string profe)
{
	if(profe == "fangshi")
		return "attack";
	if(profe == "tianxiang")
		return "cycle";
	if(profe == "lingyi")
		return "rescue";
	return "solo";
}

void initialize_player(object player)
{
	string profe;
	if(!player)
		return;
	profe = player->query_profeId();
	if(!is_supported_profession(profe))
		return;
	if((int)player["/plus/profession_vip/version"] >=
	   PROFESSION_VIP_VERSION){
		int active_level = VIPD->query_active_vip_level(player);
		if(active_level > 0){
			player["/plus/profession_vip/last_vip_level"] = active_level;
			player["/plus/profession_vip/last_vip_end"] =
				(int)player->query_vip_end_time();
		}
		return;
	}
	if(!player["/plus/profession_vip/strategy"])
		player["/plus/profession_vip/strategy"] =
			query_default_strategy(profe);
	if(!player["/plus/profession_vip/slot1"])
		player["/plus/profession_vip/slot1"] =
			query_default_strategy(profe);
	if(!player["/plus/profession_vip/slot2"]){
		if(profe == "fangshi")
			player["/plus/profession_vip/slot2"] = "heal";
		else if(profe == "tianxiang")
			player["/plus/profession_vip/slot2"] = "burst";
		else if(profe == "lingyi")
			player["/plus/profession_vip/slot2"] = "group";
		else
			player["/plus/profession_vip/slot2"] = "team";
	}
	if(!player["/plus/profession_vip/slot3"]){
		if(profe == "fangshi")
			player["/plus/profession_vip/slot3"] = "defense";
		else if(profe == "tianxiang")
			player["/plus/profession_vip/slot3"] = "safe";
		else if(profe == "lingyi")
			player["/plus/profession_vip/slot3"] = "cleanse";
		else
			player["/plus/profession_vip/slot3"] = "boss";
	}
	if(!player["/plus/profession_vip/slot4"])
		player["/plus/profession_vip/slot4"] = "auto";
	if(!player["/plus/profession_vip/style"])
		player["/plus/profession_vip/style"] = "default";
	if(!player["/plus/profession_vip/styles"])
		player["/plus/profession_vip/styles"] = (["default":1]);
	if(!player["/plus/profession_vip/pass_claims"])
		player["/plus/profession_vip/pass_claims"] = ([]);
	player["/plus/profession_vip/monitor"] = 1;
	player["/plus/profession_vip/version"] = PROFESSION_VIP_VERSION;
	int active_level = VIPD->query_active_vip_level(player);
	if(active_level > 0){
		player["/plus/profession_vip/last_vip_level"] = active_level;
		player["/plus/profession_vip/last_vip_end"] =
			(int)player->query_vip_end_time();
	}
}

int query_active_vip_level(object player)
{
	if(!player)
		return 0;
	return VIPD->query_active_vip_level(player);
}

int query_trial_seconds_left(object player)
{
	int left;
	if(!player)
		return 0;
	left = (int)player["/plus/profession_vip/trial_end"]-time();
	if(left < 0)
		left = 0;
	return left;
}

int query_effective_level(object player)
{
	int level;
	if(!player || !is_supported_profession(player->query_profeId()))
		return 0;
	level = query_active_vip_level(player);
	if(query_trial_seconds_left(player) > 0 && level < PROFESSION_TRIAL_LEVEL)
		level = PROFESSION_TRIAL_LEVEL;
	return level;
}

mapping claim_trial(object player)
{
	mapping result = (["success":0,"reason":"invalid","end_time":0]);
	if(!player || !is_supported_profession(player->query_profeId()))
		return result;
	initialize_player(player);
	if((int)player["/plus/profession_vip/trial_claimed"]){
		result["reason"] = "claimed";
		return result;
	}
	// 已有黄金或更高会员时不浪费一次性试用，会员降档后仍可领取。
	if(query_active_vip_level(player) >= PROFESSION_TRIAL_LEVEL){
		result["reason"] = "active_vip";
		return result;
	}
	player["/plus/profession_vip/trial_claimed"] = 1;
	player["/plus/profession_vip/trial_end"] =
		time()+PROFESSION_TRIAL_SECONDS;
	result["success"] = 1;
	result["reason"] = "success";
	result["end_time"] =
		(int)player["/plus/profession_vip/trial_end"];
	return result;
}

void record_membership_state(object player)
{
	if(!player || !is_supported_profession(player->query_profeId()))
		return;
	initialize_player(player);
	player["/plus/profession_vip/last_vip_level"] =
		VIPD->query_active_vip_level(player);
	player["/plus/profession_vip/last_vip_end"] =
		(int)player->query_vip_end_time();
}

// 登录迁移在VIPD清除过期标志前调用，用于保留到期摘要所需的最后档位。
void record_raw_membership_snapshot(object player)
{
	int raw_level;
	int raw_end;
	if(!player || !is_supported_profession(player->query_profeId()))
		return;
	raw_level = (int)player->query_vip_flag();
	raw_end = (int)player->query_vip_end_time();
	if(raw_level < 1 || raw_end <= 0)
		return;
	if(raw_level > VIP_MAX_LEVEL)
		raw_level = VIP_MAX_LEVEL;
	player["/plus/profession_vip/last_vip_level"] = raw_level;
	player["/plus/profession_vip/last_vip_end"] = raw_end;
}

string query_expiry_notice(object player)
{
	int last_level;
	int last_end;
	if(!player || !is_supported_profession(player->query_profeId()))
		return "";
	initialize_player(player);
	if(query_effective_level(player) > 0)
		return "";
	last_level = (int)player["/plus/profession_vip/last_vip_level"];
	last_end = (int)player["/plus/profession_vip/last_vip_end"];
	// 管理操作或测试可能直接调整会员到期时间，摘要应跟随人物当前
	// 的真实到期字段，而不是继续引用旧快照。
	int current_end = (int)player->query_vip_end_time();
	if(last_level > 0 && current_end > 0 && current_end <= time() &&
	   current_end != last_end){
		last_end = current_end;
		player["/plus/profession_vip/last_vip_end"] = current_end;
	}
	if(last_level <= 0 || last_end <= 0 || last_end > time() ||
	   (int)player["/plus/profession_vip/expiry_ack"] >= last_end)
		return "";
	return query_assistant_name(player->query_profeId())+
		"已随会员到期暂停；技能、等级、外观和全部配置均已保留，续费后可继续执行。";
}

void acknowledge_expiry(object player)
{
	if(player)
		player["/plus/profession_vip/expiry_ack"] =
			(int)player["/plus/profession_vip/last_vip_end"];
}

array(string) query_valid_strategies(string profe,int include_auto)
{
	array(string) result;
	if(profe == "fangshi")
		result = ({"attack","heal","defense"});
	else if(profe == "zhenyue")
		result = ({"solo","boss","team"});
	else if(profe == "tianxiang")
		result = ({"cycle","burst","safe"});
	else if(profe == "lingyi")
		result = ({"rescue","group","cleanse"});
	else
		return ({});
	if(include_auto)
		result += ({"auto"});
	return result;
}

string query_strategy_name(string profe,string strategy)
{
	if(profe == "fangshi"){
		if(strategy == "attack") return "攻灵优先";
		if(strategy == "heal") return "鹤疗优先";
		if(strategy == "defense") return "龟守优先";
		if(strategy == "auto") return "灵契自适应";
	}
	if(profe == "zhenyue"){
		if(strategy == "solo") return "独行稳压";
		if(strategy == "boss") return "首领抗压";
		if(strategy == "team") return "队伍守御";
		if(strategy == "auto") return "山河自适应";
	}
	if(profe == "tianxiang"){
		if(strategy == "cycle") return "星痕循环";
		if(strategy == "burst") return "三星爆发";
		if(strategy == "safe") return "星壁优先";
		if(strategy == "auto") return "天象自适应";
	}
	if(profe == "lingyi"){
		if(strategy == "rescue") return "急救优先";
		if(strategy == "group") return "队伍续航";
		if(strategy == "cleanse") return "净化优先";
		if(strategy == "auto") return "百草自适应";
	}
	return "未知策略";
}

int can_use_strategy(object player,string strategy)
{
	int include_auto;
	if(!player || query_effective_level(player) <= 0)
		return 0;
	include_auto = query_effective_level(player) >= 4;
	return search(query_valid_strategies(player->query_profeId(),include_auto),
		strategy) != -1;
}

int set_strategy(object player,string strategy)
{
	if(!player || !can_use_strategy(player,strategy))
		return 0;
	initialize_player(player);
	player["/plus/profession_vip/strategy"] = strategy;
	return 1;
}

string query_strategy(object player)
{
	string strategy;
	string profe;
	if(!player)
		return "";
	profe = player->query_profeId();
	initialize_player(player);
	strategy = (string)player["/plus/profession_vip/strategy"];
	if(search(query_valid_strategies(profe,1),strategy) == -1)
		strategy = query_default_strategy(profe);
	return strategy;
}

int save_strategy_slot(object player,int slot,string strategy)
{
	int limit;
	if(!player)
		return 0;
	limit = query_slot_limit_for_level(query_effective_level(player));
	if(slot < 1 || slot > limit || !can_use_strategy(player,strategy))
		return 0;
	player["/plus/profession_vip/slot"+slot] = strategy;
	return 1;
}

string query_strategy_slot(object player,int slot)
{
	if(!player || slot < 1 || slot > 4)
		return "";
	initialize_player(player);
	return (string)player["/plus/profession_vip/slot"+slot];
}

int use_strategy_slot(object player,int slot)
{
	int limit;
	string strategy;
	if(!player)
		return 0;
	limit = query_slot_limit_for_level(query_effective_level(player));
	if(slot < 1 || slot > limit)
		return 0;
	strategy = query_strategy_slot(player,slot);
	return set_strategy(player,strategy);
}

int set_monitor_enabled(object player,int enabled)
{
	if(!player || query_effective_level(player) < 1)
		return 0;
	initialize_player(player);
	player["/plus/profession_vip/monitor"] = enabled ? 1 : 0;
	return 1;
}

int set_auto_enabled(object player,int enabled)
{
	if(!player || (enabled && query_effective_level(player) < 2))
		return 0;
	initialize_player(player);
	player["/plus/profession_vip/auto"] = enabled ? 1 : 0;
	return 1;
}

int set_resonance_enabled(object player,int enabled)
{
	if(!player || player->query_profeId() != "fangshi" ||
	   (enabled && query_effective_level(player) < 3))
		return 0;
	initialize_player(player);
	player["/plus/profession_vip/resonance"] = enabled ? 1 : 0;
	return 1;
}

int query_monitor_enabled(object player)
{
	return player && query_effective_level(player) >= 1 &&
		(int)player["/plus/profession_vip/monitor"] == 1;
}

int query_auto_enabled(object player)
{
	return player && query_effective_level(player) >= 2 &&
		(int)player["/plus/profession_vip/auto"] == 1;
}

int query_resonance_enabled(object player)
{
	return player && player->query_profeId() == "fangshi" &&
		query_effective_level(player) >= 3 &&
		(int)player["/plus/profession_vip/resonance"] == 1;
}

private string query_stats_month()
{
	mapping now_time = localtime(time());
	return sprintf("%04d%02d",(int)now_time["year"]+1900,
		(int)now_time["mon"]+1);
}

mapping query_month_stats(object player)
{
	string month;
	if(!player)
		return ([]);
	month = query_stats_month();
	if((string)player["/plus/profession_vip/stats_month"] != month ||
	   !player["/plus/profession_vip/stats"]){
		player["/plus/profession_vip/stats_month"] = month;
		player["/plus/profession_vip/stats"] = ([]);
	}
	return (mapping)player["/plus/profession_vip/stats"];
}

void record_stat(object player,string name,int amount)
{
	mapping stats;
	if(!player || !name || name == "" || amount <= 0)
		return;
	stats = query_month_stats(player);
	stats[name] = (int)stats[name]+amount;
}

private int is_pve_enemy(object player)
{
	object|zero enemy;
	string master;
	if(!player || !player->query_in_combat())
		return 0;
	enemy = player->query_enemy();
	if(!enemy || !enemy->is("npc") || enemy->is("player"))
		return 0;
	if(functionp(enemy->query_master)){
		master = (string)enemy->query_master();
		if(master && master != "")
			return 0;
	}
	if(functionp(enemy->query_summon_type))
		return 0;
	return 1;
}

private int has_same_room_team(object player)
{
	string team_id;
	object env;
	if(!player)
		return 0;
	team_id = player->query_term();
	env = environment(player);
	if(!env || team_id == "" || team_id == "noterm")
		return 0;
	foreach(all_inventory(env),object member){
		if(member != player && member->is("player") &&
		   member->query_term() == team_id && member->get_cur_life() > 0 &&
		   LOGICALZONED->can_action("team",player,member))
			return 1;
	}
	return 0;
}

private int has_low_life_member(object player,int percent)
{
	string team_id;
	object env;
	if(!player || player->query_life_max() <= 0)
		return 0;
	if(player->get_cur_life()*100 <= player->query_life_max()*percent)
		return 1;
	team_id = player->query_term();
	env = environment(player);
	if(!env || team_id == "" || team_id == "noterm")
		return 0;
	foreach(all_inventory(env),object member){
		if(member == player || !member->is("player") ||
		   member->query_term() != team_id ||
		   member->query_life_max() <= 0 ||
		   !LOGICALZONED->can_action("team",player,member))
			continue;
		if(member->get_cur_life()*100 <= member->query_life_max()*percent)
			return 1;
	}
	return 0;
}

private int has_afflicted_member(object player)
{
	array(string) kinds = ({"dot","curse","curse2","70_skill_curse"});
	array(object) members = ({player});
	string team_id;
	object env;
	if(!player)
		return 0;
	team_id = player->query_term();
	env = environment(player);
	if(env && team_id!="" && team_id!="noterm"){
		foreach(all_inventory(env),object member){
			if(member!=player && member->is("player") &&
			   member->query_term()==team_id && member->get_cur_life()>0 &&
			   LOGICALZONED->can_action("team",player,member))
				members += ({member});
		}
	}
	foreach(members,object member)
		foreach(kinds,string kind)
			if(member->query_debuff(kind,0)!="none")
				return 1;
	return 0;
}

private int is_boss_enemy(object player)
{
	object|zero enemy;
	if(!is_pve_enemy(player))
		return 0;
	enemy = player->query_enemy();
	return (int)enemy->_boss == 1 || (int)enemy->_meritocrat == 1 ||
		enemy->query_level() >= player->query_level()+3;
}

string query_runtime_strategy(object player)
{
	string configured;
	string desired;
	string profe;
	int changed_at;
	if(!player)
		return "";
	configured = query_strategy(player);
	if(configured != "auto" || query_effective_level(player) < 4)
		return configured;
	profe = player->query_profeId();
	desired = query_default_strategy(profe);
	if(profe == "fangshi"){
		if(has_low_life_member(player,65)) desired = "heal";
		else if(is_boss_enemy(player)) desired = "defense";
	}
	else if(profe == "zhenyue"){
		if(has_same_room_team(player)) desired = "team";
		else if(is_boss_enemy(player)) desired = "boss";
	}
	else if(profe == "tianxiang"){
		if(player->get_cur_life()*100 <= player->query_life_max()*45)
			desired = "safe";
		else if(player->query_tianxiang_star_marks()>=2 ||
		   is_boss_enemy(player))
			desired = "burst";
	}
	else if(profe == "lingyi"){
		if(has_afflicted_member(player))
			desired = "cleanse";
		else if(has_same_room_team(player) && has_low_life_member(player,75))
			desired = "group";
		else
			desired = "rescue";
	}
	changed_at = (int)player["/tmp/profession_vip/strategy_changed"];
	if(!player["/tmp/profession_vip/runtime_strategy"]){
		player["/tmp/profession_vip/runtime_strategy"] = desired;
		player["/tmp/profession_vip/strategy_changed"] = time();
		return desired;
	}
	if((string)player["/tmp/profession_vip/runtime_strategy"] != desired &&
	   time()-changed_at >= PROFESSION_STRATEGY_HOLD){
		player["/tmp/profession_vip/runtime_strategy"] = desired;
		player["/tmp/profession_vip/strategy_changed"] = time();
		record_stat(player,"strategy_switch",1);
	}
	return (string)player["/tmp/profession_vip/runtime_strategy"];
}

private array(string) query_fangshi_summon_order(object player)
{
	string strategy = query_runtime_strategy(player);
	if(strategy == "heal")
		return ({"heling","guiling","huling"});
	if(strategy == "defense")
		return ({"guiling","heling","huling"});
	return ({"huling","heling","guiling"});
}

mapping replenish_fangshi(object player,int automatic)
{
	mapping result = (["success":0,"reason":"invalid","summon":""]);
	string player_name;
	if(!player || player->query_profeId() != "fangshi")
		return result;
	initialize_player(player);
	if(query_effective_level(player) < (automatic ? 2 : 1)){
		result["reason"] = "vip";
		return result;
	}
	if(automatic && !query_auto_enabled(player)){
		result["reason"] = "disabled";
		return result;
	}
	if(player->query_in_combat()){
		result["reason"] = "combat";
		return result;
	}
	player_name = player->query_name();
	if(!SUMMOND->can_summon(player_name)){
		result["reason"] = "full";
		return result;
	}
	foreach(query_fangshi_summon_order(player),string summon_type){
		if(SUMMOND->query_summon_skill_name(player,summon_type) == "")
			continue;
		if(SUMMOND->get_player_summons(player_name)[summon_type])
			continue;
		if(SUMMOND->summon_creature(player_name,summon_type,0,0)){
			result["success"] = 1;
			result["reason"] = "success";
			result["summon"] = summon_type;
			record_stat(player,"summon",1);
			return result;
		}
	}
	result["reason"] = "no_learned_summon";
	return result;
}

mapping try_fangshi_resonance(object player)
{
	mapping result = (["success":0,"reason":"invalid"]);
	if(!player || player->query_profeId() != "fangshi" ||
	   !query_resonance_enabled(player))
		return result;
	if(!is_pve_enemy(player)){
		result["reason"] = "pve_only";
		return result;
	}
	// 自动共鸣只在有真实救援价值时触发，手动共鸣仍永久免费。
	if(!has_low_life_member(player,65) &&
	   player->get_cur_mofa()*100 > player->query_mofa_max()*35){
		result["reason"] = "not_needed";
		return result;
	}
	result = SUMMOND->activate_resonance(player);
	if(result["success"])
		record_stat(player,"resonance",1);
	return result;
}

array(string) query_zhenyue_context_candidates(object player)
{
	array(string) names = ({});
	object|zero enemy;
	string strategy;
	if(!player || player->query_profeId() != "zhenyue" ||
	   !query_auto_enabled(player) || !is_pve_enemy(player))
		return names;
	strategy = query_runtime_strategy(player);
	enemy = player->query_enemy();
	if(enemy && enemy->first_target != player)
		names += ({"zhenhunhou","dizhenhou"});
	if(query_effective_level(player) >= 3 &&
	   (strategy == "team" || has_low_life_member(player,70)) &&
	   player->query_buff("team_guard",0) != "absorb")
		names += ({"wanshanchaogong","wanshanbugu","shanhebi"});
	else if(strategy == "boss" &&
	   player->query_buff("team_guard",0) != "absorb")
		names += ({"wanshanbugu","shanhebi"});
	return names;
}

string query_zhenyue_manual_recommendation(object player)
{
	array(string) names;
	if(!player || player->query_profeId() != "zhenyue" ||
	   query_effective_level(player) < 1)
		return "";
	if(player->query_in_combat() && is_pve_enemy(player)){
		object|zero enemy = player->query_enemy();
		if(enemy && enemy->first_target != player)
			names = ({"zhenhunhou","dizhenhou"});
		else if(player->query_buff("team_guard",0) != "absorb")
			names = ({"wanshanchaogong","wanshanbugu","shanhebi"});
		else
			names = ({"buzhouzhenji","hengshanji","yueji"});
	}
	else
		names = ({"shanhebi","dizhenhou","yueji"});
	foreach(names,string name)
		if(player->skills && player->skills[name])
			return name;
	return "";
}

void record_zhenyue_action(object player,string skill_name)
{
	if(!player || player->query_profeId() != "zhenyue")
		return;
	if(search(skill_name,"hou") != -1 || skill_name == "wanshanchaogong")
		record_stat(player,"taunt",1);
	if(skill_name == "shanhebi" || skill_name == "wanshanbugu")
		record_stat(player,"guard",1);
	record_stat(player,"action",1);
}

array(string) query_tianxiang_context_candidates(object player)
{
	array(string) names = ({});
	string strategy;
	int marks;
	if(!player || player->query_profeId() != "tianxiang" ||
	   !query_auto_enabled(player) || !is_pve_enemy(player))
		return names;
	strategy = query_runtime_strategy(player);
	marks = player->query_tianxiang_star_marks();
	if(strategy == "safe" &&
	   player->query_buff("buff",0) != "absorb")
		names += ({"wanxiangxingbi","xingbi"});
	if(marks>=2 && strategy == "burst")
		names += ({"xinghezhuiluo","xingluo"});
	if(marks<3)
		names += ({"jiuxinglianzhu","yueyin","xingyu","tianxuan",
			"yaoguang","liuxing","hanchen","xingmang"});
	else
		names += ({"xingluo","xinghezhuiluo"});
	return names;
}

string query_tianxiang_manual_recommendation(object player)
{
	array(string) names;
	int marks;
	if(!player || player->query_profeId() != "tianxiang" ||
	   query_effective_level(player) < 1)
		return "";
	marks = player->query_tianxiang_star_marks();
	if(player->query_in_combat() && is_pve_enemy(player)){
		if(player->get_cur_life()*100 <= player->query_life_max()*45 &&
		   player->query_buff("buff",0) != "absorb")
			names = ({"wanxiangxingbi","xingbi"});
		else if(marks>=2)
			names = ({"xinghezhuiluo","xingluo"});
		else
			names = ({"jiuxinglianzhu","yueyin","xingyu","tianxuan",
				"yaoguang","liuxing","hanchen","xingmang"});
	}
	else
		names = ({"xingbi","xingmang","hanchen"});
	foreach(names,string name)
		if(player->skills && player->skills[name])
			return name;
	return "";
}

void record_tianxiang_action(object player,string skill_name)
{
	object|zero skill;
	if(!player || player->query_profeId() != "tianxiang")
		return;
	skill = (object)(ROOT+"/gamelib/single/skills/"+skill_name);
	if(skill && skill->query_star_mark_gain()>0)
		record_stat(player,"mark",1);
	if(skill && skill->query_star_mark_consume())
		record_stat(player,"burst",1);
	if(skill_name=="xingbi" || skill_name=="wanxiangxingbi")
		record_stat(player,"guard",1);
	record_stat(player,"action",1);
}

array(string) query_lingyi_context_candidates(object player)
{
	array(string) names = ({});
	string strategy;
	if(!player || player->query_profeId()!="lingyi" ||
	   !query_auto_enabled(player) || !is_pve_enemy(player))
		return names;
	strategy = query_runtime_strategy(player);
	if(has_afflicted_member(player) &&
	   (strategy=="cleanse" || strategy=="auto"))
		names += ({"liuhehuichun","wanmuxinchun","ganlin","qingxin"});
	if(has_same_room_team(player) && has_low_life_member(player,75) &&
	   (strategy=="group" || strategy=="auto"))
		names += ({"liuhehuichun","cixinpudu","wanmuxinchun","ganlin","yulu"});
	if(has_low_life_member(player,70))
		names += ({"huimingtianlu","xuming","lingyu","qingxin","huichun"});
	return names;
}

string query_lingyi_manual_recommendation(object player)
{
	array(string) names;
	if(!player || player->query_profeId()!="lingyi" ||
	   query_effective_level(player)<1)
		return "";
	if(has_afflicted_member(player))
		names = ({"liuhehuichun","wanmuxinchun","ganlin","qingxin"});
	else if(has_same_room_team(player) && has_low_life_member(player,75))
		names = ({"liuhehuichun","cixinpudu","ganlin","yulu","lingyu","huichun"});
	else
		names = ({"huimingtianlu","xuming","lingyu","qingxin","huichun"});
	foreach(names,string name)
		if(player->skills && player->skills[name])
			return name;
	return "";
}

void record_lingyi_action(object player,string skill_name)
{
	object|zero skill;
	if(!player || player->query_profeId()!="lingyi")
		return;
	skill = (object)(ROOT+"/gamelib/single/skills/"+skill_name);
	if(skill && skill->s_skill_type=="heal")
		record_stat(player,"heal",1);
	if(skill && skill->query_lingyi_cleanse())
		record_stat(player,"cleanse",1);
	record_stat(player,"action",1);
}

mapping try_out_of_combat_support(object player)
{
	if(player && player->query_profeId() == "fangshi" &&
	   query_auto_enabled(player))
		return replenish_fangshi(player,1);
	if(player && player->query_profeId()=="lingyi" &&
	   query_auto_enabled(player) && !player->query_in_combat() &&
	   (has_low_life_member(player,70) || has_afflicted_member(player))){
		string skill = query_lingyi_manual_recommendation(player);
		int before_mofa = player->get_cur_mofa();
		if(skill!="" && player->perform_support(skill) &&
		   player->get_cur_mofa()<before_mofa){
			record_lingyi_action(player,skill);
			return (["success":1,"reason":"success","skill":skill]);
		}
	}
	return (["success":0,"reason":"unsupported"]);
}

string query_monitor_notice(object player)
{
	string notice = "";
	int now;
	if(!player || !query_monitor_enabled(player))
		return "";
	now = time();
	if(now-(int)player["/tmp/profession_vip/notice_time"] < 60)
		return "";
	if(player->query_profeId() == "fangshi"){
		int current = SUMMOND->get_current_summon_count(player->query_name());
		int maximum = SUMMOND->get_max_summons(player->query_name());
		if(current < maximum)
			notice = "灵契监控：当前灵兽"+current+"/"+maximum+
				"，可在职业助手补位。";
	}
	else if(player->query_profeId() == "zhenyue" &&
	   player->query_in_combat() && is_pve_enemy(player)){
		object|zero enemy = player->query_enemy();
		if(enemy && enemy->first_target != player)
			notice = "守御监控：敌人仇恨已偏离镇越。";
		else if(has_low_life_member(player,50))
			notice = "守御监控：你或同房队友生命已低于50%。";
	}
	else if(player->query_profeId() == "tianxiang" &&
	   player->query_in_combat() && is_pve_enemy(player)){
		int marks = player->query_tianxiang_star_marks();
		if(marks>=2)
			notice = "观星监控：当前已有"+marks+"层星痕，可选择星落引爆。";
		else if(player->get_cur_life()*100 <= player->query_life_max()*45 &&
		   player->query_buff("buff",0) != "absorb")
			notice = "观星监控：生命偏低且星壁未生效。";
	}
	else if(player->query_profeId()=="lingyi" &&
	   player->query_in_combat() && is_pve_enemy(player)){
		if(has_afflicted_member(player))
			notice = "百草监控：队伍存在可净化的负面状态。";
		else if(has_low_life_member(player,50))
			notice = "百草监控：你或同房队友生命已低于50%。";
	}
	if(notice != ""){
		player["/tmp/profession_vip/notice_time"] = now;
		record_stat(player,"warning",1);
	}
	return notice;
}

mapping query_style_info(string profe,string style)
{
	if(style == "default")
		return (["id":"default","name":"经典外观","tier":0,
			"level":1,"cost":0,"class":"profession-style-none"]);
	if(profe == "fangshi"){
		if(style == "lingguang") return (["id":style,"name":"灵光契印",
			"tier":1,"level":20,"cost":60,"class":"profession-style-fangshi-1"]);
		if(style == "qinghe") return (["id":style,"name":"青霄灵阵",
			"tier":2,"level":50,"cost":120,"class":"profession-style-fangshi-2"]);
		if(style == "sixiang") return (["id":style,"name":"四象归真",
			"tier":3,"level":80,"cost":200,"class":"profession-style-fangshi-3"]);
	}
	if(profe == "zhenyue"){
		if(style == "xuanyan") return (["id":style,"name":"玄岩盾辉",
			"tier":1,"level":20,"cost":60,"class":"profession-style-zhenyue-1"]);
		if(style == "jinque") return (["id":style,"name":"金阙山河",
			"tier":2,"level":50,"cost":120,"class":"profession-style-zhenyue-2"]);
		if(style == "wanshan") return (["id":style,"name":"万山宗师",
			"tier":3,"level":80,"cost":200,"class":"profession-style-zhenyue-3"]);
	}
	if(profe == "tianxiang"){
		if(style == "xinghui") return (["id":style,"name":"星辉轨迹",
			"tier":1,"level":20,"cost":60,"class":"profession-style-tianxiang-1"]);
		if(style == "yuehuan") return (["id":style,"name":"月环星幕",
			"tier":2,"level":50,"cost":120,"class":"profession-style-tianxiang-2"]);
		if(style == "wanxiang") return (["id":style,"name":"万象天穹",
			"tier":3,"level":80,"cost":200,"class":"profession-style-tianxiang-3"]);
	}
	if(profe == "lingyi"){
		if(style == "qinglu") return (["id":style,"name":"青露药光",
			"tier":1,"level":20,"cost":60,"class":"profession-style-lingyi-1"]);
		if(style == "bailian") return (["id":style,"name":"白莲回生",
			"tier":2,"level":50,"cost":120,"class":"profession-style-lingyi-2"]);
		if(style == "wanmu") return (["id":style,"name":"万木春辉",
			"tier":3,"level":80,"cost":200,"class":"profession-style-lingyi-3"]);
	}
	return ([]);
}

array(string) query_style_ids(string profe)
{
	if(profe == "fangshi")
		return ({"default","lingguang","qinghe","sixiang"});
	if(profe == "zhenyue")
		return ({"default","xuanyan","jinque","wanshan"});
	if(profe == "tianxiang")
		return ({"default","xinghui","yuehuan","wanxiang"});
	if(profe == "lingyi")
		return ({"default","qinglu","bailian","wanmu"});
	return ({});
}

int owns_style(object player,string style)
{
	mapping styles;
	if(!player)
		return 0;
	initialize_player(player);
	styles = (mapping)player["/plus/profession_vip/styles"];
	return styles && (int)styles[style] == 1;
}

private void grant_style(object player,string style)
{
	mapping styles;
	initialize_player(player);
	styles = (mapping)player["/plus/profession_vip/styles"];
	if(!styles)
		styles = ([]);
	styles[style] = 1;
	player["/plus/profession_vip/styles"] = styles;
}

private void log_purchase(object player,string action,string goods,int cost)
{
	string now;
	if(!player)
		return;
	now = ctime(time());
	Stdio.append_file(ROOT+"/log/profession_vip.log",
		now[0..sizeof(now)-2]+" "+player->query_name_cn()+"("+
		player->query_name()+") "+action+" "+goods+" cost="+cost+"\n");
}

mapping buy_style(object player,string style)
{
	mapping result = (["success":0,"reason":"invalid","cost":0]);
	mapping info;
	string profe;
	int cost;
	if(!player)
		return result;
	profe = player->query_profeId();
	info = query_style_info(profe,style);
	if(!sizeof(info) || style == "default")
		return result;
	if(owns_style(player,style)){
		result["reason"] = "owned";
		return result;
	}
	if(player->query_level() < (int)info["level"]){
		result["reason"] = "level";
		return result;
	}
	cost = (int)info["cost"];
	result["cost"] = cost;
	if(!YUSHID->pay_yushi(player,cost)){
		result["reason"] = "yushi";
		return result;
	}
	grant_style(player,style);
	player["/plus/profession_vip/style"] = style;
	log_purchase(player,"style",style,cost);
	result["success"] = 1;
	result["reason"] = "success";
	return result;
}

int equip_style(object player,string style)
{
	if(!player || !owns_style(player,style) ||
	   !sizeof(query_style_info(player->query_profeId(),style)))
		return 0;
	player["/plus/profession_vip/style"] = style;
	return 1;
}

string query_selected_style(object player)
{
	string style;
	if(!player)
		return "default";
	initialize_player(player);
	style = (string)player["/plus/profession_vip/style"];
	if(!owns_style(player,style) ||
	   !sizeof(query_style_info(player->query_profeId(),style)))
		style = "default";
	return style;
}

mapping buy_growth_pass(object player)
{
	mapping result = (["success":0,"reason":"invalid",
		"cost":PROFESSION_PASS_COST]);
	if(!player || !is_supported_profession(player->query_profeId()))
		return result;
	initialize_player(player);
	if((int)player["/plus/profession_vip/pass"] == 1){
		result["reason"] = "owned";
		return result;
	}
	if(!YUSHID->pay_yushi(player,PROFESSION_PASS_COST)){
		result["reason"] = "yushi";
		return result;
	}
	player["/plus/profession_vip/pass"] = 1;
	log_purchase(player,"growth_pass",player->query_profeId(),
		PROFESSION_PASS_COST);
	result["success"] = 1;
	result["reason"] = "success";
	return result;
}

string query_pass_style_for_tier(string profe,int tier)
{
	array(string) ids = query_style_ids(profe);
	if(tier < 1 || tier > 3 || sizeof(ids) < 4)
		return "";
	return ids[tier];
}

mapping claim_pass_style(object player,int tier)
{
	mapping result = (["success":0,"reason":"invalid","style":""]);
	mapping claims;
	string style;
	int need_level;
	if(!player || (int)player["/plus/profession_vip/pass"] != 1 ||
	   tier < 1 || tier > 3)
		return result;
	claims = (mapping)player["/plus/profession_vip/pass_claims"];
	if(!claims)
		claims = ([]);
	if((int)claims[(string)tier] == 1){
		result["reason"] = "claimed";
		return result;
	}
	need_level = tier == 1 ? 20 : (tier == 2 ? 50 : 80);
	if(player->query_level() < need_level){
		result["reason"] = "level";
		return result;
	}
	style = query_pass_style_for_tier(player->query_profeId(),tier);
	if(style == "")
		return result;
	grant_style(player,style);
	claims[(string)tier] = 1;
	player["/plus/profession_vip/pass_claims"] = claims;
	player["/plus/profession_vip/style"] = style;
	result["success"] = 1;
	result["reason"] = "success";
	result["style"] = style;
	return result;
}

string query_growth_title(object player)
{
	int level;
	if(!player)
		return "";
	level = player->query_level();
	if(player->query_profeId() == "fangshi"){
		if(level >= 80) return "万灵宗师";
		if(level >= 50) return "御灵方尊";
		if(level >= 20) return "三灵契者";
		return "初窥灵契";
	}
	if(player->query_profeId() == "zhenyue"){
		if(level >= 80) return "镇越宗师";
		if(level >= 50) return "山河壁垒";
		if(level >= 20) return "守山之士";
		return "负岳新人";
	}
	if(player->query_profeId() == "tianxiang"){
		if(level >= 80) return "万象星主";
		if(level >= 50) return "星轨观者";
		if(level >= 20) return "观星术士";
		return "初识天象";
	}
	if(player->query_profeId() == "lingyi"){
		if(level >= 80) return "万木医圣";
		if(level >= 50) return "百草灵师";
		if(level >= 20) return "回春医者";
		return "初辨药息";
	}
	return "";
}

void decorate_summon(object player,object summon)
{
	mapping info;
	string style;
	if(!player || !summon || player->query_profeId() != "fangshi")
		return;
	style = query_selected_style(player);
	info = query_style_info("fangshi",style);
	if((int)info["tier"] <= 0)
		return;
	summon->name_cn = "【"+(string)info["name"]+"】"+
		summon->query_name_cn(1);
	summon->desc = summon->query_desc()+
		"灵兽身上的异象仅为契印外观，不改变任何战斗属性。\n";
}

string query_combat_style_effect(object player,string action)
{
	mapping info;
	string style;
	if(!player || player->query_profeId() != "zhenyue")
		return "";
	style = query_selected_style(player);
	info = query_style_info("zhenyue",style);
	if((int)info["tier"] <= 0)
		return "";
	if(action == "taunt")
		return "【"+(string)info["name"]+"】岩纹亮起，山势虚影随震吼展开。\n";
	if(action == "guard")
		return "【"+(string)info["name"]+"】山河光幕环绕队伍，此为纯外观效果。\n";
	return "";
}

mapping query_status(object player)
{
	mapping result = (["supported":0]);
	mapping style_info;
	string profe;
	string style;
	int level;
	if(!player)
		return result;
	profe = player->query_profeId();
	if(!is_supported_profession(profe))
		return result;
	initialize_player(player);
	level = query_effective_level(player);
	style = query_selected_style(player);
	style_info = query_style_info(profe,style);
	result["supported"] = 1;
	result["name"] = query_assistant_name(profe);
	result["level"] = level;
	result["level_label"] = query_assistant_level_label(level);
	result["trial_left"] = query_trial_seconds_left(player);
	result["trial_claimed"] =
		(int)player["/plus/profession_vip/trial_claimed"];
	result["strategy"] = query_strategy(player);
	result["strategy_name"] =
		query_strategy_name(profe,query_strategy(player));
	result["monitor"] = query_monitor_enabled(player);
	result["auto"] = query_auto_enabled(player);
	result["resonance"] = query_resonance_enabled(player);
	result["slot_limit"] = query_slot_limit_for_level(level);
	result["style"] = style;
	result["style_name"] = (string)style_info["name"];
	result["style_tier"] = (int)style_info["tier"];
	result["style_class"] = (string)style_info["class"];
	result["title"] = query_growth_title(player);
	result["pass"] = (int)player["/plus/profession_vip/pass"];
	result["expiry_notice"] = query_expiry_notice(player);
	return result;
}
