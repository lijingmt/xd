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
			//s += "[确定:mail_send_confirm "+me->name+" "+me->name_cn+" "+to+" "+ob->name_cn+" "+subject+" "+body+"]\n";
			ob->recieve_mail(send,send_cn,to,to_cn,subject,body);
			if(remove_flag) ob->remove();
		}
		s+="发送成功，请返回！\n";
		s+="[返回:qqlist]\n";
		write(s);
		//this_player()->write_view(WAP_VIEWD["/mailbox_mail"]);
		return 1;
	}
	s+="输入错误，请返回重试！\n";	
	s+="[返回:qqlist]\n";
	write(s);
	return 1;
}
