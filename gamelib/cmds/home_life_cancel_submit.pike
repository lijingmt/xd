#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string lifeType = "";
	int ind = 0;
	sscanf(arg,"%s %d",lifeType,ind);
	string re = "";
	re += "��ȷ��Ҫ��ô����\n";
	re += "[ȷ��:home_life_cancel_confirm "+ lifeType+" "+ ind +"]\n";
	re += "[����:home_life_detail "+ lifeType +" "+ind +"]";
	write(re);
	return 1;
}
