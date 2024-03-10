#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	int n;
	sscanf(arg,"%d",n);
	this_player()->delete_mail(n);
	s+="成功删除该邮件，请返回！\n";
	s+="[返回:mailbox]\n";
	write(s);
	//this_player()->write_view(WAP_VIEWD["/mailbox_delete"]);
	return 1;
}


