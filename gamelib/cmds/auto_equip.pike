#include <command.h>
#include <gamelib/include/gamelib.h>
#include <wapmud2/include/wapmud2.h>

// 自动穿装助手：
// 1. 默认只填补空装备位，绝不替换玩家已经穿戴的装备。
// 2. 玩家主动选择 smart 时，只替换同槽且评分严格更高的普通装备。
//    强化、融合、镶宝石、稀有装备交给玩家手动决定。
// 3. 装备前检查物品类型、任务标记、等级、职业和人物属性。
// 4. 正确处理双手武器与主手、副手之间的冲突。

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
		"broken":"装备已损坏",
		"unknown_slot":"未知装备位",
		"occupied":"装备位已有物品",
		"invested":"强化、融合、镶嵌或稀有装备受保护",
		"set_protected":"套装共鸣受保护",
		"not_stronger":"评分未严格超过现有装备",
		"wear_failed":"穿戴失败",
		"replace_failed":"替换失败并已恢复旧装备",
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

string query_equip_reject_reason(object player,object item,
	void|object replacing)
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
	if(functionp(item->query_catchup_equipment) &&
	   item->query_catchup_equipment() &&
	   !item->query_catchup_can_equip(player))
		return "catchup_inactive";
	if(item->query_item_canDura() == 1 && item->item_dura > 0 &&
	   item->item_cur_dura <= 0)
		return "broken";
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
		if(replacing)
			have_yellow_jade -= query_yellow_jade_on_item(replacing);
		if(have_yellow_jade < 0)
			have_yellow_jade = 0;
		if(have_yellow_jade + item_yellow_jade > 4)
			return "yellow_jade";
	}
	return "";
}

int query_item_gem_count(object item)
{
	array(object) gems;
	if(!item || !functionp(item->query_baoshi))
		return 0;
	gems = item->query_baoshi("all");
	return gems ? sizeof(gems) : 0;
}

