#include <command.h>
#include <gamelib/include/gamelib.h>
//用于提高技能熟练度
int main(string arg)
{
	object me = this_player();
	string s = "";
	string teyao_name = "";
	string skill_name = "";
	int count = 0;
	if(sscanf(arg,"%s %d %s",teyao_name,count,skill_name)!=3){
		sscanf(arg,"%s %d",teyao_name,count);
		teyao_name = arg;
		s += "请选择您要提升熟练度的技能:\n";
		//s += me->view_skills_mud("skill_eat_teyao "+teyao_name+" "+count); 
		s += me->view_skills_mud("skill_eat_teyao "+teyao_name); 
	}
	else{
		sscanf(arg,"%s %d %s",teyao_name,count,skill_name);
		mapping skills_m = me->skills;
		if(skills_m[skill_name] && skills_m[skill_name][0]<me->query_skill_up()){
			//当玩家拥有skill_name这种技能，且技能等级还没达到技能的上限
			object teyao = present(teyao_name,me,count);
			if(teyao){
				//玩家身上存在这种特药
				int effect_value = teyao->query_effect_value();
				if(teyao->query_danyao_type()=="skill_improve"){
					//提高技能熟练度
					int shuliandu = MUD_SKILLSD[skill_name]->performs_shuliandu[skills_m[skill_name][0]];
					int get_shuliandu = (int)(shuliandu*0.2);
					skills_m[skill_name][1] += get_shuliandu;
					s += "您食用了"+teyao->query_name_cn()+"使"+MUD_SKILLSD[skill_name]->query_name_cn()+"的熟练度提高了"+effect_value+"%\n";
					if(skills_m[skill_name][1]>shuliandu){
						skills_m[skill_name][1] = shuliandu;
					}
				}
				me->remove_combine_item(teyao_name,1);
			}
			else{
				s += "您背包里没有这种特药\n";
				s += "\n";
				s += "[购买:yushi_buy_teyao_list exp]\n";
			}
		}
		else{
			s += MUD_SKILLSD[skill_name]->query_name_cn()+"等级已达到技能上限，不能再提升，别浪费药了\n";
		}
		if(present(teyao_name,me)){
			s += "[返回:inventory_daoju]\n";
		}
		else{
			s += "[返回:yushi_buy_teyao_list exp]\n";
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
