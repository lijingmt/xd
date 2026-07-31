#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define AUTOFIGHT_DAILY_SECONDS (8*60*60)
#define AUTOFIGHT_VIP_BONUS_SECONDS (2*60*60)
#define AUTOFIGHT_MAX_VIP_LEVEL 4
#define AUTOFIGHT_ROUTE_COOLDOWN 8
#define AUTOFIGHT_CONFIG_VERSION 4

private array(mapping(string:mixed)) smart_training_routes = ({
	([
		"max":2,
		"level":1,
		"name":"初入仙途",
		"human":"congxianzhen/shangshanlu",
		"monst":"jinaodao/chucuntulu",
		"third":"congxianzhen/shangshanlu",
	]),
	([
		"max":5,
		"level":3,
		"name":"村外试炼",
		"human":"congxianzhen/xiaoshouxueyiceng",
		"monst":"jinaodao/qianshakeng",
		"third":"huanyecun/huanyecun",
	]),
	([
		"max":8,
		"level":6,
		"name":"营地试炼",
		"human":"kunlunshan/piaohuaxi",
		"monst":"jinaodao/wanmuyuan",
		"third":"liehuoying/liehuonan",
	]),
	([
		"max":10,
		"level":9,
		"name":"迷雾试炼",
		"human":"kunlunshan/pubudongxuesanceng",
		"monst":"jinaodao/xiangshudongsiceng",
		"third":"mihuandao/nongwusenlin",
	]),
	([
		"max":13,
		"level":11,
		"name":"初阶修行",
		"human":"kunlunshan/xiuxian",
		"monst":"jinaodao/fenghouzhen",
		"third":"kunlunshan/xiuxian",
	]),
	([
		"max":16,
		"level":14,
		"name":"炼体修行",
		"human":"kunlunshan/lianshen",
		"monst":"jinaodao/hongshazhen",
		"third":"kunlunshan/lianshen",
	]),
	([
		"max":19,
		"level":17,
		"name":"洞府修行",
		"human":"shierxianjing/taoyuantongjiuceng",
		"monst":"wugongdong/xieduhe",
		"third":"shierxianjing/taoyuantongjiuceng",
	]),
	([
		"max":22,
		"level":20,
		"name":"灵境修行",
		"human":"shierxianjing/taoyuantongshijiuceng",
		"monst":"wugongdong/rongchongfang",
		"third":"liangjinghu/yanghuxuanqiao",
	]),
	([
		"max":25,
		"level":23,
		"name":"深洞修行",
		"human":"shierxianjing/magudongshisanceng",
		"monst":"wugongdong/wugongshenyuan",
		"third":"shierxianjing/magudongshisanceng",
	]),
	([
		"max":28,
		"level":26,
		"name":"水阁修行",
		"human":"plshuige/qingyuntai",
		"monst":"plshuige/liexiandao",
		"third":"liangjinghu/yinhuxuanqiao",
	]),
	([
		"max":31,
		"level":29,
		"name":"云海修行",
		"human":"plshuige/mianyunti",
		"monst":"plshuige/yunpulu",
		"third":"liangjinghu/huayaotingyuan15",
	]),
	([
		"max":34,
		"level":32,
		"name":"城外历练",
		"human":"xiqiwaicheng/nanchengqiangjiao",
		"monst":"chaogewaicheng/chaogedongnanlou",
		"third":"muye/xicezhanhao",
	]),
	([
		"max":37,
		"level":35,
		"name":"牧野历练",
		"human":"xiqiwaicheng/huanhuashuitai",
		"monst":"chaogewaicheng/eluanshihetan",
		"third":"muye/guzhandao",
	]),
	([
		"max":40,
		"level":38,
		"name":"战场历练",
		"human":"muye/poyaozhen9",
		"monst":"muye/fuluying9",
		"third":"muye/hexiyandong10",
	]),
	([
		"max":43,
		"level":41,
		"name":"外海历练",
		"human":"waihai/lingyicheng",
		"monst":"waihai/lingyicheng",
		"third":"waihai/lingyicheng",
	]),
	([
		"max":46,
		"level":44,
		"name":"外海深修",
		"human":"waihai/qianhaiguanmucong",
		"monst":"waihai/qianhaiguanmucong",
		"third":"waihai/qianhaiguanmucong",
	]),
	([
		"max":49,
		"level":47,
		"name":"三界进阶",
		"human":"yandigu/xiaoshilu",
		"monst":"fuxishan/fuxidongrukou",
		"third":"huangyuan/yingxielu",
	]),
	([
		"max":52,
		"level":50,
		"name":"流光平原历练",
		"human":"liuguangpingyuan/liuguangchalu",
		"monst":"liuguangpingyuan/liuguangchalu",
		"third":"liuguangpingyuan/liuguangchalu",
	]),
	([
		"max":54,
		"level":53,
		"name":"蓬莱云石历练",
		"human":"plxianjing/dangyunshijie",
		"monst":"plxianjing/dangyunshijie",
		"third":"plxianjing/dangyunshijie",
	]),
	([
		"max":58,
		"level":55,
		"name":"冰幻云台历练",
		"human":"plxianjing/binghuanyuntai",
		"monst":"plxianjing/binghuanyuntai",
		"third":"plxianjing/binghuanyuntai",
	]),
	([
		"max":61,
		"level":60,
		"name":"云野平原历练",
		"human":"penglaihuanjing/yunyepingyuan",
		"monst":"penglaihuanjing/yunyepingyuan",
		"third":"penglaihuanjing/yunyepingyuan",
	]),
	([
		"max":63,
		"level":62,
		"name":"秋霜石路历练",
		"human":"penglaihuanjing/qiushuangshilu",
		"monst":"penglaihuanjing/qiushuangshilu",
		"third":"penglaihuanjing/qiushuangshilu",
	]),
	([
		"max":65,
		"level":64,
		"name":"烈火池塘历练",
		"human":"penglaihuanjing/liehuochitang",
		"monst":"penglaihuanjing/liehuochitang",
		"third":"penglaihuanjing/liehuochitang",
	]),
	([
		"max":67,
		"level":66,
		"name":"昆仑幻境历练",
		"human":"klshuanjingwaicheng/heiheyuan",
		"monst":"klshuanjingwaicheng/heiheyuan",
		"third":"klshuanjingwaicheng/heiheyuan",
	]),
	([
		"max":69,
		"level":68,
		"name":"幻境深处历练",
		"human":"klshuanjingwaicheng/heishandong",
		"monst":"klshuanjingwaicheng/heishandong",
		"third":"klshuanjingwaicheng/heishandong",
	]),
});

