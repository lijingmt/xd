#include <command.h>
#include <gamelib/include/gamelib.h>

private string render_candidates(object me)
{
	string s = "【灵宠论道】\n\n";
	s += "三宠依次交锋、三局两胜，每一局最多12回合。人物等级、装备、VIP与宠物培养数值全部标准化。\n";
	s += "人物不会死亡，不掉物品、不红名；每天只奖励前3个不同注册账号，同账号小号不能互刷。\n\n";
	object env = environment(me);
	int count = 0;
	if(env){
		foreach(all_inventory(env),object target){
			if(!target || target==me || !target->is || !target->is("player") ||
			   !LOGICALZONED->can_interact(me,target))
				continue;
			s += "• "+target->query_name_cn()+"（"+target->query_level()+
				"级） [邀请论道:pet_duel invite "+target->query_name()+"]\n";
			count++;
		}
	}
	if(!count)
		s += "当前房间没有可邀请的其他玩家。可先去万灵台集合。\n";
	mapping invite = PETD->query_pet_duel_invite(me);
	if(sizeof(invite))
		s += "\n待处理："+(string)invite["challenger_name"]+
			" [接受:pet_duel accept "+(string)invite["challenger_id"]+" "+
			(string)invite["token"]+"] [拒绝:pet_duel refuse "+
			(string)invite["challenger_id"]+" "+(string)invite["token"]+"]\n";
	s += "\n[调整三宠编队:pet team]|[前往万灵台:wanling_rift gather]\n";
	s += "[返回万灵谱:pet]|[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	array(string) parts = arg ? arg/" " : ({});
	mapping result;
	if(!arg || arg=="" || arg=="list"){
		write(render_candidates(me));
		return 1;
	}
	if(parts[0]=="invite" && sizeof(parts)>=2)
		result = PETD->invite_pet_duel(me,parts[1]);
	else if(parts[0]=="accept" && sizeof(parts)>=3)
		result = PETD->accept_pet_duel(me,parts[1],parts[2]);
	else if(parts[0]=="refuse" && sizeof(parts)>=3)
		result = PETD->refuse_pet_duel(me,parts[1],parts[2]);
	else
		result = (["ok":0,"message":"未知的灵宠论道操作。"]);
	write((string)result["message"]+"\n[返回论道:pet_duel list]|[返回万灵谱:pet]\n");
	return 1;
}
