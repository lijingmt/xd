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

// 向房间广播消息
void summon_tell_room(object env, string msg){
	if(!env)
		return;
	foreach(all_inventory(env), object ob){
		if(ob && ob->is("living")){
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
	summon_start_time = time();
	call_out(check_duration, 60);  // 每分钟检查一次
}

void set_master(string name){
	master_name = name;
}

string query_master(){
	return master_name;
}

void set_summon_duration(int seconds){
	summon_duration = seconds;
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
	if(!master){
		remove_summon_record();
		destruct(this_object());
		return;
	}

	// 检查主人是否在战斗中死亡
	if(master->get_cur_life() <= 0){
		object env = environment(this_object());
		if(env){
			summon_tell_room(env, query_name_cn() + "化作一道光芒消失了。\n");
		}
		remove_summon_record();
		destruct(this_object());
		return;
	}

	// 继续检查
	call_out(check_duration, 60);
}

/**
 * 心跳 - 处理跟随和攻击
 */
void heart_beat(){
	::heart_beat();

	if(!master_name)
		return;

	object master = find_player(master_name);
	if(!master){
		remove_summon_record();
		destruct(this_object());
		return;
	}

	// 检查是否在同一房间
	object my_env = environment(this_object());
	object master_env = environment(master);

	if(!master_env){
		// 主人没有环境，可能已死亡或离线
		return;
	}

	if(my_env != master_env){
		// 不在同一房间，跟随主人
		if(my_env){
			summon_tell_room(my_env, query_name_cn() + "急匆匆地离开了。\n");
		}
		this_object()->move(master_env);
		summon_tell_room(master_env, query_name_cn() + "急匆匆地赶了过来。\n");
	}

	// 如果主人在战斗中，参与战斗
	if(master->query_in_combat()){
		object enemy = master->query_enemy();
		if(enemy && enemy->get_cur_life() > 0){
			// 如果召唤物不在战斗中，开始攻击
			if(!this_object()->query_in_combat()){
				this_object()->kill(enemy->query_name(), 0);
				my_env = environment(this_object()); // 更新环境引用
				if(my_env){
					summon_tell_room(my_env, query_name_cn() + "愤怒地冲向" + enemy->query_name_cn() + "！\n");
				}
			}
			// 如果已在战斗中，确保目标正确
			else if(this_object()->query_enemy() != enemy){
				this_object()->kill(enemy->query_name(), 0);
			}
		}
	}
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

	// 如果攻击者和主人同一阵营，不能攻击
	object master = find_player(master_name);
	if(master && attacker->query_raceId() == master->query_raceId())
		return 0;

	return 1;  // 默认可以被攻击
}

/**
 * 召唤物不会被计数为击杀
 */
void add_kill_count(string name){
	// 召唤物不增加击杀计数
}
