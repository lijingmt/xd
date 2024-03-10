#include <globals.h>
#include <mudlib/include/mudlib.h>
string skill_bname = "";//技能名称
int level_limit = 0;//等级限制
int beidong_level = 0;//被动技能书的等级
string profe_read_limit="";//职业限制 职业id：职业名字
int viceskill_level = 0;  //学习配方的熟练度限制
int peifang_id = 0; //配方id，通过此id在duanzaod或者liandand中获得这个配方的信息
int read_flag = 1;//阅读过的标记
int skill_level = 0;//主动技能书的等级
int is_book(){
	return 1;
}
//主动技能的学习
int read(){
	object me=this_player();
	if(me&&me->is_character()){
		if(me->query_level()>=this_object()->level_limit){//等级符合要求可以学习
			if(this_object()->profe_read_limit==me->query_profe_cn(me->query_profeId())){ //职业要求要求可以学习
				if(me->skills[this_object()->skill_bname]==0){
					me->skills[this_object()->skill_bname]=({1,0});
					this_object()->read_flag = 0;
					return 1;//成功学习了该新技能
				}
				else {
					//用于学习10级以上的技能，added by caijie 080826
					if(!this_object()->skill_level)
						return 2;//已经学会了该技能，不用重复学
					int cur_level = me->skills[this_object()->skill_bname][0];
					int skill_level = this_object()->skill_level;
					int diff = skill_level - cur_level;
					if(diff<1)
						return 6;//同级不能学习
					else if (diff==1){
						me->skills[this_object()->skill_bname]=({skill_level,0});
						this_object()->read_flag = 0;
						return 1;//成功学习了技能熟练度超过10级以上的技能
					}
					else if(diff>1)
						return 7;
					//added by caijie end
				}
			}
			else
				return 3;//职业限制不能学习
		}
		else
			return 4;//等级限制不能学习
	}
	return 0;//学习新技能失败
}
//被动技能的学习
int beidong_read(){
	object me=this_player();
	if(me&&me->is_character()){
		if(me->query_level()>=this_object()->level_limit){//等级符合要求可以学习
			if(this_object()->profe_read_limit==me->query_profe_cn(me->query_profeId())){//职业要求要求可以学习
				//如果第一次学习该技能,并且该技能书为1级,可以学习到一级
				if(me->skills[this_object()->skill_bname]==0){
					if(this_object()->beidong_level==1){//该被动技能书为1级可以直接学到
						//将该被动技能增加的属性加到用户身上
						//得到该技能对象在内存中
						int cur_book_skills_value = 0;
						int add_skills_value = 0;
						string buff_type = ""; 
						//该被动技能在用户技能内存对象中,可以取值
						cur_book_skills_value = (int)MUD_SKILLSD[this_object()->skill_bname]->query_performs_attack(1);
						//被动技能增加的属性
						buff_type = (string)MUD_SKILLSD[this_object()->skill_bname]->s_curse_type;
						//先得到并减去当前等级技能书附加的属性
						add_skills_value = cur_book_skills_value;
						//然后将学到的该被动技能等级的属性加到该玩家身上
						if(add_skills_value>0){
							//根据被动技能增加属性的不同,来增加用户属性如下
							if(buff_type=="str")
								me->set_base_str(add_skills_value);
							else if(buff_type=="dex")
								me->set_base_dex(add_skills_value);
							else if(buff_type=="think")
								me->set_base_think(add_skills_value);
							else if(buff_type=="all"){
								me->set_base_all(add_skills_value);
							}
							else if(buff_type=="defend"){
								me->set_base_defend(add_skills_value);		
							}
							else if(buff_type=="hitte")
								me->set_base_hitte(add_skills_value);		
							else if(buff_type=="doub")
								me->set_base_baoji(add_skills_value);		
							else if(buff_type=="dodge")
								me->set_base_dodge(add_skills_value);		
						}
						//再将该技能放置到用户身上,并设置等级
						me->skills[this_object()->skill_bname]=({1,0});
						this_object()->read_flag = 0;
						return 1;//成功学习了该新技能
					}
					else{
						return 5;//如果第一次学该被动技能,技能书不为1级,则不能学习
					}
				}
				else{//已经学会了该技能,判断是否能学该技能的下一个级别
					int cur_user_level = (int)me->skills[this_object()->skill_bname][0];
					int cur_book_level = this_object()->beidong_level;
					int diff = cur_book_level - cur_user_level;
					if(diff<1)//该技能书等级根玩家当前技能等级相同,不能学习
						return 6;
					else if(diff==1){//该技能书正好是下一级的技能书,可以学习
						//得到该技能对象在内存中
						int cur_user_skills_value = 0;
						int cur_book_skills_value = 0;
						int add_skills_value = 0;
						string buff_type = ""; 
						mapping m=me->skills;
						if(m&&sizeof(m)){
							foreach(sort(indices(m)),string name){
								if(this_object()->skill_bname==name){
									//该被动技能在用户技能内存对象中,可以取值
									cur_user_skills_value = (int)MUD_SKILLSD[name]->query_performs_attack(cur_user_level);
									cur_book_skills_value = (int)MUD_SKILLSD[name]->query_performs_attack(cur_book_level);
									//被动技能增加的属性
									buff_type = (string)MUD_SKILLSD[name]->s_curse_type;
									break;
								}
							}
						}
						//先得到并减去当前等级技能书附加的属性
						add_skills_value = cur_book_skills_value - cur_user_skills_value;
						//然后将学到的该被动技能等级的属性加到该玩家身上
						if(add_skills_value>0){
							//根据被动技能增加属性的不同,来增加用户属性如下
							if(buff_type=="str")
								me->set_base_str(cur_book_skills_value);		
							else if(buff_type=="dex")
								me->set_base_dex(cur_book_skills_value);		
							else if(buff_type=="think")
								me->set_base_think(cur_book_skills_value);		
							else if(buff_type=="all"){
								me->set_base_all(cur_book_skills_value);		
							}
							else if(buff_type=="defend"){
								me->set_base_defend(cur_book_skills_value);	
							}
							else if(buff_type=="hitte")
								me->set_base_hitte(cur_book_skills_value);		
							else if(buff_type=="doub")
								me->set_base_baoji(cur_book_skills_value);		
							else if(buff_type=="dodge")
								me->set_base_dodge(cur_book_skills_value);		
						}
						//再将该学到的技能新等级赋予该用户该技能上
						me->skills[this_object()->skill_bname][0]++;
						this_object()->read_flag = 0;
						return 1;//成功学习并提升了该技能到下一等级
					}
					else if(diff>1)//该技能书大于下一级的技能书,不能学习
						return 7;	
				}
			}
			else
				return 3;//职业限制不能学习
		}
		else{
			return 4;//等级限制不能学习
		}
	}
	return 0;//学习新技能失败
}

