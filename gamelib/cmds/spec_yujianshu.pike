#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int flag;
	string s = "";
	object me=this_player();
	if(!arg){
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	else{
		s += "�������У��ܿ��ٵ��������ߣ��ķ�300����ȴʱ��15����\n";
		sscanf(arg,"%d",flag);
		if(flag == 0){
			s += "������δ��ȴ\n";
			s += "[����:myskills]\n";
			s += "[������Ϸ:look]\n";
			write(s);
		}
		else if(flag == 1){
			if(me->get_cur_mofa()<300){
				s += "û���㹻�ķ���ʩ��������\n";
				s += "[����:myskills]\n";
				s += "[������Ϸ:look]\n";
				write(s);
			}
			else{
				s += "����������:\n";
				mapping(string:array) map_term = ([]);
				map_term = (mapping)TERMD->query_term_m(me->query_term());
				if(map_term&&sizeof(map_term)){
					foreach(indices(map_term),string uid){
						object termer = find_player(uid);
						if(termer && termer->query_name() != me->query_name()){
							object env = environment(termer);
							s += "["+termer->query_name_cn()+":spec_yujian_to "+uid+"]("+env->query_name_cn()+")\n";
						}
					}
				}
				else
					s += "��Ŀǰ��û�ж���\n";
				s += "[����:myskills]\n";
				s += "[������Ϸ:look]\n";
				write(s);
			}
		}
	}
	return 1;
}
