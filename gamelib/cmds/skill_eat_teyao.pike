#include <command.h>
#include <gamelib/include/gamelib.h>

#define SKILL_MEDICINE_BATCH_MAX 100
// 历史实际效果一直是每瓶推进当前等级门槛的20%；本次只优化批量与
// 达标即时升级，不改变已经形成共识的数值。
#define LEGACY_SKILL_MEDICINE_PERCENT 20

private int query_skill_medicine_stock(object player,string medicine_name)
{
	int total=0;
	if(!player || !medicine_name || medicine_name=="")
		return 0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==medicine_name &&
		   functionp(item->query_danyao_type) &&
		   (string)item->query_danyao_type()=="skill_improve")
			total+=item->is("combine_item") ? (int)item->amount : 1;
	return total;
}

private object|zero query_skill_medicine(object player,string medicine_name)
{
	if(!player || !medicine_name || medicine_name=="" ||
	   sizeof(medicine_name)>64 || search(medicine_name,"/")!=-1 ||
	   search(medicine_name,"..")!=-1)
		return 0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==medicine_name &&
		   functionp(item->query_danyao_type) &&
		   (string)item->query_danyao_type()=="skill_improve")
			return item;
	return 0;
}

// 兼容旧版本留下的“熟练度已经100%，但还没靠下一次战斗突破”档案。
// 这种状态本来已经完成门槛，首次使用新版入口时直接晋级且不扣药。
int advance_completed_skill_progress(object player,string skill_name)
{
	object skill;
	int level;
	int progress;
	int skill_limit;
	int advanced=0;
	if(!player || !player->skills || !player->skills[skill_name])
		return 0;
	skill=MUD_SKILLSD[skill_name];
	if(!skill || (int)skill->boss_skill==1)
		return 0;
	level=(int)player->skills[skill_name][0];
	progress=(int)player->skills[skill_name][1];
	skill_limit=(int)player->query_skill_up(skill_name);
	while(level<skill_limit){
		int required=(int)skill->performs_shuliandu[level];
		if(required<=0 || progress<required)
			break;
		level++;
		progress=0;
		advanced++;
	}
	if(advanced)
		player->skills[skill_name]=({level,progress});
	return advanced;
}

int query_bottles_to_next_level(object player,string skill_name)
{
	object skill;
	int level;
	int required;
	int progress;
	int gain;
	if(!player || !player->skills || !player->skills[skill_name])
		return 0;
	skill=MUD_SKILLSD[skill_name];
	if(!skill)
		return 0;
	level=(int)player->skills[skill_name][0];
	if(level>=(int)player->query_skill_up(skill_name))
		return 0;
	required=(int)skill->performs_shuliandu[level];
	progress=(int)player->skills[skill_name][1];
	if(required<=0)
		return 0;
	gain=max(1,required*LEGACY_SKILL_MEDICINE_PERCENT/100);
	return max(1,(required-progress+gain-1)/gain);
}

mapping(string:mixed) consume_skill_medicine(object player,
	string medicine_name,string skill_name,int requested)
{
	mapping(string:mixed) result=(["ok":0,"used":0,"levels":0,
		"message":"无法使用金玉露。"]);
	object medicine=query_skill_medicine(player,medicine_name);
	object skill;
	int level;
	int progress;
	int skill_limit;
	int used=0;
	int levels=0;
	if(!player || !medicine || !skill_name || skill_name=="" ||
	   sizeof(skill_name)>64 || search(skill_name,"/")!=-1 ||
	   search(skill_name,"..")!=-1 || requested<1 ||
	   requested>SKILL_MEDICINE_BATCH_MAX ||
	   !player->skills || !player->skills[skill_name]){
		result["message"]="药品、技能或数量无效。";
		return result;
	}
	skill=MUD_SKILLSD[skill_name];
	if(!skill || (int)skill->boss_skill==1){
		result["message"]="这个技能不能使用金玉露提升。";
		return result;
	}
	levels=advance_completed_skill_progress(player,skill_name);
	level=(int)player->skills[skill_name][0];
	progress=(int)player->skills[skill_name][1];
	skill_limit=(int)player->query_skill_up(skill_name);
	if(level>=skill_limit){
		if(levels){
			result=(["ok":1,"used":0,"levels":levels,"level":level,
				"progress":progress,"skill_name":skill_name,
				"message":"旧熟练度已直接完成升级。"]);
			return result;
		}
		result["message"]=(string)skill->query_name_cn()+
			"等级已达到当前上限，不能再提升。";
		return result;
	}
	// 旧档刚完成的100%先免费晋级；本次不吞掉玩家原本要使用的药。
	if(levels){
		result=(["ok":1,"used":0,"levels":levels,"level":level,
			"progress":progress,"skill_name":skill_name,
			"message":"旧熟练度已直接完成升级。"]);
		return result;
	}
	requested=min(requested,query_skill_medicine_stock(
		player,medicine_name));
	for(int index=0;index<requested && level<skill_limit;index++){
		int required=(int)skill->performs_shuliandu[level];
		int gain;
		if(required<=0)
			break;
		gain=max(1,required*LEGACY_SKILL_MEDICINE_PERCENT/100);
		progress+=gain;
		used++;
		if(progress>=required){
			level++;
			progress=0;
			levels++;
		}
	}
	if(used<=0){
		result["message"]="背包里没有可用金玉露，或技能已经达到上限。";
		return result;
	}
	mapping removal=player->remove_combine_item_transaction(
		medicine_name,used);
	if(!(int)removal["ok"] || (int)removal["removed"]!=used){
		if((int)removal["removed"]>0)
			player->rollback_combine_item_transaction(removal);
		result["message"]="金玉露数量发生变化，本次没有提升技能。";
		return result;
	}
	player->skills[skill_name]=({level,progress});
	result=(["ok":1,"used":used,"levels":levels,"level":level,
		"progress":progress,"skill_name":skill_name,
		"message":"技能熟练度提升成功。"]);
	return result;
}

