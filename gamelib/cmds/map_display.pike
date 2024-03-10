#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	object me=this_player();
	object env = environment(me);
	s += "您现在身处"+env->query_name_cn()+"\n";
	s += "\n";
	s += env->query_picture_url();
	s += MAPD->query_map(env);
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
