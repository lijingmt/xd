#include <command.h>
#include <gamelib/include/gamelib.h>

private string material_name(string material)
{
	if(material=="spirit_mark") return "灵印";
	if(material=="spirit_dew") return "灵露";
	if(material=="egg_fragment") return "灵卵残片";
	if(material=="skill_rune") return "灵纹符";
	if(material=="cosmetic_dust") return "月华尘";
	if(material=="bond_token") return "同心叶";
	return material;
}

private string pet_short_id(string pet_id)
{
	if(sizeof(pet_id)<=8)
		return pet_id;
	return pet_id[0..7];
}

private string render_starter(object me)
{
	string s = "【万灵初契】\n\n";
	s += "15级可从三位伙伴中任选一位；另外两位以后都可用灵印稳定兑换，选择不会造成不可逆的强弱差距。\n\n";
	foreach(PETD->query_starter_species(),string species){
		mapping info = PETD->query_pet_species(species);
		s += (string)info["icon"]+" §g"+(string)info["name"]+"§r · "+
			(string)info["role"]+"\n"+(string)info["origin"]+"\n"+
			"协战："+(string)info["skill"]+" " +
			"[选择它:pet choose "+species+"]\n\n";
	}
	s += "通用灵宠不占方士虎灵、鹤灵、龟灵的召唤数量，也不会参与三灵共鸣。\n";
	s += "[返回万灵谱:pet]|[返回游戏:look]\n";
	return s;
}

private string render_catalog(mapping state)
{
	string s = "【山海万灵图鉴】\n\n";
	multiset(string) owned = (<>);
	foreach((array)state["pets"],mapping pet)
		owned[(string)pet["species"]] = 1;
	mapping catalog = PETD->query_pet_catalog();
	foreach(sort(indices(catalog)),string species){
		mapping info = catalog[species];
		s += owned[species] ? "✓ " : "○ ";
		s += (string)info["icon"]+(string)info["name"]+" · "+
			(string)info["role"];
		if((int)info["boss"])
			s += " · 裂隙契约";
		else if((int)info["exchange"])
			s += " · 30灵印保底";
		s += " [小传:pet detail "+species+"]\n";
	}
	s += "\n收录 "+(int)state["collection_count"]+"/"+
		(int)state["catalog_total"]+"\n";
	s += "[返回万灵谱:pet]|[返回游戏:look]\n";
	return s;
}

private string render_detail(mapping state,string species)
{
	mapping info = PETD->query_pet_species(species);
	string s;
	if(!sizeof(info))
		return "万灵谱中没有这种异兽。\n[返回图鉴:pet catalog]\n";
	s = "【"+(string)info["icon"]+(string)info["name"]+"】\n\n";
	s += "灵属："+(string)info["family"]+" | 定位："+
		(string)info["role"]+"\n";
	s += (string)info["origin"]+"\n\n";
	s += "战斗灵技："+(string)info["skill"]+
		"。PVE按冷却协战；人物PVP按战斗回合充能，每场最多触发2次，成长收益经过压缩且不能补刀。\n";
	s += "三套灵纹：\n";
	foreach((array)info["skill_sets"],array skills)
		s += "• "+(skills*"、")+"\n";
	int owned = -1;
	for(int i=0;i<sizeof((array)state["pets"]);i++)
		if(state["pets"][i]["species"]==species){
			owned = i;
			break;
		}
	if(owned>=0){
		mapping pet = state["pets"][owned];
		mapping attributes = pet["attributes"];
		s += "\n已收录：Lv."+(int)pet["level"]+"/60 · "+
			(int)pet["star"]+"星 · "+(string)pet["evolution_name"]+
			" · 羁绊"+(int)pet["bond"]+"/5\n";
		s += "灵宠战力："+(int)pet["power"]+" | 生命"+
			(int)attributes["life"]+" | 攻击"+(int)attributes["attack"]+
			" | 防御"+(int)attributes["defense"]+" | 灵息"+
			(int)attributes["spirit"]+" | 迅捷"+(int)attributes["speed"]+"\n";
		s += "PVE成长倍率："+(int)pet["growth_percent"]+
			"% | PVP压缩倍率："+(int)pet["pvp_growth_percent"]+
			"% | 编号"+pet_short_id((string)pet["id"])+"\n";
		s += "当前灵纹："+((array)pet["skills"]*"、")+"\n";
		s += "灵纹节奏："+((int)pet["skill_set"]==1 ?
			"轻灵（80%效果/24秒）" : ((int)pet["skill_set"]==2 ?
			"厚积（115%效果/36秒）" : "均衡（100%效果/30秒）"))+"\n";
		s += "已收录外观："+((array)pet["variants"]*"、")+"\n";
		s += "[设为协战:pet active "+(string)pet["id"]+"] "+
			"[提升等级:pet level "+(string)pet["id"]+"]\n"+
			"[消耗残片升星:pet star "+(string)pet["id"]+"] "+
			"[深化羁绊:pet bond "+(string)pet["id"]+"]\n"+
			"[轮换灵纹:pet reset "+(string)pet["id"]+"]\n"+
			"[40月华尘解锁星辉异色:pet variant "+
			(string)pet["id"]+"]\n";
	}
	else if((int)info["exchange"])
		s += "\n[用30灵印稳定兑换:pet exchange "+species+"]\n";
	else
		s += "\n本灵契可由裂隙低概率完整灵卵取得，也可用60枚灵卵残片稳定孵化；异色只改变外观。\n"+
			"[60残片稳定孵化:pet hatch "+species+"]\n";
	s += "\n[返回图鉴:pet catalog]|[返回万灵谱:pet]\n";
	return s;
}

