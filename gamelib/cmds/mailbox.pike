#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	s += this_player()->view_mail_list()+"\n";
	s+="[����:my_qqlist]\n";
	s+="[������Ϸ:look]\n";
	write(s);
	//this_player()->write_view(WAP_VIEWD["/mailbox"]);
	return 1;
}


