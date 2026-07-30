#include <globals.h>
#include <wapmud2.h>
#include <gamelib/include/gamelib.h>
inherit WAP_NPC;

/**
 * 召唤物基类
 * 所有灵兽继承此类
 */

string master_name;  // 主人名字
int summon_duration; // 召唤持续时间（秒）
int summon_start_time; // 召唤开始时间
string summon_type;  // 召唤物类型: "huling", "heling", "guiling"
int summon_skill_level; // 服务端鉴权后的召唤技能等级

// 向房间广播消息
void summon_tell_room(object env, string msg){
	if(!env)
		return;
	foreach(all_inventory(env), object ob){
		if(ob && (ob->is("player") || ob->is("npc"))){
			tell_object(ob, msg);
		}
	}
}

protected void create(){
	name=object_name(this_object());
	set_raceId("third");
	set_profeId("beast");
	// 移除 _tasknpc = 1，让召唤物可以正常参与战斗
	setup_npc();
	summon_duration = 60;
	summon_start_time = time();
	set_heart_beat(1);
	call_out(check_duration, summon_duration);
}

void set_master(string name){
	master_name = name;
}

string query_master(){
	return master_name;
}

void set_summon_duration(int seconds){
	if(seconds < 60)
		seconds = 60;
	if(seconds > 900)
		seconds = 900;
	summon_duration = seconds;
	summon_start_time = time();
	remove_call_out(check_duration);
	call_out(check_duration, summon_duration);
}

int query_summon_duration(){
	return summon_duration;
}

int query_summon_remaining(){
	int remaining = summon_duration-(time()-summon_start_time);
	if(remaining < 0)
		remaining = 0;
	return remaining;
}

void set_summon_skill_level(int skill_level){
	if(skill_level < 1)
		skill_level = 1;
	if(skill_level > 10)
		skill_level = 10;
	summon_skill_level = skill_level;
}

int query_summon_skill_level(){
	return summon_skill_level;
}

void set_summon_type(string type){
	summon_type = type;
}

string query_summon_type(){
	return summon_type;
}

void remove_summon_record(){
	if(master_name && summon_type){
		SUMMOND->remove_creature_record(master_name, summon_type);
	}
}

/**
 * 主人已离线或不在任何游戏场景时立即清理召唤物。
 * 定时检查、心跳和测试共用同一条生命周期路径。
 */
int cleanup_if_master_unavailable(object|zero master){
	if(master && environment(master) && master->get_cur_life() > 0)
		return 0;
	remove_summon_record();
	destruct(this_object());
	return 1;
}

/**
 * 检查召唤持续时间
 */
void check_duration(){
	if(!master_name){
		destruct(this_object());
		return;
	}

	int elapsed = time() - summon_start_time;
	if(elapsed >= summon_duration){
		// 时间到，消失
		object env = environment(this_object());
		if(env){
			summon_tell_room(env, query_name_cn() + "化作一道光芒消失了。\n");
		}
		remove_summon_record();
		destruct(this_object());
		return;
	}

	// 检查主人是否在线
	object master = find_player(master_name);
	if(cleanup_if_master_unavailable(master))
		return;

	// 按剩余秒数精确安排下一次到期检查，避免额外存活近一分钟。
	int remaining = summon_duration-elapsed;
	if(remaining < 1)
		remaining = 1;
	call_out(check_duration, remaining);
}

/**
 * 强制灵兽聚焦主人的当前目标。
 */
int focus_summon_target(object target){
	if(get_cur_life() <= 0 || !target ||
	   (!target->is("player") && !target->is("npc")) ||
	   target->get_cur_life() <= 0 ||
	   environment(this_object()) != environment(target))
		return 0;

	int changed = query_enemy() != target;
	this_object()->kill(target,0);
	this_object()->reset_targets();
	this_object()->flush_targets(target,100);
	this_object()->enemy = target;
	return changed;
}

/**
 * 主人结束战斗后，灵兽同时解除旧目标，避免独自追打。
 */
void disengage_summon(){
	if(!query_in_combat())
		return;
	object old_enemy = query_enemy();
	if(old_enemy)
		old_enemy->clean_targets(this_object());
	_clean_fight();
}

/**
 * 心跳 - 处理跟随和攻击
 */
void heart_beat(){
	if(get_cur_life() <= 0){
		fight_die();
		return;
	}
	::heart_beat();
	if(!objectp(this_object()) || get_cur_life() <= 0)
		return;

	if(!master_name)
		return;

	object master = find_player(master_name);
	if(cleanup_if_master_unavailable(master))
		return;
	if(!SUMMOND->register_existing_summon(
	   master_name,summon_type,this_object())){
		destruct(this_object());
		return;
	}

	// 检查是否在同一房间
	object my_env = environment(this_object());
	object master_env = environment(master);

	if(my_env != master_env){
		// 不在同一房间，跟随主人
		if(my_env){
			summon_tell_room(my_env, query_name_cn() + "急匆匆地离开了。\n");
		}
		this_object()->move(master_env);
		if(environment(this_object()) != master_env){
			remove_summon_record();
			destruct(this_object());
			return;
		}
		summon_tell_room(master_env, query_name_cn() + "急匆匆地赶了过来。\n");
	}

	// 如果主人在战斗中，参与战斗
	if(master->query_in_combat()){
		object enemy = master->query_enemy();
		if(enemy && enemy->get_cur_life() > 0){
			int changed = focus_summon_target(enemy);
			if(changed){
				my_env = environment(this_object());
				if(my_env)
					summon_tell_room(my_env, query_name_cn() +
						"愤怒地冲向" + enemy->query_name_cn() + "！\n");
			}
		}
	}
	else
		disengage_summon();
}

/**
 * 覆盖死亡处理 - 召唤物死后只是消失，不掉落
 */
void fight_die(){
	object env = environment(this_object());
	if(env){
		summon_tell_room(env, query_name_cn() + "发出一声哀鸣，化作光芒消失了。\n");
	}

	object master = find_player(master_name);
	if(master){
		tell_object(master, "你的" + query_name_cn() + "已经死亡消失。\n");
	}

	// 从召唤守护进程中移除（消息已在上面发送，这里只清理数据）
	remove_summon_record();

	destruct(this_object());
}

/**
 * 不能被玩家攻击（除非是PVP）
 */
int can_be_attacked(object attacker){
	if(!attacker)
		return 0;

	// 如果攻击者是主人，不能攻击
	if(attacker->query_name() == master_name)
		return 0;

	// 有效队伍始终受到保护。
	object master = find_player(master_name);
	if(master){
		string master_team = master->query_term();
		if(master_team != "" && master_team != "noterm" &&
		   attacker->query_term() == master_team)
			return 0;

		// 同阵营默认保护，但正式决斗和帮战双方可以攻击灵兽。
		if(attacker->query_raceId() == master->query_raceId()){
			if(attacker->is("player") &&
			   attacker->kill_flag == 0 && master->kill_flag == 0)
				return 1;
			if(attacker->bangid && master->bangid &&
			   BANGZHAND->is_in_bangzhan(
				attacker->bangid,master->bangid))
				return 1;
			return 0;
		}
	}

	return 1;  // 默认可以被攻击
}

/**
 * 召唤物不会被计数为击杀
 */
void add_kill_count(string name){
	// 召唤物不增加击杀计数
}
