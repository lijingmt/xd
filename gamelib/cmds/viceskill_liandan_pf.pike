#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type 
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(arg == "attri_base"){
		s += "[［一般类］:viceskill_liandan_pf normal]|[［特殊类］:viceskill_liandan_pf spec]\n";
		s += "［属性类］|[［辅助类］:viceskill_liandan_pf attri_vice]\n";
		s += "[［伤害类］:viceskill_liandan_pf attri_attack]|[［防御类］:viceskill_liandan_pf attri_defend]\n";
	}
	else if(arg == "attri_vice"){
		s += "[［一般类］:viceskill_liandan_pf normal]|[［特殊类］:viceskill_liandan_pf spec]\n";
		s += "[［属性类］:viceskill_liandan_pf attri_base]|［辅助类］\n";
		s += "[［伤害类］:viceskill_liandan_pf attri_attack]|[［防御类］:viceskill_liandan_pf attri_defend]\n";
	}
	else if(arg == "attri_defend"){
		s += "[［一般类］:viceskill_liandan_pf normal]|[［特殊类］:viceskill_liandan_pf spec]\n";
		s += "[［属性类］:viceskill_liandan_pf attri_base]|[［辅助类］:viceskill_liandan_pf attri_vice]\n";
		s += "[［伤害类］:viceskill_liandan_pf attri_attack]|［防御类］\n";
	}
	else if(arg == "attri_attack"){
		s += "[［一般类］:viceskill_liandan_pf normal]|[［特殊类］:viceskill_liandan_pf spec]\n";
		s += "[［属性类］:viceskill_liandan_pf attri_base]|[［辅助类］:viceskill_liandan_pf attri_vice]\n";
		s += "［伤害类］|[［防御类］:viceskill_liandan_pf attri_defend]\n";
	}
	else if(arg == "normal"){
		s += "［一般类］|[［特殊类］:viceskill_liandan_pf spec]\n";
		s += "[［属性类］:viceskill_liandan_pf attri_base]|[［辅助类］:viceskill_liandan_pf attri_vice]\n";
		s += "[［伤害类］:viceskill_liandan_pf attri_attack]|[［防御类］:viceskill_liandan_pf attri_defend]\n";
	}
	else if(arg == "spec"){
		s += "[［一般类］:viceskill_liandan_pf normal]|［特殊类］\n";
		s += "[［属性类］:viceskill_liandan_pf attri_base]|[［辅助类］:viceskill_liandan_pf attri_vice]\n";
		s += "[［伤害类］:viceskill_liandan_pf attri_attack]|[［防御类］:viceskill_liandan_pf attri_defend]\n";
	}
	s += "--------\n";
	s += LIANDAND->query_peifang(me,arg);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:viceskill_view liandan]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
