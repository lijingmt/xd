#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = termid flag
//flag = 1 ��ʾ��ʱ�ӳ����ɷ���ֿ���Ķ���
//     = 0 ��ʾ��Ա��ֻ���ܲ鿴
int main(string arg)
{
	string s = "";
	object me=this_player();
	string termid = "";
	int flag = 0;
	sscanf(arg,"%s %d",termid,flag);
	string team_id = me->query_term();
	if(team_id == "noterm" || team_id != termid){
		s += "���Ѿ�û���������������\n";
		s += "[����:look]\n";
		write(s);
		return 1;
	}
	else{
		s += "����ֿ⣺\n";
		s += "��ʱ���������ֵ������Ʒ���ӳ����Է�����Щ��Ʒ\n";
		s += "��ע�⡿����ӳ���ʱ���䣬�ֿ�Ķ������ڶ����ɢʱ��ʧ\n";
		s += "--------\n";
		s += TERMD->query_termItems(termid,flag);
	}
	s += "\n[����:my_term]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