//53级，65级特殊技能的学习
//是以新换旧的形式
int spec_read(string old){
	object me=this_player();
	if(me&&me->is_character()){
		if(me->query_level()>=this_object()->level_limit){//等级符合要求可以学习
			if(this_object()->profe_read_limit==me->query_profe_cn(me->query_profeId())){ //职业要求要求可以学习
				if(!me->skills[this_object()->skill_bname]){
					if(me->skills[old]){
						m_delete(me->skills,old);
						me->skills[this_object()->skill_bname]=({1,0});
						this_object()->read_flag = 0;
						return 1;//成功学习了该新技能
					}
					else
						return 5;//必须学会前一级
				}
				else {
					return 6;//必须学会前一级，并且不能重复学习
				}
			}
			else
				return 3;//职业限制不能学习
		}
		else
			return 4;//等级限制不能学习
	}
	return 0;//学习新技能失败
}

//学习锻造配方时调用
int duanzao_read()
{
	object me = this_player();
	object peifang = this_object();
	string type = peifang->query_peifang_type();
	if(me->vice_skills["duanzao"] == 0)
		return 8; //不会锻造技能
	else{
		int p_id = peifang->peifang_id;
		array(int) skill = me->vice_skills["duanzao"];
		int lev_limit = peifang->viceskill_level;
		if(lev_limit<0)
			return 9; //配方要求熟练度<0,说明导表时出错了
		else{
			int now_lev = (int)skill[0];
			if(now_lev < lev_limit)
				return 10;//熟练度不够，无法学习
			else{
				if(type == "d_weapon"){
					if(me["/duanzao/d_weapon"][p_id] == 0){
						me["/duanzao/d_weapon"][p_id]=1;
						peifang->read_flag = 0;
						return 1;//学习成功
					}
					else
						return 11;//已学过此配方
				}
				else if(type == "m_weapon"){
					if(me["/duanzao/m_weapon"][p_id] == 0){
						me["/duanzao/m_weapon"][p_id]=1;
						peifang->read_flag = 0;
						return 1;//学习成功
					}
					else
						return 11;//已学过此配方
				}
				else if(type == "s_weapon"){
					if(me["/duanzao/s_weapon"][p_id] == 0){
						me["/duanzao/s_weapon"][p_id]=1;
						peifang->read_flag = 0;
						return 1;//学习成功
					}
					else
						return 11;//已学过此配方
				}
				else if(type == "armor"){
					if(me["/duanzao/armor"][p_id] == 0){
						me["/duanzao/armor"][p_id]=1;
						peifang->read_flag = 0;
						return 1;//学习成功
					}
					else
						return 11;//已学过此配方
				}
			}
		}
	}
}

