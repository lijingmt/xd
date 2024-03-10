#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	//this_player()->write_view(WAP_VIEWD["/mailbox_compose"],0,0,arg);
	//return 1;
	object me = this_player();
	string desc="写邮件\n";
	if(!arg||arg==""||sizeof(arg)==0){
		desc += "你要给谁写邮件？\n";	
		desc+="[返回:qqlist]\n";
		write(desc);
		return 1;
	}
	//参数关键字不能大于5，在jsp层有限定
	desc+="信件标题[string bt:...]\n";
    desc+="信件内容[string bd:...]\n";
    desc+="[submit 提交:mailbox_mail to="+arg+" ...]\n";
	//desc+="--------\n";
	//desc+="[邮寄物品:mailbox_items "+arg+"]\n";
	//desc+="--------\n";
	desc+="[返回:qqlist]\n";
	desc+="[返回游戏:look]\n";
	write(desc);
	return 1;
}