private string render_materials(mapping state)
{
	string s = "【万灵材料栏】\n\n";
	s += "这些材料不进入背包，不占格子，也不能被丢弃或卖错。\n\n";
	foreach(indices(state["materials"]),string material)
		s += "• "+material_name(material)+"："+
			(int)state["materials"][material]+"\n";
	s += "\n灵印可稳定换基础灵宠；灵卵残片既可用于1—10星成长，也可用60枚任选裂隙异兽稳定孵化；3/6/9星自动进化。灵纹符按顺序轮换协战节奏；40月华尘可保底解锁星辉异色。\n";
	s += "[可兑换灵宠:pet catalog]|[返回万灵谱:pet]\n";
	return s;
}

private string render_team(mapping state,object me)
{
	array team = state["duel_teams"][me->query_name()] || ({});
	string s = "【三宠论道编队】\n\n";
	s += "人物等级、装备、VIP和宠物培养数值全部标准化；不足三只时自动借用新手试炼灵宠。\n\n";
	for(int i=0;i<sizeof((array)state["pets"]);i++){
		mapping pet = state["pets"][i];
		mapping info = PETD->query_pet_species((string)pet["species"]);
		int selected = search(team,(string)pet["id"])!=-1;
		s += selected ? "✓ " : "○ ";
		s += (string)info["icon"]+(string)info["name"]+" "+
			(selected ? "[移出:pet teamtoggle " : "[加入:pet teamtoggle ")+
			(string)pet["id"]+"]\n";
	}
	s += "\n当前已选 "+sizeof(team)+"/3。\n";
	s += "[寻找论道对手:pet_duel list]|[返回万灵谱:pet]\n";
	return s;
}

