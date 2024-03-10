#include <globals.h>
//需要被存储的，去掉private字段,测试阶段可以好好看看
//比如这个attack_power是然木剑的攻击力,这样游戏世界
//中所有然木剑生成的object都具有这个属性，没必要存储起来
//除非属于该物品装备状态的特殊属性是会变化，而且需要存储，比如磨损程度等
private int attack_power=0;//武器伤害基础值
int query_attack_power(){ return attack_power;}
void set_attack_power(int a){ attack_power=a;}

private int attack_power_limit=0;//武器伤害上限值
int query_attack_power_limit(){ return attack_power_limit;}
void set_attack_power_limit(int a){ attack_power_limit=a;}

private int speed_power=0;//武器攻击速度,可能会变化，需要存储
int query_speed_power(){ return speed_power;}
void set_speed_power(int a){ speed_power=a;}

private int equip_defend=0;//防具的防御力
int query_equip_defend(){ return equip_defend+(query_defend_add()==0?0:query_defend_add());}
void set_equip_defend(int a){ equip_defend=a;}

private int str_add=0;//物品附带力量增加属性
int query_str_add(){ return str_add;}
void set_str_add(int a){ str_add=a;}

private int dex_add=0;//物品附带敏捷增加属性
int query_dex_add(){ return dex_add;}
void set_dex_add(int a){ dex_add=a;}

private int think_add=0;//物品附带智力增加属性
int query_think_add(){ return think_add;}
void set_think_add(int a){ think_add=a;}

private int life_add=0;//生命附加
int query_life_add(){ return life_add*10;}
void set_life_add(int a){ life_add=a;}

private int mofa_add=0;//法力附加
int query_mofa_add(){ return mofa_add*10;}
void set_mofa_add(int a){ mofa_add=a;}

private int lunck_add=0;//幸运附加
int query_lunck_add(){ return lunck_add;}
void set_lunck_add(int a){ lunck_add=a;}

private int appear_add=0;//容貌附加
int query_appear_add(){ return appear_add;}
void set_appear_add(int a){ appear_add=a;}

//附加攻击，防御，闪避，命中，暴击属性
private int attack_add=0;//附加攻击
int query_attack_add(){ return attack_add;}
void set_attack_add(int a){ attack_add=a;}

private int defend_add=0;//附加防御
int query_defend_add(){ return defend_add*10;}
void set_defend_add(int a){ defend_add=a;}

private int dodge_add=0;//附加闪避
int query_dodge_add(){ return dodge_add;}
void set_dodge_add(int a){ dodge_add=a;}

private int hitte_add=0;//附加命中
int query_hitte_add(){ return hitte_add;}
void set_hitte_add(int a){ hitte_add=a;}

private int doub_add=0;//附加暴击
int query_doub_add(){ return doub_add;}
void set_doub_add(int a){ doub_add=a;}

//新属性0121//////////////////////////////////
private int all_add=0;//物品附加全属性
int query_all_add(){ return all_add;}
void set_all_add(int a){ all_add=a;}

private int recive_add=0;//物品附加吸收伤害
int query_recive_add(){ return recive_add;}
void set_recive_add(int a){ recive_add=a;}

private int back_add=0;//物品附加反弹伤害
int query_back_add(){ return back_add;}
void set_back_add(int a){ back_add=a;}

private int weapon_attack_add=0;//物品附加武器攻击力增加百分比
int query_weapon_attack_add(){ return weapon_attack_add;}
void set_weapon_attack_add(int a){ weapon_attack_add=a;}

private int dura_add=0;//物品附加耐久度
int query_dura_add(){ return dura_add*10;}
void set_dura_add(int a){ dura_add=a;}

private int rase_life_add=0;//物品附加生命恢复增加
int query_rase_life_add(){ return rase_life_add;}
void set_rase_life_add(int a){ rase_life_add=a;}

private int rase_mofa_add=0;//物品附加法力恢复增加
int query_rase_mofa_add(){ return rase_mofa_add;}
void set_rase_mofa_add(int a){ rase_mofa_add=a;}

private int huo_mofa_attack_add=0;//物品附加火系法术伤害
int query_huo_mofa_attack_add(){ return huo_mofa_attack_add;}
void set_huo_mofa_attack_add(int a){ huo_mofa_attack_add=a;}

private int bing_mofa_attack_add=0;//物品附加冰系法术伤害
int query_bing_mofa_attack_add(){ return bing_mofa_attack_add;}
void set_bing_mofa_attack_add(int a){ bing_mofa_attack_add=a;}

