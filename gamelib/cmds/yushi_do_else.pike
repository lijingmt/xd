#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "玉石相关操作\n";
	s += "\n";
	s += "[其他方式购买:add_else_fee]\n";
	s += "[玉石说明:yushi_explain]\n";
	s += "[捐赠获取玉石说明:yushi_readme]\n";
	s += "[炼化装备说明:convert_readme]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
