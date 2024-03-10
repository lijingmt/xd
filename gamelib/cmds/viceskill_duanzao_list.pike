#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type 
//此指令在玩家锻造物品时最先调用，列出玩家目前能锻造的物品列表
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(me->vice_skills["duanzao"] == 0)
		s += "你现在并不会锻造技能\n";
	else{
		s += "请选择你要锻造的物品\n";
		if(arg == "m_weapon"){
			s += "［主手武器］:\n";
			s += "[［副手武器］:viceskill_duanzao_list s_weapon]\n";
			s += "[［双手武器］:viceskill_duanzao_list d_weapon]\n";
			s += "[［防具］:viceskill_duanzao_list armor]\n";
		}
		else if(arg == "s_weapon"){
			s += "[［主手武器］:viceskill_duanzao_list m_weapon]\n";
			s += "［副手武器］\n";
			s += "[［双手武器］:viceskill_duanzao_list d_weapon]\n";
			s += "[［防具］:viceskill_duanzao_list armor]\n";
		}
		else if(arg == "d_weapon"){
			s += "[［主手武器］:viceskill_duanzao_list m_weapon]\n";
			s += "[［副手武器］:viceskill_duanzao_list s_weapon]\n";
			s += "［双手武器］\n";
			s += "[［防具］:viceskill_duanzao_list armor]\n";
		}
		else if(arg == "armor"){
			s += "[［主手武器］:viceskill_duanzao_list m_weapon]\n";
			s += "[［副手武器］:viceskill_duanzao_list s_weapon]\n";
			s += "[［双手武器］:viceskill_duanzao_list d_weapon]\n";
			s += "［防具］\n";
		}
		s += "--------\n";
		s += DUANZAOD->query_can_duanzao(me,arg);
		//me->write_view(WAP_VIEWD["/emote"],0,0,s);
		//s += "\n[返回:viceskill_duanzao_list m_weapon]\n";
	}
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