//学习炼丹配方时调用
int liandan_read()
{
	object me = this_player();
	object peifang = this_object();
	string type = peifang->query_peifang_type();
	if(me->vice_skills["liandan"] == 0)
		return 8; //不会炼丹技能
	else{
		int p_id = peifang->peifang_id;
		array(int) skill = me->vice_skills["liandan"];
		int lev_limit = peifang->viceskill_level;
		if(lev_limit<0)
			return 9; //配方要求熟练度<0,说明导表时出错了
		else{
			int now_lev = (int)skill[0];
			if(now_lev < lev_limit)
				return 10;//熟练度不够，无法学习
			else{
				if(me["/liandan/"+type][p_id] == 0){
					me["/liandan/"+type][p_id]=1;
					peifang->read_flag = 0;
					return 1;//学习成功
				}
				else
					return 11;//已学过此配方
			}
		}
	}
}
//学习裁缝配方时调用
int caifeng_read()
{
	object me = this_player();
	object peifang = this_object();
	string type = peifang->query_peifang_type();
	if(me->vice_skills["caifeng"] == 0)
		return 8; //不会裁缝技能
	else{
		int p_id = peifang->peifang_id;
		array(int) skill = me->vice_skills["caifeng"];
		int lev_limit = peifang->viceskill_level;
		if(lev_limit<0)
			return 9; //配方要求熟练度<0,说明导表时出错了
		else{
			int now_lev = (int)skill[0];
			if(now_lev < lev_limit)
				return 10;//熟练度不够，无法学习
			else{
				if(me["/caifeng/"+type][p_id] == 0){
					me["/caifeng/"+type][p_id]=1;
					peifang->read_flag = 0;
					return 1;//学习成功
				}
				else
					return 11;//已学过此配方
			}
		}
	}
}
//学习制甲配方时调用
int zhijia_read()
{
	object me = this_player();
	object peifang = this_object();
	string type = peifang->query_peifang_type();
	if(me->vice_skills["zhijia"] == 0)
		return 8; //不会制甲技能
	else{
		int p_id = peifang->peifang_id;
		array(int) skill = me->vice_skills["zhijia"];
		int lev_limit = peifang->viceskill_level;
		if(lev_limit<0)
			return 9; //配方要求熟练度<0,说明导表时出错了
		else{
			int now_lev = (int)skill[0];
			if(now_lev < lev_limit)
				return 10;//熟练度不够，无法学习
			else{
				if(me["/zhijia/"+type][p_id] == 0){
					me["/zhijia/"+type][p_id]=1;
					peifang->read_flag = 0;
					return 1;//学习成功
				}
				else
					return 11;//已学过此配方
			}
		}
	}
}


