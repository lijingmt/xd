#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag
//�����������ܵ�ָ����и��������ڱ�����ʱ�������
int main(string arg)
{
	string s = "";
	object me=this_player();
	string skill_name = "";
	string skill_name_cn = "";
	int flag = 0;
	sscanf(arg,"%s %d",skill_name,flag);
	if(me->vice_skills[skill_name] == 0)
		s += "���Ѿ����������ּ���\n";
	else{
		if(skill_name == "caikuang")
			skill_name_cn = "�ɿ�";
		else if(skill_name == "duanzao")
			skill_name_cn = "����";
		else if(skill_name == "caiyao")
			skill_name_cn = "��ҩ";
		else if(skill_name == "liandan")
			skill_name_cn = "����";
		if(flag == 0){
			s += "����"+skill_name_cn+"����\n";
			s += "�����˼��ܺ��㽫ʧȥһ����˼�����ص���������ȷ��Ҫ������\n";
			s += "[��:viceskill_giveup "+skill_name+" 1] [��:myskills]\n";
		}
		else if(flag == 1){
			m_delete(me->vice_skills,skill_name);
			s = "��������"+skill_name_cn+"����\n";
			if(skill_name == "duanzao"){
				me["/duanzao"] = ([]);
				//me["/duanzao/m_weapon"] = ([]);
				//me["/duanzao/s_weapon"] = ([]);
				//me["/duanzao/armor"] = ([]);
			}
			else if(skill_name == "liandan"){
				me["/liandan"] = ([]);
			}
			s += "\n[����:myskills]\n";
		}
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
