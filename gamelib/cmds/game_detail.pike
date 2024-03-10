#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "关于游戏\n";
	s += "\n";
	s += "[捐赠获取仙玉:add_szx_fee]\n";
	s += "[其他玉石相关操作:yushi_do_else]";
	s += "[关于安全码:bandpsw_readme]\n";
	//s += "[问卷调查:diaocha_list A 17]\n";
	//s += "[提交建议:diaocha_advice]\n";
	s += "[配置快捷键:my_toolbar]\n";
	s += "[图片开关:pic_switch_list]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
