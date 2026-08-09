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

// 方士职业天赋“灵契共鸣”的独立冷却时间
private int resonance_cooldown = 90;
private int perfect_resonance_cooldown = 120;

// 辅助函数：向房间广播消息
void tell_room_daemon(object env, string msg, void|object actor){
	if(!env)
		return;
	foreach(all_inventory(env,actor), object ob){
		if(actor && ob && ob->is("player") &&
		   !LOGICALZONED->is_visible(ob,actor))
			continue;
		if(ob && (ob->is("player") || ob->is("npc"))){
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
		object summon = active_summons[player_name][summon_type];
		if(!summon || summon->get_cur_life() <= 0){
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
 * 查询单只灵兽对应的已学技能。
 * 高级虎灵会替换基础虎灵，但仍保留召唤授权。
 */
string query_summon_skill_name(object player, string summon_type){
	if(!player || player->query_profeId() != "fangshi" || !player->skills)
		return "";
	if(summon_type == "huling"){
		if(player->skills["huling_mystic"])
			return "huling_mystic";
		if(player->skills["huling"])
			return "huling";
		return "";
	}
	if(summon_type == "heling" && player->skills["heling"])
		return "heling";
	if(summon_type == "guiling" && player->skills["guiling"])
		return "guiling";
	return "";
}

/**
 * 查询三灵合一对应的已学技能。
 */
string query_all_spirits_skill_name(object player){
	if(!player || player->query_profeId() != "fangshi" || !player->skills)
		return "";
	if(player->skills["sanlingheyi2"])
		return "sanlingheyi2";
	if(player->skills["sanlingheyi"])
		return "sanlingheyi";
	return "";
}

/**
 * 从人物真实技能数据取得有效等级，并限制在技能配置上限内。
 */
int query_authorized_skill_level(object player, string skill_name){
	if(!player || !skill_name || !player->skills ||
	   !player->skills[skill_name])
		return 0;

	int skill_level = (int)player->skills[skill_name][0];
	int skill_level_max = 0;
	object|zero skill = MUD_SKILLSD[skill_name];
	if(!skill){
		mixed err = catch {
			skill = (object)(ROOT +
				"/gamelib/single/skills/" + skill_name);
		};
		if(err)
			skill = 0;
	}
	if(!skill || !skill->query_skill_level_max)
		return 0;
	if(skill && skill->query_skill_level_max)
		skill_level_max = (int)skill->query_skill_level_max();
	if(skill_level < 1)
		return 0;
	if(skill_level > skill_level_max)
		skill_level = skill_level_max;
	return skill_level;
}

/**
 * 校验存活召唤物与主人的职业、技能授权是否仍然匹配。
 * 方士沿用三灵技能；无相/太极只允许各自的阴阳灵兽。
 */
private int is_authorized_summon_owner(object player,string summon_type){
	string skill_name;
	if(!player || !summon_type || !player->skills)
		return 0;
	if(summon_type=="balanced_spirit"){
		if(player->query_profeId()=="wuxiang")
			skill_name = "wuxianghuan";
		else if(player->query_profeId()=="taiji")
			skill_name = "taijihuan";
		else
			return 0;
	}
	else{
		if(player->query_profeId()!="fangshi")
			return 0;
		skill_name = query_summon_skill_name(player,summon_type);
	}
	return skill_name!="" &&
		query_authorized_skill_level(player,skill_name)>0;
}

/**
 * 单只召唤持续时间完全由服务端真实技能等级计算。
 */
int query_single_summon_duration(int skill_level){
	int duration = 600 + skill_level*60;
	if(duration < 660)
		duration = 660;
	if(duration > 900)
		duration = 900;
	return duration;
}

/**
 * 三灵合一持续时间完全由服务端真实技能等级计算。
 */
int query_all_spirits_duration(int skill_level){
	int duration = 300 + skill_level*60;
	if(duration < 360)
		duration = 360;
	if(duration > 600)
		duration = 600;
	return duration;
}

/**
 * 召唤类型白名单。
 */
int is_valid_summon_type(string summon_type){
	return search(({"huling","heling","guiling","balanced_spirit"}),
		summon_type) != -1;
}

/**
 * 已通过职业与技能鉴权后的内部召唤实现。
 */
private object create_authorized_summon(object player, string player_name,
	string summon_type, int duration, int skill_level, int broadcast){
	if(!player || !player_name || !summon_type || skill_level <= 0)
		return 0;

	// 检查是否可以召唤
	if(!can_summon(player_name))
		return 0;

	// 检查是否已有同类型召唤
	if(active_summons[player_name] && active_summons[player_name][summon_type])
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
		case "balanced_spirit":
			summon_file = ROOT "/gamelib/clone/npc/summon/huling";
			summon_name = "阴阳灵兽";
			break;
		default:
			return 0;
	}

	object summon = clone(summon_file);
	if(!summon)
		return 0;

	// 设置召唤物属性
	summon->set_summon_type(summon_type);
	summon->set_master(player_name);
	summon->set_summon_skill_level(skill_level);
	summon->set_summon_duration(duration);
	summon->adjust_stats_by_player(player_level, skill_level);
	// 永久职业外观只修改灵兽名称和描述，所有数值计算已经完成且不变。
	PROFESSIONVIPD->decorate_summon(player,summon);

	// 移动到主人所在房间
	summon->move(env);
	if(environment(summon) != env){
		destruct(summon);
		return 0;
	}

	// 记录召唤物
	if(!active_summons[player_name])
		active_summons[player_name] = ([]);

	active_summons[player_name][summon_type] = summon;

	// 广播
	if(broadcast)
		tell_room_daemon(env,
			player->query_name_cn() + "召唤出了" +
			summon->query_name_cn() + "！\n",player);

	return summon;
}

/**
 * 无相/太极的五分钟弱版灵兽。职业、技能名与真实已学等级都由守护进程
 * 重新验证，施法层传入的等级和持续时间不能放大召唤物。
 */
object summon_balanced_spirit(string player_name,string skill_name){
	object player;
	object summon;
	string expected_skill;
	int skill_level;
	int scaled_level;
	if(!player_name || !skill_name)
		return 0;
	player = find_player(player_name);
	if(!player)
		return 0;
	if(player->query_profeId()=="wuxiang")
		expected_skill = "wuxianghuan";
	else if(player->query_profeId()=="taiji")
		expected_skill = "taijihuan";
	else
		return 0;
	if(skill_name!=expected_skill || !player->skills ||
	   !player->skills[expected_skill])
		return 0;
	skill_level = query_authorized_skill_level(player,expected_skill);
	if(skill_level<=0)
		return 0;
	summon = create_authorized_summon(player,player_name,
		"balanced_spirit",300,skill_level,0);
	if(!summon)
		return 0;
	// 使用半数人物等级生成，明确低于方士专精虎灵。
	scaled_level = player->query_level()/2;
	if(scaled_level<1)
		scaled_level = 1;
	summon->adjust_stats_by_player(scaled_level,skill_level);
	summon->name_cn = player->query_profeId()=="taiji" ?
		"太极阴阳灵兽" : "无相阴阳灵兽";
	tell_room_daemon(environment(player),player->query_name_cn()+
		"唤出了一只"+summon->query_name_cn()+"助战！\n",player);
	return summon;
}

/**
 * 召唤单只灵兽。
 * 守护进程必须自行校验职业和已学技能，不能信任命令层传入的等级。
 */
object summon_creature(string player_name, string summon_type,
	int _duration, int _skill_level){
	if(!player_name || !summon_type)
		return 0;

	object player = find_player(player_name);
	if(!player || player->query_profeId() != "fangshi")
		return 0;
	string skill_name = query_summon_skill_name(player, summon_type);
	if(skill_name == "")
		return 0;
	int skill_level = query_authorized_skill_level(player, skill_name);
	if(skill_level <= 0)
		return 0;
	return create_authorized_summon(
		player, player_name, summon_type,
		query_single_summon_duration(skill_level), skill_level, 1);
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
			tell_room_daemon(env, summon->query_name_cn() +
				"化作光芒消失了。\n",summon);
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
				tell_room_daemon(env, summon->query_name_cn() +
					"化作光芒消失了。\n",summon);
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
	get_current_summon_count(player_name);
	if(!active_summons[player_name])
		return ([]);
	return copy_value(active_summons[player_name]);
}

/**
 * Capture only reconstructable summon state for a fenced worker handoff.
 * Objects themselves never cross a process boundary. Absolute expiry prevents
 * retries or a slow migration from extending duration, and HP is restored as
 * a ratio against server-recomputed attributes rather than trusting old stats.
 */
mapping(string:mapping(string:int)) snapshot_worker_handoff(object player){
	mapping(string:mapping(string:int)) snapshot = ([]);
	string player_name;
	object env;
	if(!player || !functionp(player->query_name) || !environment(player))
		return snapshot;
	player_name = (string)player->query_name();
	env = environment(player);
	foreach(sort(indices(get_player_summons(player_name))),string summon_type){
		object summon = active_summons[player_name] &&
			active_summons[player_name][summon_type];
		int remaining;
		int life_max;
		if(!is_valid_summon_type(summon_type) || !summon ||
		   environment(summon)!=env || summon->get_cur_life()<=0 ||
		   !functionp(summon->query_summon_remaining))
			continue;
		remaining = (int)summon->query_summon_remaining();
		life_max = max(1,(int)summon->query_life_max());
		if(remaining<1)
			continue;
		snapshot[summon_type] = ([
			"expires_at":time()+remaining,
			"life":max(1,(int)summon->get_cur_life()),
			"life_max":life_max,
		]);
	}
	return snapshot;
}

/** Restore one-shot handoff data after the player has reached its fenced room. */
int restore_worker_handoff(object player,mapping snapshot){
	string player_name;
	int restored;
	if(!player || !environment(player) || !mappingp(snapshot) ||
	   sizeof(snapshot)>4)
		return 0;
	player_name = (string)player->query_name();
	foreach(sort(indices(snapshot)),mixed raw_type){
		string summon_type = stringp(raw_type) ? (string)raw_type : "";
		mapping state = snapshot[raw_type];
		string skill_name = "";
		int skill_level;
		int remaining;
		int max_duration;
		int old_life;
		int old_life_max;
		object summon;
		if(!is_valid_summon_type(summon_type) || !mappingp(state))
			continue;
		if(summon_type=="balanced_spirit"){
			if(player->query_profeId()=="wuxiang")
				skill_name = "wuxianghuan";
			else if(player->query_profeId()=="taiji")
				skill_name = "taijihuan";
			max_duration = 300;
		}
		else
			skill_name = query_summon_skill_name(player,summon_type);
		skill_level = query_authorized_skill_level(player,skill_name);
		if(skill_level<1)
			continue;
		if(max_duration<1)
			max_duration = query_single_summon_duration(skill_level);
		remaining = min(max_duration,(int)state["expires_at"]-time());
		// The summon base class intentionally clamps duration to 60 seconds.
		// Dropping a nearly expired summon is safer than extending it on travel.
		if(remaining<60)
			continue;
		old_life = (int)state["life"];
		old_life_max = (int)state["life_max"];
		if(old_life<1 || old_life_max<1 || old_life>old_life_max)
			continue;
		summon = create_authorized_summon(player,player_name,
			summon_type,remaining,skill_level,0);
		if(!summon)
			continue;
		if(summon_type=="balanced_spirit"){
			int scaled_level = max(1,(int)player->query_level()/2);
			summon->adjust_stats_by_player(scaled_level,skill_level);
			summon->name_cn = player->query_profeId()=="taiji" ?
				"太极阴阳灵兽" : "无相阴阳灵兽";
		}
		int new_life_max = max(1,(int)summon->query_life_max());
		int restored_life = max(1,min(new_life_max,
			new_life_max*old_life/old_life_max));
		summon->set_life(restored_life);
		restored++;
	}
	return restored;
}

/**
 * 守护进程热更新后，存活灵兽可从心跳恢复登记。
 * 同类型已有有效对象时拒绝后到对象，避免产生双灵兽。
 */
int register_existing_summon(string player_name, string summon_type,
	object summon){
	if(!player_name || !is_valid_summon_type(summon_type) || !summon ||
	   summon->get_cur_life() <= 0 ||
	   summon->query_profeId() != "beast" ||
	   summon->query_master() != player_name ||
	   summon->query_summon_type() != summon_type)
		return 0;

	object player = find_player(player_name);
	if(!player || !environment(player) ||
	   !is_authorized_summon_owner(player,summon_type))
		return 0;

	get_current_summon_count(player_name);
	if(active_summons[player_name] &&
	   active_summons[player_name][summon_type]){
		return active_summons[player_name][summon_type] == summon;
	}
	if(get_current_summon_count(player_name) >=
	   get_max_summons(player_name))
		return 0;
	if(!active_summons[player_name])
		active_summons[player_name] = ([]);
	active_summons[player_name][summon_type] = summon;
	return 1;
}

/**
 * 检查登记对象是否仍是主人身边存活的对应灵兽。
 */
int is_living_summon(object summon, object env,
	string player_name, string summon_type){
	if(!summon || !env || summon->get_cur_life() <= 0 ||
	   environment(summon) != env ||
	   summon->query_master() != player_name ||
	   summon->query_summon_type() != summon_type)
		return 0;
	return 1;
}

/**
 * 灵兽造成最后一击时，战斗奖励与PK记录归属其在线主人。
 */
object query_combat_credit_owner(object actor){
	if(!actor || !actor->query_master || !actor->query_summon_type)
		return actor;
	string owner_name = (string)actor->query_master();
	string summon_name = (string)actor->query_summon_type();
	if(owner_name == "" || !is_valid_summon_type(summon_name) ||
	   actor->query_profeId() != "beast")
		return actor;
	object owner = find_player(owner_name);
	if(!is_authorized_summon_owner(owner,summon_name))
		return actor;
	return owner;
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

	if(is_living_summon(
	   summons["huling"],env,player_name,"huling")){
		result["huling"] = 1;
		result["count"]++;
	}
	if(is_living_summon(
	   summons["heling"],env,player_name,"heling")){
		result["heling"] = 1;
		result["count"]++;
	}
	if(is_living_summon(
	   summons["guiling"],env,player_name,"guiling")){
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

	foreach(all_inventory(env,player), object member){
		if(member == player || !member->is("player") ||
		   member->query_term() != team_id ||
		   !LOGICALZONED->can_action("team",player,member))
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
				player->query_name_cn() + "发动了【三灵共鸣】！\n",player);
		else
			tell_room_daemon(env, player->query_name_cn() +
				"与身边灵兽缔结灵契，发动了【灵契共鸣】！\n",player);
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
 * 玩家死亡时立即解除所有召唤。
 */
void player_death(string player_name){
	dismiss_all(player_name);
}

/**
 * 三灵合一 - 同时召唤三只灵兽
 * 返回召唤的灵兽数量
 */
int summon_all_spirits(string player_name, int _duration, int _skill_level){
	if(!player_name)
		return 0;

	object player = find_player(player_name);
	if(!player || player->query_profeId() != "fangshi")
		return 0;
	string skill_name = query_all_spirits_skill_name(player);
	if(skill_name == "")
		return 0;
	int skill_level = query_authorized_skill_level(player, skill_name);
	if(skill_level <= 0)
		return 0;

	// 50级学习技能，60级召唤上限达到3后才开放三只实体灵兽。
	if(get_max_summons(player_name) < 3)
		return 0;

	array(string) summon_types = ({"huling", "heling", "guiling"});
	array(string) missing_types = ({});
	array(string) created_types = ({});
	mapping existing = get_player_summons(player_name);
	foreach(summon_types, string summon_type){
		if(!existing[summon_type])
			missing_types += ({summon_type});
	}
	if(sizeof(missing_types) == 0)
		return 0;
	if(get_current_summon_count(player_name) + sizeof(missing_types) >
	   get_max_summons(player_name))
		return 0;

	int duration = query_all_spirits_duration(skill_level);
	foreach(missing_types, string summon_type){
		object s = create_authorized_summon(
			player, player_name, summon_type,
			duration, skill_level, 0);
		if(!s){
			foreach(created_types, string created_type){
				object created = active_summons[player_name] &&
					active_summons[player_name][created_type];
				remove_creature_record(player_name, created_type);
				if(created)
					destruct(created);
			}
			return 0;
		}
		created_types += ({summon_type});
	}

	tell_room_daemon(environment(player), player->query_name_cn() +
		"施展三灵合一，虎、鹤、龟三道灵光同时降临！\n",player);
	return sizeof(created_types);
}
