#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type 
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(arg == "m_weapon"){
		s += "������������:\n";
		s += "[�۸���������:viceskill_duanzao_pf s_weapon]\n";
		s += "[��˫��������:viceskill_duanzao_pf d_weapon]\n";
		s += "[�۷��ߣ�:viceskill_duanzao_pf armor]\n";
	}
	else if(arg == "s_weapon"){
		s += "[������������:viceskill_duanzao_pf m_weapon]\n";
		s += "�۸���������\n";
		s += "[��˫��������:viceskill_duanzao_pf d_weapon]\n";
		s += "[�۷��ߣ�:viceskill_duanzao_pf armor]\n";
	}
	else if(arg == "d_weapon"){
		s += "[������������:viceskill_duanzao_pf m_weapon]\n";
		s += "[�۸���������:viceskill_duanzao_pf s_weapon]\n";
		s += "��˫��������\n";
		s += "[�۷��ߣ�:viceskill_duanzao_pf armor]\n";
	}
	else if(arg == "armor"){
		s += "[������������:viceskill_duanzao_pf m_weapon]\n";
		s += "[�۸���������:viceskill_duanzao_pf s_weapon]\n";
		s += "[��˫��������:viceskill_duanzao_pf d_weapon]\n";
		s += "�۷��ߣ�\n";
	}
	s += "--------\n";
	s += DUANZAOD->query_peifang(me,arg);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[����:viceskill_view duanzao]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
