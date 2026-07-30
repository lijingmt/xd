#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define AUTOFIGHT_DAILY_SECONDS (8*60*60)
#define AUTOFIGHT_VIP_BONUS_SECONDS (2*60*60)
#define AUTOFIGHT_MAX_VIP_LEVEL 4

protected void create()
{
}

void initialize_player(object me)
{
	int daily_limit;
	if(!me)
		return;
	if(!(int)me["/plus/autofight_initialized"]){
		daily_limit = query_daily_seconds_for(me);
		me["/plus/autofight_initialized"] = 1;
		me["/plus/autofight_daily_limit"] = daily_limit;
		me["/plus/autofight_time_left"] = daily_limit;
		me["/plus/autofight_hp_percent"] = 50;
		me["/plus/autofight_mana_percent"] = 30;
		me["/plus/autofight_loot"] = 1;
		me["/plus/autofight_roam"] = 0;
		me["/plus/autofight_food"] = "auto";
		me["/plus/autofight_water"] = "auto";
	}
	else
		sync_daily_limit(me);
}

int query_daily_seconds()
{
	return AUTOFIGHT_DAILY_SECONDS;
}

int query_vip_level(object me)
{
	int vip_level;
	if(!me)
		return 0;
	vip_level = 0;
	if(functionp(me->query_vip_flag))
		vip_level = (int)me->query_vip_flag();
	if(vip_level < 0)
		vip_level = 0;
	if(vip_level > AUTOFIGHT_MAX_VIP_LEVEL)
		vip_level = AUTOFIGHT_MAX_VIP_LEVEL;
	return vip_level;
}

int query_daily_seconds_for(object me)
{
	return AUTOFIGHT_DAILY_SECONDS+
		query_vip_level(me)*AUTOFIGHT_VIP_BONUS_SECONDS;
}

void sync_daily_limit(object me)
{
	int daily_limit;
	int previous_limit;
	int time_left;
	if(!me)
		return;
	daily_limit = query_daily_seconds_for(me);
	previous_limit = (int)me["/plus/autofight_daily_limit"];
	if(previous_limit <= 0)
		previous_limit = AUTOFIGHT_DAILY_SECONDS;
	time_left = (int)me["/plus/autofight_time_left"];
	if(previous_limit != daily_limit)
		time_left += daily_limit-previous_limit;
	if(time_left < 0)
		time_left = 0;
	if(time_left > daily_limit)
		time_left = daily_limit;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = time_left;
}

void reset_daily_time(object me)
{
	int daily_limit;
	if(!me)
		return;
	daily_limit = query_daily_seconds_for(me);
	me["/plus/autofight_initialized"] = 1;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = daily_limit;
	me["/tmp/autofight_last_charge"] = 0;
}

int query_time_left(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_time_left"];
}

int query_hp_percent(object me)
{
	int percent;
	if(!me)
		return 50;
	initialize_player(me);
	percent = (int)me["/plus/autofight_hp_percent"];
	if(percent != 30 && percent != 50 && percent != 70)
		percent = 50;
	return percent;
}

int query_mana_percent(object me)
{
	int percent;
	if(!me)
		return 30;
	initialize_player(me);
	percent = (int)me["/plus/autofight_mana_percent"];
	if(percent != 0 && percent != 30 && percent != 50)
		percent = 30;
	return percent;
}

int query_loot_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_loot"] == 1;
}

int query_roam_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_roam"] == 1;
}

void start_autofight(object me)
{
	if(!me)
		return;
	initialize_player(me);
	me["/tmp/autofight_last_charge"] = time();
	me->set_autofight("enable");
}

void stop_autofight(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_last_charge"] = 0;
	me->set_autofight("disable");
}

int charge_time(object me)
{
	int now;
	int last;
	int elapsed;
	int left;
	if(!me)
		return 0;
	initialize_player(me);
	now = time();
	last = (int)me["/tmp/autofight_last_charge"];
	if(last <= 0 || last > now){
		me["/tmp/autofight_last_charge"] = now;
		return query_time_left(me);
	}
	elapsed = now-last;
	if(elapsed <= 0)
		return query_time_left(me);
	left = query_time_left(me)-elapsed;
	if(left < 0)
		left = 0;
	me["/plus/autofight_time_left"] = left;
	me["/tmp/autofight_last_charge"] = now;
	return left;
}

string query_start_block_reason(object me)
{
	object env;
	if(!me)
		return "玩家对象不存在";
	initialize_player(me);
	if(me->is("npc"))
		return "NPC不能开启自动挂机";
	env = environment(me);
	if(!env)
		return "你当前不在有效地图中";
	if(me->is("ghost") || me->get_cur_life() <= 0)
		return "死亡或灵魂状态不能开启自动挂机";
	if((int)me["/plus/random_rcd"] > 0)
		return "请先完成当前的安全验证";
	if(query_time_left(me) <= 0)
		return sprintf("今天的%d小时自动挂机时间已经用完",
			query_daily_seconds_for(me)/3600);
	if(query_loot_enabled(me) && me->if_over_easy_load())
		return "背包已满，请整理背包后再开启";
	return "";
}

string query_runtime_block_reason(object me)
{
	return query_start_block_reason(me);
}

int should_recover_life(object me)
{
	int life;
	int life_max;
	int percent;
	if(!me)
		return 0;
	life = me->get_cur_life();
	life_max = me->query_life_max();
	percent = query_hp_percent(me);
	if(life <= 0 || life_max <= 0)
		return 0;
	return life*100 < life_max*percent;
}

