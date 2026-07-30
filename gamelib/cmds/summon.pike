#include <command.h>
#include <gamelib/include/gamelib.h>

/**
 * 召唤灵兽命令
 * 方士使用已学技能召唤灵兽
 */
int main(string|zero arg)
{
	object me = this_player();
	string s = "";

	if(!me)
		return 0;

	// 检查是否是方士
	if(me->query_profeId() != "fangshi"){
		s += "只有方士才能召唤灵兽！\n";
		me->write(s);
		return 1;
	}

	// 显示召唤帮助
	if(!arg){
		s += "【召唤灵兽】\n\n";
		s += "方士可以召唤以下灵兽：\n\n";
		s += "[召唤虎灵:summon huling] - 物理攻击型\n";
		s += "[召唤鹤灵:summon heling] - 治疗辅助型\n";
		s += "[召唤龟灵:summon guiling] - 防御坦克型\n";
		s += "[三灵合一:summon all] - 60级起同时召唤三只灵兽\n\n";
		s += "【方士专属·灵契共鸣】\n";
		s += "虎契缩短方士技能冷却，鹤契治疗自己与同队成员，";
		s += "龟契净化持续伤害和诅咒；";
		s += "三灵齐聚还会解除技能封禁并恢复仙力。\n";
		s += "普通共鸣冷却90秒，三灵共鸣冷却120秒。\n";
		s += "[发动灵契共鸣:summon resonance]\n\n";
		s += "[查看当前召唤:summon list]\n";
		s += "[解除所有召唤:summon dismiss]\n";
		s += "[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	if(arg == "list"){
		mapping summons = SUMMOND->get_player_summons(me->query_name());
		s += "【当前召唤】\n\n";
		if(sizeof(summons) == 0){
			s += "你当前没有召唤任何灵兽。\n";
		}
		else{
			foreach(summons; string summon_type; object summon){
				if(summon){
					s += summon->query_name_cn() + " - " + summon_type + "\n";
				}
			}
		}
		mapping resonance_state = SUMMOND->get_resonance_state(me);
		s += "\n【灵契共鸣】\n";
		if(resonance_state["count"] == 0){
			s += "暂无在你身边的灵兽，无法发动共鸣。\n";
		}
		else{
			s += "当前灵契：" + resonance_state["count"] + "道";
			if(resonance_state["perfect"])
				s += "（三灵齐聚）";
			s += "\n";
			if(resonance_state["huling"])
				s += "虎契·破军：缩短方士技能冷却\n";
			if(resonance_state["heling"])
				s += "鹤契·回春：治疗自己与同队成员\n";
			if(resonance_state["guiling"])
				s += "龟契·净厄：净化持续伤害和诅咒\n";
			if(resonance_state["perfect"])
				s += "三灵加护：额外解除技能封禁\n";
			if(resonance_state["cooldown"] > 0)
				s += "共鸣还需冷却" + resonance_state["cooldown"] + "秒。\n";
			else
				s += "[发动灵契共鸣:summon resonance]\n";
		}
		s += "\n[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	if(arg == "resonance" || arg == "gongming"){
		mapping result = SUMMOND->activate_resonance(me);
		if(!result["success"]){
			if(result["reason"] == "no_summon")
				s += "你身边没有灵兽，无法缔结灵契。\n";
			else if(result["reason"] == "cooldown")
				s += "灵契共鸣还需冷却" + result["cooldown"] + "秒。\n";
			else if(result["reason"] == "dead")
				s += "你已失去战斗能力，无法发动灵契共鸣。\n";
			else
				s += "只有方士才能发动灵契共鸣。\n";
			s += "[查看灵契状态:summon list]\n[返回游戏:look]\n";
			me->write(s);
			return 1;
		}

		s += "【灵契共鸣】你与" + result["count"] +
			"只灵兽心意相通！\n";
		if(result["huling"])
			s += "虎契·破军：缩短" + result["cooldown_skills"] +
				"个技能" + result["cooldown_seconds"] + "秒冷却。\n";
		if(result["heling"])
			s += "鹤契·回春（" + result["heal_percent"] + "%）：为" +
				result["healed_members"] +
				"名成员恢复共" + result["healed_life"] + "点生命。\n";
		if(result["guiling"])
			s += "龟契·净厄：净化" + result["cleansed"] +
				"个负面状态。\n";
		if(result["perfect"])
			s += "三灵共鸣：额外恢复" + result["mofa_restored"] +
				"点仙力，并解除公共冷却！\n";
		s += "[查看灵契状态:summon list]\n[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	if(arg == "dismiss"){
		SUMMOND->dismiss_all(me->query_name());
		s += "你解除了所有灵兽的召唤。\n[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	// 解析召唤参数
	string summon_type = arg;
	int duration = 600; // 默认10分钟
	int skill_level = 1;

	// 检查技能等级
	mapping skills = me->skills;
	string huling_skill = "huling";
	if(skills && skills["huling_mystic"])
		huling_skill = "huling_mystic";
	if(skills && skills[huling_skill]){
		// 虎灵·秘会替换虎灵，但仍应保留虎灵召唤能力。
		// 召唤强度使用替换后的高级技能等级。
		skill_level = skills[huling_skill][0];
	}
	if(skills && skills["heling"] && skill_level < skills["heling"][0]){
		skill_level = skills["heling"][0];
	}
	if(skills && skills["guiling"] && skill_level < skills["guiling"][0]){
		skill_level = skills["guiling"][0];
	}

	// 三灵合一
	if(arg == "all"){
		// 三灵合一(2级)会替换基础技能，高级方士仍应能召唤三灵。
		string all_skill = "sanlingheyi";
		if(skills && skills["sanlingheyi2"])
			all_skill = "sanlingheyi2";
		if(!skills || !skills[all_skill]){
			s += "你还没有学习三灵合一技能！\n[返回游戏:look]\n";
			me->write(s);
			return 1;
		}
		if(SUMMOND->get_max_summons(me->query_name()) < 3){
			s += "你已经掌握三灵附体，但要到60级召唤上限达到3只后，";
			s += "才能让虎、鹤、龟三灵同时现身。\n[返回游戏:look]\n";
			me->write(s);
			return 1;
		}
		if(SUMMOND->get_current_summon_count(me->query_name()) == 3){
			s += "虎、鹤、龟三灵已经全部在你身边。\n[查看当前召唤:summon list]\n";
			s += "[返回游戏:look]\n";
			me->write(s);
			return 1;
		}

		int all_level = skills[all_skill][0];
		duration = 300 + all_level * 60;

		int count = SUMMOND->summon_all_spirits(me->query_name(), duration, all_level);
		if(count > 0 &&
		   SUMMOND->get_current_summon_count(me->query_name()) == 3){
			s += "三灵合一！虎、鹤、龟三只灵兽同时出现！\n[返回游戏:look]\n";
		}
		else{
			s += "三灵召唤失败，本次没有留下不完整的灵兽组合。";
			s += "请先解除多余召唤后再试。\n[返回游戏:look]\n";
		}
		me->write(s);
		return 1;
	}

	// 单只灵兽召唤
	// 检查是否学习了对应技能
	if(summon_type == "huling" && (!skills || !skills[huling_skill])){
		s += "你还没有学习虎灵技能！\n[返回游戏:look]\n";
		me->write(s);
		return 1;
	}
	if(summon_type == "heling" && (!skills || !skills["heling"])){
		s += "你还没有学习鹤灵技能！\n[返回游戏:look]\n";
		me->write(s);
		return 1;
	}
	if(summon_type == "guiling" && (!skills || !skills["guiling"])){
		s += "你还没有学习龟灵技能！\n[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	// 获取技能等级
	if(summon_type == "huling" && skills[huling_skill]){
		skill_level = skills[huling_skill][0];
		duration = 600 + skill_level * 60;
	}
	else if(skills && skills[summon_type]){
		skill_level = skills[summon_type][0];
		duration = 600 + skill_level * 60;
	}

	// 召唤
	object summon = SUMMOND->summon_creature(me->query_name(), summon_type, duration, skill_level);
	if(!summon){
		s += "召唤失败！可能是你已达到召唤上限或已有同名灵兽。\n";
		s += "你可以使用 [summon list] 查看当前召唤。\n[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	s += "你召唤出了" + summon->query_name_cn() + "！\n[返回游戏:look]\n";
	NEWBIED->record_summon(me,summon_type);
	me->write(s);
	return 1;
}
