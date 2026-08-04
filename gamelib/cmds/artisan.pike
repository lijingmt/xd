#include <command.h>
#include <gamelib/include/gamelib.h>

private string format_seconds(int seconds)
{
	int days;
	int hours;
	if(seconds<=0)
		return "现在";
	days = seconds/(24*60*60);
	hours = (seconds%(24*60*60))/(60*60);
	if(days>0)
		return (string)days+"天"+(string)hours+"小时后";
	if(hours<=0)
		return "1小时内";
	return (string)hours+"小时后";
}

private string view_pouch(object me)
{
	string s = "【百工材料囊】\n";
	mapping(string:int) materials = ARTISAND->query_pouch_materials(me);
	mapping(string:string) names = ARTISAND->query_pouch_material_names(me);
	array(string) item_names = sort(indices(materials));
	int total = 0;
	if(!sizeof(item_names))
		s += "材料囊目前为空。\n";
	foreach(item_names,string item_name){
		int amount = (int)materials[item_name];
		string name_cn = names[item_name] || item_name;
		total += amount;
		s += name_cn+" × "+(string)amount+"\n";
		s += "[取1份:artisan withdraw "+item_name+" 1]";
		if(amount>=10)
			s += "|[取10份:artisan withdraw "+item_name+" 10]";
		s += "|[全部取出:artisan withdraw "+item_name+" "+
			(string)amount+"]\n";
	}
	s += "--------\n共"+(string)total+"份材料；制作时会自动同时读取材料囊和包袱。\n";
	s += "[一键收纳包袱材料:artisan deposit]\n";
	if(ARTISAND->query_auto_pouch(me))
		s += "野外采集自动入囊：已开启 [关闭:artisan auto 0]\n";
	else
		s += "野外采集自动入囊：已关闭 [开启:artisan auto 1]\n";
	s += "[返回百工坊:artisan]|[返回游戏:look]\n";
	return s;
}

private string view_master(object me)
{
	string s = "【百工大师专精】\n";
	string specialty = ARTISAND->query_master_specialty(me);
	array(string) skills = ({"duanzao","liandan","caifeng","zhijia"});
	if(specialty=="")
		s += "当前尚未选择。首次选择免费，熟练度需达到"+
			(string)ARTISAND->query_master_level()+"。\n";
	else{
		s += "当前专精：§6"+ARTISAND->query_skill_name_cn(specialty)+"大师§r\n";
		s += "再次切换需"+
			MUD_MONEYD->query_other_money_cn(ARTISAND->query_master_switch_cost())+
			"，可切换时间："+
			format_seconds(ARTISAND->query_master_switch_remaining(me))+"。\n";
	}
	foreach(skills,string skill_name){
		array skill = me->vice_skills[skill_name];
		if(!arrayp(skill) || sizeof(skill)<3){
			s += ARTISAND->query_skill_name_cn(skill_name)+"：尚未学习\n";
			continue;
		}
		s += ARTISAND->query_skill_name_cn(skill_name)+"："+
			(string)skill[0]+"/"+(string)skill[2];
		if((int)skill[0]>=ARTISAND->query_master_level() &&
		   specialty!=skill_name)
			s += " [选择专精:artisan master "+skill_name+"]";
		else if(specialty==skill_name)
			s += "（当前专精）";
		s += "\n";
	}
	s += "--------\n大师专精提供高阶升阶制作、少量品质幸运和30次匠心保底；专精本身不直接增加角色属性。\n";
	s += "[高阶制作:artisan high]|[返回百工坊:artisan]|[返回游戏:look]\n";
	return s;
}

