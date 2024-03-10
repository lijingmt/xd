#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name
int main(string arg)
{
	string s = "";
	object me=this_player();
	string skill_name = "";
	sscanf(arg,"%s",skill_name);
	array(int) tmp_vice = me->vice_skills[skill_name];
	//tmp_vice[0]:当前熟练度，[1]:当前熟练度下的已使用技能次数，[2]:此技能熟练度上限。
	if(tmp_vice && sizeof(tmp_vice)){
		int now_lev = tmp_vice[0];
		int max_lev = tmp_vice[2];
		if(skill_name == "caikuang"){
			s += "采矿\n可以在矿藏中采集到矿石和宝石\n";
			s += "熟练度："+now_lev+"/"+max_lev+"\n";
			//s += "[遗忘此技能:viceskill_giveup caikuang 0]\n";
		}
		else if(skill_name == "duanzao"){
			s += "锻造\n可以锻造，熔炼出装备，也可以将装备溶解成材料再利用\n";
			s += "熟练度："+now_lev+"/"+max_lev+"\n";
			s += "[已会的锻造配方:viceskill_duanzao_pf m_weapon]\n";
			//s += "[遗忘此技能:viceskill_giveup duanzao 0]\n";
		}
		else if(skill_name == "caiyao"){
			s += "采药\n可以从采集野外的草药，这些都是炼丹的必需品\n";
			s += "熟练度："+now_lev+"/"+max_lev+"\n";
			//s += "[遗忘此技能:viceskill_giveup caikuang 0]\n";
		}
		else if(skill_name == "liandan"){
			s += "炼丹\n可以将草药炼制成为各种具有神奇功效的丹药\n";
			s += "熟练度："+now_lev+"/"+max_lev+"\n";
			s += "[炼制丹药:viceskill_liandan_pf normal]\n";
			//s += "[遗忘此技能:viceskill_giveup caikuang 0]\n";
		}
		else if(skill_name == "caifeng"){
			s += "裁缝\n可以将布料做成各种轻盈的布衣装备\n";
			s += "熟练度："+now_lev+"/"+max_lev+"\n";
			s += "[缝制:viceskill_caifeng_pf head]\n";
		}
		else if(skill_name == "zhijia"){
			s += "制甲\n可以将皮革做成各种坚韧的皮甲装备\n";
			s += "熟练度："+now_lev+"/"+max_lev+"\n";
			s += "[制造:viceskill_zhijia_pf head]\n";
		}
		s += "[遗忘此技能:viceskill_giveup "+skill_name+" 0]\n";
	}
	else 
		s += "你不会此技能，或者你有非法的操作，请联系管理员\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
