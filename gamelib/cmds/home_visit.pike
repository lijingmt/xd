#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = HOMED->query_room_by_masterId(arg,"main");
	string s = "";
	if(room){
		me->move(room);
		me->reset_view(WAP_VIEWD["/home"]);                                                                      
		me->write_view();
		return 1;
	}
	else{
		s += "���Һ�����װ�ޣ��Ժ�������\n";
		s += "\n[ȷ��:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
