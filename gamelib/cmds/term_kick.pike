#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "���뽫��λ��Ա�Ƴ����飿\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	//only term leader can kick out termer
	if(TERMD->get_term_power(me->query_term(),me->query_name())!="leader"){
		s += "ֻ�жӳ��������Ȩ�ޣ�\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	int rs;
	object ob = find_player(arg);
	if(!ob){
		s += "�ö�Ա�����ߣ��뷵�ء�\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	else{
		rs = TERMD->kick_termer(me->query_term(), ob->query_name(), ob->query_name_cn());
		switch(rs){
			case 0:
				s += "�Ƴ���Ա "+ob->query_name_cn()+" ʧ��\n";
				break;
			case 1:
				s += "�ɹ��Ƴ���Ա "+ob->query_name_cn()+"\n";
				//ˢ�¶���
				TERMD->flush_term(me->query_term());
				break;
			case 2:
				s += "��û�����Ȩ�ޣ��뷵�ء�\n";
				break;
		}
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