private string render_quantity_page(object player,string medicine_name,
	string skill_name)
{
	object skill=MUD_SKILLSD[skill_name];
	int advanced;
	int stock;
	int needed;
	string out="【批量使用金玉露】\n";
	if(!skill || !player->skills || !player->skills[skill_name])
		return "技能不存在或尚未学会。\n[返回道具:inventory_daoju]\n";
	advanced=advance_completed_skill_progress(player,skill_name);
	stock=query_skill_medicine_stock(player,medicine_name);
	needed=query_bottles_to_next_level(player,skill_name);
	if(advanced)
		out+="旧档中已达到100%的熟练度已直接完成"+advanced+
			"次升级，本次没有消耗金玉露。\n";
	out+="目标技能："+(string)skill->query_name_cn()+"\n"+
		"当前库存："+stock+"瓶；每瓶沿用原规则提升当前等级20%熟练度。\n";
	if(needed>0)
		out+="升到下一级预计需要"+needed+"瓶。\n";
	if(stock>0){
		out+="\n[使用1瓶:skill_eat_teyao use "+medicine_name+" "+
			skill_name+" 1]";
		if(stock>=5)
			out+=" [使用5瓶:skill_eat_teyao use "+medicine_name+" "+
				skill_name+" 5]";
		if(stock>=10)
			out+=" [使用10瓶:skill_eat_teyao use "+medicine_name+" "+
				skill_name+" 10]";
		out+="\n";
		if(needed>0)
			out+="[直接升到下一级:skill_eat_teyao use "+medicine_name+
				" "+skill_name+" "+min(stock,needed)+"]\n";
		out+="自定数量（1-100）：[skill_eat_teyao use "+medicine_name+
			" "+skill_name+" ...]\n";
	}
	else
		out+="背包里没有金玉露。\n";
	out+="[重选技能:skill_eat_teyao "+medicine_name+
		" 0]|[返回道具:inventory_daoju]|[返回游戏:look]\n";
	return out;
}

int main(string|zero arg)
{
	object player=this_player();
	string medicine_name="";
	string skill_name="";
	int item_index=0;
	int requested=0;
	if(!player)
		return 0;
	if(arg && sscanf(arg,"select %s %d %s",medicine_name,item_index,
	   skill_name)==3){
		write(render_quantity_page(player,medicine_name,skill_name));
		return 1;
	}
	if(arg && sscanf(arg,"use %s %s %d",medicine_name,skill_name,
	   requested)==3){
		mapping result=consume_skill_medicine(player,medicine_name,
			skill_name,requested);
		if(!(int)result["ok"])
			write((string)result["message"]+"\n");
		else{
			object skill=MUD_SKILLSD[skill_name];
			write(((int)result["used"]>0 ? "你连续使用了"+
				(int)result["used"]+"瓶金玉露，" :
				"旧档中已满的熟练度已直接结算，未消耗金玉露，")+
				(string)skill->query_name_cn()+"当前为"+
				(int)result["level"]+"级。"+
				((int)result["levels"]>0 ? "已直接完成"+
				(int)result["levels"]+"次升级，无需再打怪突破。" :
				"熟练度继续提高。")+"\n");
		}
		write("[继续使用:skill_eat_teyao select "+medicine_name+
			" 0 "+skill_name+"]|[返回道具:inventory_daoju]|"+
			"[返回游戏:look]\n");
		return 1;
	}
	// 兼容旧页面：旧链接形如“skill_eat_teyao jinyulu 0 skill”。
	if(arg && sscanf(arg,"%s %d %s",medicine_name,item_index,
	   skill_name)==3){
		mapping legacy=consume_skill_medicine(player,medicine_name,
			skill_name,1);
		write((string)legacy["message"]+"\n"+
			"[继续使用:skill_eat_teyao select "+medicine_name+" "+
			item_index+" "+skill_name+"]|[返回游戏:look]\n");
		return 1;
	}
	if(!arg || sscanf(arg,"%s %d",medicine_name,item_index)!=2 ||
	   !query_skill_medicine(player,medicine_name)){
		write("背包里没有这种技能药品。\n"+
			"[购买:yushi_buy_teyao_list exp]|[返回游戏:look]\n");
		return 1;
	}
	write("请选择要提升熟练度的技能：\n"+
		player->view_skills_mud("skill_eat_teyao select "+medicine_name+
		" "+item_index)+"\n[返回道具:inventory_daoju]|[返回游戏:look]\n");
	return 1;
}
