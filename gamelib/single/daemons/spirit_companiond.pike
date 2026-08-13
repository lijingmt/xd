/**
 * 本命灵伴：按可登录角色独立保存的收集、培养、装备与协战系统。
 *
 * 数据只进入当前角色唯一的.o档案；不读取、不迁移、不复制也不改写
 * 账号共享宠物万灵谱。PVE/PVP使用独立且有上限的协战公式。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define SPIRIT_COMPANION_ROOT "/spirit_companion/record"
#define PET_BATTLE_SOURCE_ROOT "/pet_battle/source"
#define SPIRIT_COMPANION_VERSION 1
#define SPIRIT_COMPANION_LEVEL_MAX MAX_LEVEL
#define SPIRIT_COMPANION_GEAR_MAX 60

private Thread.Mutex spirit_companion_lock = Thread.Mutex();

private array(string) spirit_companion_order = ({
	"qingyuanli","zhufengquan","yunlingque","xingchenlu",
	"yanweihu","shuijinggui","leimingbao","yuelingtu",
});

private array(string) spirit_companion_starters = ({
	"qingyuanli","zhufengquan","yunlingque",
});

private mapping(string:mapping(string:mixed)) spirit_companion_catalog = ([
	"qingyuanli":(["name":"青原狸","icon":"狸","role":"mofa",
		"skill":"青爪引泉","temperament":"沉静亲人，擅长为主人引回灵息",
		"combat":"稳定攻击并回复少量法力"]),
	"zhufengquan":(["name":"逐风犬","icon":"犬","role":"damage",
		"skill":"逐风连咬","temperament":"热情勇敢，总会抢先追上敌人",
		"combat":"出手稍慢但追击伤害更高"]),
	"yunlingque":(["name":"云翎雀","icon":"雀","role":"heal",
		"skill":"云翎回春","temperament":"轻灵好奇，羽光能安抚伤势",
		"combat":"轻灵攻击并回复少量生命"]),
	"xingchenlu":(["name":"星尘鹿","icon":"鹿","role":"mofa",
		"skill":"星河踏","temperament":"温和坚定，踏过之处星辉流转",
		"combat":"稳定攻击并回复少量法力"]),
	"yanweihu":(["name":"焰尾狐","icon":"狐","role":"damage",
		"skill":"焰尾追袭","temperament":"机敏好胜，喜欢寻找敌人的破绽",
		"combat":"出手稍慢但追击伤害更高"]),
	"shuijinggui":(["name":"水镜龟","icon":"龟","role":"heal",
		"skill":"水镜润心","temperament":"从容厚重，水镜能缓和伤痛",
		"combat":"稳健攻击并回复少量生命"]),
	"leimingbao":(["name":"雷鸣豹","icon":"豹","role":"damage",
		"skill":"雷影裂爪","temperament":"迅捷果断，雷声未至利爪先临",
		"combat":"出手稍慢但追击伤害更高"]),
	"yuelingtu":(["name":"月灵兔","icon":"兔","role":"mofa",
		"skill":"月华灵跃","temperament":"活泼聪慧，能收拢散落的灵气",
		"combat":"轻灵攻击并回复少量法力"]),
]);

private mapping(string:mapping(string:mixed)) spirit_gear_slots = ([
	"wind_bell":(["name":"追风铃","desc":"增强灵伴协战伤害"]),
	"heart_knot":(["name":"守心结","desc":"增强灵伴回复效果"]),
	"cloud_pendant":(["name":"云露坠","desc":"兼顾伤害与回复"]),
]);

private mapping(string:string) spirit_material_names = ([
	"companion_food":"同心灵果",
	"craft_shard":"星砂碎片",
	"spirit_thread":"月华灵丝",
]);

private mapping(string:mixed) spirit_result(int ok,string message)
{
	return (["ok":ok,"message":message]);
}

private int valid_spirit_id(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	for(int i=0;i<sizeof(value);i++)
		if(!((value[i]>='0' && value[i]<='9') ||
		   (value[i]>='a' && value[i]<='f')))
			return 0;
	return 1;
}

private int valid_spirit_owner_fields(object player)
{
	return player && functionp(player->query_name) &&
		functionp(player->query_account_owner) &&
		(string)player->query_name()!="" &&
		(string)player->query_account_owner()!="";
}

private int valid_spirit_owner(object player)
{
	if(!valid_spirit_owner_fields(player))
		return 0;
	return ACCOUNT_CHARACTERD->account_owns_character(
		player->query_account_owner(),player->query_name());
}

private int spirit_player_in_combat(object player)
{
	return player && functionp(player->query_in_combat) &&
		player->query_in_combat();
}

private mapping(string:int) empty_spirit_materials()
{
	return (["companion_food":0,"craft_shard":0,"spirit_thread":0]);
}

private mapping(string:mixed) empty_spirit_record(object player)
{
	return ([
		"version":SPIRIT_COMPANION_VERSION,
		"owner_id":player->query_name(),
		"registration_account":player->query_account_owner(),
		"revision":0,
		"pets":({}),
		"active_id":"",
		"materials":empty_spirit_materials(),
		"gear_inventory":({}),
		"explore_progress":0,
		"daily_key":0,
		"daily_interact":0,
		"daily_explore":0,
		"created_at":time(),
		"updated_at":time(),
	]);
}

private int current_spirit_day_key(void|int at_time)
{
	mapping(string:int) now_time = localtime(at_time || time());
	return ((int)now_time["year"])*1000+(int)now_time["yday"];
}

private int spirit_xp_need(int level)
{
	if(level<1)
		level = 1;
	return level*20;
}

/** 培养进度保存在角色档案；战斗与界面只按不超过人物的等级生效。 */
private int spirit_companion_level_limit(void|object player)
{
	int level_max = SPIRIT_COMPANION_LEVEL_MAX;
	if(player && functionp(player->query_level))
		level_max = (int)player->query_level();
	if(level_max<1)
		level_max = 1;
	if(level_max>SPIRIT_COMPANION_LEVEL_MAX)
		level_max = SPIRIT_COMPANION_LEVEL_MAX;
	return level_max;
}