private int feng_mofa_attack_add=0;//物品附加风系法术伤害
int query_feng_mofa_attack_add(){ return feng_mofa_attack_add;}
void set_feng_mofa_attack_add(int a){ feng_mofa_attack_add=a;}

private int du_mofa_attack_add=0;//物品附加毒系法术伤害
int query_du_mofa_attack_add(){ return du_mofa_attack_add;}
void set_du_mofa_attack_add(int a){ du_mofa_attack_add=a;}

private int spec_mofa_attack_add=0;//物品附加特殊法术伤害
int query_spec_mofa_attack_add(){ return spec_mofa_attack_add;}
void set_spec_mofa_attack_add(int a){ spec_mofa_attack_add=a;}

private int mofa_all_add=0;//物品附加全系法术伤害
int query_mofa_all_add(){ return mofa_all_add;}
void set_mofa_all_add(int a){ mofa_all_add=a;}

private int attack_huoyan_add=0;//物品附加火焰攻击力
int query_attack_huoyan_add(){ return attack_huoyan_add;}
void set_attack_huoyan_add(int a){ attack_huoyan_add=a;}

private int attack_bingshuang_add=0;//物品附加冰霜攻击力
int query_attack_bingshuang_add(){ return attack_bingshuang_add;}
void set_attack_bingshuang_add(int a){ attack_bingshuang_add=a;}

private int attack_fengren_add=0;//物品附加风刃攻击力
int query_attack_fengren_add(){ return attack_fengren_add;}
void set_attack_fengren_add(int a){ attack_fengren_add=a;}

private int attack_dusu_add=0;//物品附加毒素攻击力
int query_attack_dusu_add(){ return attack_dusu_add;}
void set_attack_dusu_add(int a){ attack_dusu_add=a;}

private int attack_spec_add=0;//物品附加特殊攻击力
int query_attack_spec_add(){ return attack_spec_add;}
void set_attack_spec_add(int a){ attack_spec_add=a;}

private int attack_all_add=0;//物品附加全系物理伤害
int query_attack_all_add(){ return attack_all_add;}
void set_attack_all_add(int a){ attack_all_add=a;}

private int huoyan_defend_add=0;//物品附加火焰抗性
int query_huoyan_defend_add(){ return huoyan_defend_add;}
void set_huoyan_defend_add(int a){ huoyan_defend_add=a;}

private int bingshuang_defend_add=0;//物品附加冰霜抗性
int query_bingshuang_defend_add(){ return bingshuang_defend_add;}
void set_bingshuang_defend_add(int a){ bingshuang_defend_add=a;}

private int fengren_defend_add=0;//物品附加风刃抗性
int query_fengren_defend_add(){ return fengren_defend_add;}
void set_fengren_defend_add(int a){ fengren_defend_add=a;}

private int dusu_defend_add=0;//物品附加毒素抗性
int query_dusu_defend_add(){ return dusu_defend_add;}
void set_dusu_defend_add(int a){ dusu_defend_add=a;}

private int all_mofa_defend_add=0;//物品附加全法术抗性
int query_all_mofa_defend_add(){ return all_mofa_defend_add;}
void set_all_mofa_defend_add(int a){ all_mofa_defend_add=a;}

//新属性0121//////////////////////////////////
int equiped;//是否装备了该物品

private int renxing = 0;//韧性
void set_renxing(int num){ renxing = num;}
int query_renxing(){ return renxing;}

private array(string) item_profeLimit=({});//物品装备的职业限制，特定职业方可装备该物品
void set_item_profeLimit(string s){
	//array(string) arr = s/":";	
	//if(arr&&sizeof(arr)){
	//	item_profeLimit = copy_value(arr);
	//}
	item_profeLimit += ({s});
}
array(string) query_item_profeLimit(){return item_profeLimit;}

private int item_canLevel;//物品装备需要等级，可以装备的等级限制
int query_item_canLevel(){ return item_canLevel;}
void set_item_canLevel(int a){ item_canLevel=a;}

private string item_kind;//物品种类：单手武器（主副手）single_main_weapon,single_other_weapon, 双手武器（武器 double_main_weapon），鞋子shoes（防具）戒指ring项链neck（首饰）披风（饰物）等。
string query_item_kind(){ return item_kind;}
void set_item_kind(string a){ item_kind=a;}