protected void create()
{
}

void initialize_player(object me)
{
	int config_version;
	int daily_limit;
	if(!me)
		return;
	if(!(int)me["/plus/autofight_initialized"]){
		daily_limit = query_daily_seconds_for(me);
		me["/plus/autofight_initialized"] = 1;
		me["/plus/autofight_daily_limit"] = daily_limit;
		me["/plus/autofight_time_left"] = daily_limit;
		if(me->query_level()<=NEWBIED->query_newbie_supply_max_level()){
			me["/plus/autofight_hp_percent"] = 70;
			me["/plus/autofight_mana_percent"] = 50;
		}
		else{
			me["/plus/autofight_hp_percent"] = 50;
			me["/plus/autofight_mana_percent"] = 30;
		}
		me["/plus/autofight_loot"] = 1;
		me["/plus/autofight_roam"] = 0;
		me["/plus/autofight_smart_route"] = 1;
		me["/plus/autofight_auto_rest"] = 1;
		me["/plus/autofight_food"] = "auto";
		me["/plus/autofight_water"] = "auto";
		me["/plus/autofight_auto_sell_mode"] = "off";
		me["/plus/autofight_sell_weapon"] = 1;
		me["/plus/autofight_sell_armor"] = 1;
		me["/plus/autofight_sell_accessory"] = 1;
		me["/plus/autofight_sell_level_gap"] = 5;
		me["/plus/autofight_gather_mode"] = "off";
		me["/plus/autofight_material_keep"] = -1;
	}
	else
		sync_daily_limit(me);
	config_version =
		(int)me["/plus/autofight_config_version"];
	if(config_version < 2){
		me["/plus/autofight_smart_route"] = 1;
		me["/plus/autofight_auto_rest"] = 1;
	}
	if(config_version < 3){
		me["/plus/autofight_auto_sell_mode"] = "off";
		me["/plus/autofight_sell_weapon"] = 1;
		me["/plus/autofight_sell_armor"] = 1;
		me["/plus/autofight_sell_accessory"] = 1;
		me["/plus/autofight_sell_level_gap"] = 5;
	}
	if(config_version < 4){
		me["/plus/autofight_gather_mode"] = "off";
		me["/plus/autofight_material_keep"] = -1;
	}
	if(config_version < AUTOFIGHT_CONFIG_VERSION)
		me["/plus/autofight_config_version"] =
			AUTOFIGHT_CONFIG_VERSION;
}

int query_daily_seconds()
{
	return AUTOFIGHT_DAILY_SECONDS;
}

int query_vip_level(object me)
{
	int vip_level;
	if(!me)
		return 0;
	vip_level = 0;
	if(functionp(me->query_vip_flag))
		vip_level = (int)me->query_vip_flag();
	if(vip_level < 0)
		vip_level = 0;
	if(vip_level > AUTOFIGHT_MAX_VIP_LEVEL)
		vip_level = AUTOFIGHT_MAX_VIP_LEVEL;
	return vip_level;
}

