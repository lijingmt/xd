#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg)
		s+="��Ҫ������ĸ���ҵ����Σ�\n";
	else{
		if(me["/plus/chatblock"]&&sizeof(me["/plus/chatblock"])){
			int flag = 1;
			foreach(me["/plus/chatblock"],string uid){
				if(uid&&uid==arg){
					me["/plus/chatblock"] -= ({arg});
					flag  = 0;
					break;
				}
			}
			if(flag)
				s += "���û���δ�������ι��������ݣ��뷵������ѡ��\n";
			else
				s += "���Ѿ�����˶Ը���ҵ����Σ��뷵�ء�\n";	
		}
		else//�ù۲��߻�û�����ι��κ��ˣ������ṩ���νӿ�
			s += "�㻹û�����ι��κ��ˣ��뷵������ѡ��ȷ������\n";
	}
	s+="[����:chatroom_blocklist]\n";
	s+="[������Ϸ:look]\n";
	write(s);
	return 1;
}
