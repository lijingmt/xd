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
			s+="对方把你加入了屏蔽列表，你无法执行发信操作，请返回。\n";
			if(remove_flag) ob->remove();
			s+="[返回:qqlist]\n";
			write(s);
			return 1;			
		}
		/*
		s += "收件人："+ob->name_cn+"\n"; 
		s += "标题："+subject+"\n"; 
		s += "内容："+body+"\n";
		s += "请检查无误后，点击确定提交该邮件：\n";
		s += "[确定:mail_send_confirm "+me->name+" "+me->name_cn+" "+to+" "+ob->name_cn+" "+subject+" "+body+"]\n";
		*/
		s+="信件已发送，请返回．\n";
		ob->recieve_mail(this_player()->name,this_player()->name_cn,to,ob->name_cn,subject,body);
		if(remove_flag) ob->remove();
	}
	else
		s+="你要回信的人很繁忙，不用回复了，快去拍卖行领取你的物品或钱财。\n";
	s+="[返回:my_qqlist]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