int query_daily_seconds_for(object me)
{
	return AUTOFIGHT_DAILY_SECONDS+
		query_vip_level(me)*AUTOFIGHT_VIP_BONUS_SECONDS;
}

void sync_daily_limit(object me)
{
	int daily_limit;
	int previous_limit;
	int time_left;
	if(!me)
		return;
	daily_limit = query_daily_seconds_for(me);
	previous_limit = (int)me["/plus/autofight_daily_limit"];
	if(previous_limit <= 0)
		previous_limit = AUTOFIGHT_DAILY_SECONDS;
	time_left = (int)me["/plus/autofight_time_left"];
	if(previous_limit != daily_limit)
		time_left += daily_limit-previous_limit;
	if(time_left < 0)
		time_left = 0;
	if(time_left > daily_limit)
		time_left = daily_limit;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = time_left;
}

void reset_daily_time(object me)
{
	int daily_limit;
	if(!me)
		return;
	daily_limit = query_daily_seconds_for(me);
	me["/plus/autofight_initialized"] = 1;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = daily_limit;
	me["/tmp/autofight_last_charge"] = 0;
}

int query_time_left(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_time_left"];
}

int query_hp_percent(object me)
{
	int percent;
	if(!me)
		return 50;
	initialize_player(me);
	percent = (int)me["/plus/autofight_hp_percent"];
	if(percent != 30 && percent != 50 && percent != 70)
		percent = 50;
	return percent;
}

int query_mana_percent(object me)
{
	int percent;
	if(!me)
		return 30;
	initialize_player(me);
	percent = (int)me["/plus/autofight_mana_percent"];
	if(percent != 0 && percent != 30 && percent != 50)
		percent = 30;
	return percent;
}

int query_loot_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_loot"] == 1;
}

int query_roam_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_roam"] == 1;
}

int query_smart_route_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_smart_route"] == 1;
}

int query_auto_rest_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_auto_rest"] == 1;
}

string query_gather_mode(object me)
{
	string mode;
	array(string) valid_modes = ({"off","mine","herb","both"});
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_gather_mode"];
	if(search(valid_modes,mode) == -1)
		return "off";
	return mode;
}

string query_gather_mode_cn(string mode)
{
	if(mode == "mine")
		return "自动采矿";
	if(mode == "herb")
		return "自动采药";
	if(mode == "both")
		return "采药和采矿";
	return "关闭";
}

int query_material_keep(object me)
{
	int keep;
	if(!me)
		return -1;
	initialize_player(me);
	keep = (int)me["/plus/autofight_material_keep"];
	if(keep != -1 && keep != 0 && keep != 100 &&
	   keep != 300 && keep != 500)
		return -1;
	return keep;
}

object|zero query_gather_source(object me)
{
	object env;
	string mode;
	array(object) all;
	if(!me || me->in_combat)
		return 0;
	mode = query_gather_mode(me);
	if(mode == "off")
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = all_inventory(env);
	foreach(all,object source){
		string source_type;
		string skill_name;
		mixed skill;
		int need_level;
		if(!source || !functionp(source->query_source_type))
			continue;
		source_type = source->query_source_type();
		if(source_type == "kuang"){
			if(mode != "mine" && mode != "both")
				continue;
			skill_name = "caikuang";
			need_level = KUANGD->query_need_level(source->query_name());
		}
		else if(source_type == "caoyao"){
			if(mode != "herb" && mode != "both")
				continue;
			skill_name = "caiyao";
			need_level = CAOYAOD->query_need_level(source->query_name());
		}
		else
			continue;
		skill = me->vice_skills[skill_name];
		if(!arrayp(skill) || !sizeof(skill))
			continue;
		if(need_level >= 0 && (int)skill[0] >= need_level)
			return source;
	}
	return 0;
}

string query_auto_sell_mode(object me)
{
	string mode;
	array(string) valid_modes = ({
		"off","normal","excellent","refined",
	});
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_auto_sell_mode"];
	if(search(valid_modes,mode) == -1)
		return "off";
	return mode;
}

string query_auto_sell_mode_cn(string mode)
{
	if(mode == "normal")
		return "仅普通白装";
	if(mode == "excellent")
		return "普通及优良装备";
	if(mode == "refined")
		return "普通、优良及精制装备";
	return "关闭";
}

int query_auto_sell_mode_requirement(string mode)
{
	if(mode == "normal")
		return 1;
	if(mode == "excellent")
		return 2;
	if(mode == "refined")
		return 3;
	return 0;
}

int query_auto_sell_quality_limit(string mode)
{
	if(mode == "excellent")
		return 2;
	if(mode == "refined")
		return 4;
	return 0;
}

