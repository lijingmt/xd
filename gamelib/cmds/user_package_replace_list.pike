#include <command.h>
#include <gamelib/include/gamelib.h>
//�г�������Ͽ��滻�ı���
int main(string arg)
{
	object me = this_player();
	string s="";
	string type = "";
	int pac_size = 0;
	string tmp_s = "";
	sscanf(arg,"%s %d",type,pac_size);
	if(type=="beibao")tmp_s = "����";
	if(type=="cangku")tmp_s = "�ֿ�";
	s += "���ѹ����"+tmp_s+"�У�\n";
	s += BUYD->get_pac_replace_list(me,type,pac_size);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
