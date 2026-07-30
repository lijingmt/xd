#include <command.h>
#include <gamelib/include/gamelib.h>

/**
 * 方士开放状态说明。
 * 方士已经全服免费开放，此兼容命令不再写入无效的解锁状态。
 */
string query_fangshi_open_info()
{
	string s = "";
	s += "【方士职业】\n\n";
	s += "方士已经全服免费开放，不需要额外解锁，也不消耗任何道具。\n";
	s += "新建人物时选择“中立”，再选择“方士”即可开始修炼。\n\n";
	s += "职业特色：虎灵进攻、鹤灵治疗、龟灵守护，并可发动灵契共鸣。\n";
	s += "当前方士人物可从新手引导查看技能、装备和成长路线。\n\n";
	s += "[查看新手引导:newbie_guide]\n";
	s += "[查看方士技能书:buy_items book fangshi]\n";
	s += "[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	if(!me)
		return 0;
	me->write(query_fangshi_open_info());
	return 1;
}