int query_auto_sell_enabled(object me)
{
	string mode;
	int requirement;
	int vip_level;
	if(!me)
		return 0;
	mode = query_auto_sell_mode(me);
	requirement = query_auto_sell_mode_requirement(mode);
	vip_level = query_vip_level(me);
	return requirement > 0 && vip_level >= requirement &&
		vip_level >= query_auto_sell_gap_requirement(
			query_auto_sell_level_gap(me));
}

int query_auto_sell_trigger_percent(object me)
{
	int vip_level = query_vip_level(me);
	if(vip_level >= 4)
		return 70;
	if(vip_level == 3)
		return 80;
	if(vip_level == 2)
		return 90;
	return 100;
}

int query_auto_sell_batch_size(object me)
{
	int vip_level = query_vip_level(me);
	if(vip_level >= 4)
		return 8;
	if(vip_level == 3)
		return 4;
	if(vip_level == 2)
		return 2;
	return 1;
}

int query_auto_sell_level_gap(object me)
{
	int gap;
	if(!me)
		return 5;
	initialize_player(me);
	gap = (int)me["/plus/autofight_sell_level_gap"];
	if(gap != 0 && gap != 3 && gap != 5)
		return 5;
	return gap;
}

int query_auto_sell_gap_requirement(int gap)
{
	if(gap == 0)
		return 3;
	if(gap == 3)
		return 2;
	return 1;
}

int query_backpack_percent(object me)
{
	int maximum;
	int count;
	if(!me)
		return 0;
	maximum = me->query_beibao_size();
	if(maximum <= 0)
		return 0;
	count = sizeof(all_inventory(me));
	return count*100/maximum;
}

private int is_auto_sell_equipment_type(object item)
{
	string item_type;
	if(!item)
		return 0;
	item_type = item->query_item_type();
	return item_type == "weapon" ||
		item_type == "single_weapon" ||
		item_type == "double_weapon" ||
		item_type == "armor" ||
		item_type == "jewelry" ||
		item_type == "decorate";
}

private int is_auto_sell_category_enabled(object me,object item)
{
	string item_type;
	if(!me || !item)
		return 0;
	item_type = item->query_item_type();
	if(item_type == "weapon" ||
	   item_type == "single_weapon" ||
	   item_type == "double_weapon")
		return (int)me["/plus/autofight_sell_weapon"] == 1;
	if(item_type == "armor")
		return (int)me["/plus/autofight_sell_armor"] == 1;
	if(item_type == "jewelry" || item_type == "decorate")
		return (int)me["/plus/autofight_sell_accessory"] == 1;
	return 0;
}

private int has_auto_sell_protected_gem(object item)
{
	array(string) colors = ({"blue","red","yellow"});
	if(!item || !functionp(item->query_baoshi))
		return 0;
	foreach(colors,string color){
		array(object) gems = item->query_baoshi(color);
		if(gems && sizeof(gems))
			return 1;
	}
	return 0;
}

private int has_auto_sell_protected_filename(object item)
{
	string path;
	if(!item)
		return 1;
	path = (file_name(item)/"#")[0];
	if(search(path,"/duanzao/") != -1 ||
	   search(path,"/suit_") != -1 ||
	   search(path,"Xa") != -1 ||
	   search(path,"Xl") != -1 ||
	   search(path,"Xh") != -1 ||
	   search(path,"Xf") != -1)
		return 1;
	return 0;
}

string query_auto_sell_reject_reason(object me,object item)
{
	string mode;
	string item_from;
	int level_gap;
	int item_level;
	if(!me || !item || environment(item) != me)
		return "not_in_backpack";
	if(!item->is("item") || !item->is("equip") ||
	   !is_auto_sell_equipment_type(item))
		return "not_equipment";
	if(!query_auto_sell_enabled(me))
		return "disabled";
	if(item->equiped)
		return "equipped";
	if(item->query_item_task() == 1)
		return "task_item";
	if(item->query_item_canTrade() != 1)
		return "not_tradeable";
	if(item->query_item_canDrop() != 1 ||
	   item->query_item_canStorage() != 1)
		return "restricted";
	if(item->query_item_only() == 1)
		return "unique";
	if(item->item_playerDesc && item->item_playerDesc != "")
		return "player_marked";
	item_from = item->query_item_from();
	if(item_from && item_from != "")
		return "special_source";
	if(has_auto_sell_protected_filename(item))
		return "forged_or_fused";
	if(functionp(item->query_convert_count) &&
	   item->query_convert_count() > 0)
		return "converted";
	if(has_auto_sell_protected_gem(item))
		return "socketed";
	mode = query_auto_sell_mode(me);
	if(item->query_item_rareLevel() >
	   query_auto_sell_quality_limit(mode))
		return "quality";
	if(item->query_item_rareLevel() >= 5)
		return "rare";
	if(!is_auto_sell_category_enabled(me,item))
		return "category";
	item_level = item->query_item_canLevel();
	if(item_level < 0)
		return "no_level_requirement";
	level_gap = query_auto_sell_level_gap(me);
	if(item_level > me->query_level()-level_gap)
		return "recent_level";
	return "";
}

