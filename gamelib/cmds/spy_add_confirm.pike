#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	object ob = find_player(arg);
	string uid ="";
	sscanf(arg,"%s",uid);
	int result = me->insert_spy_info(uid);
	switch(result){
		case 0:
			s += "���ע������Ѿ��ﵽ10������ɾ��һЩ�������ɡ�\n";
			break;
		case 1:
			s += "������Ѿ�����Ĺ�ע�����ˣ���Ҫ�ظ����Ŷ��\n";
			break;
		case 2:
			s += "��ϲ�����Ѿ���"+ob->query_name_cn()+"��ӵ���ע�б��ں��������������ʱ�������ҵ��鱨��\n";
			break;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
