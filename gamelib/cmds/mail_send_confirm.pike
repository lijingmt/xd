#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string send;
	string send_cn;
	string to;
	string to_cn;
	string body;
	string subject;

	string s="";
	object me = this_player();
	
	if(arg&&sscanf(arg,"%s %s %s %s %s %s",send,send_cn,to,to_cn,subject,body)==6){
		object ob=find_player(to);
		int remove_flag=0;
		if(!ob){
			ob=me->load_player(to);
			remove_flag=1;
		}
		if(ob){
			//s += "[ȷ��:mail_send_confirm "+me->name+" "+me->name_cn+" "+to+" "+ob->name_cn+" "+subject+" "+body+"]\n";
			ob->recieve_mail(send,send_cn,to,to_cn,subject,body);
			if(remove_flag) ob->remove();
		}
		s+="���ͳɹ����뷵�أ�\n";
		s+="[����:qqlist]\n";
		write(s);
		//this_player()->write_view(WAP_VIEWD["/mailbox_mail"]);
		return 1;
	}
	s+="��������뷵�����ԣ�\n";	
	s+="[����:qqlist]\n";
	write(s);
	return 1;
}
