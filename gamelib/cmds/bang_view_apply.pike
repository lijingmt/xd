#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string content = "";
	if(me->bangid == 0){
		s += "��û�����κΰ�����\n";
	}
	else{
		s = BANGD->query_bang_apply(me->bangid);
		if(s=="")
			s = "û���µ��������\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