private int find_spirit_pet_index(array pets,string pet_id)
{
	for(int i=0;i<sizeof(pets);i++)
		if(mappingp(pets[i]) && (string)pets[i]["id"]==pet_id)
			return i;
	return -1;
}

private int find_spirit_species_index(array pets,string species)
{
	for(int i=0;i<sizeof(pets);i++)
		if(mappingp(pets[i]) && (string)pets[i]["species"]==species)
			return i;
	return -1;
}

private int find_spirit_gear_index(array gear_inventory,string gear_id)
{
	for(int i=0;i<sizeof(gear_inventory);i++)
		if(mappingp(gear_inventory[i]) &&
		   (string)gear_inventory[i]["id"]==gear_id)
			return i;
	return -1;
}

private string new_spirit_id_unlocked(mapping record)
{
	multiset(string) used = (<>);
	foreach((array)record["pets"],mapping pet)
		used[(string)pet["id"]] = 1;
	foreach((array)record["gear_inventory"],mapping gear)
		used[(string)gear["id"]] = 1;
	for(int attempt=0;attempt<30;attempt++){
		string candidate = String.string2hex(
			Crypto.Random.random_string(32));
		if(!used[candidate])
			return candidate;
	}
	return "";
}

private mapping(string:mixed) make_spirit_pet_unlocked(mapping record,
	string species,string source)
{
	string pet_id = new_spirit_id_unlocked(record);
	if(pet_id=="" || !spirit_companion_catalog[species])
		return ([]);
	return ([
		"id":pet_id,"species":species,"level":1,"xp":0,"bond":1,
		"equipment":([]),"source":source,"acquired_at":time(),
	]);
}

private mapping(string:mixed) make_spirit_gear_unlocked(mapping record,
	string slot,int quality,string source)
{
	array(string) quality_names = ({"","素朴","凝光","星辉","月华"});
	string gear_id = new_spirit_id_unlocked(record);
	if(gear_id=="" || !spirit_gear_slots[slot] ||
	   quality<1 || quality>4)
		return ([]);
	int attack_bonus = slot=="wind_bell" ? quality*2 :
		(slot=="cloud_pendant" ? quality : 0);
	int support_bonus = slot=="heart_knot" ? quality*2 :
		(slot=="cloud_pendant" ? quality : 0);
	return ([
		"id":gear_id,"slot":slot,
		"name":quality_names[quality]+
			(string)spirit_gear_slots[slot]["name"],
		"quality":quality,"attack_bonus":attack_bonus,
		"support_bonus":support_bonus,"source":source,
		"acquired_at":time(),
	]);
}

private int valid_spirit_record_fields(mapping record,object player)
{
	multiset(string) ids = (<>);
	multiset(string) species_seen = (<>);
	multiset(string) gear_ids = (<>);
	multiset(string) equipped = (<>);
	if(!mappingp(record) || !valid_spirit_owner_fields(player) ||
	   (int)record["version"]!=SPIRIT_COMPANION_VERSION ||
	   (string)record["owner_id"]!=(string)player->query_name() ||
	   (string)record["registration_account"]!=
		(string)player->query_account_owner() ||
	   !arrayp(record["pets"]) || !arrayp(record["gear_inventory"]) ||
	   !mappingp(record["materials"]) ||
	   sizeof((array)record["pets"])>sizeof(spirit_companion_catalog) ||
	   sizeof((array)record["gear_inventory"])>SPIRIT_COMPANION_GEAR_MAX ||
	   (int)record["revision"]<0 ||
	   (int)record["explore_progress"]<0 ||
	   (int)record["daily_key"]<0 ||
	   (int)record["daily_interact"]<0 ||
	   (int)record["daily_interact"]>1 ||
	   (int)record["daily_explore"]<0 ||
	   (int)record["daily_explore"]>1)
		return 0;
	foreach((array)record["pets"],mixed raw_pet){
		mapping pet;
		string pet_id;
		string species;
		if(!mappingp(raw_pet))
			return 0;
		pet = raw_pet;
		pet_id = (string)pet["id"];
		species = (string)pet["species"];
		if(!valid_spirit_id(pet_id) || ids[pet_id] ||
		   !spirit_companion_catalog[species] || species_seen[species] ||
		   (int)pet["level"]<1 ||
		   (int)pet["level"]>SPIRIT_COMPANION_LEVEL_MAX ||
		   (int)pet["xp"]<0 || (int)pet["xp"]>1000000 ||
		   (int)pet["bond"]<1 || (int)pet["bond"]>100 ||
		   !mappingp(pet["equipment"]) ||
		   sizeof((mapping)pet["equipment"])>3 ||
		   !stringp(pet["source"]) || (int)pet["acquired_at"]<=0)
			return 0;
		ids[pet_id] = 1;
		species_seen[species] = 1;
	}
	foreach((array)record["gear_inventory"],mixed raw_gear){
		mapping gear;
		string gear_id;
		if(!mappingp(raw_gear))
			return 0;
		gear = raw_gear;
		gear_id = (string)gear["id"];
		if(!valid_spirit_id(gear_id) || ids[gear_id] || gear_ids[gear_id] ||
		   !spirit_gear_slots[(string)gear["slot"]] ||
		   !stringp(gear["name"]) || (int)gear["quality"]<1 ||
		   (int)gear["quality"]>4 || (int)gear["attack_bonus"]<0 ||
		   (int)gear["attack_bonus"]>8 ||
		   (int)gear["support_bonus"]<0 ||
		   (int)gear["support_bonus"]>8 ||
		   !stringp(gear["source"]) || (int)gear["acquired_at"]<=0)
			return 0;
		gear_ids[gear_id] = 1;
	}
	foreach((array)record["pets"],mapping pet)
		foreach((mapping)pet["equipment"];string slot;mixed raw_gear_id){
			string gear_id = (string)raw_gear_id;
			int gear_index = find_spirit_gear_index(
				record["gear_inventory"],gear_id);
			if(!spirit_gear_slots[slot] || !stringp(raw_gear_id) ||
			   gear_index<0 || equipped[gear_id] ||
			   (string)record["gear_inventory"][gear_index]["slot"]!=slot)
				return 0;
			equipped[gear_id] = 1;
		}
	foreach(indices(empty_spirit_materials()),string material)
		if(!intp(record["materials"][material]) ||
		   (int)record["materials"][material]<0 ||
		   (int)record["materials"][material]>1000000000)
			return 0;
	if((string)record["active_id"]!="" &&
	   !ids[(string)record["active_id"]])
		return 0;
	return 1;
}