array(object) query_auto_sell_candidates(object me)
{
	array(object) candidates = ({});
	if(!me || !query_auto_sell_enabled(me))
		return candidates;
	foreach(all_inventory(me),object item){
		if(query_auto_sell_reject_reason(me,item) == "")
			candidates += ({item});
	}
	return candidates;
}

int should_auto_sell(object me)
{
	if(!me || !query_auto_sell_enabled(me))
		return 0;
	if(query_backpack_percent(me) <
	   query_auto_sell_trigger_percent(me))
		return 0;
	return sizeof(query_auto_sell_candidates(me)) > 0;
}

int query_auto_sell_value(object item)
{
	int money_num;
	if(!item || !is_auto_sell_equipment_type(item))
		return 0;
	money_num = (int)item->query_item_canLevel()*50/4;
	if(money_num <= 0)
		money_num = 1;
	return money_num;
}

mapping(string:mixed) perform_auto_sell(object me)
{
	mapping(string:mixed) result = ([
		"count":0,
		"money":0,
		"names":({}),
	]);
	array(object) candidates;
	int batch_size;
	if(!me || !query_auto_sell_enabled(me) || me->in_combat)
		return result;
	candidates = query_auto_sell_candidates(me);
	batch_size = query_auto_sell_batch_size(me);
	for(int i = 0;i < sizeof(candidates) && i < batch_size;i++){
		object item = candidates[i];
		string item_name;
		string item_path;
		string now;
		int money_num;
		if(query_auto_sell_reject_reason(me,item) != "")
			continue;
		item_name = item->query_name_cn();
		item_path = (file_name(item)/"#")[0];
		money_num = query_auto_sell_value(item);
		me->add_money(money_num);
		result["count"] = (int)result["count"]+1;
		result["money"] = (int)result["money"]+money_num;
		result["names"] += ({item_name});
		now = ctime(time());
		Stdio.append_file(ROOT+"/log/autofight_sell.log",
			now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
			me->query_name()+") VIP"+query_vip_level(me)+
			" 自动出售 "+item_name+" "+item_path+" 得到"+
			money_num+"\n");
		item->remove();
	}
	return result;
}

private int is_auto_sell_material(object me,object item)
{
	string material_type;
	int keep;
	if(!me || !item || environment(item) != me)
		return 0;
	keep = query_material_keep(me);
	if(keep < 0 || !item->is("combine_item"))
		return 0;
	material_type = item->query_for_material();
	if(material_type != "duanzao" && material_type != "liandan")
		return 0;
	if(item->query_item_canTrade() != 1 || item->value <= 0)
		return 0;
	return item->amount > keep;
}

int consolidate_gathered_materials(object me)
{
	mapping(string:object) first_items = ([]);
	int removed = 0;
	if(!me)
		return 0;
	foreach(all_inventory(me),object item){
		string material_type;
		string key;
		object first;
		if(!item || !item->is("combine_item"))
			continue;
		material_type = item->query_for_material();
		if(material_type != "duanzao" && material_type != "liandan")
			continue;
		key = item->query_name()+"#"+item->query_toVip();
		first = first_items[key];
		item->max_count = 9999;
		if(!first){
			first_items[key] = item;
			continue;
		}
		int available = 9999-first->amount;
		if(available <= 0){
			first_items[key] = item;
			continue;
		}
		if(item->amount <= available){
			first->amount += item->amount;
			item->remove();
			removed++;
		}
		else{
			first->amount = 9999;
			item->amount -= available;
			first_items[key] = item;
		}
	}
	return removed;
}

object|zero query_auto_sell_material(object me)
{
	if(!me || query_material_keep(me) < 0)
		return 0;
	foreach(all_inventory(me),object item){
		if(is_auto_sell_material(me,item))
			return item;
	}
	return 0;
}

int should_auto_sell_material(object me)
{
	if(!me || me->in_combat)
		return 0;
	return query_auto_sell_material(me) ? 1 : 0;
}