private string view_high_craft(object me)
{
	string s = "【大师高阶制作】\n";
	string specialty = ARTISAND->query_master_specialty(me);
	array(int) levels;
	array(int) recipes;
	if(specialty=="")
		return s+"请先选择大师专精。\n[选择专精:artisan master]|[返回百工坊:artisan]\n";
	if(specialty=="liandan")
		return s+"炼丹大师通过百颗批量炼制与补给配方发挥专长，不进行装备升阶。\n"+
			"[炼制丹药:viceskill_liandan_pf normal]|[返回百工坊:artisan]\n";
	levels = ARTISAND->query_master_target_levels(me);
	recipes = ARTISAND->query_high_recipe_ids(me,specialty);
	if(!sizeof(levels))
		s += "人物达到80级后才可进行高阶制作。\n";
	else if(!sizeof(recipes))
		s += "你还没有学会65级以上的"+
			ARTISAND->query_skill_name_cn(specialty)+"配方。\n";
	else{
		s += "当前专精："+ARTISAND->query_skill_name_cn(specialty)+
			"；可将已学65级以上配方升阶为不超过人物等级的装备。\n";
		foreach(levels,int target_level)
			s += "[制作"+(string)target_level+"级装备:artisan_master_craft "+
				specialty+" "+(string)target_level+"]\n";
	}
	s += "高阶制作按目标等级增加原料消耗，每次最多5件；Boss独有效果不会被复制。\n";
	s += "[返回大师专精:artisan master]|[返回百工坊:artisan]|[返回游戏:look]\n";
	return s;
}

private string view_main(object me)
{
	string s = "§6【百工坊·百工复兴】§r\n";
	string specialty = ARTISAND->query_master_specialty(me);
	array(string) skills = ({"caikuang","caiyao","duanzao","liandan","caifeng","zhijia"});
	s += "基础手艺可以全部学习；采集、包袱材料与材料囊已经打通。\n";
	if(specialty=="")
		s += "大师专精：尚未选择\n";
	else
		s += "大师专精：§6"+ARTISAND->query_skill_name_cn(specialty)+"§r\n";
	foreach(skills,string skill_name){
		array skill = me->vice_skills[skill_name];
		if(!arrayp(skill) || sizeof(skill)<3){
			s += ARTISAND->query_skill_name_cn(skill_name)+
				"：尚未学习 [了解并学习:viceskill_learn "+skill_name+" 0]\n";
			continue;
		}
		s += "["+ARTISAND->query_skill_name_cn(skill_name)+
			":viceskill_view "+skill_name+"] "+(string)skill[0]+"/"+
			(string)skill[2];
		if((int)skill[0]<(int)skill[2])
			s += "（进度"+(string)skill[1]+"/"+
				(string)ARTISAND->query_progress_required((int)skill[0])+"）";
		s += "\n";
	}
	s += "--------\n";
	s += "[材料囊:artisan pouch]|[大师专精:artisan master]|[高阶制作:artisan high]\n";
	s += "每门基础手艺学费10金，可全部学习，不再互相占用名额。\n";
	s += "[查看全部技能:myskills]|[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	string action = "";
	string value = "";
	int amount = 0;
	ARTISAND->initialize_player(me);
	if(!arg || arg=="")
		s = view_main(me);
	else if(arg=="pouch")
		s = view_pouch(me);
	else if(arg=="deposit"){
		mapping result = ARTISAND->deposit_all_materials(me);
		s = (string)result["message"]+"\n"+view_pouch(me);
	}
	else if(sscanf(arg,"withdraw %s %d",value,amount)==2){
		mapping result = ARTISAND->withdraw_material(me,value,amount);
		s = (string)result["message"]+"\n"+view_pouch(me);
	}
	else if(sscanf(arg,"auto %d",amount)==1){
		int old_value = (int)me["/artisan/auto_pouch"];
		if(amount!=0 && amount!=1)
			s = "自动收纳设置无效。\n";
		else{
			me["/artisan/auto_pouch"] = amount;
			if(!functionp(me->save_with_result) || !me->save_with_result()){
				me["/artisan/auto_pouch"] = old_value;
				s = "人物存档失败，设置没有改变。\n";
			}
			else if(amount)
				s = "野外采集材料自动入囊已经开启。\n";
			else
				s = "野外采集材料自动入囊已经关闭。\n";
		}
		s += view_pouch(me);
	}
	else if(arg=="master")
		s = view_master(me);
	else if(sscanf(arg,"master %s",value)==1){
		mapping result = ARTISAND->select_master_specialty(me,value);
		s = (string)result["message"]+"\n"+view_master(me);
	}
	else if(arg=="high")
		s = view_high_craft(me);
	else{
		sscanf(arg,"%s",action);
		s = "百工坊没有这个操作："+action+"。\n"+view_main(me);
	}
	write(s);
	return 1;
}
