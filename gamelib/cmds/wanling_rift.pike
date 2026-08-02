#include <command.h>
#include <gamelib/include/gamelib.h>

private string render_rift(mapping state)
{
	if(!state["ok"])
		return "【万灵裂隙】\n\n每周轮替一只山海异兽。需要3—5名15级以上玩家组队，并在同一房间集合。\n"+
			"没有强制职业：每轮任何人都可选择破阵、守御、疗愈、封印；生命进入15%后开放缚灵。\n\n"+
			"[一键发布招募:wanling_rift recruit]|[前往万灵台:wanling_rift gather]\n"+
			"[队长开启裂隙:wanling_rift start]|[查看队伍:my_term]\n"+
			"[返回今日修行:daily_cultivation]|[返回游戏:look]\n";
	mapping boss = PETD->query_pet_species((string)state["boss_species"]);
	string s = "【万灵裂隙·"+(string)boss["name"]+"】\n\n";
	s += "状态："+(string)state["status"]+" | 回合 "+
		(int)state["round"]+"/12\n";
	s += "异兽灵障："+(int)state["hp"]+"/"+(int)state["hp_max"]+
		" | 队伍灵息："+(int)state["spirit"]+"/100\n";
	s += "当前机制："+PETD->query_rift_mechanic_name(
		(string)state["mechanic"])+"\n";
	if((string)state["last_message"]!="")
		s += (string)state["last_message"]+"\n";
	s += "已行动 "+sizeof((mapping)state["actions"])+"/"+
		sizeof((array)state["participants"])+"\n\n";
	if((string)state["status"]=="active" && !(int)state["acted"]){
		s += "[破阵:wanling_rift action break] [守御:wanling_rift action guard] "+
			"[疗愈:wanling_rift action heal] [封印:wanling_rift action seal]";
		if((string)state["mechanic"]=="capture")
			s += " [缚灵:wanling_rift action capture]";
		s += "\n";
	}
	else if((string)state["status"]=="active")
		s += "你本轮已经行动，正在等待队友。\n";
	else if((string)state["status"]=="won")
		s += "[领取个人奖励:wanling_rift claim]\n";
	else
		s += "本次探索已经结束，可重新组队挑战。\n";
	s += "\n个人贡献：\n";
	foreach(state["contributions"];string player_id;mapping one)
		s += "• "+player_id+" 行动"+(int)one["actions"]+
			"，伤害"+(int)one["damage"]+"，守御"+(int)one["guard"]+
			"，疗愈"+(int)one["heal"]+"，封印"+(int)one["control"]+"\n";
	s += "[刷新战局:wanling_rift]|[今日修行:daily_cultivation]|[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	array(string) parts = arg ? arg/" " : ({});
	mapping result;
	if(!arg || arg==""){
		write(render_rift(PETD->query_rift_state(me)));
		return 1;
	}
	if(parts[0]=="gather"){
		if(me->in_combat){
			write("战斗中不能前往万灵台。\n[继续战斗:attack]\n");
			return 1;
		}
		object env = environment(me);
		if(env && env->query_room_type()=="fb"){
			write("副本中不能离场前往万灵台，请先正常离开副本。\n[返回游戏:look]\n");
			return 1;
		}
		me->command("qge74hye wanling/wanlingtai");
		return 1;
	}
	if(parts[0]=="recruit")
		result = PETD->open_rift_recruit(me);
	else if(parts[0]=="start")
		result = PETD->start_rift(me);
	else if(parts[0]=="action" && sizeof(parts)>=2)
		result = PETD->take_rift_action(me,parts[1]);
	else if(parts[0]=="claim")
		result = PETD->claim_rift_reward(me);
	else if(parts[0]=="weekly" && sizeof(parts)>=2)
		result = PETD->claim_pet_weekly_choice(me,parts[1]);
	else
		result = (["ok":0,"message":"未知的裂隙操作。"]);
	string s = (string)result["message"]+"\n";
	if(mappingp(result["pet_acquisition"]) &&
	   sizeof((mapping)result["pet_acquisition"]))
		s += (string)result["pet_acquisition"]["message"]+"\n";
	if((int)result["cosmetic"])
		s += "极稀有月华异色已经记录；它只改变外观，不增加属性。\n";
	s += "[查看裂隙:wanling_rift]|[返回今日修行:daily_cultivation]|[返回游戏:look]\n";
	write(s);
	return 1;
}
