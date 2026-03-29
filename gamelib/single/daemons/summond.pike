/**
 * ========================================================================
 * Summon Daemon - 召唤系统守护进程
 * ========================================================================
 *
 * 管理所有方士的召唤物
 *
 * ========================================================================
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

// 每个玩家的召唤物映射
// 格式: master_name -> ([召唤物类型: 召唤物对象])
private mapping(string:mapping) active_summons = ([]);

// 每个玩家的最大召唤数量
private mapping(string:int) max_summons = ([]);

/**
 * 获取玩家的最大召唤数量
 */
int get_max_summons(string player_name){
	if(!player_name)
		return 1;

	object player = find_player(player_name);
	if(!player)
		return 1;

	// 方士职业根据等级可以召唤更多灵兽
	if(player->query_profeId() == "fangshi"){
		int level = player->query_level();
		if(level < 30)
			return 1;
		else if(level < 60)
			return 2;
		else
			return 3;  // 高级方士可以同时召唤3只
	}

	return 1;
}

/**
 * 获取玩家当前的召唤数量
 */
int get_current_summon_count(string player_name){
	if(!player_name || !active_summons[player_name])
		return 0;

	return sizeof(active_summons[player_name]);
}

/**
 * 检查玩家是否可以召唤
 */
int can_summon(string player_name){
	if(!player_name)
		return 0;

	int current = get_current_summon_count(player_name);
	int max = get_max_summons(player_name);

	return current < max;
}

/**
 * 召唤灵兽
 * 返回: 召唤物对象，失败返回0
 */
object summon_creature(string player_name, string summon_type, int duration, int skill_level){
	if(!player_name || !summon_type)
		return 0;

	// 检查是否可以召唤
	if(!can_summon(player_name))
		return 0;

	// 检查是否已有同类型召唤
	if(active_summons[player_name] && active_summons[player_name][summon_type])
		return 0;

	object player = find_player(player_name);
	if(!player)
		return 0;

	int player_level = player->query_level();
	object env = environment(player);
	if(!env)
		return 0;

	// 创建召唤物
	string summon_file = "";
	string summon_name = "";

	switch(summon_type){
		case "huling":
			summon_file = ROOT "/gamelib/clone/npc/summon/huling";
			summon_name = "猛虎灵兽";
			break;
		case "heling":
			summon_file = ROOT "/gamelib/clone/npc/summon/heling";
			summon_name = "仙鹤灵兽";
			break;
		case "guiling":
			summon_file = ROOT "/gamelib/clone/npc/summon/guiling";
			summon_name = "灵龟神兽";
			break;
		default:
			return 0;
	}

	object summon = load_object(summon_file);
	if(!summon){
		summon = new(summon_file);
		if(!summon)
			return 0;
	}

	// 设置召唤物属性
	summon->set_master(player_name);
	summon->set_summon_duration(duration);
	summon->adjust_stats_by_player(player_level, skill_level);

	// 移动到主人所在房间
	summon->move(env);

	// 记录召唤物
	if(!active_summons[player_name])
		active_summons[player_name] = ([]);

	active_summons[player_name][summon_type] = summon;

	// 设置心跳
	summon->set_heart_beat(1);

	// 广播
	tell_room(env, player->query_name_cn() + "召唤出了" + summon_name + "！\n");

	return summon;
}

/**
 * 解除召唤
 */
void dismiss_creature(string player_name, string summon_type){
	if(!player_name || !summon_type)
		return;

	if(!active_summons[player_name])
		return;

	// 先从映射中移除，避免重复调用
	object summon = m_delete(active_summons[player_name], summon_type);

	// 如果没有召唤物了，清理玩家记录
	if(sizeof(active_summons[player_name]) == 0){
		m_delete(active_summons, player_name);
	}

	// 然后销毁召唤物对象
	if(summon){
		object env = environment(summon);
		if(env){
			tell_room(env, summon->query_name_cn() + "化作光芒消失了。\n");
		}
		destruct(summon);
	}
}

/**
 * 解除玩家所有召唤
 */
void dismiss_all(string player_name){
	if(!player_name)
		return;

	if(!active_summons[player_name])
		return;

	// 获取所有召唤物并清空映射
	mapping player_summons = active_summons[player_name];
	m_delete(active_summons, player_name);

	// 逐个销毁召唤物
	foreach(player_summons, string summon_type){
		object summon = player_summons[summon_type];
		if(summon){
			object env = environment(summon);
			if(env){
				tell_room(env, summon->query_name_cn() + "化作光芒消失了。\n");
			}
			destruct(summon);
		}
	}
}

/**
 * 获取玩家的召唤物列表
 */
mapping get_player_summons(string player_name){
	if(!player_name)
		return ([]);

	return active_summons[player_name] || ([]);
}

/**
 * 玩家下线时清除所有召唤
 */
void player_logout(string player_name){
	dismiss_all(player_name);
}

/**
 * 三灵合一 - 同时召唤三只灵兽
 * 返回召唤的灵兽数量
 */
int summon_all_spirits(string player_name, int duration, int skill_level){
	if(!player_name)
		return 0;

	object player = find_player(player_name);
	if(!player)
		return 0;

	int count = 0;
	array(string) summon_types = ({"huling", "heling", "guiling"});

	foreach(summon_types, string summon_type){
		object s = summon_creature(player_name, summon_type, duration, skill_level);
		if(s)
			count++;
	}

	return count;
}
