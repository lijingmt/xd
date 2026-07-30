#include <command.h>
#include <gamelib/include/gamelib.h>
#include <wapmud2/include/wapmud2.h>

// 新手自动穿装助手：
// 1. 只填补空装备位，绝不替换玩家已经穿戴的装备。
// 2. 装备前检查物品类型、任务标记、等级、职业和人物属性。
// 3. 正确处理双手武器与主手、副手之间的冲突。

int is_weapon_type(string item_type)
{
	return item_type == "weapon" ||
		item_type == "single_weapon" ||
		item_type == "double_weapon";
}

int is_supported_slot(string slot)
{
	array(string) slots = ({
		"double_main_weapon",
		"single_main_weapon",
		"single_other_weapon",
		"armor_head",
		"armor_cloth",
		"armor_waste",
		"armor_hand",
		"armor_thou",
		"armor_shoes",
		"jewelry_ring",
		"jewelry_neck",
		"jewelry_bangle",
		"decorate_manteau",
		"decorate_thing",
		"decorate_tool",
	});
	return search(slots,slot) != -1;
}

string query_slot_label(string slot)
{
	mapping(string:string) labels = ([
		"double_main_weapon":"双手武器",
		"single_main_weapon":"主手武器",
		"single_other_weapon":"副手武器",
		"armor_head":"头部",
		"armor_cloth":"衣服",
		"armor_waste":"护腕",
		"armor_hand":"手套",
		"armor_thou":"裤子",
		"armor_shoes":"鞋子",
		"jewelry_ring":"戒指",
		"jewelry_neck":"项链",
		"jewelry_bangle":"手镯",
		"decorate_manteau":"披风",
		"decorate_thing":"挂件",
		"decorate_tool":"携带物",
	]);
	if(labels[slot])
		return labels[slot];
	return slot;
}

string query_reason_label(string reason)
{
	mapping(string:string) labels = ([
		"not_equipment":"不是可穿戴装备",
		"already_equipped":"已经穿戴",
		"task_item":"任务物品",
		"disabled":"禁止穿戴",
		"level":"等级不足",
		"profession":"职业不符",
		"strength":"力量不足",
		"dexterity":"敏捷不足",
		"intelligence":"智力不足",
		"yellow_jade":"黄水玉数量超限",
		"unknown_slot":"未知装备位",
		"occupied":"装备位已有物品",
		"wear_failed":"穿戴失败",
	]);
	if(labels[reason])
		return labels[reason];
	return reason;
}

int query_yellow_jade_on_item(object item)
{
	int count = 0;
	array(object) gems;

	if(!item || !functionp(item->query_baoshi))
		return 0;
	gems = item->query_baoshi("yellow");
	if(!gems || !sizeof(gems))
		return 0;

	foreach(gems,object gem){
		string gem_name;
		if(!gem)
			continue;
		gem_name = gem->query_name();
		if(gem_name == "pshuangshuiyu" ||
		   gem_name == "slhuangshuiyu" ||
		   gem_name == "jinghuangshuiyu")
			count++;
	}
	return count;
}

string query_equip_reject_reason(object player,object item)
{
	string item_type;
	string slot;
	array(string) profession_limits;
	int profession_allowed = 0;

	if(!player || !item || environment(item) != player)
		return "not_equipment";
	if(!item->is("equip"))
		return "not_equipment";

	item_type = item->query_item_type();
	if(!is_weapon_type(item_type) &&
	   item_type != "armor" &&
	   item_type != "jewelry" &&
	   item_type != "decorate")
		return "not_equipment";
	if(item->equiped)
		return "already_equipped";
	if(item->query_item_task() == 1)
		return "task_item";
	if(item->query_item_canEquip() == 0)
		return "disabled";
	if(player->query_level() < item->query_item_canLevel())
		return "level";

	profession_limits = item->query_item_profeLimit();
	for(int i = 0;i < sizeof(profession_limits);i++){
		if(profession_limits[i] == player->query_profeId()){
			profession_allowed = 1;
			break;
		}
	}
	if(!profession_allowed)
		return "profession";
	if(item->query_item_strLimit() > player->query_str())
		return "strength";
	if(item->query_item_dexLimit() > player->query_dex())
		return "dexterity";
	if(item->query_item_thinkLimit() > player->query_think())
		return "intelligence";

	slot = item->query_item_kind();
	if(!slot || !is_supported_slot(slot))
		return "unknown_slot";

	if(!is_weapon_type(item_type)){
		int have_yellow_jade = 0;
		int item_yellow_jade = query_yellow_jade_on_item(item);
		if(functionp(player->query_baoshi_xiangqian_num)){
			have_yellow_jade =
				player->query_baoshi_xiangqian_num("pshuangshuiyu",1) +
				player->query_baoshi_xiangqian_num("slhuangshuiyu",1) +
				player->query_baoshi_xiangqian_num("jinghuangshuiyu",1);
		}
		if(have_yellow_jade + item_yellow_jade > 4)
			return "yellow_jade";
	}
	return "";
}

int query_item_score(object item)
{
	int score;
	string item_type;

	if(!item)
		return -1;
	item_type = item->query_item_type();
	score = item->query_item_canLevel()*1000000;
	score += item->query_item_rareLevel()*100000;
	score += item->query_all_add()*10000;
	score += item->query_str_add()*1000;
	score += item->query_dex_add()*1000;
	score += item->query_think_add()*1000;
	score += item->query_life_add()*10;
	score += item->query_mofa_add()*10;

	if(is_weapon_type(item_type)){
		score += item->query_attack_power_limit()*100;
		score += item->query_attack_power()*100;
		score += item->query_attack_add()*10;
		score += item->query_hitte_add();
		score += item->query_doub_add();
	}
	else{
		score += item->query_equip_defend()*100;
		score += item->query_dodge_add()*10;
		score += item->query_recive_add()*10;
	}
	return score;
}