int is_invested_equipment(object item)
{
	string source;
	if(!item)
		return 0;
	if(item->query_item_rareLevel() > 0 || query_item_gem_count(item) > 0)
		return 1;
	source = file_name(item);
	return search(source,"Xl") != -1 || search(source,"Xh") != -1 ||
		search(source,"Xf") != -1;
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

int is_newmoon_set_equipment(object item)
{
	return item && item->is("equip") &&
		functionp(item->query_newmoon_resonance_profession) &&
		(string)item->query_newmoon_resonance_profession()!="" &&
		functionp(item->query_newmoon_collection_id) &&
		(string)item->query_newmoon_collection_id()!="";
}

string query_newmoon_set_key(object item)
{
	if(!is_newmoon_set_equipment(item))
		return "";
	return (string)item->query_newmoon_collection_id()+"|"+
		(string)item->query_newmoon_resonance_profession()+"|"+
		(string)item->query_newmoon_resonance_theme();
}

private string select_preferred_set_group(mapping groups)
{
	string best_key="";
	int best_count=-1;
	int best_rank=-1;
	int best_score=-1;
	foreach(sort(indices(groups)),string key){
		mapping one=groups[key];
		int count=sizeof((mapping)one["slots"]);
		int rank=(int)one["rank"];
		int score=(int)one["score"];
		if(count>best_count ||
		   (count==best_count && rank>best_rank) ||
		   (count==best_count && rank==best_rank && score>best_score)){
			best_key=key;
			best_count=count;
			best_rank=rank;
			best_score=score;
		}
	}
	return best_key;
}

string query_preferred_set_key(object player)
{
	mapping equipped_groups=([]);
	mapping inventory_groups=([]);
	if(!player)
		return "";
	foreach(all_inventory(player),object item){
		string key;
		string slot;
		mapping target;
		if(!is_newmoon_set_equipment(item) ||
		   (string)item->query_newmoon_resonance_profession()!=
		   (string)player->query_profeId())
			continue;
		key=query_newmoon_set_key(item);
		slot=(string)item->query_item_kind();
		if(key=="" || slot=="")
			continue;
		if(item->equiped)
			target=equipped_groups;
		else{
			if(query_equip_reject_reason(player,item)!="")
				continue;
			target=inventory_groups;
		}
		if(!mappingp(target[key]))
			target[key]=(["slots":([]),"rank":
				(int)item->query_newmoon_collection_rank(),"score":0]);
		target[key]["slots"][slot]=1;
		target[key]["score"]=(int)target[key]["score"]+
			query_item_score(item);
	}
	// 已穿套装优先，避免补空位时混入另一系列并拆散未来共鸣。
	if(sizeof(equipped_groups))
		return select_preferred_set_group(equipped_groups);
	return select_preferred_set_group(inventory_groups);
}

void add_rejected(mapping result,string reason)
{
	mapping rejected = result["rejected"];
	if(!rejected[reason])
		rejected[reason] = 0;
	rejected[reason]++;
}

object|zero query_better_item(object|zero current,object candidate,
	void|string preferred_set_key)
{
	if(!current)
		return candidate;
	if(preferred_set_key && preferred_set_key!=""){
		int current_preferred=
			query_newmoon_set_key(current)==preferred_set_key;
		int candidate_preferred=
			query_newmoon_set_key(candidate)==preferred_set_key;
		if(current_preferred!=candidate_preferred)
			return candidate_preferred ? candidate : current;
	}
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

mapping auto_equip_player(object player,void|int prefer_set)
{
	mapping result = ([
		"mode":prefer_set ? "set" : "fill",
		"equipped":({}),
		"replaced":({}),
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
	string preferred_set_key="";

	if(!player)
		return result;
	inventory = all_inventory(player);
	if(prefer_set)
		preferred_set_key=query_preferred_set_key(player);
	result["preferred_set_key"]=preferred_set_key;

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
				best_double = query_better_item(best_double,item,
					preferred_set_key);
			else if(slot == "single_main_weapon")
				best_main = query_better_item(best_main,item,
					preferred_set_key);
			else if(slot == "single_other_weapon")
				best_other = query_better_item(best_other,item,
					preferred_set_key);
			else
				add_rejected(result,"unknown_slot");
			continue;
		}

		if(occupied[slot]){
			add_rejected(result,"occupied");
			continue;
		}
		best_armor[slot] = query_better_item(best_armor[slot],item,
			preferred_set_key);
	}

	if(!has_double && !has_main && !has_other){
		// 主手与双手武器也必须服从套装优先级，不能在最后一步又被
		// 一把高面板普通双手武器覆盖掉已选中的同系列套装武器。
		object|zero first_weapon=best_main;
		if(best_double)
			first_weapon=query_better_item(first_weapon,best_double,
				preferred_set_key);
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

int replace_selected_item(object player,object current,object candidate,
	mapping result)
{
	mixed worn;
	mixed restored;
	string item_type;
	if(!player || !current || !candidate ||
	   environment(current) != player || environment(candidate) != player ||
	   !current->equiped || candidate->equiped ||
	   current->query_item_kind() != candidate->query_item_kind()){
		add_rejected(result,"replace_failed");
		return 0;
	}
	item_type = candidate->query_item_type();
	if(is_weapon_type(item_type))
		worn = player->wield(candidate);
	else
		worn = player->wear(candidate);
	if(worn && candidate->equiped && !current->equiped){
		result["replaced"] += ({([
			"old":current,
			"new":candidate,
			"slot":candidate->query_item_kind(),
		])});
		return 1;
	}
	// wear/wield 可能先卸下旧装备再失败，必须尽力恢复原状态。
	if(!current->equiped){
		if(is_weapon_type(current->query_item_type()))
			restored = player->wield(current);
		else
			restored = player->wear(current);
	}
	add_rejected(result,"replace_failed");
	return 0;
}

mapping auto_replace_player(object player,void|int allow_break_set)
{
	// 先沿用原有安全逻辑补齐空槽，再只比较仍有候选的同槽装备。
	mapping result = auto_equip_player(player);
	mapping best = ([]);
	mapping protected_slots = ([]);
	array(object) inventory;
	result["mode"] = allow_break_set ? "breakset" : "smart";
	if(!player)
		return result;
	inventory = all_inventory(player);
	foreach(inventory,object item){
		string slot;
		string reason;
		object|zero current;
		if(!item || !item->is("equip") || item->equiped)
			continue;
		slot = item->query_item_kind();
		current = player->query_equip()[slot];
		if(!current)
			continue;
		reason = query_equip_reject_reason(player,item,current);
		if(sizeof(reason)){
			add_rejected(result,reason);
			continue;
		}
		if(is_newmoon_set_equipment(current) && !allow_break_set){
			if(!protected_slots[slot]){
				protected_slots[slot] = 1;
				add_rejected(result,"set_protected");
			}
			continue;
		}
		if(is_invested_equipment(current) &&
		   !(allow_break_set && is_newmoon_set_equipment(current))){
			if(!protected_slots[slot]){
				protected_slots[slot] = 1;
				add_rejected(result,"invested");
			}
			continue;
		}
		if(query_item_score(item) <= query_item_score(current)){
			add_rejected(result,"not_stronger");
			continue;
		}
		best[slot] = query_better_item(best[slot],item);
	}
	foreach(sort(indices(best)),string slot){
		object|zero current = player->query_equip()[slot];
		object candidate = best[slot];
		if(current && candidate &&
		   query_item_score(candidate) > query_item_score(current))
			replace_selected_item(player,current,candidate,result);
	}
	result["invested_protected"] = sizeof(protected_slots);
	return result;
}

string render_result(mapping result)
{
	string s = "【自动穿装助手】\n";
	array(object) equipped = result["equipped"];
	array(mapping) replaced = result["replaced"] || ({});
	mapping rejected = result["rejected"];
	string mode=(string)result["mode"];
	int smart = mode == "smart" || mode == "breakset";
	int set_mode = mode == "set";

	if(sizeof(equipped)){
		s += "已为你穿戴：\n";
		for(int i = 0;i < sizeof(equipped);i++){
			object item = equipped[i];
			s += "· " + query_slot_label(item->query_item_kind()) +
				"：" + item->query_name_cn() + "\n";
		}
		s += "共穿戴" + sizeof(equipped) + "件装备。\n";
	}
	else if(!smart || !sizeof(replaced))
		s += "没有找到可以填补空位的装备。\n";
	if(sizeof(replaced)){
		s += "已智能替换：\n";
		foreach(replaced,mapping one){
			object old_item = one["old"];
			object new_item = one["new"];
			s += "· " + query_slot_label((string)one["slot"]) + "：" +
				old_item->query_name_cn() + " → " +
				new_item->query_name_cn() + "\n";
		}
	}
	if(smart && !sizeof(equipped) && !sizeof(replaced))
		s += "没有找到评分更高且可安全替换的装备。\n";

	if(!smart && result["protected"] > 0)
		s += "已保护" + result["protected"] +
			"件现有装备，不会自动替换。\n";
	if(smart && (int)result["invested_protected"] > 0)
		s += "已保护" + (int)result["invested_protected"] +
			"个槽位的强化、融合、镶嵌或稀有装备。\n";
	if(sizeof(rejected)){
		s += "暂未穿戴：";
		array(string) reasons = ({});
		foreach(sort(indices(rejected)),string reason)
			reasons += ({query_reason_label(reason) + rejected[reason] + "件"});
		s += reasons*"、";
		s += "。\n";
	}
	if(smart){
		if(mode=="breakset")
			s += "\n提示：你已明确允许拆散套装；仍只替换同槽且评分严格"+
				"更高的装备，其他养成装备继续受保护。\n";
		else
			s += "\n提示：只替换同槽且评分严格更高的普通装备；"+
				"套装共鸣及其他养成装备不会被拆散。\n";
		s += "[仅补空位:auto_equip fill]\n";
	}
	else if(set_mode){
		if((string)result["preferred_set_key"]!="")
			s += "\n提示：已优先补齐当前已穿套装；未穿套装时优先选择"+
				"可组成最多不同部位的一组。现有装备不会被替换。\n";
		else
			s += "\n提示：没有找到本职业可穿套装，已按普通评分补空位。\n";
		s += "[智能替换更强装备:auto_equip smart]\n";
	}
	else{
		s += "\n提示：当前模式只补空位，不会顶掉现有装备。\n";
		s += "[套装优先补空位:auto_equip set]|"+
			"[智能替换更强装备:auto_equip smart]\n";
	}
	if(mode=="smart")
		s += "[允许拆散套装（需确认）:auto_equip breakset]\n";
	s += "[套装管理:set_equipment_cleanup]\n";
	s += "[查看装备:inventory]\n";
	s += "[返回游戏:look]\n";
	return s;
}

mapping auto_unequip_player(object player)
{
	mapping result = (["removed":({}),"failed":0,"mode":"off"]);
	if(!player)
		return result;
	if(player->in_combat)
		return result+(["in_combat":1]);
	foreach(all_inventory(player),object item){
		if(!item || !item->equiped)
			continue;
		if(is_weapon_type((string)item->query_item_type())){
			if(player->unwield(item)){
				result["removed"] += ({item});
				continue;
			}
		}
		else if(player->unwear(item)){
			result["removed"] += ({item});
			continue;
		}
		result["failed"]++;
	}
	return result;
}

private string render_unequip_result(mapping result)
{
	array(object) removed=(array)result["removed"];
	string s = "【一键脱装】\n";
	if((int)result["in_combat"]){
		s += "战斗中不能批量脱装，请先脱离战斗。\n";
		return s+"[返回游戏:look]\n";
	}
	if(!sizeof(removed)){
		s += "你身上没有穿戴装备。\n";
		return s+"[一键穿装:auto_equip]\n[返回游戏:look]\n";
	}
	foreach(removed,object item)
		s += "· 已脱下："+(string)item->query_name_cn()+"\n";
	s += "共脱下"+sizeof(removed)+"件装备。\n";
	if((int)result["failed"]>0)
		s += "有"+(int)result["failed"]+"件装备未能脱下。\n";
	s += "\n提示：脱装后可用一键穿装重新搭配。\n";
	s += "[一键穿装:auto_equip]|[套装优先补空位:auto_equip set]|"+
		"[智能替换更强装备:auto_equip smart]\n";
	s += "[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object player = this_player();
	mapping result;

	if(!player)
		return 0;
	if(arg=="off"){
		result = auto_unequip_player(player);
		NEWBIED->record_action(player,"auto_equip");
		player->write_view(WAP_VIEWD["/emote"],0,0,
			render_unequip_result(result));
		return 1;
	}
	if(arg=="breakset"){
		player->write_view(WAP_VIEWD["/emote"],0,0,
			"【允许拆散套装】\n此操作可能让2/4/6/8/10件共鸣失效。"+
			"只有确实希望按单件评分替换时才继续。\n\n"+
			"[确认允许拆套:auto_equip breakset_confirm]|"+
			"[取消:auto_equip]\n");
		return 1;
	}
	if(arg == "smart")
		result = auto_replace_player(player);
	else if(arg=="breakset_confirm")
		result=auto_replace_player(player,1);
	else if(arg=="set")
		result=auto_equip_player(player,1);
	else
		result = auto_equip_player(player);
	if(arg != "silent"){
		NEWBIED->record_action(player,"auto_equip");
		player->write_view(WAP_VIEWD["/emote"],0,0,render_result(result));
	}
	return 1;
}
