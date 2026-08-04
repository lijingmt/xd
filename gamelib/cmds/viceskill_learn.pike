#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	string skill_name = "";
	int flag = 0;
	int valid_skill = 0;
	sscanf(arg,"%s %d",skill_name,flag);
	if(me->vice_skills==0)
		me->vice_skills=([]);
	ARTISAND->initialize_player(me);
	valid_skill = ARTISAND->is_valid_skill(skill_name);
	if(!valid_skill)
		s += "没有这种可以学习的百工技能。\n";
	else if(me->vice_skills[skill_name] != 0)
		s += "你已经学会了这种技能\n";
	else{
		if(flag == 0){
			if(skill_name == "caikuang"){
				s = "采矿技能：\n";
				s += "可以从矿藏中采集到矿石和宝石，这些都是锻造的必需品\n";
				s += "学费：10金\n";
			}
			else if(skill_name == "duanzao"){
				s = "锻造技能：\n";
				s += "可以锻造，熔炼出装备，也可以将装备溶解成材料再利用\n";
				s += "学费：10金\n";
			}
			else if(skill_name == "caiyao"){
				s = "采药技能：\n";
				s += "可以从采集野外的草药，这些都是炼丹的必需品\n";
				s += "学费：10金\n";
			}
			else if(skill_name == "liandan"){
				s = "炼丹技能：\n";
				s += "可以把采集的草药，炼制成具有各种特效的丹药\n";
				s += "学费：10金\n";
			}
			else if(skill_name == "caifeng"){
				s = "裁缝技能：\n";
				s += "可以把各种布料做成轻盈的布衣装备\n";
				s += "学费：10金\n";
			}
			else if(skill_name == "zhijia"){
				s = "制甲技能：\n";
				s += "可以把各种皮革做成坚韧的皮甲装备\n";
				s += "学费：10金\n";
			}
			s += "百工新规：基础手艺可以全部学习；熟练度达到210后，可在百工坊选择一项大师专精。\n";
			s += "[学习:viceskill_learn "+skill_name+" 1]\n";
		}
		else if(flag == 1){
			if(me->query_account()<1000){
				s += "学习失败！\n";
				s += "穷小子还想来骗手艺，努力赚够钱了再来找我吧\n";
			}
			else{
				mapping old_vice_skills = copy_value(me->vice_skills);
				mixed old_recipe_data = copy_value(me["/"+skill_name]);
				int old_account = me->query_account();
				int learned = 0;
				me->del_account(1000);
				if(skill_name == "caikuang"){
					me->vice_skills[skill_name]=({1,0,VICESKILL_UP});
					s = "学习成功！\n";
					s += "你获得了新的技能：采矿\n";
					learned = 1;
				}
				else if(skill_name == "duanzao"){
					me->vice_skills[skill_name]=({1,0,VICESKILL_UP});
					me["/duanzao/d_weapon"] = ([]);
					me["/duanzao/m_weapon"] = ([]);
					me["/duanzao/s_weapon"] = ([]);
					me["/duanzao/armor"] = ([]);
					me["/duanzao/weapon"] = ([]);
					s = "学习成功！\n";
					s += "你获得了新的技能：锻造\n";
					learned = 1;
				}
				else if(skill_name == "caiyao"){
					me->vice_skills[skill_name]=({1,0,VICESKILL_UP});
					s = "学习成功！\n";
					s += "你获得了新的技能：采药\n";
					learned = 1;
				}
				else if(skill_name == "liandan"){
					me->vice_skills[skill_name]=({1,0,VICESKILL_UP});
					me["/liandan/attri_base"] = ([]);
					me["/liandan/attri_vice"] = ([]);
					me["/liandan/attri_defend"] = ([]);
					me["/liandan/attri_attack"] = ([]);
					me["/liandan/spec"] = ([]);
					me["/liandan/normal"] = ([]);
					me["/liandan/attri_supply"] = ([]);
					s = "学习成功！\n";
					s += "你获得了新的技能：炼丹\n";
					learned = 1;
				}
				else if(skill_name == "caifeng"){
					me->vice_skills[skill_name]=({1,0,VICESKILL_UP});
					me["/caifeng/head"] = ([]);
					me["/caifeng/cloth"] = ([]);
					me["/caifeng/waste"] = ([]);
					me["/caifeng/hand"] = ([]);
					me["/caifeng/thou"] = ([]);
					me["/caifeng/shoes"] = ([]);
					me["/caifeng/other"] = ([]);
					s = "学习成功！\n";
					s += "你获得了新的技能：裁缝\n";
					learned = 1;
				}
				else if(skill_name == "zhijia"){
					me->vice_skills[skill_name]=({1,0,VICESKILL_UP});
					me["/zhijia/head"] = ([]);
					me["/zhijia/cloth"] = ([]);
					me["/zhijia/waste"] = ([]);
					me["/zhijia/hand"] = ([]);
					me["/zhijia/thou"] = ([]);
					me["/zhijia/shoes"] = ([]);
					s = "学习成功！\n";
					s += "你获得了新的技能：制甲\n";
					learned = 1;
				}
				if(!learned || !functionp(me->save_with_result) ||
				   !me->save_with_result()){
					me->vice_skills = old_vice_skills;
					me["/"+skill_name] = old_recipe_data;
					me->set_account(old_account);
					s = "学习存档失败，学费与技能变更已经回滚，请稍后重试。\n";
				}
				else{
					s += "基础手艺不再占用二选二名额。\n";
					s += "[前往百工坊:artisan]\n";
				}
			}
		}
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "[返回:look]\n";
	//write(s);
	return 1;
}
