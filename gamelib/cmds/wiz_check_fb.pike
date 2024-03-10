#include <command.h>
#include <gamelib/include/gamelib.h>
//查看副本内容
int main(string arg)
{
	string s = FBD->check_fb();
	write(s);
	return 1;
}
