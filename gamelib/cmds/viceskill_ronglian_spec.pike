#include <command.h>
#include <gamelib/include/gamelib.h>
//arg 
//��ָ��鿴������������Ϣ`
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(me->vice_skills["duanzao"] == 0)
		s += "�����ڲ�������켼��\n";
	else{
		s += "�ض���װ����������һ�����ʻ��������Ʒ��\n";
		s += RONGLIAND->query_spec_desc();
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
