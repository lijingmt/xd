#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string uid =arg;
	int load_flag = 0;
	object ob = find_player(uid);
	if(!ob){
		ob = me->load_player(uid);
		load_flag =1;
	}
	if(me->is_spied(uid))
		s += "���������й�ע "+ob->query_name_cn()+" �����٣����б���ɾ�����޷��ٵ�֪�����٣�ȷ��Ҫɾ����?\n";
	else
		s += "�㽫��"+ob->query_name_cn()+"�Ƴ���ע�б�ȷ��Ҫ��ô����\n";
	s += "[ȷ��:spy_del_confirm "+uid+"]  ";
	s += "[����:popview]\n";

	if(load_flag)
	{
		ob->remove(); //�����ص����������
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
