#include <globals.h>
#include <mudlib/include/mudlib.h>
#define level_max 11
string view_skills()
{
	mapping m=this_object()->skills;
	string e=this_object()->skills_enable;

	string out="";
	if(m&&sizeof(m)){
		foreach(sort(indices(m)),string name){
			if(e==name){
				out+="□";
			}
			//技能冷却信息
			string coldtime_s = "";
			if(this_object()->f_skills[name]>1){
				int coldtime_sec = this_object()->f_skills[name]-1;
				int coldtime_min = coldtime_sec/60;
				if(coldtime_min>1){
					coldtime_s = "("+(coldtime_min+1)+"m)";
				}
				else
					coldtime_s = "("+(coldtime_sec+1)+"s)";
			}

			if(MUD_SKILLSD[name]->query_name() == "chongdong" || MUD_SKILLSD[name]->s_skill_type == "spec" || MUD_SKILLSD[name]->s_skill_type == "70_spec")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+":skill_detail "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]<level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):skill_detail "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级):skill_detail "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="beidong")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级/5级):skill_detail "+name+"](被动)";
			out += coldtime_s+"\n";
		}
		if(out==""){
			return "你还没有学习过任何技能。";
		}
	}
	else if(out==""){
		return "你还不会任何技能。";
	}
	return out;
}
//用于在不同指令中查看技能的方法，以指令名为参数,added by caijie 08/11/17
string view_skills_mud(string cmds)
{
	mapping m=this_object()->skills;
	string e=this_object()->skills_enable;

	string out="";
	if(m&&sizeof(m)){
		foreach(sort(indices(m)),string name){
			if(e==name){
				out+="□";
			}
			//技能冷却信息
			string coldtime_s = "";
			if(this_object()->f_skills[name]>1){
				int coldtime_sec = this_object()->f_skills[name]-1;
				int coldtime_min = coldtime_sec/60;
				if(coldtime_min>1){
					coldtime_s = "("+(coldtime_min+1)+"m)";
				}
				else
					coldtime_s = "("+(coldtime_sec+1)+"s)";
			}
			if(MUD_SKILLSD[name]->query_name() == "chongdong" || MUD_SKILLSD[name]->s_skill_type == "spec" || MUD_SKILLSD[name]->s_skill_type == "70_spec")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+":"+cmds+" "+name+"]";
			if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]<level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):"+cmds+" "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级):"+cmds+" "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="beidong")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级/5级):"+cmds+" "+name+"](被动)";
			out += coldtime_s+"\n";
		}
		if(out==""){
			return "你还没有学习过任何技能。";
		}
	}
	else if(out==""){
		return "你还不会任何技能。";
	}
	return out;
}
//配置技能快捷键时调用，由liaocheng于07/4/16添加
string view_skills_toolbar(int num)
{
	mapping m=this_object()->skills;
	string e=this_object()->skills_enable;

	string out="";
	if(m&&sizeof(m)){
		foreach(sort(indices(m)),string name){
			if(e==name){
				out+="□";
			}
			if(MUD_SKILLSD[name]->query_name() == "chongdong" || MUD_SKILLSD[name]->s_skill_type == "spec" || MUD_SKILLSD[name]->s_skill_type == "70_spec")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+":toolbar_set "+num+" "+name+" 1]\n";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]<level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):toolbar_set "+num+" "+name+" 1]\n";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级):toolbar_set "+num+" "+name+" 1]\n";
		}
		if(out==""){
			return "你还没有学习过任何技能。";
		}
	}
	else
	if(out==""){
		return "你还不会任何技能。";
	}
	return out;
}
string view_performs(string name)
{
	string out="";
	object cur_skill = MUD_SKILLSD[name];
	if(cur_skill){
		if(cur_skill->query_name() == "chongdong" || cur_skill->s_skill_type == "spec" || MUD_SKILLSD[name]->s_skill_type == "70_spec")
			out+=MUD_SKILLSD[name]->query_name_cn()+"\n";
		else if(cur_skill->s_type=="zhudong"&&this_object()->skills[name][0]<level_max)
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"级/"+(int)(100*(this_object()->skills[name][1])/(cur_skill->performs_shuliandu[this_object()->skills[name][0]]))+"%)\n";
		else if(cur_skill->s_type=="zhudong"&&this_object()->skills[name][0]==level_max)
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"级)\n";
		else if(cur_skill->s_type=="beidong")
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"级/5级)\n";
		out += cur_skill->query_picture_url()+"\n";
		if(cur_skill->s_type=="zhudong")
			out+="主动技能，";
		else if(cur_skill->s_type=="beidong")
			out+="被动技能，";
		out+=cur_skill->query_desc()+cur_skill->query_performs_desc((int)this_object()->skills[name][0])+"\n";
	
		mapping(int:string) lvLimit = cur_skill->query_performs_level_limit_all();
		if(lvLimit && sizeof(lvLimit))//该技能有等级限制
		{
			out += "等级需求：";
			if(sizeof(lvLimit) == 1){ //只有一个级别的技能
				out += "Lv" + lvLimit[1] + "\n";
			}
			else{//多个级别的技能则分别显示
				out += "\n";
				for(int i=1;i<=sizeof(lvLimit);i++)
					out += i+"级: Lv" + lvLimit[i] + "\n";
			}
		}

		if(cur_skill->s_type=="zhudong"){
			if(name==this_object()->skills_enable)
				out+="[取消自动施放:disable_autoSkills "+name+"]";
			else
				out+="[自动施放:set_autoSkills "+name+"]";
		}
	}
	else{
		return "你要查看的技能不存在。";
	}
	if(out==""){
		return "你要查看哪个技能？";
	}
	return out;
}
string view_use_performs()
{
	mapping m=this_object()->skills;
	string e=this_object()->skills_enable;

	string out="";
	if(m&&sizeof(m)){
		foreach(sort(indices(m)),string name){
			if(MUD_SKILLSD[name]->s_type=="beidong")
				continue;//被动技能在战斗调用界面中不显示
			if(e==name)
				out+="□";
			//技能冷却信息
			string coldtime_s = "";
			if(this_object()->f_skills[name]>1){
				int coldtime_sec = this_object()->f_skills[name]-1;
				int coldtime_min = coldtime_sec/60;
				if(coldtime_min>1)
					coldtime_s = "("+(coldtime_min+1)+"m)";
				else
					coldtime_s = "("+(coldtime_sec+1)+"s)";
			}
			if(MUD_SKILLSD[name]->query_name() == "chongdong" || MUD_SKILLSD[name]->s_skill_type == "spec")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+":use_perform "+name+"]";
			else if(m[name][0]<level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):use_perform "+name+"]";
			else if(m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"级):use_perform "+name+"]";
			out += coldtime_s+"\n";
		}
		if(out==""){
			return "你还没有学习过任何能够主动施放的技能。";
		}
	}
	else
		if(out==""){
			return "你还没有学习过任何能够施放的技能。";
		}
	return out;
}

//返回技能上限
int query_skill_up()
{
	return level_max;
}