int should_recover_mana(object me)
{
	int mana;
	int mana_max;
	int percent;
	if(!me)
		return 0;
	mana = me->get_cur_mofa();
	mana_max = me->query_mofa_max();
	percent = query_mana_percent(me);
	if(percent <= 0 || mana_max <= 0)
		return 0;
	return mana*100 < mana_max*percent;
}

private int is_valid_target(object me, object ob)
{
	string npc_type;
	string me_race;
	string npc_race;
	int me_level;
	int npc_level;
	if(!me || !ob || ob == me)
		return 0;
	if(!ob->is("character") || !ob->is("npc"))
		return 0;
	if(ob->hind != 0 || ob->get_cur_life() <= 0)
		return 0;
	if(ob->_boss || ob->_tasknpc)
		return 0;
	if(functionp(ob->query_summon_type))
		return 0;
	npc_type = ob->query_npc_type();
	if(npc_type == "city_keeper" || npc_type == "city_guarder" ||
	   npc_type == "city_lord")
		return 0;
	if(functionp(ob->can_be_attacked) && !ob->can_be_attacked(me))
		return 0;
	me_race = me->query_raceId();
	npc_race = ob->query_raceId();
	if(me_race != "third" && me_race == npc_race)
		return 0;
	me_level = me->query_level();
	npc_level = ob->query_level();
	if(npc_level > me_level+2)
		return 0;
	return 1;
}

object|zero query_target(object me)
{
	object env;
	object|zero best;
	array(object) all;
	int best_level;
	if(!me)
		return 0;
	env = environment(me);
	if(!env || env->is("peaceful"))
		return 0;
	all = all_inventory(env);
	best_level = -1;
	foreach(all,object ob){
		int npc_level;
		if(!is_valid_target(me,ob))
			continue;
		npc_level = ob->query_level();
		if(npc_level > best_level){
			best = ob;
			best_level = npc_level;
		}
	}
	return best;
}

private int can_loot_item(object me, object ob)
{
	string owner;
	string name_cn;
	int protect_time;
	if(!me || !ob)
		return 0;
	if(!ob->is("item") || ob->is("npc"))
		return 0;
	if(functionp(ob->query_item_canGet) && ob->query_item_canGet() != 1)
		return 0;
	if(ob->query_name() == "corpse")
		return 0;
	name_cn = ob->query_name_cn();
	if(name_cn && (search(name_cn,"尸体") != -1 ||
	   search(name_cn,"骸骨") != -1))
		return 0;
	owner = ob->item_whoCanGet;
	protect_time = (int)ob->item_TimewhoCanGet;
	if(owner && owner != "" && owner != "1" &&
	   owner != me->query_name() && owner != me->query_term()){
		if(time()-protect_time < 120)
			return 0;
	}
	return 1;
}

object|zero query_loot_item(object me)
{
	object env;
	array(object) all;
	if(!me || !query_loot_enabled(me))
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = all_inventory(env);
	foreach(all,object ob){
		if(can_loot_item(me,ob))
			return ob;
	}
	return 0;
}

private int is_matching_recovery_item(object item, string kind)
{
	mapping supply;
	if(!item || item->amount <= 0 || item->eat_flag != 1)
		return 0;
	supply = item->add_supplay;
	if(!supply || !sizeof(supply))
		return 0;
	if(kind == "life")
		return functionp(item->eat) && (int)supply["life_supply"] > 0;
	if(kind == "mana")
		return functionp(item->drink) && (int)supply["mofa_supply"] > 0;
	return 0;
}

object|zero query_recovery_item(object me, string kind)
{
	string setting;
	array(object) all;
	if(!me)
		return 0;
	initialize_player(me);
	if(kind == "life")
		setting = (string)me["/plus/autofight_food"];
	else
		setting = (string)me["/plus/autofight_water"];
	all = all_inventory(me);
	foreach(all,object item){
		if(setting != "auto" && setting != "" &&
		   item->query_name() != setting)
			continue;
		if(is_matching_recovery_item(item,kind))
			return item;
	}
	if(setting != "auto" && setting != ""){
		foreach(all,object item){
			if(is_matching_recovery_item(item,kind))
				return item;
		}
	}
	return 0;
}

int query_object_count(object ob, object env)
{
	array(object) all;
	int count;
	if(!ob || !env)
		return 0;
	all = all_inventory(env);
	count = 0;
	foreach(all,object item){
		if(item == ob)
			return count;
		if(item->query_name() == ob->query_name())
			count++;
	}
	return 0;
}

private int is_same_area(string current_path, string destination)
{
	array(string) current_parts;
	array(string) destination_parts;
	if(!current_path || !destination)
		return 0;
	current_path = (current_path/"#")[0];
	current_parts = current_path/"/";
	destination_parts = destination/"/";
	if(sizeof(current_parts) < 2 || sizeof(destination_parts) < 2)
		return 0;
	return current_parts[sizeof(current_parts)-2] ==
		destination_parts[sizeof(destination_parts)-2];
}

string query_safe_exit(object me)
{
	object env;
	array(string) exits;
	array(string) safe_exits;
	string current_path;
	if(!me || !query_roam_enabled(me))
		return "";
	env = environment(me);
	if(!env || !env->exits || !sizeof(env->exits))
		return "";
	current_path = file_name(env);
	exits = indices(env->exits);
	safe_exits = ({});
	foreach(exits,string direction){
		string destination;
		destination = (string)env->exits[direction];
		if(!destination || destination == "")
			continue;
		if(env->closed_exits[direction])
			continue;
		if(env->hidden_exits[direction])
			continue;
		if(env->guarded_exits[direction])
			continue;
		if(is_same_area(current_path,destination))
			safe_exits += ({direction});
	}
	if(!sizeof(safe_exits))
		return "";
	return safe_exits[random(sizeof(safe_exits))];
}
