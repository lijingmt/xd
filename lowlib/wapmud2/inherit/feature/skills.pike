#include <globals.h>
#include <mudlib/include/mudlib.h>
#define level_max 11

// 技能对象在重启后按需注册。只允许载入人物存档中真实拥有的受限技能名，
// 既避免技能页把已学技能误判为不存在，也阻止伪造 skill_detail 路径。
private object|zero query_owned_skill_object(string name)
{
	object|zero skill = 0;
	mixed load_err = 0;
	if(!name || name=="" || sizeof(name)>64 ||
	   search(name,"/")!=-1 || search(name,"..")!=-1 ||
	   !this_object()->skills || !this_object()->skills[name] ||
	   (int)this_object()->skills[name][0]<=0)
		return 0;
	skill = MUD_SKILLSD[name];
	if(!skill){
		load_err = catch {
			skill = (object)(ROOT+"/gamelib/single/skills/"+name);
		};
		if(load_err)
			skill = 0;
	}
	return skill;
}

// 返回技能真正配置的熟练度上限；未声明时保持老职业10级规则。
int query_skill_training_level_max(string name)
{
	object|zero skill = query_owned_skill_object(name);
	if(skill && skill->query_skill_level_max)
		return (int)skill->query_skill_level_max();
	return level_max-1;
}

// f_skills 保存的是“剩余秒数+1”。统一在这里转换，避免技能列表、
// 战斗技能页和详情页分别计算时把整分钟冷却多显示一分钟。
private string query_skill_cooldown_text(string name)
{
	int coldtime_sec;
	int coldtime_min;
	if(!name || !this_object()->f_skills ||
	   (int)this_object()->f_skills[name]<=1)
		return "";
	coldtime_sec = (int)this_object()->f_skills[name]-1;
	if(coldtime_sec>=60){
		coldtime_min = coldtime_sec/60;
		if(coldtime_sec%60>0)
			coldtime_min++;
		return "("+coldtime_min+"m)";
	}
	return "("+coldtime_sec+"s)";
}