private int valid_spirit_record(mapping record,object player)
{
	return valid_spirit_owner(player) &&
		valid_spirit_record_fields(record,player);
}

private void refresh_spirit_day_unlocked(mapping record)
{
	int day_key = current_spirit_day_key();
	if((int)record["daily_key"]==day_key)
		return;
	record["daily_key"] = day_key;
	record["daily_interact"] = 0;
	record["daily_explore"] = 0;
}

private void add_spirit_material_unlocked(mapping record,string material,
	int amount)
{
	if(!has_index(spirit_material_names,material) || amount==0)
		return;
	int value = (int)record["materials"][material]+amount;
	if(value<0)
		value = 0;
	if(value>1000000000)
		value = 1000000000;
	record["materials"][material] = value;
}

private void add_spirit_xp_unlocked(mapping pet,int amount,int level_max)
{
	if(level_max<1)
		level_max = 1;
	if(level_max>SPIRIT_COMPANION_LEVEL_MAX)
		level_max = SPIRIT_COMPANION_LEVEL_MAX;
	if(amount<=0 || (int)pet["level"]>=level_max)
		return;
	pet["xp"] = (int)pet["xp"]+amount;
	while((int)pet["level"]<level_max &&
	      (int)pet["xp"]>=spirit_xp_need((int)pet["level"])){
		pet["xp"] = (int)pet["xp"]-
			spirit_xp_need((int)pet["level"]);
		pet["level"] = (int)pet["level"]+1;
	}
	if((int)pet["level"]>=level_max)
		pet["xp"] = 0;
}

private int save_spirit_record(object player,mapping record,
	mapping|zero previous)
{
	int saved = 0;
	mixed err;
	record["updated_at"] = time();
	player[SPIRIT_COMPANION_ROOT] = copy_value(record);
	err = catch{ saved=player->save_with_result(); };
	if(!err && saved)
		return 1;
	if(mappingp(previous))
		player[SPIRIT_COMPANION_ROOT] = copy_value(previous);
	else
		player->m_delete_foruser(SPIRIT_COMPANION_ROOT);
	return 0;
}

private mapping(string:mixed) enrich_spirit_pet(mapping pet,mapping record,
	void|object player)
{
	mapping result = copy_value(pet);
	mapping info = spirit_companion_catalog[(string)pet["species"]];
	int trained_level = (int)pet["level"];
	int level_max = spirit_companion_level_limit(player);
	int effective_level = trained_level;
	int attack_bonus = 0;
	int support_bonus = 0;
	if(effective_level<1)
		effective_level = 1;
	if(effective_level>level_max)
		effective_level = level_max;
	foreach((mapping)pet["equipment"];string slot;mixed gear_id){
		int index = find_spirit_gear_index(record["gear_inventory"],
			(string)gear_id);
		if(index>=0){
			attack_bonus += (int)record["gear_inventory"][index]["attack_bonus"];
			support_bonus +=
				(int)record["gear_inventory"][index]["support_bonus"];
		}
	}
	result += info;
	result["trained_level"] = trained_level;
	result["level"] = effective_level;
	result["level_limited"] = trained_level>effective_level;
	result["level_max"] = level_max;
	result["xp"] = trained_level>=level_max ? 0 : (int)pet["xp"];
	result["xp_need"] = trained_level>=level_max ?
		0 : spirit_xp_need(trained_level);
	result["attack_bonus"] = attack_bonus;
	result["support_bonus"] = support_bonus;
	result["active"] = (string)record["active_id"]==(string)pet["id"];
	return result;
}

mapping(string:mapping(string:mixed)) query_spirit_companion_catalog()
{
	return copy_value(spirit_companion_catalog);
}

array(string) query_spirit_companion_starters()
{
	return copy_value(spirit_companion_starters);
}

mapping(string:string) query_spirit_material_names()
{
	return copy_value(spirit_material_names);
}

mapping(string:mapping(string:mixed)) query_spirit_gear_slots()
{
	return copy_value(spirit_gear_slots);
}

int query_spirit_companion_level_max(void|object player)
{
	return spirit_companion_level_limit(player);
}

/** 每约2种共享宠物提供1%本命共鸣，封顶8%；只读共享图鉴。 */
int query_shared_pet_resonance_bonus(object player)
{
	int collection_count =
		PETD->query_shared_pet_collection_count_read_only(player);
	int bonus = collection_count>0 ? (collection_count+1)/2 : 0;
	if(bonus>8)
		bonus = 8;
	if(player){
		player["/tmp/spirit_companion/shared_resonance_bonus"] = bonus;
		player["/tmp/spirit_companion/shared_resonance_at"] = time();
	}
	return bonus;
}

private int query_cached_shared_pet_resonance_bonus(object player)
{
	if(player &&
	   (int)player["/tmp/spirit_companion/shared_resonance_at"]+60>
		time())
		return (int)player[
			"/tmp/spirit_companion/shared_resonance_bonus"];
	return query_shared_pet_resonance_bonus(player);
}

/** 缺省保持共享宠物，确保所有旧人物升级后战斗表现不变。 */
string query_pet_battle_source(object player)
{
	string source;
	if(!player)
		return "shared";
	source = (string)(player[PET_BATTLE_SOURCE_ROOT] || "shared");
	return source=="personal" ? "personal" : "shared";
}

