#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string content = "";
	if(me->bangid == 0){
		s += "你没有在任何帮派里\n";
	}
	else{
		s = BANGD->query_bang_apply(me->bangid);
		if(s=="")
			s = "没有新的入帮申请\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
