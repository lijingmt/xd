#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	int level = 0;
	if(!me->bangid){
		s = "��δ�����κΰ���\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">:";
		s += BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		level = BANGD->query_level(me->query_name(),me->bangid);
		if(level != 6){
			s = "�������Ѳ��ǰ���\n";
		}
		else{
			s += "ֻ���������ϵİ�Ա���ܽ������ת�����뿼������󣬵����Ա���ת��\n";
			s += BANGD->query_for_root(me);
		}
	}
	s += "[����:bang_manage "+level+"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