mapping(string:mixed) set_pet_battle_source(object player,string source)
{
	mapping result = spirit_result(0,"宠物战斗位切换失败。");
	mapping state;
	int ready = 0;
	int saved = 0;
	mixed err;
	mixed previous;
	if(!valid_spirit_owner(player) ||
	   search(({"shared","personal"}),source)==-1)
		return result;
	if(player->query_in_combat && player->query_in_combat())
		return spirit_result(0,"交战中不能更换携带的宠物。");
	if(source=="personal"){
		state = query_spirit_companion_state(player);
		ready = (int)state["ok"] && (int)state["claimed"] &&
			(string)state["active_id"]!="";
		if(!ready)
			return spirit_result(0,"请先在本命灵伴界面选择出战灵伴。");
	}
	else{
		state = PETD->query_pet_state(player);
		ready = (int)state["ok"] &&
			(string)(state["active"][player->query_name()] || "")!="";
		if(!ready)
			return spirit_result(0,"请先在共享宠物界面设置协战宠物。");
	}
	object key = spirit_companion_lock->lock();
	previous = player[PET_BATTLE_SOURCE_ROOT];
	player[PET_BATTLE_SOURCE_ROOT] = source;
	err = catch{ saved=player->save_with_result(); };
	if(err || !saved){
		if(previous)
			player[PET_BATTLE_SOURCE_ROOT] = previous;
		else
			player->m_delete_foruser(PET_BATTLE_SOURCE_ROOT);
		result["message"] = "人物档案保存失败，本次战斗位切换已回滚。";
	}
	else{
		PETD->reset_pet_combat_state(player);
		reset_spirit_companion_combat_state(player);
		result = spirit_result(1,source=="personal" ?
			"当前战斗位已切换为本命灵伴；共享宠物暂停协战。" :
			"当前战斗位已切换为共享宠物；本命灵伴暂停协战。");
		result["source"] = source;
	}
	destruct(key);
	return result;
}

mapping(string:mixed) query_spirit_companion_state(object player)
{
	mapping result = spirit_result(0,"本命灵伴暂不可用。");
	mixed raw_record;
	if(!valid_spirit_owner(player))
		return result;
	raw_record = player[SPIRIT_COMPANION_ROOT];
	if(!raw_record){
		result = spirit_result(1,"当前角色还没有本命灵伴。");
		result["claimed"] = 0;
		result["catalog"] = query_spirit_companion_catalog();
		return result;
	}
	if(!mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		result["message"] =
			"本命灵伴数据校验失败，已停止操作以保护人物档案。";
		return result;
	}
	mapping record = copy_value((mapping)raw_record);
	refresh_spirit_day_unlocked(record);
	result = copy_value(record);
	result["ok"] = 1;
	result["message"] = "";
	result["claimed"] = sizeof((array)record["pets"])>0;
	result["catalog"] = query_spirit_companion_catalog();
	result["material_names"] = query_spirit_material_names();
	result["gear_slots"] = query_spirit_gear_slots();
	result["shared_resonance_bonus"] =
		query_shared_pet_resonance_bonus(player);
	array enriched = ({});
	foreach((array)record["pets"],mapping pet)
		enriched += ({enrich_spirit_pet(pet,record,player)});
	result["pets"] = enriched;
	return result;
}

mapping(string:mixed) choose_spirit_companion(object player,string species)
{
	mapping result = spirit_result(0,"本命初遇没有生效。");
	object key;
	mixed raw_record;
	if(!valid_spirit_owner(player) ||
	   search(spirit_companion_starters,species)==-1)
		return result;
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能缔结或培养本命灵伴。");
	key = spirit_companion_lock->lock();
	raw_record = player[SPIRIT_COMPANION_ROOT];
	if(raw_record){
		result["message"] = mappingp(raw_record) &&
			valid_spirit_record_fields((mapping)raw_record,player) ?
			"这个角色已经完成本命初遇。" :
			"现有本命灵伴数据异常，已停止覆盖。";
		destruct(key);
		return result;
	}
	mapping record = empty_spirit_record(player);
	mapping pet = make_spirit_pet_unlocked(record,species,"starter");
	if(!sizeof(pet)){
		destruct(key);
		return result;
	}
	record["pets"] += ({pet});
	record["active_id"] = pet["id"];
	add_spirit_material_unlocked(record,"companion_food",10);
	add_spirit_material_unlocked(record,"craft_shard",6);
	add_spirit_material_unlocked(record,"spirit_thread",3);
	foreach(indices(spirit_gear_slots),string slot){
		mapping gear = make_spirit_gear_unlocked(record,slot,1,"starter");
		if(sizeof(gear)){
			record["gear_inventory"] += ({gear});
			pet["equipment"][slot] = gear["id"];
		}
	}
	record["revision"] = 1;
	if(!valid_spirit_record(record,player) ||
	   !save_spirit_record(player,record,0))
		result["message"] = "人物档案保存失败，本次初遇已安全回滚。";
	else{
		result = spirit_result(1,(string)spirit_companion_catalog[species]["name"]+
			"与你结下本命契约，并带来一套素朴灵伴装备。");
		result["pet"] = enrich_spirit_pet(pet,record,player);
	}
	destruct(key);
	return result;
}

mapping(string:mixed) set_active_spirit_companion(object player,string pet_id)
{
	mapping result = spirit_result(0,"本命灵伴切换失败。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能切换出战本命灵伴。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	if(find_spirit_pet_index(record["pets"],pet_id)<0){
		result["message"] = "本命图鉴中没有这位灵伴。";
		destruct(key);
		return result;
	}
	record["active_id"] = pet_id;
	record["revision"] = (int)record["revision"]+1;
	if(save_spirit_record(player,record,previous)){
		reset_spirit_companion_combat_state(player);
		result = spirit_result(1,"出战本命灵伴已经切换。");
	}
	else
		result["message"] = "人物档案保存失败，本次切换已回滚。";
	destruct(key);
	return result;
}