mapping(string:mixed) perform_auto_sell_material(object me)
{
	mapping(string:mixed) result = ([
		"count":0,
		"money":0,
		"name":"",
	]);
	object|zero item;
	int keep;
	int sell_amount;
	int money_num;
	string item_name;
	string item_path;
	string now;
	if(!me || me->in_combat)
		return result;
	item = query_auto_sell_material(me);
	if(!item)
		return result;
	keep = query_material_keep(me);
	sell_amount = item->amount-keep;
	if(sell_amount <= 0)
		return result;
	item_name = item->query_name_cn();
	item_path = (file_name(item)/"#")[0];
	money_num = item->value*sell_amount;
	if(money_num <= 0)
		money_num = sell_amount;
	me->add_money(money_num);
	result["count"] = sell_amount;
	result["money"] = money_num;
	result["name"] = item_name;
	item->amount = keep;
	if(item->amount <= 0)
		item->remove();
	now = ctime(time());
	Stdio.append_file(ROOT+"/log/autofight_material_sell.log",
		now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
		me->query_name()+") 自动出售采集原料 "+item_name+" "+
		item_path+" 数量"+sell_amount+" 得到"+money_num+"\n");
	return result;
}

void start_autofight(object me)
{
	if(!me)
		return;
	initialize_player(me);
	me["/tmp/autofight_last_charge"] = time();
	me["/tmp/autofight_no_target_ticks"] = 0;
	me->set_autofight("enable");
}

void stop_autofight(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_last_charge"] = 0;
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_resting"] = 0;
	me->set_autofight("disable");
}

int charge_time(object me)
{
	int now;
	int last;
	int elapsed;
	int left;
	if(!me)
		return 0;
	initialize_player(me);
	now = time();
	last = (int)me["/tmp/autofight_last_charge"];
	if(last <= 0 || last > now){
		me["/tmp/autofight_last_charge"] = now;
		return query_time_left(me);
	}
	elapsed = now-last;
	if(elapsed <= 0)
		return query_time_left(me);
	left = query_time_left(me)-elapsed;
	if(left < 0)
		left = 0;
	me["/plus/autofight_time_left"] = left;
	me["/tmp/autofight_last_charge"] = now;
	return left;
}

string query_start_block_reason(object me)
{
	object env;
	if(!me)
		return "玩家对象不存在";
	initialize_player(me);
	if(me->is("npc"))
		return "NPC不能开启自动挂机";
	env = environment(me);
	if(!env)
		return "你当前不在有效地图中";
	if(me->is("ghost") || me->get_cur_life() <= 0)
		return "死亡或灵魂状态不能开启自动挂机";
	if((int)me["/plus/random_rcd"] > 0)
		return "请先完成当前的安全验证";
	if(query_time_left(me) <= 0)
		return sprintf("今天的%d小时自动挂机时间已经用完",
			query_daily_seconds_for(me)/3600);
	consolidate_gathered_materials(me);
	if(query_loot_enabled(me) && me->if_over_easy_load()){
		if(query_auto_sell_material(me))
			return "";
		if(query_auto_sell_enabled(me) &&
		   sizeof(query_auto_sell_candidates(me)))
			return "";
		if(query_auto_sell_mode(me) != "off")
			return "背包已满，智能清包没有找到符合当前规则的装备";
		return "背包已满，请整理背包后再开启";
	}
	return "";
}

string query_runtime_block_reason(object me)
{
	return query_start_block_reason(me);
}

int should_recover_life(object me)
{
	int life;
	int life_max;
	int percent;
	if(!me)
		return 0;
	life = me->get_cur_life();
	life_max = me->query_life_max();
	percent = query_hp_percent(me);
	if(life <= 0 || life_max <= 0)
		return 0;
	return life*100 < life_max*percent;
}

int should_recover_mana(object me)
{
	int mana;
	int mana_max;
	int percent;
	if(!me)
		return 0;
	mana = me->get_cur_mofa();
	mana_max = me->query_mofa_max();
	percent = query_mana_percent(me);
	if(percent <= 0 || mana_max <= 0)
		return 0;
	return mana*100 < mana_max*percent;
}

mapping(string:mixed) query_training_route(object me)
{
	mapping(string:mixed) route;
	string race;
	string path;
	int level;
	if(!me)
		return ([]);
	level = me->query_level();
	race = me->query_raceId();
	if(level>=70){
		path = "plxianjing/chilingxiaolu";
		if(race=="monst")
			path = "plxianjing/chiyuxiaolu";
		else if(race=="third")
			path = "penglaihuanjing/qiushuangxiaojing";
		return ([
			"max":MAX_LEVEL,
			"level":level>MAX_LEVEL ? MAX_LEVEL : level,
			"name":"动态同级历练",
			"path":path,
		]);
	}
	foreach(smart_training_routes,mapping(string:mixed) one){
		if(level<=(int)one["max"]){
			path = (string)one[race];
			if(path=="")
				path = (string)one["third"];
			if(path=="")
				path = (string)one["human"];
			route = copy_value(one);
			route["path"] = path;
			return route;
		}
	}
	return ([]);
}

