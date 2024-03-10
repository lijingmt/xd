#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	s += TIPSD->query_yunying_tips();
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}

