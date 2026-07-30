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

// 方士职业天赋“灵契共鸣”的独立冷却时间
private int resonance_cooldown = 90;
private int perfect_resonance_cooldown = 120;

// 辅助函数：向房间广播消息
void tell_room_daemon(object env, string msg){
	if(!env)
		return;
	foreach(all_inventory(env), object ob){
		if(ob && ob->is("living")){
			tell_object(ob, msg);
		}
	}
}

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

	array(string) summon_types = indices(active_summons[player_name]);
	foreach(summon_types, string summon_type){
		if(!active_summons[player_name][summon_type]){
			m_delete(active_summons[player_name], summon_type);
		}
	}
	if(sizeof(active_summons[player_name]) == 0){
		m_delete(active_summons, player_name);
		return 0;
	}

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

	object summon = clone(summon_file);
	if(!summon)
		return 0;

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

	// 广播
	tell_room_daemon(env, player->query_name_cn() + "召唤出了" + summon_name + "！\n");

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
			tell_room_daemon(env, summon->query_name_cn() + "化作光芒消失了。\n");
		}
		destruct(summon);
	}
}

/**
 * 只清理召唤记录，不销毁对象。
 * 召唤物自然消失或死亡时调用，避免 SUMMOND 保留旧对象。
 */
void remove_creature_record(string player_name, string summon_type){
	if(!player_name || !summon_type)
		return;

	if(!active_summons[player_name])
		return;

	m_delete(active_summons[player_name], summon_type);
	if(sizeof(active_summons[player_name]) == 0){
		m_delete(active_summons, player_name);
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
	array(string) summon_types = indices(player_summons);
	foreach(summon_types, string summon_type){
		object summon = player_summons[summon_type];
		if(summon){
			object env = environment(summon);
			if(env){
				tell_room_daemon(env, summon->query_name_cn() + "化作光芒消失了。\n");
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
 * 获取灵兽技能的有效等级，不能超过该技能真实配置的成长上限。
 */
int get_resonance_skill_level(object player, string skill_name){
	if(!player || !player->skills)
		return 1;

	string effective_skill = skill_name;
	// 虎灵·秘通过高级秘籍替换虎灵，共鸣必须继承高级技能等级。
	if(skill_name == "huling" && player->skills["huling_mystic"])
		effective_skill = "huling_mystic";
	if(!player->skills[effective_skill])
		return 1;

	int skill_level = (int)player->skills[effective_skill][0];
	int skill_level_max = 10;
	object|zero skill = MUD_SKILLSD[effective_skill];
	if(!skill){
		mixed err = catch {
			skill = (object)(ROOT +
				"/gamelib/single/skills/" + effective_skill);
		};
		if(err)
			skill = 0;
	}
	if(skill && skill->query_skill_level_max)
		skill_level_max = (int)skill->query_skill_level_max();
	if(skill_level < 1)
		skill_level = 1;
	if(skill_level > skill_level_max)
		skill_level = skill_level_max;
	return skill_level;
}

/**
 * 获取当前在主人身边的灵兽组合与共鸣冷却。
 */
mapping get_resonance_state(object player){
	mapping result = ([
		"valid":0,
		"count":0,
		"huling":0,
		"heling":0,
		"guiling":0,
		"perfect":0,
		"cooldown":0,
	]);
	if(!player || player->query_profeId() != "fangshi")
		return result;

	result["valid"] = 1;
	string player_name = player->query_name();
	object env = environment(player);
	get_current_summon_count(player_name);
	mapping summons = get_player_summons(player_name);

	if(env && summons["huling"] &&
	   environment(summons["huling"]) == env){
		result["huling"] = 1;
		result["count"]++;
	}
	if(env && summons["heling"] &&
	   environment(summons["heling"]) == env){
		result["heling"] = 1;
		result["count"]++;
	}
	if(env && summons["guiling"] &&
	   environment(summons["guiling"]) == env){
		result["guiling"] = 1;
		result["count"]++;
	}
	if(result["count"] == 3)
		result["perfect"] = 1;

	int cooldown_left =
		(int)player["/plus/fangshi/resonance_until"] - time();
	if(cooldown_left < 0)
		cooldown_left = 0;
	result["cooldown"] = cooldown_left;
	return result;
}

/**
 * 虎契：只缩短方士技能当前仍在冷却中的时间。
 */
int reduce_resonance_cooldowns(object player, int seconds){
	if(!player || !player->f_skills || seconds <= 0)
		return 0;

	int affected = 0;
	array(string) skill_names = indices(player->f_skills);
	foreach(skill_names, string skill_name){
		object|zero skill = 0;
		mixed err = catch {
			skill = (object)(ROOT +
				"/gamelib/single/skills/" + skill_name);
		};
		if(err || !skill || search(skill->skill_type, "fangshi") == -1)
			continue;

		int before = (int)player->f_skills[skill_name];
		if(before <= 1)
			continue;
		int after = before - seconds;
		if(after < 1)
			after = 1;
		player->f_skills[skill_name] = after;
		affected++;
	}
	return affected;
}

/**
 * 鹤契：按生命上限治疗一个成员，并遵循既有减疗规则。
 */
int heal_resonance_member(object member, int percent){
	if(!member || percent <= 0)
		return 0;

	int life_before = member->get_cur_life();
	if(life_before <= 0)
		return 0;
	int life_limit = member->query_life_max();
	int heal_amount = life_limit * percent / 100;
	if(heal_amount < 1)
		heal_amount = 1;
	if(member->query_debuff("curse",0) == "life"){
		int heal_reduce = (int)member->query_debuff("curse",1);
		if(heal_reduce < 0)
			heal_reduce = 0;
		if(heal_reduce > 90)
			heal_reduce = 90;
		heal_amount = heal_amount * (100-heal_reduce) / 100;
	}

	int life_after = life_before + heal_amount;
	if(life_after > life_limit)
		life_after = life_limit;
	member->set_life(life_after);
	return life_after-life_before;
}

/**
 * 龟契：普通共鸣净化持续伤害和诅咒，三灵共鸣额外解除技能封禁。
 */
int cleanse_resonance_member(object member, int clean_control){
	if(!member)
		return 0;
	if(member->get_cur_life() <= 0)
		return 0;

	int cleansed = 0;
	array(string) debuff_names = ({"dot", "curse"});
	foreach(debuff_names, string debuff_name){
		if(member->query_debuff(debuff_name,0) != "none"){
			member->clean_debuff(debuff_name);
			cleansed++;
		}
	}
	if(clean_control && member->query_debuff("curse2",0) != "none"){
		member->clean_debuff("curse2");
		cleansed++;
	}
	return cleansed;
}

/**
 * 获取共鸣影响的自己与同房间队友。
 */
array(object) get_resonance_members(object player){
	array(object) members = ({player});
	if(!player)
		return ({});

	string team_id = player->query_term();
	object env = environment(player);
	if(!env || team_id == "" || team_id == "noterm")
		return members;

	foreach(all_inventory(env), object member){
		if(member == player || !member->is("player") ||
		   member->query_term() != team_id)
			continue;
		members += ({member});
	}
	return members;
}

/**
 * 方士职业天赋：灵契共鸣。
 *
 * 虎灵缩短技能冷却，鹤灵治疗自己与同队成员，龟灵净化负面状态；
 * 三灵同时在场时额外恢复仙力并解除公共冷却。
 */
mapping activate_resonance(object player){
	mapping result = ([
		"success":0,
		"reason":"invalid",
		"count":0,
		"huling":0,
		"heling":0,
		"guiling":0,
		"perfect":0,
		"cooldown":0,
		"cooldown_seconds":0,
		"cooldown_skills":0,
		"heal_percent":0,
		"healed_members":0,
		"healed_life":0,
		"cleansed":0,
		"mofa_restored":0,
	]);
	if(!player || player->query_profeId() != "fangshi"){
		result["reason"] = "profession";
		return result;
	}
	if(player->get_cur_life() <= 0){
		result["reason"] = "dead";
		return result;
	}

	mapping state = get_resonance_state(player);
	result["count"] = state["count"];
	result["huling"] = state["huling"];
	result["heling"] = state["heling"];
	result["guiling"] = state["guiling"];
	result["perfect"] = state["perfect"];
	result["cooldown"] = state["cooldown"];
	if(state["count"] <= 0){
		result["reason"] = "no_summon";
		return result;
	}
	if(state["cooldown"] > 0){
		result["reason"] = "cooldown";
		return result;
	}

	int current_resonance_cooldown = resonance_cooldown;
	if(state["perfect"])
		current_resonance_cooldown = perfect_resonance_cooldown;
	player["/plus/fangshi/resonance_until"] =
		time() + current_resonance_cooldown;
	result["success"] = 1;
	result["reason"] = "success";
	result["cooldown"] = current_resonance_cooldown;

	array(object) members = get_resonance_members(player);
	if(state["huling"]){
		int tiger_level = get_resonance_skill_level(player, "huling");
		int cooldown_seconds = 3 + (tiger_level-1)*3/4;
		if(cooldown_seconds > 6)
			cooldown_seconds = 6;
		result["cooldown_seconds"] = cooldown_seconds;
		result["cooldown_skills"] =
			reduce_resonance_cooldowns(player, cooldown_seconds);
	}
	if(state["heling"]){
		int crane_level = get_resonance_skill_level(player, "heling");
		int heal_percent = 6 + (crane_level-1)*6/4;
		if(state["perfect"])
			heal_percent += 3;
		result["heal_percent"] = heal_percent;
		foreach(members, object member){
			int healed = heal_resonance_member(member, heal_percent);
			result["healed_life"] += healed;
			if(healed > 0)
				result["healed_members"]++;
		}
	}
	if(state["guiling"]){
		foreach(members, object member){
			result["cleansed"] +=
				cleanse_resonance_member(member, state["perfect"]);
		}
	}
	if(state["perfect"]){
		int mofa_before = player->get_cur_mofa();
		int mofa_after = mofa_before + player->query_mofa_max()*15/100;
		if(mofa_after > player->query_mofa_max())
			mofa_after = player->query_mofa_max();
		player->set_mofa(mofa_after);
		player->timeCold = 0;
		result["mofa_restored"] = mofa_after-mofa_before;
	}

	object env = environment(player);
	if(env){
		if(state["perfect"])
			tell_room_daemon(env, "虎啸、鹤鸣、龟甲三道灵光交汇，" +
				player->query_name_cn() + "发动了【三灵共鸣】！\n");
		else
			tell_room_daemon(env, player->query_name_cn() +
				"与身边灵兽缔结灵契，发动了【灵契共鸣】！\n");
	}
	return result;
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