private string render_main(mapping state,object me)
{
	string character_id = me->query_name();
	string active_id = (string)(state["active"][character_id] || "");
	string active_name = "未设置";
	for(int i=0;i<sizeof((array)state["pets"]);i++)
		if(state["pets"][i]["id"]==active_id){
			mapping info = PETD->query_pet_species(
				(string)state["pets"][i]["species"]);
			active_name = (string)info["icon"]+(string)info["name"]+
				"（Lv."+(int)state["pets"][i]["level"]+" · "+
				(int)state["pets"][i]["star"]+"星"+
				(string)state["pets"][i]["evolution_name"]+"）";
			break;
		}
	string boss_species = (string)state["weekly_boss"];
	mapping boss = PETD->query_pet_species(boss_species);
	string s = "§g【山海万灵谱】§r\n\n";
	s += "账号共享收藏："+(int)state["collection_count"]+"/"+
		(int)state["catalog_total"]+" | 当前协战："+active_name+"\n";
	s += "本周裂隙："+(string)boss["icon"]+(string)boss["name"]+
		" | 周胜场 "+(int)state["weekly"]["rift_wins"]+"/3"+
		" | 完整灵卵保底 "+(int)state["rift_pity"]+"/30\n";
	s += "灵印："+(int)state["materials"]["spirit_mark"]+
		" | 灵露："+(int)state["materials"]["spirit_dew"]+
		" | 灵卵残片："+(int)state["materials"]["egg_fragment"]+"\n\n";
	if(sizeof((mapping)state["pending_rift_rewards"]))
		s += "★ 有"+sizeof((mapping)state["pending_rift_rewards"])+
			"份裂隙个人奖励等待领取（资格保留7天）。\n"+
			"[立即领取:wanling_rift claim]\n\n";
	if(!(int)state["starter_claimed"]){
		if(me->query_level()>=15)
			s += "★ 第一位万灵伙伴已经可以领取。\n[选择新手灵宠:pet starter]\n\n";
		else
			s += "○ 15级开放第一位万灵伙伴，当前"+me->query_level()+"级。\n\n";
	}
	if(sizeof((array)state["pets"])){
		s += "我的伙伴：\n";
		foreach((array)state["pets"],mapping pet){
			mapping info = PETD->query_pet_species((string)pet["species"]);
				s += ((string)pet["id"]==active_id ? "✓ " : "○ ")+
					(string)info["icon"]+(string)info["name"]+" "+
					"Lv."+(int)pet["level"]+"·"+(int)pet["star"]+
					"星"+(string)pet["evolution_name"]+"·战力"+
					(int)pet["power"]+"·羁绊"+(int)pet["bond"]+
					" [详情:pet detail "+(string)pet["species"]+"]\n";
		}
		s += "[暂停当前协战:pet active none]\n\n";
	}
	s += "[今日修行:daily_cultivation]|[万灵裂隙:wanling_rift]|[灵宠论道:pet_duel list]\n";
	s += "[完整图鉴:pet catalog]|[论道编队:pet team]|[独立材料栏:pet materials]\n";
	s += "[前往万灵台:wanling_rift gather]\n";
	s += "\n公平规则：PVE使用完整培养成长；人物PVP只保留20%额外成长、每场最多2次且不能补刀。三宠论道继续完全标准化。会员不出售战斗专属宠物或属性洗练。\n";
	if(me->query_profeId()=="fangshi")
		s += "方士说明：万灵伙伴不占虎灵、鹤灵、龟灵名额，不触发三灵共鸣。\n";
	s += "[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	mapping state;
	array(string) parts;
	string message = "";
	if(!me)
		return 0;
	state = PETD->query_pet_state(me);
	if(!state["ok"]){
		write((string)state["message"]+"\n[返回游戏:look]\n");
		return 1;
	}
	if(!arg || arg==""){
		write(render_main(state,me));
		return 1;
	}
	parts = arg/" ";
	if(parts[0]=="starter"){
		write(render_starter(me));
		return 1;
	}
	if(parts[0]=="catalog"){
		write(render_catalog(state));
		return 1;
	}
	if(parts[0]=="materials"){
		write(render_materials(state));
		return 1;
	}
	if(parts[0]=="team"){
		write(render_team(state,me));
		return 1;
	}
	if(parts[0]=="detail" && sizeof(parts)>=2){
		write(render_detail(state,parts[1]));
		return 1;
	}
	if(parts[0]=="choose" && sizeof(parts)>=2)
		message = (string)PETD->choose_starter_pet(me,parts[1])["message"];
	else if(parts[0]=="active" && sizeof(parts)>=2)
		message = (string)PETD->set_active_pet(me,parts[1])["message"];
	else if(parts[0]=="level" && sizeof(parts)>=2)
		message = (string)PETD->train_pet_level(me,parts[1])["message"];
	else if(parts[0]=="star" && sizeof(parts)>=2)
		message = (string)PETD->upgrade_pet_star(me,parts[1])["message"];
	else if(parts[0]=="bond" && sizeof(parts)>=2)
		message = (string)PETD->deepen_pet_bond(me,parts[1])["message"];
	else if(parts[0]=="reset" && sizeof(parts)>=2)
		message = (string)PETD->reset_pet_skills(me,parts[1])["message"];
	else if(parts[0]=="exchange" && sizeof(parts)>=2)
		message = (string)PETD->exchange_pet(me,parts[1])["message"];
	else if(parts[0]=="hatch" && sizeof(parts)>=2)
		message = (string)PETD->hatch_pet_fragments(me,parts[1])["message"];
	else if(parts[0]=="variant" && sizeof(parts)>=2)
		message = (string)PETD->unlock_pet_dust_variant(me,parts[1])["message"];
	else if(parts[0]=="teamtoggle" && sizeof(parts)>=2){
		array(string) team = state["duel_teams"][me->query_name()] || ({});
		int index = search(team,parts[1]);
		if(index!=-1)
			team -= ({parts[1]});
		else if(sizeof(team)<3)
			team += ({parts[1]});
		else{
			write("论道编队已经有3只，请先移出一只。\n[返回编队:pet team]\n");
			return 1;
		}
		message = (string)PETD->set_pet_duel_team(me,team)["message"];
		write(message+"\n[返回编队:pet team]\n");
		return 1;
	}
	else{
		write("未知的万灵操作。\n[返回万灵谱:pet]\n");
		return 1;
	}
	write(message+"\n[返回万灵谱:pet]\n[返回游戏:look]\n");
	return 1;
}
