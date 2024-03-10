#include <command.h>
#include <gamelib/include/gamelib.h>
//查看已学的裁缝配方
//arg = type 
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(arg == "head"){
		s += "头部 | [胸部:viceskill_zhijia_pf cloth]\n";
		s += "[手腕:viceskill_zhijia_pf waste] | [手部:viceskill_zhijia_pf hand]\n";
		s += "[腿部:viceskill_zhijia_pf thou] | [脚部:viceskill_zhijia_pf shoes]\n";
	}
	else if(arg == "cloth"){
		s += "[头部:viceskill_zhijia_pf head] | 胸部\n";
		s += "[手腕:viceskill_zhijia_pf waste] | [手部:viceskill_zhijia_pf hand]\n";
		s += "[腿部:viceskill_zhijia_pf thou] | [脚部:viceskill_zhijia_pf shoes]\n";
	}
	else if(arg == "waste"){
		s += "[头部:viceskill_zhijia_pf head] | [胸部:viceskill_zhijia_pf cloth]\n";
		s += "手腕 | [手部:viceskill_zhijia_pf hand]\n";
		s += "[腿部:viceskill_zhijia_pf thou] | [脚部:viceskill_zhijia_pf shoes]\n";
	}
	else if(arg == "hand"){
		s += "[头部:viceskill_zhijia_pf head] | [胸部:viceskill_zhijia_pf cloth]\n";
		s += "[手腕:viceskill_zhijia_pf waste] | 手部\n";
		s += "[腿部:viceskill_zhijia_pf thou] | [脚部:viceskill_zhijia_pf shoes]\n";
	}
	else if(arg == "thou"){
		s += "[头部:viceskill_zhijia_pf head] | [胸部:viceskill_zhijia_pf cloth]\n";
		s += "[手腕:viceskill_zhijia_pf waste] | [手部:viceskill_zhijia_pf hand]\n";
		s += "腿部 | [脚部:viceskill_zhijia_pf shoes]\n";
	}
	else if(arg == "shoes"){
		s += "[头部:viceskill_zhijia_pf head] | [胸部:viceskill_zhijia_pf cloth]\n";
		s += "[手腕:viceskill_zhijia_pf waste] | [手部:viceskill_zhijia_pf hand]\n";
		s += "[腿部:viceskill_zhijia_pf thou] | 脚部\n";
	}
	s += "--------\n";
	s += ZHIJIAD->query_peifang(me,arg);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:viceskill_view zhijia]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
