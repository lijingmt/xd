#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	//������ʽΪmoney id
	int money = 0;
	int sale_id = 0;
	int id = 0;
	sscanf(arg,"%d %d",money,id);
	string s_rtn = "";
	
	//��Ǯ�������
	if(AUCTIOND->finish_getback(id) == 1){ 
		//ȷ��û�б���ȡ��
		this_player()->add_account(money);
		s_rtn += "����ȡ��"+MUD_MONEYD->query_other_money_cn(money)+"\n";
	}
	else if(AUCTIOND->finish_getback(id) == 0)
		s_rtn += "���۸�������Щ��ʵ�ˣ����Ѿ���ȡ����ЩǮ��\n";
	else if(AUCTIOND->finish_getback(id) == 2)
		s_rtn += "����������ҵ��̫��æ��������ʧ����ϵ����Ա\n";
	s_rtn += "[����:look]\n";
	write(s_rtn);
	return 1;
}
