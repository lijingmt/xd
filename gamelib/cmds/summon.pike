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
		s += "[三灵合一:summon all] - 同时召唤三只灵兽\n\n";
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
		s += "\n[返回游戏:look]\n";
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
	if(skills && skills["huling"]){
		skill_level = skills["huling"][0];
	}
	if(skills && skills["heling"] && skill_level < skills["heling"][0]){
		skill_level = skills["heling"][0];
	}
	if(skills && skills["guiling"] && skill_level < skills["guiling"][0]){
		skill_level = skills["guiling"][0];
	}

	// 三灵合一
	if(arg == "all"){
		// 检查是否学习了三灵合一
		if(!skills || !skills["sanlingheyi"]){
			s += "你还没有学习三灵合一技能！\n[返回游戏:look]\n";
			me->write(s);
			return 1;
		}

		int all_level = skills["sanlingheyi"][0];
		duration = 300 + all_level * 60; // 5-10分钟

		int count = SUMMOND->summon_all_spirits(me->query_name(), duration, all_level);
		if(count == 0){
			s += "召唤失败！可能是你已达到召唤上限或已有同名灵兽。\n[返回游戏:look]\n";
		}
		else if(count < 3){
			s += "三灵合一！你召唤了" + count + "只灵兽！\n[返回游戏:look]\n";
		}
		else{
			s += "三灵合一！虎、鹤、龟三只灵兽同时出现！\n[返回游戏:look]\n";
		}
		me->write(s);
		return 1;
	}

	// 单只灵兽召唤
	// 检查是否学习了对应技能
	if(summon_type == "huling" && (!skills || !skills["huling"])){
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
	if(skills[summon_type]){
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
	me->write(s);
	return 1;
}
