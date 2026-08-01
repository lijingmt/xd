#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string s = "关于游戏\n";
	s += "\n";
	s += "[捐赠获取仙玉:add_szx_fee]\n";
	s += "[其他玉石相关操作:yushi_do_else]\n";
	if(me->bandpswd && sizeof(me->bandpswd))
		s += "[修改安全码:bandpsw_change]\n";
	else
		s += "[绑定安全码:set_bandpsw]\n";
	s += "[安全码说明:bandpsw_readme]\n";
	//s += "[问卷调查:diaocha_list A 17]\n";
	//s += "[提交建议:diaocha_advice]\n";
	s += "[配置快捷键:my_toolbar]\n";
	s += "[图片开关:pic_switch_list]\n";
	s += "[手动存档:save_game]\n";
	s += "[意见反馈:feedback]\n";
	if(PROFESSIONVIPD->is_supported_profession(me->query_profeId()))
		s += "[职业助手:profession_assistant]\n";
	// 改名字功能：只有无名开头的玩家可以看到
	string current_name = me->query_name_cn(1);
	if(search(current_name, "无名") == 0){
		s += "[修改名字:set_name]\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
