#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s+="��Ҫ�۲��ĸ��û�����Ϣ��\n";
		s+="�뷵�ء�\n";
	}
	else{
		if(arg==me->query_name()){
			s+="�㲻�ܶ��Լ�ִ�иò������뷵�ء�\n";
			s+="[����:chatroom_entry "+me->query_chatid()+"]\n";
			s+="[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		object who = find_player(arg);
		if(who){
			s += who->query_name_cn()+"\n";	
			s += "[����Ϣ:tell "+who->query_name()+"]\n";
			s += "[��Ϊ����:qqlist "+who->query_name()+"]\n";
			if(me["/plus/chatblock"]&&sizeof(me["/plus/chatblock"])){
				int flag = 1;
				foreach(me["/plus/chatblock"],string uid){
					if(uid&&uid==who->query_name()){
						//�ù۲��������ı����и÷����ߵģ��
						s += "[�����������:chatroom_disblock "+who->query_name()+"]\n";
						flag  = 0;
						break;
					}
				}
				if(flag){
					//�÷�����û���ڹ۲��ߵ������ı��У��ṩ���νӿ�
					s += "[���δ���:chatroom_block "+who->query_name()+"]\n";
				}
			}
			else//�ù۲��߻�û�����ι��κ��ˣ������ṩ���νӿ�
				s += "[���δ���:chatroom_block "+who->query_name()+"]\n";
		}
		else{
			s += "���û��Ѿ��뿪���뷵�ء�\n";	
		}
	}
	s+="[����:chatroom_entry "+me->query_chatid()+"]\n";
	s+="[������Ϸ:look]\n";
	write(s);
	return 1;
}
