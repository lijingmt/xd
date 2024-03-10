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
				out+="��";
			}
			//������ȴ��Ϣ
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
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):skill_detail "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��):skill_detail "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="beidong")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��/5��):skill_detail "+name+"](����)";
			out += coldtime_s+"\n";
		}
		if(out==""){
			return "�㻹û��ѧϰ���κμ��ܡ�";
		}
	}
	else if(out==""){
		return "�㻹�����κμ��ܡ�";
	}
	return out;
}
//�����ڲ�ָͬ���в鿴���ܵķ�������ָ����Ϊ����,added by caijie 08/11/17
string view_skills_mud(string cmds)
{
	mapping m=this_object()->skills;
	string e=this_object()->skills_enable;

	string out="";
	if(m&&sizeof(m)){
		foreach(sort(indices(m)),string name){
			if(e==name){
				out+="��";
			}
			//������ȴ��Ϣ
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
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):"+cmds+" "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��):"+cmds+" "+name+"]";
			else if(MUD_SKILLSD[name]->s_type=="beidong")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��/5��):"+cmds+" "+name+"](����)";
			out += coldtime_s+"\n";
		}
		if(out==""){
			return "�㻹û��ѧϰ���κμ��ܡ�";
		}
	}
	else if(out==""){
		return "�㻹�����κμ��ܡ�";
	}
	return out;
}
//���ü��ܿ�ݼ�ʱ���ã���liaocheng��07/4/16���
string view_skills_toolbar(int num)
{
	mapping m=this_object()->skills;
	string e=this_object()->skills_enable;

	string out="";
	if(m&&sizeof(m)){
		foreach(sort(indices(m)),string name){
			if(e==name){
				out+="��";
			}
			if(MUD_SKILLSD[name]->query_name() == "chongdong" || MUD_SKILLSD[name]->s_skill_type == "spec" || MUD_SKILLSD[name]->s_skill_type == "70_spec")
				out+="["+MUD_SKILLSD[name]->query_name_cn()+":toolbar_set "+num+" "+name+" 1]\n";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]<level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):toolbar_set "+num+" "+name+" 1]\n";
			else if(MUD_SKILLSD[name]->s_type=="zhudong"&&m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��):toolbar_set "+num+" "+name+" 1]\n";
		}
		if(out==""){
			return "�㻹û��ѧϰ���κμ��ܡ�";
		}
	}
	else
	if(out==""){
		return "�㻹�����κμ��ܡ�";
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
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"��/"+(int)(100*(this_object()->skills[name][1])/(cur_skill->performs_shuliandu[this_object()->skills[name][0]]))+"%)\n";
		else if(cur_skill->s_type=="zhudong"&&this_object()->skills[name][0]==level_max)
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"��)\n";
		else if(cur_skill->s_type=="beidong")
			out += cur_skill->query_name_cn()+"("+this_object()->skills[name][0]+"��/5��)\n";
		out += cur_skill->query_picture_url()+"\n";
		if(cur_skill->s_type=="zhudong")
			out+="�������ܣ�";
		else if(cur_skill->s_type=="beidong")
			out+="�������ܣ�";
		out+=cur_skill->query_desc()+cur_skill->query_performs_desc((int)this_object()->skills[name][0])+"\n";
	
		mapping(int:string) lvLimit = cur_skill->query_performs_level_limit_all();
		if(lvLimit && sizeof(lvLimit))//�ü����еȼ�����
		{
			out += "�ȼ�����";
			if(sizeof(lvLimit) == 1){ //ֻ��һ������ļ���
				out += "Lv" + lvLimit[1] + "\n";
			}
			else{//�������ļ�����ֱ���ʾ
				out += "\n";
				for(int i=1;i<=sizeof(lvLimit);i++)
					out += i+"��: Lv" + lvLimit[i] + "\n";
			}
		}

		if(cur_skill->s_type=="zhudong"){
			if(name==this_object()->skills_enable)
				out+="[ȡ���Զ�ʩ��:disable_autoSkills "+name+"]";
			else
				out+="[�Զ�ʩ��:set_autoSkills "+name+"]";
		}
	}
	else{
		return "��Ҫ�鿴�ļ��ܲ����ڡ�";
	}
	if(out==""){
		return "��Ҫ�鿴�ĸ����ܣ�";
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
				continue;//����������ս�����ý����в���ʾ
			if(e==name)
				out+="��";
			//������ȴ��Ϣ
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
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��/"+(int)(100*(m[name][1])/(MUD_SKILLSD[name]->performs_shuliandu[m[name][0]]))+"%):use_perform "+name+"]";
			else if(m[name][0]==level_max)
				out+="["+MUD_SKILLSD[name]->query_name_cn()+"("+m[name][0]+"��):use_perform "+name+"]";
			out += coldtime_s+"\n";
		}
		if(out==""){
			return "�㻹û��ѧϰ���κ��ܹ�����ʩ�ŵļ��ܡ�";
		}
	}
	else
		if(out==""){
			return "�㻹û��ѧϰ���κ��ܹ�ʩ�ŵļ��ܡ�";
		}
	return out;
}

//���ؼ�������
int query_skill_up()
{
	return level_max;
}
