#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "�����˭����Ϊ�ӳ���\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	//only term leader can kick out termer
	if(TERMD->get_term_power(me->query_term(),me->query_name())!="leader"){
		s += "ֻ�жӳ�����Ȩ��ת�ƶӳ���\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	int rs;
	object ob = find_player(arg);
	if(!ob){
		s += "���û������ߣ��޷����д˲�����\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	else{
		rs = TERMD->update_termLeader(me->query_term(),me->query_name(),ob->query_name(),ob->query_name_cn());
		if(rs)	
			s += "�ɹ��� "+ob->query_name_cn()+" ����Ϊ�ӳ���\n";
		else	
			s += "����Ա "+ob->query_name_cn()+" ���öӳ�ʧ�ܡ�\n";
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