mapping(string:mixed) interact_spirit_companion(object player)
{
	mapping result = spirit_result(0,"今日陪伴没有生效。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能陪伴或培养本命灵伴。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	refresh_spirit_day_unlocked(record);
	if((int)record["daily_interact"]){
		result["message"] = "今天已经陪伴过本命灵伴了。";
		destruct(key);
		return result;
	}
	int pet_index = find_spirit_pet_index(record["pets"],
		(string)record["active_id"]);
	if(pet_index<0){
		destruct(key);
		return result;
	}
	record["daily_interact"] = 1;
	record["pets"][pet_index]["bond"] =
		(int)record["pets"][pet_index]["bond"]+1;
	if((int)record["pets"][pet_index]["bond"]>100)
		record["pets"][pet_index]["bond"] = 100;
	int level_max = spirit_companion_level_limit(player);
	int can_grow = (int)record["pets"][pet_index]["level"]<level_max;
	add_spirit_xp_unlocked(record["pets"][pet_index],10,level_max);
	add_spirit_material_unlocked(record,"companion_food",2);
	record["revision"] = (int)record["revision"]+1;
	if(save_spirit_record(player,record,previous))
		result = spirit_result(1,can_grow ?
			"陪伴完成：灵伴成长10点，并获得2枚同心灵果。" :
			"陪伴完成：灵伴已与当前人物等级同步，未囤积溢出成长；获得2枚同心灵果。");
	else
		result["message"] = "人物档案保存失败，本次陪伴已回滚。";
	destruct(key);
	return result;
}

mapping(string:mixed) explore_spirit_companion(object player)
{
	mapping result = spirit_result(0,"灵境寻踪没有生效。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能进行灵境寻踪。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	refresh_spirit_day_unlocked(record);
	if((int)record["daily_explore"]){
		result["message"] = "今天已经完成灵境寻踪了。";
		destruct(key);
		return result;
	}
	record["daily_explore"] = 1;
	record["explore_progress"] = (int)record["explore_progress"]+1;
	add_spirit_material_unlocked(record,"craft_shard",2);
	add_spirit_material_unlocked(record,"spirit_thread",1);
	string discovered = "";
	if((int)record["explore_progress"]%3==0)
		foreach(spirit_companion_order,string species)
			if(find_spirit_species_index(record["pets"],species)<0){
				mapping pet = make_spirit_pet_unlocked(record,species,"explore");
				if(sizeof(pet)){
					record["pets"] += ({pet});
					discovered = species;
				}
				break;
			}
	record["revision"] = (int)record["revision"]+1;
	if(save_spirit_record(player,record,previous)){
		result = spirit_result(1,"寻踪完成：获得2枚星砂碎片与1缕月华灵丝。"+
			(discovered!="" ? " 新灵伴"+
			(string)spirit_companion_catalog[discovered]["name"]+
			"加入了本命图鉴！" : " 再坚持寻踪即可遇见新的灵伴。"));
		result["discovered"] = discovered;
	}
	else
		result["message"] = "人物档案保存失败，本次寻踪已回滚。";
	destruct(key);
	return result;
}

mapping(string:mixed) feed_spirit_companion(object player,string pet_id)
{
	mapping result = spirit_result(0,"灵果喂养没有生效。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能喂养或培养本命灵伴。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	int pet_index = find_spirit_pet_index(record["pets"],pet_id);
	int level_max = spirit_companion_level_limit(player);
	if(pet_index<0)
		result["message"] = "本命图鉴中没有这位灵伴。";
	else if((int)record["pets"][pet_index]["level"]>=
	   level_max)
		result["message"] = (int)record["pets"][pet_index]["level"]>
			level_max ? "这位灵伴的培养进度已保留至Lv."+
			(int)record["pets"][pet_index]["level"]+
			"；当前角色只按Lv."+level_max+"生效。" :
			"这位灵伴已与当前人物Lv."+level_max+
			"同步；人物升级后才能继续喂养。";
	else if((int)record["materials"]["companion_food"]<5)
		result["message"] = "喂养需要5枚同心灵果。";
	else{
		add_spirit_material_unlocked(record,"companion_food",-5);
		add_spirit_xp_unlocked(record["pets"][pet_index],20,level_max);
		record["revision"] = (int)record["revision"]+1;
		if(save_spirit_record(player,record,previous))
			result = spirit_result(1,"喂养完成，灵伴成长20点。");
		else
			result["message"] = "人物档案保存失败，本次喂养已回滚。";
	}
	destruct(key);
	return result;
}

mapping(string:mixed) forge_spirit_gear(object player,string slot)
{
	mapping result = spirit_result(0,"灵伴装备打造没有生效。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能打造灵伴装备。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player) ||
	   !spirit_gear_slots[slot]){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	if(sizeof((array)record["gear_inventory"])>=SPIRIT_COMPANION_GEAR_MAX)
		result["message"] = "灵伴装备栏已满，请先分解不用的装备。";
	else if((int)record["materials"]["craft_shard"]<5 ||
	   (int)record["materials"]["spirit_thread"]<2)
		result["message"] = "打造需要5枚星砂碎片与2缕月华灵丝。";
	else{
		int quality_roll = random(100);
		int quality = quality_roll<50 ? 1 :
			(quality_roll<80 ? 2 : (quality_roll<95 ? 3 : 4));
		mapping gear = make_spirit_gear_unlocked(record,slot,quality,"forge");
		if(sizeof(gear)){
			add_spirit_material_unlocked(record,"craft_shard",-5);
			add_spirit_material_unlocked(record,"spirit_thread",-2);
			record["gear_inventory"] += ({gear});
			record["revision"] = (int)record["revision"]+1;
			if(save_spirit_record(player,record,previous)){
				result = spirit_result(1,"打造成功："+(string)gear["name"]+"。");
				result["gear"] = copy_value(gear);
			}
			else
				result["message"] = "人物档案保存失败，本次打造已回滚。";
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) equip_spirit_gear(object player,string pet_id,
	string gear_id)
{
	mapping result = spirit_result(0,"灵伴装备穿戴失败。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能更换灵伴装备。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	int pet_index = find_spirit_pet_index(record["pets"],pet_id);
	int gear_index = find_spirit_gear_index(record["gear_inventory"],gear_id);
	if(pet_index<0 || gear_index<0)
		result["message"] = "灵伴或装备已经不存在。";
	else{
		foreach((array)record["pets"],mapping pet)
			foreach((mapping)pet["equipment"];string slot;mixed equipped_id)
				if((string)equipped_id==gear_id &&
				   (string)pet["id"]!=pet_id){
					result["message"] = "这件装备正由另一位灵伴穿戴。";
					destruct(key);
					return result;
				}
		string slot = (string)record["gear_inventory"][gear_index]["slot"];
		record["pets"][pet_index]["equipment"][slot] = gear_id;
		record["revision"] = (int)record["revision"]+1;
		if(save_spirit_record(player,record,previous))
			result = spirit_result(1,"灵伴装备已经穿戴。 ");
		else
			result["message"] = "人物档案保存失败，本次穿戴已回滚。";
	}
	destruct(key);
	return result;
}

mapping(string:mixed) unequip_spirit_gear(object player,string pet_id,
	string slot)
{
	mapping result = spirit_result(0,"灵伴装备卸下失败。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能更换灵伴装备。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player) ||
	   !spirit_gear_slots[slot]){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	int pet_index = find_spirit_pet_index(record["pets"],pet_id);
	if(pet_index<0 || !record["pets"][pet_index]["equipment"][slot])
		result["message"] = "这个槽位没有穿戴装备。";
	else{
		m_delete(record["pets"][pet_index]["equipment"],slot);
		record["revision"] = (int)record["revision"]+1;
		if(save_spirit_record(player,record,previous))
			result = spirit_result(1,"灵伴装备已经卸下。 ");
		else
			result["message"] = "人物档案保存失败，本次卸下已回滚。";
	}
	destruct(key);
	return result;
}

mapping(string:mixed) dismantle_spirit_gear(object player,string gear_id)
{
	mapping result = spirit_result(0,"灵伴装备分解失败。");
	if(spirit_player_in_combat(player))
		return spirit_result(0,"交战中不能分解灵伴装备。");
	object key = spirit_companion_lock->lock();
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!valid_spirit_owner(player) || !mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	int gear_index = find_spirit_gear_index(record["gear_inventory"],gear_id);
	if(gear_index<0)
		result["message"] = "这件灵伴装备已经不存在。";
	else{
		foreach((array)record["pets"],mapping pet)
			foreach((mapping)pet["equipment"];string slot;mixed equipped_id)
				if((string)equipped_id==gear_id){
					result["message"] = "请先从灵伴身上卸下这件装备。";
					destruct(key);
					return result;
				}
		mapping gear = record["gear_inventory"][gear_index];
		record["gear_inventory"] -= ({gear});
		add_spirit_material_unlocked(record,"craft_shard",
			1+(int)gear["quality"]);
		record["revision"] = (int)record["revision"]+1;
		if(save_spirit_record(player,record,previous))
			result = spirit_result(1,"装备已分解为星砂碎片。 ");
		else
			result["message"] = "人物档案保存失败，本次分解已回滚。";
	}
	destruct(key);
	return result;
}

private mapping(string:mixed)|zero query_active_spirit_combat_pet(
	object player)
{
	mixed raw_record = player && player[SPIRIT_COMPANION_ROOT];
	if(!mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player))
		return 0;
	int pet_index = find_spirit_pet_index(raw_record["pets"],
		(string)raw_record["active_id"]);
	if(pet_index<0)
		return 0;
	mapping pet = raw_record["pets"][pet_index];
	if(!spirit_companion_catalog[(string)pet["species"]] ||
	   (int)pet["level"]<1 ||
	   (int)pet["level"]>SPIRIT_COMPANION_LEVEL_MAX ||
	   !mappingp(pet["equipment"]))
		return 0;
	return enrich_spirit_pet(pet,raw_record,player);
}

private string query_spirit_role_label(string role)
{
	if(role=="damage")
		return "强攻";
	if(role=="heal")
		return "疗愈";
	return "灵息";
}

private int apply_spirit_heal_reduction(object player,int amount)
{
	if(player && player->query_debuff("curse",0)=="life"){
		int heal_reduce = (int)player->query_debuff("curse",1);
		if(heal_reduce<0)
			heal_reduce = 0;
		if(heal_reduce>90)
			heal_reduce = 90;
		amount = amount*(100-heal_reduce)/100;
	}
	return amount;
}

/** Vue Header/战斗窗的轻量快照；只读人物当前内存档案。 */
mapping(string:mixed) query_spirit_companion_presence(object player)
{
	mapping result = ([
		"active":0,"battle_active":0,"system":"personal",
		"system_label":"本命","command":"spirit_companion",
	]);
	mapping|zero pet = query_active_spirit_combat_pet(player);
	if(!pet)
		return result;
	string role = (string)pet["role"];
	int battle_active = query_pet_battle_source(player)=="personal";
	int pvp = battle_active &&
		(string)(player["/tmp/spirit_companion/pvp_target"] || "")!="";
	int cooldown = role=="damage" ? 8 : 6;
	int ready_at = pvp ?
		(int)player["/tmp/spirit_companion/pvp_at"] :
		(int)player["/tmp/spirit_companion/combat_at"];
	int remaining = ready_at-time();
	if(remaining<0)
		remaining = 0;
	int power = (int)pet["level"]*100+(int)pet["bond"]*10+
		((int)pet["attack_bonus"]+(int)pet["support_bonus"])*20;
	result = ([
		"active":1,"battle_active":battle_active,
		"system":"personal","system_label":"本命",
		"command":"spirit_companion","pet_id":pet["id"],
		"species":pet["species"],"name":pet["name"],
		"icon":pet["icon"],"family":"灵",
		"role":query_spirit_role_label(role),"skill":pet["skill"],
		"native_skill":pet["skill"],"level":pet["level"],
		"bond":pet["bond"],"star":0,"evolution":0,
		"evolution_name":"本命契约","power":power,
		"combat_mode":pvp ? "pvp" : "pve",
		"cooldown":cooldown,"cooldown_remaining":remaining,
		"ready_at":ready_at,"pvp_charge":pvp ? cooldown-remaining : 0,
		"pvp_charge_required":cooldown,
		"pvp_uses":(int)player["/tmp/spirit_companion/pvp_uses"],
		"pvp_uses_max":2,
		"shared_resonance_bonus":
			query_cached_shared_pet_resonance_bonus(player),
	]);
	if(mappingp(player["/tmp/spirit_companion/recent_assist"])){
		mapping recent = player["/tmp/spirit_companion/recent_assist"];
		int event_at = (int)recent["event_at"];
		if(event_at>0 && event_at<=time()+1 && time()-event_at<=10)
			result["recent_event"] = copy_value(recent);
	}
	return result;
}

/** 快速决胜只读模拟：与真实PVP共用两次上限与安全倍率。 */
mapping(string:mixed) query_spirit_companion_pk_fast_profile(object player,
	object target)
{
	mapping result = (["active":0]);
	if(query_pet_battle_source(player)!="personal" || !player || !target ||
	   !target->is || !target->is("player") ||
	   environment(player)!=environment(target))
		return result;
	mapping|zero pet = query_active_spirit_combat_pet(player);
	if(!pet)
		return result;
	int uses = (int)player["/tmp/spirit_companion/pvp_uses"];
	if(uses<0)
		uses = 0;
	if(uses>2)
		uses = 2;
	string role = (string)pet["role"];
	int required = role=="damage" ? 8 : 6;
	int amount = player->query_base_damage()/20+
		player->query_level()*(int)pet["level"]/5;
	int resonance_bonus = query_cached_shared_pet_resonance_bonus(player);
	amount = amount/2;
	if(role=="damage")
		amount = amount*5/4;
	else if(role=="heal")
		amount = amount*4/5;
	amount = amount*(100+(int)pet["attack_bonus"])/100;
	amount = amount*(100+resonance_bonus)/100;
	int cap = target->query_life_max()/200;
	if(cap<1)
		cap = 1;
	if(amount<1)
		amount = 1;
	if(amount>cap)
		amount = cap;
	int ready_at = (int)player["/tmp/spirit_companion/pvp_at"];
	int remaining = ready_at-time();
	if(remaining<0)
		remaining = 0;
	if(remaining>required)
		remaining = required;
	int charge = required-remaining;
	if(charge>=required)
		charge = required-1;
	result = ([
		"active":1,"type":"damage","amount":amount,
		"remaining_uses":2-uses,"charge_required":required,
		"charge":charge,"system":"personal",
	]);
	if(role=="heal"){
		int recovery = player->query_life_max()/400;
		recovery = apply_spirit_heal_reduction(player,recovery);
		recovery = recovery*(100+(int)pet["support_bonus"]+
			resonance_bonus)/100;
		result["secondary_type"] = "heal";
		result["secondary_amount"] = recovery;
	}
	else if(role=="mofa"){
		int recovery = player->query_mofa_max()/400;
		recovery = recovery*(100+(int)pet["support_bonus"]+
			resonance_bonus)/100;
		result["secondary_type"] = "mofa";
		result["secondary_amount"] = recovery;
	}
	return result;
}

mapping(string:mixed) perform_spirit_companion_combat_assist(object player,
	object target)
{
	mapping result = (["ok":0,"type":"none","amount":0]);
	object target_owner;
	mapping|zero pet;
	int pvp = 0;
	int now;
	int uses = 0;
	if(query_pet_battle_source(player)!="personal" ||
	   !player || !target || !player->is || !player->is("player") ||
	   !target->is || player->get_cur_life()<=0 ||
	   target->get_cur_life()<=1 ||
	   environment(player)!=environment(target) ||
	   !LOGICALZONED->can_action("combat",player,target))
		return result;
	target_owner = target->is("player") ? target :
		SUMMOND->query_combat_credit_owner(target);
	if(target_owner && target_owner->is && target_owner->is("player")){
		if(target_owner==player ||
		   environment(target_owner)!=environment(player) ||
		   !player->query_in_combat || !player->query_in_combat() ||
		   !target_owner->query_in_combat ||
		   !target_owner->query_in_combat())
			return result;
		if(player->query_enemy){
			object active_target = player->query_enemy();
			object active_owner = active_target &&
				active_target->is("player") ? active_target :
				SUMMOND->query_combat_credit_owner(active_target);
			if(active_owner!=target_owner)
				return result;
		}
		pvp = 1;
	}
	else if(!target->is("npc") || target_owner!=target)
		return result;
	pet = query_active_spirit_combat_pet(player);
	if(!pet)
		return result;
	now = time();
	int cooldown = (string)pet["role"]=="damage" ? 8 : 6;
	if(pvp){
		string target_id = target_owner->query_name();
		if((string)(player["/tmp/spirit_companion/pvp_target"] || "")!=
		   target_id)
			player["/tmp/spirit_companion/pvp_target"] = target_id;
		uses = (int)player["/tmp/spirit_companion/pvp_uses"];
		if(uses>=2 || (int)player["/tmp/spirit_companion/pvp_at"]>now)
			return result;
	}
	else if((int)player["/tmp/spirit_companion/combat_at"]>now)
		return result;
	int amount = player->query_base_damage()/20+
		player->query_level()*(int)pet["level"]/5;
	int resonance_bonus = query_cached_shared_pet_resonance_bonus(player);
	if(pvp)
		amount = amount/2;
	if((string)pet["role"]=="damage")
		amount = amount*5/4;
	else if((string)pet["role"]=="heal")
		amount = amount*4/5;
	amount = amount*(100+(int)pet["attack_bonus"])/100;
	amount = amount*(100+resonance_bonus)/100;
	int cap = target->query_life_max()/(pvp ? 200 : 100);
	if(cap<1)
		cap = 1;
	if(amount>cap)
		amount = cap;
	if(amount<1)
		amount = 1;
	int actual = amount;
	if(actual>=target->get_cur_life())
		actual = target->get_cur_life()-1;
	if(actual<=0)
		return result;
	target->set_life(target->get_cur_life()-actual);
	target->flush_targets(player,actual);
	player->flush_targets(target,actual);
	int restored = 0;
	if((string)pet["role"]=="mofa"){
		int before = player->get_cur_mofa();
		int after = before+player->query_mofa_max()/(pvp ? 400 : 200);
		after = before+(after-before)*(100+(int)pet["support_bonus"]+
			resonance_bonus)/100;
		if(after>player->query_mofa_max())
			after = player->query_mofa_max();
		if(after>before){ player->set_mofa(after); restored=after-before; }
	}
	else if((string)pet["role"]=="heal"){
		int before = player->get_cur_life();
		int recovery = player->query_life_max()/(pvp ? 400 : 200);
		recovery = apply_spirit_heal_reduction(player,recovery);
		int after = before+recovery;
		after = before+(after-before)*(100+(int)pet["support_bonus"]+
			resonance_bonus)/100;
		if(after>player->query_life_max())
			after = player->query_life_max();
		if(after>before){ player->set_life(after); restored=after-before; }
	}
	if(pvp){
		player["/tmp/spirit_companion/pvp_at"] = now+cooldown;
		player["/tmp/spirit_companion/pvp_uses"] = uses+1;
	}
	else
		player["/tmp/spirit_companion/combat_at"] = now+cooldown;
	int event_seq = (int)player["/tmp/spirit_companion/assist_seq"]+1;
	player["/tmp/spirit_companion/assist_seq"] = event_seq;
	string target_name = target->query_name();
	if(functionp(target->query_name_cn) && target->query_name_cn()!="")
		target_name = target->query_name_cn();
	mapping event = ([
		"id":sprintf("%s-%d-%d-%d",player->query_name(),now,
			event_seq,random(1000000)),
		"event_at":now,"pet_id":pet["id"],"species":pet["species"],
		"name":pet["name"],"icon":pet["icon"],"family":"灵",
		"role":query_spirit_role_label((string)pet["role"]),
		"skill":pet["skill"],"native_skill":pet["skill"],
		"mode":pvp ? "pvp" : "pve","type":"damage",
		"amount":actual,"restored":restored,
		"secondary_type":restored>0 ?
			((string)pet["role"]=="mofa" ? "mofa" : "heal") : "",
		"secondary_amount":restored,
		"shared_resonance_bonus":resonance_bonus,
		"target_name":target_name,"cooldown":cooldown,
		"ready_at":now+cooldown,"level":pet["level"],
		"star":0,"evolution_name":"本命契约",
	]);
	player["/tmp/spirit_companion/recent_assist"] = copy_value(event);
	result = (["ok":1,"type":"damage","amount":actual,
		"restored":restored,"mode":pvp ? "pvp" : "pve",
		"shared_resonance_bonus":resonance_bonus,
		"uses":pvp ? uses+1 : 0,"pet_id":pet["id"],
		"pet_name":pet["name"],"skill_name":pet["skill"],
		"event":copy_value(event)]);
	string message = "【本命灵伴·"+(string)pet["name"]+"·"+
		(string)pet["skill"]+"】造成"+actual+"点协战伤害";
	if(restored>0)
		message += (string)pet["role"]=="mofa" ?
			"，并回复"+restored+"点法力" :
			"，并回复"+restored+"点生命";
	if(pvp)
		message += "（本场"+(uses+1)+"/2）";
	tell_object(player,message+"。\n");
	if(pvp)
		tell_object(target_owner,"【本命灵伴交锋】"+
			player->query_name_cn()+"的"+(string)pet["name"]+
			"施展了"+(string)pet["skill"]+"。\n");
	DAILYGOALD->record_pet_assist(player);
	return result;
}

mapping(string:mixed) record_spirit_companion_combat_xp(object player,
	object npc)
{
	mapping result = (["ok":0,"xp_gain":0,"levels_gained":0]);
	mapping credited;
	if(query_pet_battle_source(player)!="personal" || !player || !npc ||
	   !npc->is || !npc->is("npc") ||
	   SUMMOND->query_combat_credit_owner(npc)!=npc ||
	   player->query_level()-npc->query_level()>5)
		return result;
	object key = spirit_companion_lock->lock();
	mixed raw_record = player[SPIRIT_COMPANION_ROOT];
	if(!mappingp(raw_record) ||
	   !valid_spirit_record_fields((mapping)raw_record,player)){
		destruct(key);
		return result;
	}
	mapping previous = copy_value((mapping)raw_record);
	mapping record = copy_value(previous);
	int pet_index = find_spirit_pet_index(record["pets"],
		(string)record["active_id"]);
	int level_max = spirit_companion_level_limit(player);
	credited = mappingp(npc["/tmp/spirit_companion/xp_pet_ids"]) ?
		npc["/tmp/spirit_companion/xp_pet_ids"] : ([]);
	if(pet_index>=0 &&
	   !credited[(string)record["pets"][pet_index]["id"]] &&
	   (int)record["pets"][pet_index]["level"]<
		level_max){
		int old_level = (int)record["pets"][pet_index]["level"];
		int xp_gain = 5+npc->query_level()/5;
		if(xp_gain>40)
			xp_gain = 40;
		add_spirit_xp_unlocked(record["pets"][pet_index],xp_gain,
			level_max);
		record["revision"] = (int)record["revision"]+1;
		if(save_spirit_record(player,record,previous)){
			credited[(string)record["pets"][pet_index]["id"]] = 1;
			npc["/tmp/spirit_companion/xp_pet_ids"] = credited;
			result["ok"] = 1;
			result["xp_gain"] = xp_gain;
			result["levels_gained"] =
				(int)record["pets"][pet_index]["level"]-old_level;
			if((int)result["levels_gained"]>0)
				tell_object(player,"【本命灵伴成长】"+
					(string)spirit_companion_catalog[(string)record["pets"][
					pet_index]["species"]]["name"]+"升至Lv."+
					(int)record["pets"][pet_index]["level"]+"。\n");
		}
	}
	destruct(key);
	return result;
}

void reset_spirit_companion_combat_state(object player)
{
	if(!player)
		return;
	player["/tmp/spirit_companion/combat_at"] = 0;
	player["/tmp/spirit_companion/pvp_target"] = 0;
	player["/tmp/spirit_companion/pvp_uses"] = 0;
	player["/tmp/spirit_companion/pvp_at"] = 0;
}

void remove_test_spirit_companion_data(object player)
{
	if(!player || search((string)player->query_name(),"testunit")==-1)
		return;
	player->m_delete_foruser(SPIRIT_COMPANION_ROOT);
}
