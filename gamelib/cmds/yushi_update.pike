#include <command.h>
#include <gamelib/include/gamelib.h>
//�ϳ���ʯ���õ�ָ��г���ҿ��Ժϳɵ���ʯ�б�
int main(string arg)
{
	object me = this_player();
	string s = "Ŀǰ���ܺϳɵ���ʯ�У�\n";
	s += YUSHID->query_can_update(me);
	s += "\n[����:yushi_myzone.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
