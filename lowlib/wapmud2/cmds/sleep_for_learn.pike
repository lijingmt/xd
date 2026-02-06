#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	int time = (int)arg;
	this_player()->sleep_for_learn(time);
	this_player()->write_view(WAP_VIEWD["/sleep_for_learn"]);
	return 1;
}
