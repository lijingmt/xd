#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg || arg == "0"){
		s+="��Ҫ�����ĸ�����Ƶ����\n";
		s+="�뷵��ѡ������Ƶ����\n";
	}
	else{
		me->set_chatid(arg);
		if(me->query_level()>=6) //Ϊ������ǹ�ֶ������޸�
			s += "[ˢ��:chatroom_chat flush]\n[chatroom_chat ...]\n";
		if(me->query_raceId()=="human")
			s += CHATROOMD->query_chat_msg(me->query_chatid(),me->query_name());	
		else if(me->query_raceId()=="monst")
			s += CHATROOM2D->query_chat_msg(me->query_chatid(),me->query_name());	
	}
	s+="[����:chatroom_list]\n";
	s+="[������Ϸ:look]\n";
	write(s);
	return 1;
}