string view_skills()
{
	mapping m=this_object()->skills;
	string e=this_object()->skills_enable;

	string out="";
	if(m&&sizeof(m)){
		foreach(sort(indices(m)),string name){
			object|zero skill = query_owned_skill_object(name);
			if(!skill)
				continue;
			int skill_level_max = query_skill_training_level_max(name);

			if(e==name){
				out+="□";
			}
			//技能冷却信息
			string coldtime_s = query_skill_cooldown_text(name);

			if(skill->query_name() == "chongdong" || skill->s_skill_type == "spec" || skill->s_skill_type == "70_spec")
				out+="["+skill->query_name_cn()+":skill_detail "+name+"]";
			else if(skill->s_type=="zhudong"&&m[name][0]<skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(skill->performs_shuliandu[m[name][0]]))+"%):skill_detail "+name+"]";
			else if(skill->s_type=="zhudong"&&m[name][0]>=skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级):skill_detail "+name+"]";
			else if(skill->s_type=="beidong")
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级/5级):skill_detail "+name+"](被动)";
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
			object|zero skill = query_owned_skill_object(name);
			if(!skill)
				continue;
			int skill_level_max = query_skill_training_level_max(name);

			if(e==name){
				out+="□";
			}
			//技能冷却信息
			string coldtime_s = query_skill_cooldown_text(name);
			if(skill->query_name() == "chongdong" || skill->s_skill_type == "spec" || skill->s_skill_type == "70_spec")
				out+="["+skill->query_name_cn()+":"+cmds+" "+name+"]";
			else if(skill->s_type=="zhudong"&&m[name][0]<skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(skill->performs_shuliandu[m[name][0]]))+"%):"+cmds+" "+name+"]";
			else if(skill->s_type=="zhudong"&&m[name][0]>=skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级):"+cmds+" "+name+"]";
			else if(skill->s_type=="beidong")
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级/5级):"+cmds+" "+name+"](被动)";
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
			object|zero skill = query_owned_skill_object(name);
			if(!skill)
				continue;
			int skill_level_max = query_skill_training_level_max(name);

			if(e==name){
				out+="□";
			}
			if(skill->query_name() == "chongdong" || skill->s_skill_type == "spec" || skill->s_skill_type == "70_spec")
				out+="["+skill->query_name_cn()+":toolbar_set "+num+" "+name+" 1]\n";
			else if(skill->s_type=="zhudong"&&m[name][0]<skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(skill->performs_shuliandu[m[name][0]]))+"%):toolbar_set "+num+" "+name+" 1]\n";
			else if(skill->s_type=="zhudong"&&m[name][0]>=skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级):toolbar_set "+num+" "+name+" 1]\n";
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
	object|zero cur_skill = query_owned_skill_object(name);
	string coldtime_s = query_skill_cooldown_text(name);
	if(!cur_skill)
		return "你要查看的技能不存在。";

	if(cur_skill){
		int skill_level_max = query_skill_training_level_max(name);
		int display_level = (int)this_object()->skills[name][0];
		if(display_level > skill_level_max)
			display_level = skill_level_max;
		if(cur_skill->query_name() == "chongdong" || cur_skill->s_skill_type == "spec" || cur_skill->s_skill_type == "70_spec")
			out+=cur_skill->query_name_cn()+"\n";
		else if(cur_skill->s_type=="zhudong"&&this_object()->skills[name][0]<skill_level_max)
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"级/"+(int)(100*(this_object()->skills[name][1])/(cur_skill->performs_shuliandu[this_object()->skills[name][0]]))+"%)\n";
		else if(cur_skill->s_type=="zhudong"&&this_object()->skills[name][0]>=skill_level_max)
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"级)\n";
		else if(cur_skill->s_type=="beidong")
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"级/5级)\n";
		if(coldtime_s!="")
			out += "当前冷却："+coldtime_s+"\n";
		out += cur_skill->query_picture_url()+"\n";
		if(cur_skill->s_type=="zhudong")
			out+="主动技能，";
		else if(cur_skill->s_type=="beidong")
			out+="被动技能，";
		out+=cur_skill->query_desc()+cur_skill->query_performs_desc(display_level)+"\n";
		//有时候有些技能例如 金蝉魅影 找不到这个方法，只能先判断这个方法是否存在，然后再执行。
		mapping(int:int) lvLimit = cur_skill->query_performs_level_limit_all?cur_skill->query_performs_level_limit_all():0;
		//mapping(int:int) lvLimit = cur_skill->query_performs_level_limit_all();
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
			object auto_daemon=(object)(ROOT+
				"/gamelib/single/daemons/autofightd.pike");
			array(string) queue=auto_daemon->query_auto_skill_queue(
				this_object());
			out+="自动连招：";
			for(int slot=1;slot<=3;slot++){
				if(queue[slot-1]==name)
					out+="[取消优先"+slot+":disable_autoSkills "+
						name+" "+slot+"] ";
				else
					out+="[设为优先"+slot+":set_autoSkills "+
						name+" "+slot+"] ";
			}
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
			object|zero skill = query_owned_skill_object(name);
			if(!skill)
				continue;
			int skill_level_max = query_skill_training_level_max(name);

			if(skill->s_type=="beidong")
				continue;//被动技能在战斗调用界面中不显示
			if(e==name)
				out+="□";
			//技能冷却信息
			string coldtime_s = query_skill_cooldown_text(name);
			if(skill->query_name() == "chongdong" || skill->s_skill_type == "spec")
				out+="["+skill->query_name_cn()+":use_perform "+name+"]";
			else if(m[name][0]<skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级/"+(int)(100*(m[name][1])/(skill->performs_shuliandu[m[name][0]]))+"%):use_perform "+name+"]";
			else if(m[name][0]>=skill_level_max)
				out+="["+skill->query_name_cn()+"("+m[name][0]+"级):use_perform "+name+"]";
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
int query_skill_up(void|string name)
{
	if(name && sizeof(name))
		return query_skill_training_level_max(name);
	return level_max;
}