string query_current_room_path(object me)
{
	object env;
	string path;
	string prefix;
	if(!me)
		return "";
	env = environment(me);
	if(!env)
		return "";
	path = (file_name(env)/"#")[0];
	prefix = ROOT+"/gamelib/d/";
	if(has_prefix(path,prefix))
		return path[sizeof(prefix)..];
	return path;
}

int can_auto_leave_current_room(object me)
{
	object env;
	string room_type;
	if(!me)
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	room_type = env->query_room_type();
	if(room_type=="fb" || room_type=="home" ||
	   room_type=="city" || room_type=="town")
		return 0;
	return 1;
}

string query_rest_room(object me)
{
	if(!me)
		return "";
	if(me->query_raceId()=="monst")
		return "jinaodao/yuhuacunguangchang";
	return "congxianzhen/congxianzhenguangchang";
}

int query_is_resting(object me)
{
	if(!me)
		return 0;
	return (int)me["/tmp/autofight_resting"] == 1;
}

int begin_auto_rest(object me)
{
	if(!me || !query_auto_rest_enabled(me) ||
	   !can_auto_leave_current_room(me))
		return 0;
	me["/tmp/autofight_resting"] = 1;
	me["/tmp/autofight_rest_started"] = time();
	return 1;
}

void finish_auto_rest(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_resting"] = 0;
	me["/tmp/autofight_rest_started"] = 0;
}

int query_route_ready(object me)
{
	int last;
	if(!me)
		return 0;
	last = (int)me["/tmp/autofight_last_route_time"];
	return last<=0 || time()-last>=AUTOFIGHT_ROUTE_COOLDOWN;
}

void record_route(object me,string path)
{
	if(!me)
		return;
	me["/tmp/autofight_last_route_time"] = time();
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/plus/autofight_last_route"] = path;
}

int should_route_to_training_area(object me)
{
	mapping(string:mixed) route;
	string current;
	string destination;
	if(!me || !query_smart_route_enabled(me) ||
	   !can_auto_leave_current_room(me) || !query_route_ready(me))
		return 0;
	route = query_training_route(me);
	destination = (string)route["path"];
	if(destination=="")
		return 0;
	current = query_current_room_path(me);
	if(current==destination)
		return 0;
	return 1;
}

int record_no_target(object me)
{
	int ticks;
	if(!me)
		return 0;
	ticks = (int)me["/tmp/autofight_no_target_ticks"]+1;
	me["/tmp/autofight_no_target_ticks"] = ticks;
	return ticks;
}

void clear_no_target(object me)
{
	if(me)
		me["/tmp/autofight_no_target_ticks"] = 0;
}

private int is_valid_target(object me, object ob)
{
	string npc_type;
	string me_race;
	string npc_race;
	int me_level;
	int npc_level;
	int minimum_level;
	int maximum_level;
	if(!me || !ob || ob == me)
		return 0;
	if(!ob->is("character") || !ob->is("npc"))
		return 0;
	if(ob->hind != 0 || ob->get_cur_life() <= 0)
		return 0;
	if(ob->_boss || ob->_tasknpc)
		return 0;
	if(functionp(ob->query_summon_type))
		return 0;
	npc_type = ob->query_npc_type();
	if(npc_type == "city_keeper" || npc_type == "city_guarder" ||
	   npc_type == "city_lord")
		return 0;
	if(functionp(ob->can_be_attacked) && !ob->can_be_attacked(me))
		return 0;
	me_race = me->query_raceId();
	npc_race = ob->query_raceId();
	if(me_race != "third" && me_race == npc_race)
		return 0;
	me_level = me->query_level();
	npc_level = ob->query_level();
	maximum_level = me_level+2;
	minimum_level = 1;
	if(query_smart_route_enabled(me)){
		maximum_level = me_level>=50 ? me_level+1 : me_level;
		minimum_level = me_level-4;
		if(minimum_level<1)
			minimum_level = 1;
	}
	if(npc_level > maximum_level || npc_level < minimum_level)
		return 0;
	return 1;
}

object|zero query_target(object me)
{
	object env;
	object|zero best;
	array(object) all;
	int best_level;
	if(!me)
		return 0;
	env = environment(me);
	if(!env || env->is("peaceful"))
		return 0;
	all = all_inventory(env);
	best_level = -1;
	foreach(all,object ob){
		int npc_level;
		if(!is_valid_target(me,ob))
			continue;
		npc_level = ob->query_level();
		if(npc_level > best_level){
			best = ob;
			best_level = npc_level;
		}
	}
	return best;
}

