#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string action = "";
	string value = "";
	string output;
	if(!me)
		return 1;
	if(arg && sizeof(arg)){
		if(sscanf(arg,"%s %s",action,value)!=2)
			action = arg;
	}
	output = TIMED_EVENTD->handle_command(me,action,value);
	if(output && sizeof(output))
		write(output);
	return 1;
}