void add_rejected(mapping result,string reason)
{
	mapping rejected = result["rejected"];
	if(!rejected[reason])
		rejected[reason] = 0;
	rejected[reason]++;
}

object|zero query_better_item(object|zero current,object candidate)
{
	if(!current)
		return candidate;
	if(query_item_score(candidate) > query_item_score(current))
		return candidate;
	return current;
}

int wear_selected_item(object player,object item,mapping result)
{
	int worn = 0;
	string item_type;
	string slot;

	if(!player || !item)
		return 0;
	item_type = item->query_item_type();
	slot = item->query_item_kind();
	if(is_weapon_type(item_type))
		worn = player->wield(item);
	else
		worn = player->wear(item);

	if(worn && item->equiped){
		result["equipped"] += ({item});
		result["slots"] += ({slot});
		return 1;
	}
	add_rejected(result,"wear_failed");
	return 0;
}

mapping auto_equip_player(object player)
{
	mapping result = ([
		"equipped":({}),
		"slots":({}),
		"rejected":([]),
		"protected":0,
	]);
	array(object) inventory;
	mapping occupied = ([]);
	mapping best_armor = ([]);
	object|zero best_double = 0;
	object|zero best_main = 0;
	object|zero best_other = 0;
	int has_double = 0;
	int has_main = 0;
	int has_other = 0;

	if(!player)
		return result;
	inventory = all_inventory(player);

	foreach(inventory,object item){
		string slot;
		if(!item || !item->is("equip") || !item->equiped)
			continue;
		slot = item->query_item_kind();
		if(!slot)
			continue;
		occupied[slot] = item;
		result["protected"]++;
	}

	has_double = occupied["double_main_weapon"] != 0;
	has_main = occupied["single_main_weapon"] != 0;
	has_other = occupied["single_other_weapon"] != 0;

	foreach(inventory,object item){
		string reason;
		string slot;
		string item_type;

		if(!item || !item->is("equip"))
			continue;
		reason = query_equip_reject_reason(player,item);
		if(sizeof(reason)){
			if(reason != "already_equipped")
				add_rejected(result,reason);
			continue;
		}

		slot = item->query_item_kind();
		item_type = item->query_item_type();
		if(is_weapon_type(item_type)){
			if(has_double ||
			   (slot == "double_main_weapon" && (has_main || has_other)) ||
			   (slot == "single_main_weapon" && has_main) ||
			   (slot == "single_other_weapon" && has_other)){
				add_rejected(result,"occupied");
				continue;
			}
			if(slot == "double_main_weapon")
				best_double = query_better_item(best_double,item);
			else if(slot == "single_main_weapon")
				best_main = query_better_item(best_main,item);
			else if(slot == "single_other_weapon")
				best_other = query_better_item(best_other,item);
			else
				add_rejected(result,"unknown_slot");
			continue;
		}

		if(occupied[slot]){
			add_rejected(result,"occupied");
			continue;
		}
		best_armor[slot] = query_better_item(best_armor[slot],item);
	}

	if(!has_double && !has_main && !has_other){
		object|zero first_weapon = best_main;
		if(best_double &&
		   (!first_weapon ||
		    query_item_score(best_double) > query_item_score(first_weapon)))
			first_weapon = best_double;
		if(first_weapon){
			wear_selected_item(player,first_weapon,result);
			if(first_weapon->query_item_kind() == "double_main_weapon")
				has_double = 1;
			else
				has_main = 1;
		}
		if(!has_double && best_other)
			wear_selected_item(player,best_other,result);
	}
	else if(!has_double){
		if(!has_main && best_main)
			wear_selected_item(player,best_main,result);
		if(!has_other && best_other)
			wear_selected_item(player,best_other,result);
	}

	foreach(sort(indices(best_armor)),string slot){
		object item = best_armor[slot];
		if(item)
			wear_selected_item(player,item,result);
	}
	return result;
}

string render_result(mapping result)
{
	string s = "【自动穿装助手】\n";
	array(object) equipped = result["equipped"];
	mapping rejected = result["rejected"];

	if(sizeof(equipped)){
		s += "已为你穿戴：\n";
		for(int i = 0;i < sizeof(equipped);i++){
			object item = equipped[i];
			s += "· " + query_slot_label(item->query_item_kind()) +
				"：" + item->query_name_cn() + "\n";
		}
		s += "共穿戴" + sizeof(equipped) + "件装备。\n";
	}
	else
		s += "没有找到可以填补空位的装备。\n";

	if(result["protected"] > 0)
		s += "已保护" + result["protected"] +
			"件现有装备，不会自动替换。\n";
	if(sizeof(rejected)){
		s += "暂未穿戴：";
		array(string) reasons = ({});
		foreach(sort(indices(rejected)),string reason)
			reasons += ({query_reason_label(reason) + rejected[reason] + "件"});
		s += reasons*"、";
		s += "。\n";
	}
	s += "\n提示：助手只补空位；想换装时，请先手动脱下原装备。\n";
	s += "[查看装备:inventory]\n";
	s += "[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object player = this_player();
	mapping result;

	if(!player)
		return 0;
	result = auto_equip_player(player);
	if(arg != "silent"){
		NEWBIED->record_action(player,"auto_equip");
		player->write_view(WAP_VIEWD["/emote"],0,0,render_result(result));
	}
	return 1;
}