private string item_skill;//物品技能要求：武器weapon防具armor所需要的技能，比如双手武器必须有该技能方可装备
string query_item_skill(){ return item_skill;}
void set_item_skill(string a){ item_skill=a;}
//这里去掉private看是否存储

int item_dura;//物品耐久度：物品磨损程度，所有物品基本都有此种属性，除了戒指项链和任务物品等不会磨损
int item_cur_dura;//物品当前耐久度
int query_item_dura(){
	int tmp = 0;
	if(query_dura_add()){
		tmp = item_dura+query_dura_add();
		return tmp;
	}
	return item_dura;
}

//增加物品刷属性的次数
//由liaocheng于07/12/27添加，用于玉石刷装备属性
private int convert_limit = 10;//物品刷的次数限制
int convert_count;//记录物品已刷的次数
void set_convert_count(int a){
	if(a>convert_limit)
		a = convert_limit;
	convert_count = a;
}
int query_convert_count(){return convert_count;}
int query_convert_limit(){return convert_limit;}

int is_equip(){return 1;}

int query_weapon_attack(){
	return attack_power+random(attack_power_limit-attack_power+1);
}
//装备的磨损计算
void reduce_power(int power){
	object ob=this_object();
	if(ob->item_canDura){
		if(ob->item_dura>=10000)
			return;
		ob->item_cur_dura-=power;
		if(ob->item_cur_dura<0)
			ob->item_cur_dura=0;
	}
}
string query_content(){
	string r="";
	object ob=this_object();
	if(!ob->is_equip())
		return r;
	if(ob->query_item_type()=="armor"){
		switch(ob->item_kind){
			case "armor_head":
				r += "(头部)\n";
			break;
			case "armor_cloth":
				r += "(胸部)\n";
			break;
			case "armor_waste":
				r += "(腕部)\n";
			break;
			case "armor_hand":
				r += "(手部)\n";
			break;
			case "armor_thou":
				r += "(腿部)\n";
			break;
			case "armor_shoes":
				r += "(脚部)\n";
		}
	}
	else if(ob->query_item_type()=="jewelry"){
		switch(ob->item_kind){
			case "jewelry_ring":
				r += "(戒指)\n";
			break;
			case "jewelry_neck":
				r += "(项链)\n";
			break;
			case "jewelry_bangle":
				r += "(手镯)\n";
			break;
		}
	}
	else if(ob->query_item_type()=="decorate"){
		switch(ob->item_kind){
			case "decorate_manteau":
				r += "(披风)\n";
			break;
			case "decorate_thing":
				r += "(挂件)\n";
			break;
			case "decorate_tool":
				r += "(饰品)\n";
			break;
		}
	}
	if(ob->attack_power&&ob->attack_power_limit) r+="伤害："+ob->attack_power+"-"+ob->attack_power_limit+"\n";
	if(ob->item_kind=="double_main_weapon"||ob->item_kind=="single_main_weapon"||ob->item_kind=="single_other_weapon")
		r+="速度："+ob->speed_power+"\n";
	if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor")
		r+="耐久度："+ob->item_cur_dura+"/"+ob->item_dura+"\n";

	if(ob->str_add) r+="+"+ob->str_add+"力量\n";
	if(ob->dex_add) r+="+"+ob->dex_add+" 敏捷\n";
	if(ob->think_add) r+="+"+ob->think_add+" 智力\n";
	if(ob->renxing) r+="+"+ob->renxing+" 韧性\n";
	if(ob->life_add) r+="+"+ob->life_add+" 生命力\n";
	if(ob->mofa_add) r+="+"+ob->mofa_add+" 法力值\n";
	if(ob->lunck_add) r+="+"+ob->lunck_add+" 幸运\n";
	if(ob->appear_add) r+="+"+ob->appear_add+" 魅力\n";
	if(ob->hitte_add) r+="命中率增加 "+ob->hitte_add+"%\n";
	if(ob->doub_add) r+="暴击率增加 "+ob->doub_add+"%\n";
	if(ob->dodge_add) r+="闪避率增加 "+ob->dodge_add+"%\n";
	if(ob->equip_defend) r+="+"+ob->equip_defend+" 防御\n";
	if(ob->attack_add) r+="+"+ob->attack_add+" 武器伤害\n";
	if(ob->defend_add) r+="+"+ob->defend_add+" 防御力\n";
	//附加属性加成的描述：
	if(ob->all_add) r+="+"+ob->all_add+" 所有属性\n";
	if(ob->recive_add) r+="吸收伤害 "+ob->recive_add+"%\n";
	if(ob->back_add) r+="反弹伤害 "+ob->back_add+"%\n";
	if(ob->weapon_attack_add) r+="武器伤害加成 "+ob->weapon_attack_add*10+"%\n";
	if(ob->dura_add) r+="+"+ob->dura_add+" 物品耐久\n";
	if(ob->rase_life_add) r+="每秒恢复 "+ob->rase_life_add+" 点生命\n";
	if(ob->rase_mofa_add) r+="每秒恢复"+ob->rase_mofa_add+" 点法力\n";
	if(ob->huo_mofa_attack_add) r+="火系法术伤害增加 "+ob->huo_mofa_attack_add+"点\n";
	if(ob->bing_mofa_attack_add) r+="冰系法术伤害增加 "+ob->bing_mofa_attack_add+"点\n";
	if(ob->feng_mofa_attack_add) r+="风系法术伤害增加 "+ob->feng_mofa_attack_add+"点\n";
	if(ob->du_mofa_attack_add) r+="毒系法术伤害增加 "+ob->du_mofa_attack_add+"点\n";
	if(ob->spec_mofa_attack_add) r+="特殊法术伤害增加 "+ob->spec_mofa_attack_add+"点\n";
	if(ob->mofa_all_add) r+="所有法术伤害增加 "+ob->mofa_all_add+"点\n";
	if(ob->attack_huoyan_add) r+="+"+ob->attack_huoyan_add+" 火焰伤害\n";
	if(ob->attack_bingshuang_add) r+="+"+ob->attack_bingshuang_add+" 冰霜伤害\n";
	if(ob->attack_fengren_add) r+="+"+ob->attack_fengren_add+" 风刃伤害\n";
	if(ob->attack_dusu_add) r+="+"+ob->attack_dusu_add+" 毒素伤害\n";
	if(ob->attack_all_add) r+="+"+ob->attack_all_add+" 全系伤害\n";
	if(ob->attack_spec_add) r+="+"+ob->attack_spec_add+" 特殊伤害\n";
	if(ob->huoyan_defend_add) r+="火焰抗性增加 "+ob->huoyan_defend_add+"点\n";
	if(ob->bingshuang_defend_add) r+="冰霜抗性增加 "+ob->bingshuang_defend_add+"点\n";
	if(ob->fengren_defend_add) r+="风刃抗性增加 "+ob->fengren_defend_add+"点\n";
	if(ob->dusu_defend_add) r+="毒素抗性增加 "+ob->dusu_defend_add+"点\n";
	if(ob->all_mofa_defend_add) r+="全法术抗性增加 "+ob->all_mofa_defend_add+"点\n";

	//宝石
	if(ob->query_baoshi("blue")){
		foreach(ob->query_baoshi("blue"),object each_ob){
			r += each_ob->query_name_cn()+"("+(each_ob->query_desc()-"\n")+")\n";
		}
	}
	if(ob->query_baoshi("red")){
		foreach(ob->query_baoshi("red"),object each_ob){
			r += each_ob->query_name_cn()+"("+(each_ob->query_desc()-"\n")+")\n";
		}
	}
	if(ob->query_baoshi("yellow")){
		foreach(ob->query_baoshi("yellow"),object each_ob){
			r += each_ob->query_name_cn()+"("+(each_ob->query_desc()-"\n")+")\n";
		}
	}
	//凹槽
	if(ob->query_aocao("blue")) r+="蓝色凹槽x"+ob->query_aocao("blue")+"\n";
	if(ob->query_aocao("red")) r+="红色凹槽x"+ob->query_aocao("red")+"\n";
	if(ob->query_aocao("yellow")) r+="黄色凹槽x"+ob->query_aocao("yellow")+"\n";

	if(ob->query_item_rareLevel()>0)
		r+="转化次数："+ob->query_convert_count()+"/"+ob->query_convert_limit()+"\n";
	if(ob->item_canLevel>0) r+="要求级别："+ob->item_canLevel+"\n";
	//职业要求
	if(ob->item_profeLimit&&sizeof(ob->item_profeLimit)){
		r+="要求职业：";
		for(int i=0; i<sizeof(ob->item_profeLimit); i++){
			if(ob->item_profeLimit[i]&&sizeof(ob->item_profeLimit[i]))
				r+=this_player()->query_profe_cn(ob->item_profeLimit[i])+" ";
		}
		r+="\n";
	}
	r+="--------\n";
	return r;
}
