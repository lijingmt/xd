#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string lifeType = "";
	int ind = 0;
	sscanf(arg,"%s %d",lifeType,ind);
	string re = "";
	re += "你确认要这么做吗？\n";
	re += "[确认:home_life_cancel_confirm "+ lifeType+" "+ ind +"]\n";
	re += "[返回:home_life_detail "+ lifeType +" "+ind +"]";
	write(re);
	return 1;
}