private int can_loot_item(object me, object ob)
{
	string owner;
	string name_cn;
	int protect_time;
	if(!me || !ob)
		return 0;
	if(!ob->is("item") || ob->is("npc"))
		return 0;
	if(functionp(ob->query_item_canGet) && ob->query_item_canGet() != 1)
		return 0;
	if(ob->query_name() == "corpse")
		return 0;
	name_cn = ob->query_name_cn();
	if(name_cn && (search(name_cn,"尸体") != -1 ||
	   search(name_cn,"骸骨") != -1))
		return 0;
	owner = ob->item_whoCanGet;
	protect_time = (int)ob->item_TimewhoCanGet;
	if(owner && owner != "" && owner != "1" &&
	   owner != me->query_name() && owner != me->query_term()){
		if(time()-protect_time < 120)
			return 0;
	}
	return 1;
}

object|zero query_loot_item(object me)
{
	object env;
	array(object) all;
	if(!me || !query_loot_enabled(me))
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = all_inventory(env);
	foreach(all,object ob){
		if(can_loot_item(me,ob))
			return ob;
	}
	return 0;
}

private int is_matching_recovery_item(object me,object item,string kind)
{
	mapping supply;
	if(!me || !item || item->amount <= 0 || item->eat_flag != 1)
		return 0;
	if(me->query_level() < item->level_limit)
		return 0;
	if(!item->race_limit[me->query_raceId()] ||
	   !sizeof(item->race_limit[me->query_raceId()]))
		return 0;
	if(!item->profe_limit[me->query_profeId()] ||
	   !sizeof(item->profe_limit[me->query_profeId()]))
		return 0;
	supply = item->add_supplay;
	if(!supply || !sizeof(supply))
		return 0;
	if(kind == "life")
		return functionp(item->eat) && (int)supply["life_supply"] > 0;
	if(kind == "mana")
		return functionp(item->drink) && (int)supply["mofa_supply"] > 0;
	return 0;
}

object|zero query_recovery_item(object me, string kind)
{
	string setting;
	array(object) all;
	if(!me)
		return 0;
	initialize_player(me);
	if(kind == "life")
		setting = (string)me["/plus/autofight_food"];
	else
		setting = (string)me["/plus/autofight_water"];
	all = all_inventory(me);
	foreach(all,object item){
		if(setting != "auto" && setting != "" &&
		   item->query_name() != setting)
			continue;
		if(is_matching_recovery_item(me,item,kind))
			return item;
	}
	if(setting != "auto" && setting != ""){
		foreach(all,object item){
			if(is_matching_recovery_item(me,item,kind))
				return item;
		}
	}
	return 0;
}

object|zero query_recovery_item_with_newbie_supply(object me,string kind)
{
	object|zero item;
	mapping result;
	if(!me)
		return 0;
	item = query_recovery_item(me,kind);
	if(item)
		return item;
	if(me->query_level()>NEWBIED->query_newbie_supply_max_level())
		return 0;
	result = NEWBIED->claim_newbie_supplies(me);
	if(result["code"]!=1)
		return 0;
	return query_recovery_item(me,kind);
}

int query_object_count(object ob, object env)
{
	array(object) all;
	int count;
	if(!ob || !env)
		return 0;
	all = all_inventory(env);
	count = 0;
	foreach(all,object item){
		if(item == ob)
			return count;
		if(item->query_name() == ob->query_name())
			count++;
	}
	return 0;
}

private int is_same_area(string current_path, string destination)
{
	array(string) current_parts;
	array(string) destination_parts;
	if(!current_path || !destination)
		return 0;
	current_path = (current_path/"#")[0];
	current_parts = current_path/"/";
	destination_parts = destination/"/";
	if(sizeof(current_parts) < 2 || sizeof(destination_parts) < 2)
		return 0;
	return current_parts[sizeof(current_parts)-2] ==
		destination_parts[sizeof(destination_parts)-2];
}

string query_safe_exit(object me)
{
	object env;
	array(string) exits;
	array(string) safe_exits;
	string current_path;
	if(!me || (!query_roam_enabled(me) &&
	   !query_smart_route_enabled(me)))
		return "";
	if(!can_auto_leave_current_room(me))
		return "";
	env = environment(me);
	if(!env || !env->exits || !sizeof(env->exits))
		return "";
	current_path = file_name(env);
	exits = indices(env->exits);
	safe_exits = ({});
	foreach(exits,string direction){
		string destination;
		destination = (string)env->exits[direction];
		if(!destination || destination == "")
			continue;
		if(env->closed_exits[direction])
			continue;
		if(env->hidden_exits[direction])
			continue;
		if(env->guarded_exits[direction])
			continue;
		if(is_same_area(current_path,destination))
			safe_exits += ({direction});
	}
	if(!sizeof(safe_exits))
		return "";
	return safe_exits[random(sizeof(safe_exits))];
}
