#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type 
//��ָ������Ҷ�����Ʒʱ���ȵ��ã��г����Ŀǰ�ܶ������Ʒ�б�
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(me->vice_skills["duanzao"] == 0)
		s += "�����ڲ�������켼��\n";
	else{
		s += "��ѡ����Ҫ�������Ʒ\n";
		if(arg == "m_weapon"){
			s += "������������:\n";
			s += "[�۸���������:viceskill_duanzao_list s_weapon]\n";
			s += "[��˫��������:viceskill_duanzao_list d_weapon]\n";
			s += "[�۷��ߣ�:viceskill_duanzao_list armor]\n";
		}
		else if(arg == "s_weapon"){
			s += "[������������:viceskill_duanzao_list m_weapon]\n";
			s += "�۸���������\n";
			s += "[��˫��������:viceskill_duanzao_list d_weapon]\n";
			s += "[�۷��ߣ�:viceskill_duanzao_list armor]\n";
		}
		else if(arg == "d_weapon"){
			s += "[������������:viceskill_duanzao_list m_weapon]\n";
			s += "[�۸���������:viceskill_duanzao_list s_weapon]\n";
			s += "��˫��������\n";
			s += "[�۷��ߣ�:viceskill_duanzao_list armor]\n";
		}
		else if(arg == "armor"){
			s += "[������������:viceskill_duanzao_list m_weapon]\n";
			s += "[�۸���������:viceskill_duanzao_list s_weapon]\n";
			s += "[��˫��������:viceskill_duanzao_list d_weapon]\n";
			s += "�۷��ߣ�\n";
		}
		s += "--------\n";
		s += DUANZAOD->query_can_duanzao(me,arg);
		//me->write_view(WAP_VIEWD["/emote"],0,0,s);
		//s += "\n[����:viceskill_duanzao_list m_weapon]\n";
	}
	s += "\n[������Ϸ:look]\n";
	write(s);
	return 1;
}
