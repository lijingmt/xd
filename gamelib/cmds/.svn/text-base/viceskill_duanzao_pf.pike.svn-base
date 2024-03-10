#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type 
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(arg == "m_weapon"){
		s += "［主手武器］:\n";
		s += "[［副手武器］:viceskill_duanzao_pf s_weapon]\n";
		s += "[［双手武器］:viceskill_duanzao_pf d_weapon]\n";
		s += "[［防具］:viceskill_duanzao_pf armor]\n";
	}
	else if(arg == "s_weapon"){
		s += "[［主手武器］:viceskill_duanzao_pf m_weapon]\n";
		s += "［副手武器］\n";
		s += "[［双手武器］:viceskill_duanzao_pf d_weapon]\n";
		s += "[［防具］:viceskill_duanzao_pf armor]\n";
	}
	else if(arg == "d_weapon"){
		s += "[［主手武器］:viceskill_duanzao_pf m_weapon]\n";
		s += "[［副手武器］:viceskill_duanzao_pf s_weapon]\n";
		s += "［双手武器］\n";
		s += "[［防具］:viceskill_duanzao_pf armor]\n";
	}
	else if(arg == "armor"){
		s += "[［主手武器］:viceskill_duanzao_pf m_weapon]\n";
		s += "[［副手武器］:viceskill_duanzao_pf s_weapon]\n";
		s += "[［双手武器］:viceskill_duanzao_pf d_weapon]\n";
		s += "［防具］\n";
	}
	s += "--------\n";
	s += DUANZAOD->query_peifang(me,arg);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:viceskill_view duanzao]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
