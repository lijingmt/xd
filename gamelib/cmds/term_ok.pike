#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	//������������Ѿ����˶���id����Ҫ�жϵ�ǰ�����߱����Ƿ��Ѿ����˶�������
	//���ܽ����û�����ö���
	if(me->query_term()!=""&&me->query_term()!="noterm"){
		s += "���Ѿ�������ĳ�����飬�뷵�ء�\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	if(!arg){
		s += "��Ҫ����˭�Ķ��飿";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	object ob = find_player(arg);
	if(ob){
		/*if(ob->query_term()!=""&&ob->query_term()!="noterm"){
			s += "�Է��Ѿ�������ĳ�����飬�뷵�ء�\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}*/
		//����������߶��鲻���ڣ��������ߴ������飬���������
		if(ob->query_term()==""||ob->query_term()=="noterm"){
			string tid = (string)TERMD->term_create(ob->query_name());
			if(sizeof(tid)==1){
				//����ʧ��
				s += "�������ʧ�ܣ����´����ԡ�\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else{
				//�����ɹ��������߼��룬��������ҲҪ����������
				TERMD->add_termer(tid,me->query_name(),me->query_name_cn());
				me->set_term(tid);
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
		}
		else{
			int tmp = TERMD->add_termer(ob->query_term(),me->query_name(),me->query_name_cn());	
			switch(tmp){
				case 1:
					s += "������˸ö��顣\n";
					break;
				case 2:
					s += "���������Ѿ�5�ˣ��޷�����ö��顣\n";	
					break;
				case 3:
				case 0:
					s += "�������ʧ�ܣ��뷵�����ԡ�\n";
					break;
			}
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
	}
	else{
		s += "��Ҫ����Ķ��鲻���ڡ�\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
