/**
 * 百工体系公共守护：材料囊、熟练度、大师专精与安全制造事务。
 *
 * 旧的 vice_skills 与各职业配方映射仍是唯一权威数据；本守护只补充
 * /artisan 下的新字段，因此老人物无需迁移或重学配方。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define MATERIAL_ROOT ROOT "/gamelib/clone/item/material/"
#define MASTER_LEVEL 210
#define MASTER_SWITCH_SECONDS (7*24*60*60)
#define MASTER_SWITCH_COST 10000
#define NORMAL_BATCH_LIMIT 20
#define MEDICINE_BATCH_LIMIT 100
#define MASTER_BATCH_LIMIT 5
#define QUALITY_PITY_LIMIT 30

private mapping(string:string) skill_names = ([
	"caikuang":"采矿",
	"caiyao":"采药",
	"duanzao":"锻造",
	"liandan":"炼丹",
	"caifeng":"裁缝",
	"zhijia":"制甲",
]);

private array(string) craft_skills = ({
	"duanzao","liandan","caifeng","zhijia",
});

private mapping(string:array(string)) recipe_categories = ([
	"duanzao":({"m_weapon","s_weapon","d_weapon","armor","weapon"}),
	"liandan":({"normal","spec","attri_base","attri_vice",
		"attri_attack","attri_defend","attri_supply"}),
	"caifeng":({"head","cloth","waste","hand","thou","shoes","other"}),
	"zhijia":({"head","cloth","waste","hand","thou","shoes"}),
]);

string query_skill_name_cn(string skill_name)
{
	return skill_names[skill_name] || "未知手艺";
}

int is_valid_skill(string skill_name)
{
	return skill_names[skill_name] != 0;
}

int is_craft_skill(string skill_name)
{
	return search(craft_skills,skill_name) != -1;
}

int query_master_level()
{
	return MASTER_LEVEL;
}

int query_master_switch_cost()
{
	return MASTER_SWITCH_COST;
}

int query_master_switch_seconds()
{
	return MASTER_SWITCH_SECONDS;
}

void initialize_player(object player)
{
	if(!player)
		return;
	if(!mappingp(player->vice_skills))
		player->vice_skills = ([]);
	if(!mappingp(player->material_m))
		player->material_m = ([]);
	if(!mappingp(player->baoshi_add))
		player->baoshi_add = ([]);
	if(!mappingp(player["/artisan/materials"]))
		player["/artisan/materials"] = ([]);
	if(!mappingp(player["/artisan/material_names"]))
		player["/artisan/material_names"] = ([]);
	if(!mappingp(player["/artisan/material_paths"]))
		player["/artisan/material_paths"] = ([]);
	if(!mappingp(player["/artisan/insight"]))
		player["/artisan/insight"] = ([]);
	if(!(int)player["/artisan/initialized"]){
		player["/artisan/initialized"] = 1;
		player["/artisan/auto_pouch"] = 1;
	}
	if(!mappingp(player["/duanzao/weapon"]))
		player["/duanzao/weapon"] = ([]);
	if(!mappingp(player["/liandan/attri_supply"]))
		player["/liandan/attri_supply"] = ([]);
	// 两张旧补给配方曾被错误写进属性类；只迁移已学标记，不重发配方。
	if(mappingp(player["/liandan/attri_base"])){
		if(player["/liandan/attri_base"][94]){
			player["/liandan/attri_supply"][94] = 1;
			m_delete((mapping)player["/liandan/attri_base"],94);
		}
		if(player["/liandan/attri_base"][95]){
			player["/liandan/attri_supply"][95] = 1;
			m_delete((mapping)player["/liandan/attri_base"],95);
		}
	}
}

string query_master_specialty(object player)
{
	string specialty;
	if(!player)
		return "";
	initialize_player(player);
	specialty = (string)player["/artisan/master"];
	if(!is_craft_skill(specialty))
		return "";
	return specialty;
}

int query_master_switch_remaining(object player)
{
	int changed_at;
	int remaining;
	if(!player || query_master_specialty(player)=="")
		return 0;
	changed_at = (int)player["/artisan/master_changed_at"];
	remaining = MASTER_SWITCH_SECONDS-(time()-changed_at);
	if(remaining<0)
		remaining = 0;
	return remaining;
}

mapping(string:mixed) select_master_specialty(object player,string skill_name)
{
	mapping(string:mixed) result = (["ok":0,"message":"无法选择大师专精。"]);
	string old_specialty;
	int old_changed_at;
	int old_account;
	int save_ok;
	array(int) skill;
	if(!player || !is_craft_skill(skill_name))
		return result;
	initialize_player(player);
	skill = player->vice_skills[skill_name];
	if(!arrayp(skill) || sizeof(skill)<3){
		result["message"] = "你还没有学会"+query_skill_name_cn(skill_name)+"。";
		return result;
	}
	if((int)skill[0]<MASTER_LEVEL){
		result["message"] = query_skill_name_cn(skill_name)+"熟练度达到"+
			(string)MASTER_LEVEL+"后才能选择为大师专精。";
		return result;
	}
	old_specialty = query_master_specialty(player);
	if(old_specialty==skill_name){
		result["message"] = "你已经专精"+query_skill_name_cn(skill_name)+"。";
		return result;
	}
	if(old_specialty!="" && query_master_switch_remaining(player)>0){
		result["message"] = "大师专精仍在调整期，暂时不能再次切换。";
		return result;
	}
	old_account = player->query_account();
	if(old_specialty!="" && old_account<MASTER_SWITCH_COST){
		result["message"] = "切换大师专精需要"+
			MUD_MONEYD->query_other_money_cn(MASTER_SWITCH_COST)+"。";
		return result;
	}
	old_changed_at = (int)player["/artisan/master_changed_at"];
	if(old_specialty!="")
		player->del_account(MASTER_SWITCH_COST);
	player["/artisan/master"] = skill_name;
	player["/artisan/master_changed_at"] = time();
	save_ok = 0;
	if(functionp(player->save_with_result))
		save_ok = player->save_with_result();
	if(!save_ok){
		player["/artisan/master"] = old_specialty;
		player["/artisan/master_changed_at"] = old_changed_at;
		player->set_account(old_account);
		result["message"] = "人物存档失败，本次专精选择已经回滚。";
		return result;
	}
	result["ok"] = 1;
	result["message"] = "你已选择"+query_skill_name_cn(skill_name)+
		"为大师专精。高阶制作与匠心保底已经开启。";
	return result;
}

int query_progress_required(int skill_level)
{
	int required;
	if(skill_level<1)
		skill_level = 1;
	required = 1+skill_level/10;
	if(required<1)
		required = 1;
	return required;
}

mapping(string:int) advance_proficiency(object player,string skill_name,int times)
{
	mapping(string:int) result = (["old_level":0,"new_level":0,
		"old_progress":0,"new_progress":0]);
	array(int) skill;
	int needed;
	int step;
	if(!player || times<=0)
		return result;
	skill = player->vice_skills[skill_name];
	if(!arrayp(skill) || sizeof(skill)<3)
		return result;
	result["old_level"] = (int)skill[0];
	result["old_progress"] = (int)skill[1];
	// 兼容旧公式留下的较大进度：先折算已有进度，再累计本次操作。
	while((int)skill[0]<(int)skill[2]){
		needed = query_progress_required((int)skill[0]);
		if((int)skill[1]<needed)
			break;
		skill[1] = (int)skill[1]-needed;
		skill[0] = (int)skill[0]+1;
	}
	while(times>0 && (int)skill[0]<(int)skill[2]){
		needed = query_progress_required((int)skill[0]);
		step = needed-(int)skill[1];
		if(step<1)
			step = 1;
		if(step>times)
			step = times;
		skill[1] = (int)skill[1]+step;
		times -= step;
		if((int)skill[1]>=needed){
			skill[0] = (int)skill[0]+1;
			skill[1] = (int)skill[1]-needed;
		}
	}
	if((int)skill[0]>=(int)skill[2])
		skill[1] = 0;
	result["new_level"] = (int)skill[0];
	result["new_progress"] = (int)skill[1];
	return result;
}

int is_raw_material(object item)
{
	string path;
	if(!item || !functionp(item->is_combine_item) ||
	   !item->is_combine_item() || !functionp(item->query_for_material) ||
	   (string)item->query_for_material()=="")
		return 0;
	path = (file_name(item)/"#")[0];
	return has_prefix(path,MATERIAL_ROOT);
}

int query_auto_pouch(object player)
{
	if(!player)
		return 0;
	initialize_player(player);
	return (int)player["/artisan/auto_pouch"]==1;
}

int store_material_object(object player,object item)
{
	mapping(string:int) materials;
	mapping(string:string) names;
	mapping(string:string) paths;
	string item_name;
	int amount;
	if(!player || !is_raw_material(item))
		return 0;
	initialize_player(player);
	item_name = item->query_name();
	amount = (int)item->amount;
	if(item_name=="" || amount<=0)
		return 0;
	materials = player["/artisan/materials"];
	names = player["/artisan/material_names"];
	paths = player["/artisan/material_paths"];
	materials[item_name] = (int)materials[item_name]+amount;
	names[item_name] = item->query_name_cn();
	paths[item_name] = (file_name(item)/"#")[0];
	destruct(item);
	return amount;
}

int store_gathered_material(object player,object item)
{
	if(!query_auto_pouch(player))
		return 0;
	return store_material_object(player,item);
}

mapping(string:int) query_pouch_materials(object player)
{
	if(!player)
		return ([]);
	initialize_player(player);
	return copy_value((mapping(string:int))player["/artisan/materials"]);
}

mapping(string:string) query_pouch_material_names(object player)
{
	if(!player)
		return ([]);
	initialize_player(player);
	return copy_value((mapping(string:string))player["/artisan/material_names"]);
}

mapping(string:int) query_all_material_counts(object player)
{
	mapping(string:int) counts = ([]);
	mapping(string:int) pouch;
	array(object) inventory;
	if(!player)
		return counts;
	initialize_player(player);
	pouch = player["/artisan/materials"];
	foreach(indices(pouch),string item_name)
		counts[item_name] = (int)pouch[item_name];
	inventory = all_inventory(player);
	foreach(inventory,object item){
		if(!item || !functionp(item->is_combine_item) ||
		   !item->is_combine_item() ||
		   !functionp(item->query_for_material) ||
		   (string)item->query_for_material()=="")
			continue;
		counts[item->query_name()] = (int)counts[item->query_name()]+
			(int)item->amount;
	}
	return counts;
}

void refresh_material_cache(object player)
{
	if(!player)
		return;
	player->material_m = query_all_material_counts(player);
}

int query_material_count(object player,string item_name)
{
	mapping(string:int) counts;
	if(!player || item_name=="")
		return 0;
	counts = query_all_material_counts(player);
	return (int)counts[item_name];
}

private object|zero query_recipe_daemon(string skill_name)
{
	if(skill_name=="duanzao")
		return DUANZAOD;
	if(skill_name=="liandan")
		return LIANDAND;
	if(skill_name=="caifeng")
		return CAIFENGD;
	if(skill_name=="zhijia")
		return ZHIJIAD;
	return 0;
}

string query_recipe_item_path(string skill_name,int recipe_id)
{
	object|zero daemon = query_recipe_daemon(skill_name);
	if(!daemon)
		return "";
	if(skill_name=="duanzao")
		return (string)daemon->query_duanzao_item(recipe_id);
	if(skill_name=="liandan")
		return (string)daemon->query_liandan_item(recipe_id);
	if(skill_name=="caifeng")
		return (string)daemon->query_caifeng_item(recipe_id);
	if(skill_name=="zhijia")
		return (string)daemon->query_zhijia_item(recipe_id);
	return "";
}

int query_recipe_item_level(string skill_name,int recipe_id)
{
	object|zero daemon = query_recipe_daemon(skill_name);
	if(!daemon)
		return 0;
	return (int)daemon->query_item_level(recipe_id);
}

int query_recipe_need_level(string skill_name,int recipe_id)
{
	object|zero daemon = query_recipe_daemon(skill_name);
	if(!daemon)
		return -1;
	return (int)daemon->query_need_level(recipe_id);
}

mapping(string:array) query_recipe_materials(string skill_name,int recipe_id)
{
	object|zero daemon = query_recipe_daemon(skill_name);
	if(!daemon)
		return ([]);
	return (mapping(string:array))daemon->query_get_m(recipe_id);
}

string query_recipe_name_cn(string skill_name,int recipe_id)
{
	string item_path = query_recipe_item_path(skill_name,recipe_id);
	object|zero item;
	string name_cn = "未知制品";
	if(item_path=="")
		return name_cn;
	item = clone(ITEM_PATH+item_path);
	if(item){
		name_cn = item->query_name_cn();
		destruct(item);
	}
	return name_cn;
}

int has_recipe(object player,string skill_name,int recipe_id)
{
	array(string) categories;
	if(!player || !recipe_categories[skill_name])
		return 0;
	initialize_player(player);
	categories = recipe_categories[skill_name];
	foreach(categories,string category){
		mapping learned = player["/"+skill_name+"/"+category];
		if(mappingp(learned) && learned[recipe_id])
			return 1;
	}
	return 0;
}

array(int) query_learned_recipe_ids(object player,string skill_name)
{
	array(int) result = ({});
	array(string) categories;
	if(!player || !recipe_categories[skill_name])
		return result;
	initialize_player(player);
	categories = recipe_categories[skill_name];
	foreach(categories,string category){
		mapping learned = player["/"+skill_name+"/"+category];
		if(!mappingp(learned))
			continue;
		foreach(indices(learned),int recipe_id){
			if(learned[recipe_id] && search(result,recipe_id)==-1)
				result += ({recipe_id});
		}
	}
	sort(result);
	return result;
}

array(int) query_high_recipe_ids(object player,string skill_name)
{
	array(int) result = ({});
	array(int) learned = query_learned_recipe_ids(player,skill_name);
	foreach(learned,int recipe_id){
		if(query_recipe_item_level(skill_name,recipe_id)>=65)
			result += ({recipe_id});
	}
	return result;
}

array(int) query_master_target_levels(object player)
{
	array(int) result = ({});
	int top;
	if(!player || player->query_level()<80)
		return result;
	top = (player->query_level()/20)*20;
	for(int level=80;level<=top;level+=20)
		result += ({level});
	if(sizeof(result)>8)
		result = result[sizeof(result)-8..];
	return result;
}

int query_master_material_multiplier(int target_level)
{
	int multiplier = (target_level+39)/40;
	if(multiplier<2)
		multiplier = 2;
	return multiplier;
}

mapping(string:int) query_required_materials(string skill_name,int recipe_id,
	int amount,int target_level)
{
	mapping(string:int) result = ([]);
	mapping(string:array) recipe = query_recipe_materials(skill_name,recipe_id);
	int multiplier = 1;
	if(amount<1)
		return result;
	if(target_level>0)
		multiplier = query_master_material_multiplier(target_level);
	foreach(indices(recipe),string item_name){
		array one = recipe[item_name];
		if(arrayp(one) && sizeof(one)>1 && (int)one[1]>0)
			result[item_name] = (int)one[1]*amount*multiplier;
	}
	return result;
}

int query_makeable_amount(object player,string skill_name,int recipe_id,
	int target_level)
{
	mapping(string:int) needs = query_required_materials(skill_name,
		recipe_id,1,target_level);
	int result = 0;
	if(!sizeof(needs))
		return 0;
	foreach(indices(needs),string item_name){
		int need = (int)needs[item_name];
		int can_make;
		if(need<=0)
			continue;
		can_make = query_material_count(player,item_name)/need;
		if(result==0 || can_make<result)
			result = can_make;
	}
	return result;
}

private mapping(string:mixed) begin_material_consumption(object player,
	mapping(string:int) requirements)
{
	mapping(string:mixed) state = (["ok":0,"pouch":([]),"bag":({})]);
	mapping(string:int) counts;
	mapping(string:int) pouch;
	array(mapping(string:mixed)) bag_changes = ({});
	if(!player)
		return state;
	initialize_player(player);
	counts = query_all_material_counts(player);
	foreach(indices(requirements),string item_name){
		if((int)requirements[item_name]<=0 ||
		   (int)counts[item_name]<(int)requirements[item_name])
			return state;
	}
	pouch = player["/artisan/materials"];
	foreach(indices(requirements),string item_name){
		int remaining = (int)requirements[item_name];
		int from_pouch = (int)pouch[item_name];
		if(from_pouch>remaining)
			from_pouch = remaining;
		if(from_pouch>0){
			pouch[item_name] = (int)pouch[item_name]-from_pouch;
			if((int)pouch[item_name]<=0)
				m_delete(pouch,item_name);
			((mapping(string:int))state["pouch"])[item_name] = from_pouch;
			remaining -= from_pouch;
		}
		if(remaining>0){
			array(object) inventory = all_inventory(player);
			foreach(inventory,object item){
				int available;
				int take;
				mapping(string:mixed) change;
				if(remaining<=0)
					break;
				if(!item || !functionp(item->is_combine_item) ||
				   !item->is_combine_item() ||
				   item->query_name()!=item_name)
					continue;
				available = (int)item->amount;
				if(available<=0)
					continue;
				take = available;
				if(take>remaining)
					take = remaining;
				change = (["object":item,"path":(file_name(item)/"#")[0],
					"amount":take,"max_count":(int)item->max_count,
					"removed":0]);
				if(take>=available){
					change["removed"] = 1;
					destruct(item);
				}
				else
					item->amount = available-take;
				bag_changes += ({change});
				remaining -= take;
			}
		}
		if(remaining>0){
			state["bag"] = bag_changes;
			rollback_material_consumption(player,state);
			return (["ok":0,"pouch":([]),"bag":({})]);
		}
	}
	state["bag"] = bag_changes;
	state["ok"] = 1;
	return state;
}

int rollback_material_consumption(object player,mapping(string:mixed) state)
{
	mapping(string:int) pouch;
	mapping(string:int) pouch_used;
	array bag_changes;
	int restored_ok = 1;
	if(!player || !mappingp(state))
		return 0;
	initialize_player(player);
	pouch = player["/artisan/materials"];
	pouch_used = state["pouch"];
	if(mappingp(pouch_used)){
		foreach(indices(pouch_used),string item_name)
			pouch[item_name] = (int)pouch[item_name]+(int)pouch_used[item_name];
	}
	bag_changes = state["bag"];
	if(arrayp(bag_changes)){
		foreach(bag_changes,mapping change){
			object|zero item = change["object"];
			int amount = (int)change["amount"];
			if((int)change["removed"]){
				item = clone((string)change["path"]);
				if(item){
					item->amount = amount;
					item->max_count = (int)change["max_count"];
					item->move(player);
					if(environment(item)!=player)
						restored_ok = 0;
				}
				else
					restored_ok = 0;
			}
			else if(item)
				item->amount = (int)item->amount+amount;
			else
				restored_ok = 0;
		}
	}
	if(!restored_ok)
		werror("[ARTISAND] CRITICAL material rollback incomplete for %s\n",
			player->query_name());
	return restored_ok;
}

private int query_specialty_luck(object player,string skill_name)
{
	array(int) skill;
	int bonus;
	if(query_master_specialty(player)!=skill_name)
		return 0;
	skill = player->vice_skills[skill_name];
	if(!arrayp(skill) || !sizeof(skill))
		return 0;
	bonus = 5+(int)skill[0]/20;
	if(bonus>20)
		bonus = 20;
	return bonus;
}

private int query_enhancer_luck(object player,string skill_name,int amount,
	mapping(string:int) requirements)
{
	int luck = 0;
	string wanted_type = "moxian";
	if(skill_name=="duanzao")
		wanted_type = "baoshi";
	if(!mappingp(player->baoshi_add))
		return 0;
	foreach(indices(player->baoshi_add),string item_name){
		array data = player->baoshi_add[item_name];
		array(object) inventory = all_inventory(player);
		int valid = 0;
		foreach(inventory,object item){
			if(item && functionp(item->is_combine_item) &&
			   item->is_combine_item() && item->query_name()==item_name &&
			   functionp(item->query_for_material) &&
			   (string)item->query_for_material()==wanted_type){
				valid = 1;
				break;
			}
		}
		if(!valid || !arrayp(data) || sizeof(data)<2)
			continue;
		requirements[item_name] = (int)requirements[item_name]+amount;
		luck += (int)data[1];
	}
	return luck;
}

private void remove_created_items(array(object) created)
{
	foreach(created,object item){
		if(item)
			destruct(item);
	}
}

mapping(string:mixed) craft_equipment(object player,string skill_name,
	int recipe_id,int amount,int target_level)
{
	mapping(string:mixed) result = (["ok":0,"message":"制作失败。"]);
	mapping(string:int) requirements;
	mapping(string:mixed) consumption;
	array(object) created = ({});
	array(string) created_names = ({});
	array(int) skill;
	array(int) old_skill;
	mapping old_enhancers;
	string item_path;
	int recipe_level;
	int need_level;
	int luck;
	int old_insight;
	int insight;
	int save_ok;
	if(!player || !is_craft_skill(skill_name) || skill_name=="liandan")
		return result;
	initialize_player(player);
	if(amount<1 || amount>NORMAL_BATCH_LIMIT){
		result["message"] = "每次只能制作1至"+(string)NORMAL_BATCH_LIMIT+"件装备。";
		return result;
	}
	if(target_level>0 && amount>MASTER_BATCH_LIMIT){
		result["message"] = "高阶制作每次最多制作"+
			(string)MASTER_BATCH_LIMIT+"件装备。";
		return result;
	}
	skill = player->vice_skills[skill_name];
	if(!arrayp(skill) || sizeof(skill)<3){
		result["message"] = "你还没有学会"+query_skill_name_cn(skill_name)+"。";
		return result;
	}
	if(!has_recipe(player,skill_name,recipe_id)){
		result["message"] = "你尚未学会这张配方。";
		return result;
	}
	item_path = query_recipe_item_path(skill_name,recipe_id);
	recipe_level = query_recipe_item_level(skill_name,recipe_id);
	need_level = query_recipe_need_level(skill_name,recipe_id);
	if(item_path=="" || recipe_level<=0 || need_level<0){
		result["message"] = "配方数据异常，本次没有扣除材料。";
		return result;
	}
	if((int)skill[0]<need_level){
		result["message"] = query_skill_name_cn(skill_name)+"熟练度不足。";
		return result;
	}
	if(target_level>0){
		if(query_master_specialty(player)!=skill_name ||
		   (int)skill[0]<MASTER_LEVEL || recipe_level<65){
			result["message"] = "只有对应大师专精才能把65级以上配方升阶制作。";
			return result;
		}
		if(target_level<80 || target_level%20!=0 ||
		   target_level>player->query_level()){
			result["message"] = "目标等级必须是80级起、每20级一阶，且不能超过人物等级。";
			return result;
		}
	}
	requirements = query_required_materials(skill_name,recipe_id,amount,target_level);
	if(!sizeof(requirements)){
		result["message"] = "配方没有有效材料，本次没有生成制品。";
		return result;
	}
	luck = player->query_lunck()+query_specialty_luck(player,skill_name);
	if(target_level==0)
		luck += query_enhancer_luck(player,skill_name,amount,requirements);
	foreach(indices(requirements),string item_name){
		if(query_material_count(player,item_name)<(int)requirements[item_name]){
			result["message"] = "材料不足："+item_name+"需要"+
				(string)requirements[item_name]+"份。";
			return result;
		}
	}
	old_insight = (int)player["/artisan/insight/"+skill_name];
	insight = old_insight;
	for(int i=0;i<amount;i++){
		object|zero template_item = clone(ITEM_PATH+item_path);
		object|zero item;
		int dynamic_item = 0;
		int generated_level = recipe_level;
		if(target_level>0)
			generated_level = target_level;
		if(!template_item){
			remove_created_items(created);
			result["message"] = "制品模板无法载入，本次没有扣除材料。";
			return result;
		}
		if(target_level>0 || template_item->query_item_from()==""){
			destruct(template_item);
			template_item = 0;
			dynamic_item = 1;
			if(insight>=QUALITY_PITY_LIMIT-1)
				item = ITEMSD->get_convert_item(item_path,4,recipe_level,
					generated_level);
			if(!item)
				item = ITEMSD->dubo_item(generated_level,item_path,luck);
		}
		else
			item = template_item;
		if(!item || player->if_over_load(item)){
			if(item)
				destruct(item);
			remove_created_items(created);
			result["message"] = "包袱空间不足或制品生成失败，本次没有扣除材料。";
			return result;
		}
		item->move(player);
		if(environment(item)!=player){
			if(item)
				destruct(item);
			remove_created_items(created);
			result["message"] = "制品放入包袱失败，本次没有扣除材料。";
			return result;
		}
		if(dynamic_item && functionp(item->set_item_from))
			item->set_item_from("artisan");
		created += ({item});
		created_names += ({item->query_name_cn()});
		if(dynamic_item && functionp(item->query_item_rareLevel) &&
		   (int)item->query_item_rareLevel()>=4)
			insight = 0;
		else if(dynamic_item && insight<QUALITY_PITY_LIMIT)
			insight++;
	}
	consumption = begin_material_consumption(player,requirements);
	if(!(int)consumption["ok"]){
		remove_created_items(created);
		result["message"] = "材料状态已经变化，本次制作已安全取消。";
		return result;
	}
	old_skill = copy_value(skill);
	old_enhancers = copy_value(player->baoshi_add);
	advance_proficiency(player,skill_name,amount);
	player["/artisan/insight/"+skill_name] = insight;
	player->material_m = ([]);
	player->baoshi_add = ([]);
	save_ok = 0;
	if(functionp(player->save_with_result))
		save_ok = player->save_with_result();
	if(!save_ok){
		player->vice_skills[skill_name] = old_skill;
		player["/artisan/insight/"+skill_name] = old_insight;
		player->baoshi_add = old_enhancers;
		remove_created_items(created);
		rollback_material_consumption(player,consumption);
		result["message"] = "人物存档失败，制品与材料变更已经回滚。";
		return result;
	}
	result["ok"] = 1;
	result["message"] = query_skill_name_cn(skill_name)+"成功，获得"+
		(string)amount+"件制品："+(created_names*"、")+"。";
	if((int)old_skill[0]<(int)player->vice_skills[skill_name][0])
		result["message"] += "\n熟练度提高到"+
			(string)player->vice_skills[skill_name][0]+"级。";
	result["items"] = created;
	Stdio.append_file(ROOT+"/log/artisan.log",
		ctime(time())[0..sizeof(ctime(time()))-2]+" user="+
		player->query_name()+" skill="+skill_name+" recipe="+
		(string)recipe_id+" amount="+(string)amount+" target="+
		(string)target_level+"\n");
	return result;
}

mapping(string:mixed) craft_medicine(object player,int recipe_id,int amount)
{
	mapping(string:mixed) result = (["ok":0,"message":"炼制失败。"]);
	mapping(string:int) requirements;
	mapping(string:mixed) consumption;
	array(int) skill;
	array(int) old_skill;
	string item_path;
	object|zero item;
	int need_level;
	int save_ok;
	if(!player)
		return result;
	initialize_player(player);
	if(amount<1 || amount>MEDICINE_BATCH_LIMIT){
		result["message"] = "每炉只能炼制1至"+
			(string)MEDICINE_BATCH_LIMIT+"颗丹药。";
		return result;
	}
	skill = player->vice_skills["liandan"];
	if(!arrayp(skill) || sizeof(skill)<3){
		result["message"] = "你还没有学会炼丹。";
		return result;
	}
	if(!has_recipe(player,"liandan",recipe_id)){
		result["message"] = "你尚未学会这张炼丹配方。";
		return result;
	}
	item_path = query_recipe_item_path("liandan",recipe_id);
	need_level = query_recipe_need_level("liandan",recipe_id);
	if(item_path=="" || need_level<0){
		result["message"] = "炼丹配方数据异常，本次没有扣除材料。";
		return result;
	}
	if((int)skill[0]<need_level){
		result["message"] = "炼丹熟练度不足。";
		return result;
	}
	requirements = query_required_materials("liandan",recipe_id,amount,0);
	if(!sizeof(requirements)){
		result["message"] = "炼丹配方没有有效材料，本次没有生成丹药。";
		return result;
	}
	foreach(indices(requirements),string item_name){
		if(query_material_count(player,item_name)<(int)requirements[item_name]){
			result["message"] = "材料不足："+item_name+"需要"+
				(string)requirements[item_name]+"份。";
			return result;
		}
	}
	item = clone(ITEM_PATH+item_path);
	if(!item){
		result["message"] = "丹药模板无法载入，本次没有扣除材料。";
		return result;
	}
	item->amount = amount;
	item->max_count = MEDICINE_BATCH_LIMIT;
	if(player->if_over_easy_load()){
		destruct(item);
		result["message"] = "包袱空间不足，本次没有扣除材料。";
		return result;
	}
	item->move(player);
	if(environment(item)!=player){
		if(item)
			destruct(item);
		result["message"] = "丹药放入包袱失败，本次没有扣除材料。";
		return result;
	}
	consumption = begin_material_consumption(player,requirements);
	if(!(int)consumption["ok"]){
		destruct(item);
		result["message"] = "材料状态已经变化，本次炼制已安全取消。";
		return result;
	}
	old_skill = copy_value(skill);
	advance_proficiency(player,"liandan",amount);
	player->material_m = ([]);
	save_ok = 0;
	if(functionp(player->save_with_result))
		save_ok = player->save_with_result();
	if(!save_ok){
		player->vice_skills["liandan"] = old_skill;
		if(item)
			destruct(item);
		rollback_material_consumption(player,consumption);
		result["message"] = "人物存档失败，丹药与材料变更已经回滚。";
		return result;
	}
	result["ok"] = 1;
	result["message"] = "炼制成功，获得"+(string)amount+"颗"+
		item->query_name_cn()+"。";
	if((int)old_skill[0]<(int)player->vice_skills["liandan"][0])
		result["message"] += "\n炼丹熟练度提高到"+
			(string)player->vice_skills["liandan"][0]+"级。";
	result["item"] = item;
	Stdio.append_file(ROOT+"/log/artisan.log",
		ctime(time())[0..sizeof(ctime(time()))-2]+" user="+
		player->query_name()+" skill=liandan recipe="+
		(string)recipe_id+" amount="+(string)amount+" target=0\n");
	return result;
}

mapping(string:mixed) deposit_all_materials(object player)
{
	mapping(string:mixed) result = (["ok":0,"amount":0,
		"message":"没有可收纳的百工材料。"]);
	array(mapping(string:mixed)) snapshots = ({});
	array(object) inventory;
	int total = 0;
	int save_ok;
	if(!player)
		return result;
	initialize_player(player);
	inventory = all_inventory(player);
	foreach(inventory,object item){
		mapping(string:mixed) snapshot;
		if(!is_raw_material(item))
			continue;
		snapshot = (["path":(file_name(item)/"#")[0],
			"amount":(int)item->amount,
			"max_count":(int)item->max_count]);
		snapshots += ({snapshot});
		total += store_material_object(player,item);
	}
	if(total<=0)
		return result;
	save_ok = 0;
	if(functionp(player->save_with_result))
		save_ok = player->save_with_result();
	if(!save_ok){
		foreach(snapshots,mapping snapshot){
			object|zero restored = clone((string)snapshot["path"]);
			string item_name;
			if(!restored)
				continue;
			item_name = restored->query_name();
			player["/artisan/materials/"+item_name] =
				(int)player["/artisan/materials/"+item_name]-
				(int)snapshot["amount"];
			if((int)player["/artisan/materials/"+item_name]<=0)
				m_delete((mapping)player["/artisan/materials"],item_name);
			restored->amount = (int)snapshot["amount"];
			restored->max_count = (int)snapshot["max_count"];
			restored->move(player);
		}
		result["message"] = "人物存档失败，材料收纳已经回滚。";
		return result;
	}
	result["ok"] = 1;
	result["amount"] = total;
	result["message"] = "已将"+(string)total+"份百工材料收入材料囊。";
	return result;
}

mapping(string:mixed) withdraw_material(object player,string item_name,int amount)
{
	mapping(string:mixed) result = (["ok":0,"message":"取出材料失败。"]);
	mapping(string:int) materials;
	mapping(string:string) paths;
	object|zero item;
	string path;
	int save_ok;
	if(!player || item_name=="" || search(item_name,"/")!=-1 ||
	   search(item_name,"..")!=-1 || amount<1 || amount>9999)
		return result;
	initialize_player(player);
	materials = player["/artisan/materials"];
	paths = player["/artisan/material_paths"];
	if((int)materials[item_name]<amount){
		result["message"] = "材料囊中的数量不足。";
		return result;
	}
	path = paths[item_name];
	if(path=="")
		path = MATERIAL_ROOT+item_name;
	if(!has_prefix(path,MATERIAL_ROOT)){
		result["message"] = "材料记录异常，本次没有取出任何物品。";
		return result;
	}
	item = clone(path);
	if(!item){
		result["message"] = "材料模板无法载入。";
		return result;
	}
	item->amount = amount;
	item->max_count = 9999;
	// 取出使用独立大堆叠；满包时不依赖 move() 不会执行的自动合并。
	if(player->if_over_easy_load()){
		destruct(item);
		result["message"] = "包袱空间不足。";
		return result;
	}
	item->move(player);
	if(environment(item)!=player){
		if(item)
			destruct(item);
		result["message"] = "材料放入包袱失败。";
		return result;
	}
	materials[item_name] = (int)materials[item_name]-amount;
	if((int)materials[item_name]<=0)
		m_delete(materials,item_name);
	save_ok = 0;
	if(functionp(player->save_with_result))
		save_ok = player->save_with_result();
	if(!save_ok){
		materials[item_name] = (int)materials[item_name]+amount;
		if(item)
			destruct(item);
		result["message"] = "人物存档失败，取出操作已经回滚。";
		return result;
	}
	result["ok"] = 1;
	result["message"] = "已从材料囊取出"+(string)amount+"份"+
		item->query_name_cn()+"。";
	return result;
}
