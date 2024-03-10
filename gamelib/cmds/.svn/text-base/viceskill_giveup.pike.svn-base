#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag
//遗忘辅助技能的指令，所有辅助技能在被遗忘时都会调用
int main(string arg)
{
	string s = "";
	object me=this_player();
	string skill_name = "";
	string skill_name_cn = "";
	int flag = 0;
	sscanf(arg,"%s %d",skill_name,flag);
	if(me->vice_skills[skill_name] == 0)
		s += "你已经遗忘了这种技能\n";
	else{
		if(skill_name == "caikuang")
			skill_name_cn = "采矿";
		else if(skill_name == "duanzao")
			skill_name_cn = "锻造";
		else if(skill_name == "caiyao")
			skill_name_cn = "采药";
		else if(skill_name == "liandan")
			skill_name_cn = "炼金";
		if(flag == 0){
			s += "遗忘"+skill_name_cn+"技能\n";
			s += "遗忘此技能后，你将失去一切与此技能相关的能力！你确定要遗忘吗：\n";
			s += "[是:viceskill_giveup "+skill_name+" 1] [否:myskills]\n";
		}
		else if(flag == 1){
			m_delete(me->vice_skills,skill_name);
			s = "你遗忘了"+skill_name_cn+"技能\n";
			if(skill_name == "duanzao"){
				me["/duanzao"] = ([]);
				//me["/duanzao/m_weapon"] = ([]);
				//me["/duanzao/s_weapon"] = ([]);
				//me["/duanzao/armor"] = ([]);
			}
			else if(skill_name == "liandan"){
				me["/liandan"] = ([]);
			}
			s += "\n[返回:myskills]\n";
		}
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
