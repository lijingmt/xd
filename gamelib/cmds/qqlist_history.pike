#include <command.h>
#include <gamelib/include/gamelib.h>
int main()
{
	string s = this_player()->msg_history;
	if(s&&sizeof(s))
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	else{
		s = "�����κ���Ϣ��";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	return 1;
}
