#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	this_player()->pop_view();
	this_player()->write_view();
	return 1;
}

