#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string to;
	string body;
	string subject;
	string s="";
	object me = this_player();
	foreach(arg/" ",string conts){
		array a=(conts/"=");
		if(a[0]=="to")
			to=a[1];
		if(a[0]=="bt")
			subject=a[1];
		if(a[0]=="bd")
			body=a[1];
	}
	object ob=find_player(to);
	int remove_flag=0;
	if(!ob){
		ob=this_player()->load_player(to);
		remove_flag=1;
	}
	if(ob){
		if(ob["/plus/blacklist/"+me->name]){
			s+="�Է���������������б����޷�ִ�з��Ų������뷵�ء�\n";
			if(remove_flag) ob->remove();
			s+="[����:qqlist]\n";
			write(s);
			return 1;			
		}
		/*
		s += "�ռ��ˣ�"+ob->name_cn+"\n"; 
		s += "���⣺"+subject+"\n"; 
		s += "���ݣ�"+body+"\n";
		s += "��������󣬵��ȷ���ύ���ʼ���\n";
		s += "[ȷ��:mail_send_confirm "+me->name+" "+me->name_cn+" "+to+" "+ob->name_cn+" "+subject+" "+body+"]\n";
		*/
		s+="�ż��ѷ��ͣ��뷵�أ�\n";
		ob->recieve_mail(this_player()->name,this_player()->name_cn,to,ob->name_cn,subject,body);
		if(remove_flag) ob->remove();
	}
	else
		s+="��Ҫ���ŵ��˺ܷ�æ�����ûظ��ˣ���ȥ��������ȡ�����Ʒ��Ǯ�ơ�\n";
	s+="[����:my_qqlist]\n";
	s+="[������Ϸ:look]\n";
	write(s);
	return 1;
}
