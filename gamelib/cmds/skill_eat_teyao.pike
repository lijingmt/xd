#include <command.h>
#include <gamelib/include/gamelib.h>
//������߼���������
int main(string arg)
{
	object me = this_player();
	string s = "";
	string teyao_name = "";
	string skill_name = "";
	int count = 0;
	if(sscanf(arg,"%s %d %s",teyao_name,count,skill_name)!=3){
		sscanf(arg,"%s %d",teyao_name,count);
		teyao_name = arg;
		s += "��ѡ����Ҫ���������ȵļ���:\n";
		//s += me->view_skills_mud("skill_eat_teyao "+teyao_name+" "+count); 
		s += me->view_skills_mud("skill_eat_teyao "+teyao_name); 
	}
	else{
		sscanf(arg,"%s %d %s",teyao_name,count,skill_name);
		mapping skills_m = me->skills;
		if(skills_m[skill_name] && skills_m[skill_name][0]<me->query_skill_up()){
			//�����ӵ��skill_name���ּ��ܣ��Ҽ��ܵȼ���û�ﵽ���ܵ�����
			object teyao = present(teyao_name,me,count);
			if(teyao){
				//������ϴ���������ҩ
				int effect_value = teyao->query_effect_value();
				if(teyao->query_danyao_type()=="skill_improve"){
					//��߼���������
					int shuliandu = MUD_SKILLSD[skill_name]->performs_shuliandu[skills_m[skill_name][0]];
					int get_shuliandu = (int)(shuliandu*0.2);
					skills_m[skill_name][1] += get_shuliandu;
					s += "��ʳ����"+teyao->query_name_cn()+"ʹ"+MUD_SKILLSD[skill_name]->query_name_cn()+"�������������"+effect_value+"%\n";
					if(skills_m[skill_name][1]>shuliandu){
						skills_m[skill_name][1] = shuliandu;
					}
				}
				me->remove_combine_item(teyao_name,1);
			}
			else{
				s += "��������û��������ҩ\n";
				s += "\n";
				s += "[����:yushi_buy_teyao_list exp]\n";
			}
		}
		else{
			s += MUD_SKILLSD[skill_name]->query_name_cn()+"�ȼ��Ѵﵽ�������ޣ����������������˷�ҩ��\n";
		}
		if(present(teyao_name,me)){
			s += "[����:inventory_daoju]\n";
		}
		else{
			s += "[����:yushi_buy_teyao_list exp]\n";
		}
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
