#include <globals.h>
//需要被存储的，去掉private字段,测试阶段可以好好看看
//比如这个attack_power是然木剑的攻击力,这样游戏世界
//中所有然木剑生成的object都具有这个属性，没必要存储起来
//除非属于该物品装备状态的特殊属性是会变化，而且需要存储，比如磨损程度等
private int attack_power=0;//武器伤害基础值
int query_attack_power(){ return scale_newmoon_collection_base(attack_power);}
void set_attack_power(int a){ attack_power=a;}

private int attack_power_limit=0;//武器伤害上限值
int query_attack_power_limit(){ return scale_newmoon_collection_base(attack_power_limit);}
void set_attack_power_limit(int a){ attack_power_limit=a;}

private int speed_power=0;//武器攻击速度,可能会变化，需要存储
int query_speed_power(){ return speed_power;}
void set_speed_power(int a){ speed_power=a;}

private int equip_defend=0;//防具的防御力
int query_equip_defend(){ return scale_newmoon_collection_base(equip_defend)+
	(query_defend_add()==0?0:query_defend_add());}
void set_equip_defend(int a){ equip_defend=a;}

// 新月装备职业共鸣使用既有 dbase 扩展区保存，不能在这里新增顶层
// 持久化变量。旧装备序列化依赖继承布局；新增顶层字段会让历史档案
// 的 equiped 等字段错位。没有共鸣数据的全部旧装备始终返回 0 加成。
#define NEWMOON_RESONANCE_ROOT "/item_newmoon/resonance"
#define NEWMOON_BINDING_ROOT "/item_newmoon/binding"

int is_newmoon_collection_id(string collection_id)
{
	return search(({
		"newmoon","starshine","firmament","greatvoid","primordial",
		"huanji",
	}),collection_id)!=-1;
}

string query_newmoon_collection_id()
{
	if(query_newmoon_resonance_profession()=="")
		return "";
	string collection_id=(string)(this_object()[
		NEWMOON_RESONANCE_ROOT+"/collection/id"] || "");
	return is_newmoon_collection_id(collection_id) ? collection_id : "newmoon";
}

int query_newmoon_collection_rank()
{
	switch(query_newmoon_collection_id()){
		case "starshine": return 2;
		case "firmament": return 3;
		case "greatvoid": return 4;
		case "primordial": return 5;
		case "huanji": return 6;
	}
	return 1;
}

string query_newmoon_collection_name()
{
	switch(query_newmoon_collection_id()){
		case "starshine": return "曜星";
		case "firmament": return "天穹";
		case "greatvoid": return "太虚";
		case "primordial": return "太初";
		case "huanji": return "寰极";
	}
	return "新月";
}

string query_newmoon_collection_quality()
{
	switch(query_newmoon_collection_id()){
		case "starshine": return "绝世";
		case "firmament": return "传说";
		case "greatvoid": return "神话";
		case "primordial": return "太古";
		case "huanji": return "至尊";
	}
	return "稀世";
}

int query_newmoon_collection_quality_percent()
{
	switch(query_newmoon_collection_id()){
		case "starshine": return 105;
		case "firmament": return 110;
		case "greatvoid": return 116;
		case "primordial": return 123;
		case "huanji": return 132;
	}
	return 100;
}

int scale_newmoon_collection_base(int value)
{
	if(value<=0 || query_newmoon_resonance_profession()=="")
		return value;
	// 套装本体是极稀有长期追求物。只把这件装备自身的白板攻防
	// 提高到旧模板的200%，再叠加六套既有品质系数；普通装备、
	// 随机词缀、强化值与2/4/6/8/10件奖励公式都不经过这里。
	return value*2*query_newmoon_collection_quality_percent()/100;
}

int set_newmoon_collection(string collection_id)
{
	if(query_newmoon_resonance_profession()=="" ||
	   !is_newmoon_collection_id(collection_id))
		return 0;
	this_object()[NEWMOON_RESONANCE_ROOT+"/collection/id"]=collection_id;
	return 1;
}

mapping(string:mixed) query_newmoon_storage_collection_snapshot()
{
	if(query_newmoon_resonance_profession()=="" ||
	   query_newmoon_collection_id()=="newmoon")
		return ([]);
	return (["version":1,"collection_id":query_newmoon_collection_id()]);
}

int restore_newmoon_storage_collection_snapshot(mapping snapshot)
{
	if(!mappingp(snapshot) || sizeof(snapshot)!=2 ||
	   (int)snapshot["version"]!=1 ||
	   !stringp(snapshot["collection_id"]))
		return 0;
	return set_newmoon_collection((string)snapshot["collection_id"]);
}

int is_newmoon_binding_owner(string owner)
{
	int test_owner;
	if(!owner || sizeof(owner)<2 || sizeof(owner)>64)
		return 0;
	test_owner=has_prefix(owner,"__testunit_") && has_suffix(owner,"__");
	for(int index=0;index<sizeof(owner);index++){
		int one=owner[index];
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || (test_owner && one=='_'))
			continue;
		return 0;
	}
	return 1;
}

int is_newmoon_binding_id(string binding_id)
{
	if(!binding_id || sizeof(binding_id)!=64)
		return 0;
	for(int index=0;index<sizeof(binding_id);index++){
		int one=binding_id[index];
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

int is_newmoon_binding_reason(string reason)
{
	return search(({
		"equip","legacy_equip","reforge","socket","artisan",
		"pity","choice","compensation",
	}),reason)!=-1;
}

int query_newmoon_account_bound()
{
	return query_newmoon_resonance_profession()!="" &&
		query_newmoon_account_bind_owner()!="";
}

string query_newmoon_account_bind_owner()
{
	return (string)(this_object()[NEWMOON_BINDING_ROOT+"/owner"] || "");
}

string query_newmoon_account_bind_reason()
{
	return (string)(this_object()[NEWMOON_BINDING_ROOT+"/reason"] || "");
}

int query_newmoon_account_bind_time()
{
	return (int)this_object()[NEWMOON_BINDING_ROOT+"/time"];
}

string query_newmoon_account_bind_id()
{
	return (string)(this_object()[NEWMOON_BINDING_ROOT+"/id"] || "");
}

int query_newmoon_binding_matches_owner(object owner)
{
	string expected_owner="";
	if(!owner || !functionp(owner->is) || !owner->is("player") ||
	   !query_newmoon_account_bound())
		return 0;
	if(functionp(owner->query_account_owner))
		expected_owner=(string)owner->query_account_owner();
	if(expected_owner=="" && functionp(owner->query_name))
		expected_owner=(string)owner->query_name();
	return expected_owner!="" &&
		query_newmoon_account_bind_owner()==expected_owner;
}

/**
 * Bind one concrete New Moon equipment instance. State lives in dbase so the
 * historical equipment save-field layout is unchanged. Existing bindings are
 * immutable and idempotent only for the same registered account.
 */
int apply_newmoon_account_binding(string owner,string reason,int bound_at,
	string binding_id)
{
	string current_owner;
	if(query_newmoon_resonance_profession()=="" ||
	   !is_newmoon_binding_owner(owner) ||
	   !is_newmoon_binding_reason(reason) || bound_at<=0 ||
	   !is_newmoon_binding_id(binding_id))
		return 0;
	current_owner=query_newmoon_account_bind_owner();
	if(current_owner!=""){
		if(current_owner!=owner)
			return 0;
		return 1;
	}
	this_object()[NEWMOON_BINDING_ROOT+"/owner"]=owner;
	this_object()[NEWMOON_BINDING_ROOT+"/reason"]=reason;
	this_object()[NEWMOON_BINDING_ROOT+"/time"]=bound_at;
	this_object()[NEWMOON_BINDING_ROOT+"/id"]=binding_id;
	return 1;
}

/** Only used before an initial binding has been persisted successfully. */
int rollback_newmoon_account_binding(string owner,string binding_id)
{
	if(!query_newmoon_account_bound() ||
	   query_newmoon_account_bind_owner()!=owner ||
	   query_newmoon_account_bind_id()!=binding_id)
		return 0;
	this_object()->m_delete_foruser(NEWMOON_BINDING_ROOT);
	return 1;
}

mapping(string:mixed) query_newmoon_storage_binding_snapshot()
{
	if(!query_newmoon_account_bound())
		return ([]);
	return ([
		"version":1,
		"owner":query_newmoon_account_bind_owner(),
		"reason":query_newmoon_account_bind_reason(),
		"bound_at":query_newmoon_account_bind_time(),
		"binding_id":query_newmoon_account_bind_id(),
	]);
}

int restore_newmoon_storage_binding_snapshot(mapping snapshot)
{
	if(!mappingp(snapshot) || sizeof(snapshot)!=5 ||
	   (int)snapshot["version"]!=1 || !stringp(snapshot["owner"]) ||
	   !stringp(snapshot["reason"]) || !intp(snapshot["bound_at"]) ||
	   !stringp(snapshot["binding_id"]))
		return 0;
	return apply_newmoon_account_binding((string)snapshot["owner"],
		(string)snapshot["reason"],(int)snapshot["bound_at"],
		(string)snapshot["binding_id"]);
}

int is_newmoon_supported_set_attribute(string attribute)
{
	array(string) supported_set_attributes=({
		"all","defend","dodge","hitte","doub",
		"lunck","rase_life_add","rase_mofa_add","mofa_all",
		"all_mofa_defend",
	});
	return search(supported_set_attributes,attribute)!=-1;
}

int is_newmoon_supported_set_tier(int tier)
{
	return search(({2,4,6,8,10}),tier)!=-1;
}

int is_newmoon_supported_profession(string profession)
{
	return search(({
		"jianxian","yushi","zhuxian","kuangyao","wuyao",
		"yinggui","fangshi","zhenyue","tianxiang","lingyi",
		"wuxiang","taiji","zhaoming","wuji",
	}),profession)!=-1;
}

void set_newmoon_set_bonus(int tier,string attribute,int value)
{
	string tier_path;
	if(!is_newmoon_supported_set_tier(tier) ||
	   !is_newmoon_supported_set_attribute(attribute))
		return;
	tier_path=NEWMOON_RESONANCE_ROOT+"/tier/"+(string)tier;
	this_object()[tier_path+"/attribute"]=attribute;
	this_object()[tier_path+"/value"]=max(0,min(20,value));
}

void set_newmoon_full_set_bonuses(string profession)
{
	if(profession=="jianxian"){
		set_newmoon_set_bonus(6,"dodge",1);
		set_newmoon_set_bonus(8,"rase_life_add",1);
		set_newmoon_set_bonus(10,"all",1);
	}
	else if(profession=="yushi"){
		set_newmoon_set_bonus(6,"all_mofa_defend",2);
		set_newmoon_set_bonus(8,"lunck",1);
		set_newmoon_set_bonus(10,"all",1);
	}
	else if(profession=="zhuxian"){
		set_newmoon_set_bonus(6,"dodge",1);
		set_newmoon_set_bonus(8,"lunck",1);
		set_newmoon_set_bonus(10,"rase_life_add",1);
	}
	else if(profession=="kuangyao"){
		set_newmoon_set_bonus(6,"defend",1);
		set_newmoon_set_bonus(8,"hitte",1);
		set_newmoon_set_bonus(10,"all",1);
	}
	else if(profession=="wuyao"){
		set_newmoon_set_bonus(6,"rase_mofa_add",1);
		set_newmoon_set_bonus(8,"lunck",1);
		set_newmoon_set_bonus(10,"all",1);
	}
	else if(profession=="yinggui"){
		set_newmoon_set_bonus(6,"hitte",1);
		set_newmoon_set_bonus(8,"lunck",1);
		set_newmoon_set_bonus(10,"rase_life_add",1);
	}
	else if(profession=="fangshi"){
		set_newmoon_set_bonus(6,"all_mofa_defend",2);
		set_newmoon_set_bonus(8,"rase_mofa_add",1);
		set_newmoon_set_bonus(10,"lunck",1);
	}
	else if(profession=="zhenyue"){
		set_newmoon_set_bonus(6,"rase_life_add",1);
		set_newmoon_set_bonus(8,"hitte",1);
		set_newmoon_set_bonus(10,"all",1);
	}
	else if(profession=="tianxiang"){
		set_newmoon_set_bonus(6,"all_mofa_defend",2);
		set_newmoon_set_bonus(8,"rase_mofa_add",1);
		set_newmoon_set_bonus(10,"all",1);
	}
	else if(profession=="lingyi"){
		set_newmoon_set_bonus(6,"all_mofa_defend",2);
		set_newmoon_set_bonus(8,"lunck",1);
		set_newmoon_set_bonus(10,"all",1);
	}
	else if(profession=="wuxiang"){
		set_newmoon_set_bonus(6,"hitte",1);
		set_newmoon_set_bonus(8,"doub",1);
		set_newmoon_set_bonus(10,"rase_life_add",1);
	}
	else if(profession=="taiji"){
		set_newmoon_set_bonus(6,"defend",1);
		set_newmoon_set_bonus(8,"rase_life_add",1);
		set_newmoon_set_bonus(10,"rase_mofa_add",1);
	}
	else if(profession=="zhaoming"){
		set_newmoon_set_bonus(6,"doub",2);
		set_newmoon_set_bonus(8,"rase_life_add",2);
		set_newmoon_set_bonus(10,"all",2);
	}
}

void set_newmoon_resonance(string profession,string profession_cn,
	string theme,int str_bonus,int dex_bonus,int think_bonus,
	int life_bonus,int mofa_bonus,string two_piece_attribute,
	int two_piece_value,string four_piece_attribute,
	int four_piece_value)
{
	if(!profession || profession=="" || !profession_cn ||
	   profession_cn=="" || !theme || theme=="" ||
	   !is_newmoon_supported_profession(profession))
		return;
	if(!is_newmoon_supported_set_attribute(two_piece_attribute) ||
	   !is_newmoon_supported_set_attribute(four_piece_attribute))
		return;
	this_object()[NEWMOON_RESONANCE_ROOT+"/profession"]=profession;
	this_object()[NEWMOON_RESONANCE_ROOT+"/profession_cn"]=profession_cn;
	this_object()[NEWMOON_RESONANCE_ROOT+"/theme"]=theme;
	this_object()[NEWMOON_RESONANCE_ROOT+"/str"]=max(0,min(20,str_bonus));
	this_object()[NEWMOON_RESONANCE_ROOT+"/dex"]=max(0,min(20,dex_bonus));
	this_object()[NEWMOON_RESONANCE_ROOT+"/think"]=max(0,min(20,think_bonus));
	this_object()[NEWMOON_RESONANCE_ROOT+"/life"]=max(0,min(20,life_bonus));
	this_object()[NEWMOON_RESONANCE_ROOT+"/mofa"]=max(0,min(20,mofa_bonus));
	set_newmoon_set_bonus(2,two_piece_attribute,two_piece_value);
	set_newmoon_set_bonus(4,four_piece_attribute,four_piece_value);
	set_newmoon_full_set_bonuses(profession);
}

string query_newmoon_resonance_profession()
{
	return (string)(this_object()[NEWMOON_RESONANCE_ROOT+"/profession"] || "");
}

string query_newmoon_resonance_profession_cn()
{
	return (string)(this_object()[NEWMOON_RESONANCE_ROOT+"/profession_cn"] || "");
}

string query_newmoon_resonance_theme()
{
	return (string)(this_object()[NEWMOON_RESONANCE_ROOT+"/theme"] || "");
}

string query_newmoon_set_name()
{
	string profession_cn=query_newmoon_resonance_profession_cn();
	string theme=query_newmoon_resonance_theme();
	if(profession_cn=="" || theme=="")
		return "";
	return query_newmoon_collection_name()+"·"+
		query_newmoon_collection_quality()+"·"+profession_cn+"·"+theme;
}

int query_newmoon_set_piece_count()
{
	object owner=environment(this_object());
	string profession=query_newmoon_resonance_profession();
	string theme=query_newmoon_resonance_theme();
	string collection_id=query_newmoon_collection_id();
	int count=0;
	array(object) counted=({});
	mapping(string:int) counted_slots=([]);
	if(profession=="" || theme=="" || !owner ||
	   !functionp(owner->query_equip))
		return 0;
	mapping equipped=owner->query_equip();
	if(!mappingp(equipped))
		return 0;
	foreach(values(equipped),object item){
		string slot=item && functionp(item->query_item_kind) ?
			(string)item->query_item_kind() : "";
		if(item && environment(item)==owner && item->equiped &&
		   item->item_cur_dura>0 && slot!="" && !counted_slots[slot] &&
		   search(counted,item)==-1 &&
		   functionp(item->query_newmoon_binding_matches_owner) &&
		   item->query_newmoon_binding_matches_owner(owner) &&
		   functionp(item->query_newmoon_resonance_profession) &&
		   functionp(item->query_newmoon_resonance_theme) &&
		   functionp(item->query_newmoon_collection_id) &&
		   item->query_newmoon_resonance_profession()==profession &&
		   item->query_newmoon_resonance_theme()==theme &&
		   item->query_newmoon_collection_id()==collection_id){
			count++;
			counted+=({item});
			counted_slots[slot]=1;
		}
	}
	return min(10,count);
}

int query_newmoon_resonance_percent()
{
	int count=query_newmoon_set_piece_count();
	if(count>=10)
		return 200;
	if(count>=8)
		return 180;
	if(count>=6)
		return 160;
	if(count>=4)
		return 140;
	if(count>=2)
		return 120;
	return 100;
}

int query_newmoon_resonance_active()
{
	object owner=environment(this_object());
	string profession=query_newmoon_resonance_profession();
	string slot=functionp(this_object()->query_item_kind) ?
		(string)this_object()->query_item_kind() : "";
	if(profession=="" || !owner ||
	   this_object()->item_cur_dura<=0 ||
	   !functionp(owner->is) || !owner->is("player") ||
	   !query_newmoon_binding_matches_owner(owner) ||
	   !functionp(owner->query_profeId) ||
	   !functionp(owner->query_equip))
		return 0;
	mapping equipped=owner->query_equip();
	if(!mappingp(equipped) || slot=="" || equipped[slot]!=this_object())
		return 0;
	return (string)owner->query_profeId()==profession;
}

/* 分阶套装加成读取期增强（2026-09-01玩家反馈：4/6/8/10档过于鸡肋）。
 * 按仓库"读取时折算"先例（共鸣×100同款）：旧存量与新掉落存档里
 * 都还是模板小值，统一在此放大，无需迁移任何玩家物品。
 * 2件全属性×2；4件法抗×3；6件命中×2；8件暴击×2；10件回血×5。 */
int query_newmoon_set_tier_boost(int tier)
{
	switch(tier){
		case 2: return 2;
		case 4: return 3;
		case 6: return 2;
		case 8: return 2;
		case 10: return 5;
	}
	return 1;
}

int query_newmoon_set_extra_value(string attribute)
{
	int count;
	int value=0;
	array(int) tiers=({2,4,6,8,10});
	if(!query_newmoon_resonance_active())
		return 0;
	count=query_newmoon_set_piece_count();
	for(int index=0;index<sizeof(tiers);index++){
		string tier_path=NEWMOON_RESONANCE_ROOT+"/tier/"+
			(string)tiers[index];
		if(count>=tiers[index] && (string)this_object()[
		   tier_path+"/attribute"]==attribute)
			value+=(int)this_object()[tier_path+"/value"]*
				query_newmoon_set_tier_boost(tiers[index]);
	}
	// 数值整备：分阶词条保持模板精确传递（幸运/抗性等utility词条
	// 不做件数保底），仅上限从40放宽到2000；核心属性的强化由
	// query_newmoon_resonance_value 的×100系数承担。
	return max(0,min(2000,value));
}

string query_newmoon_set_extra_description(int tier)
{
	string attribute;
	int value;
	string label="";
	string tier_path;
	if(!is_newmoon_supported_set_tier(tier))
		return "";
	tier_path=NEWMOON_RESONANCE_ROOT+"/tier/"+(string)tier;
	attribute=(string)(this_object()[tier_path+"/attribute"] || "");
	value=(int)this_object()[tier_path+"/value"]*
		query_newmoon_set_tier_boost(tier);
	if(attribute=="all") label="全属性";
	else if(attribute=="defend"){
		label="防御";
		value*=10;
	}
	else if(attribute=="dodge") label="闪避率";
	else if(attribute=="hitte") label="命中率";
	else if(attribute=="doub") label="暴击率";
	else if(attribute=="lunck") label="幸运";
	else if(attribute=="rase_life_add") label="每秒生命恢复";
	else if(attribute=="rase_mofa_add") label="每秒法力恢复";
	else if(attribute=="mofa_all") label="全系法术伤害";
	else if(attribute=="all_mofa_defend") label="全法术抗性";
	if(label=="" || value<=0)
		return "";
	if(search(({"dodge","hitte","doub"}),
	   attribute)!=-1)
		return "每件已穿套装"+label+"+"+(string)value+"%";
	return "每件已穿套装"+label+"+"+(string)value;
}

int query_newmoon_resonance_value(string attribute)
{
	int base_value;
	if(!query_newmoon_resonance_active() ||
	   search(({"str","dex","think","life","mofa"}),attribute)==-1)
		return 0;
	base_value=max(0,min(20,(int)this_object()[
		NEWMOON_RESONANCE_ROOT+"/"+attribute]));
	// 这五项是每件装备自己的职业契合属性，不是分阶套装奖励。
	// 旧实例仍保存原模板值，在读取时统一折算，无需迁移玩家档案。
	// 数值整备：系数×2→×100，让套装回到与新装备（几千/条）同量级，
	// 不再是鸡肋属性；百分比类套装词条不参与该放大。
	// 共鸣等级缩放：×level/69使玩家攻击随等级增长跟上怪物防御，
	// 封顶15倍基础共鸣（69级=1x，999级≈14.5x）防止属性爆炸。
	// 全等级模拟确认普通怪1-5击、Boss入门约7击到高等级数百击。
	int level_scale=100;
	if(functionp(query_item_canLevel)){
		int lv=max(1,(int)query_item_canLevel());
		if(lv>69)
			level_scale=min(lv*100/69,1500);  // cap at 15x
	}
	return base_value*100*
		query_newmoon_resonance_percent()/100*
		level_scale/100;
}

string query_newmoon_resonance_bonus_text()
{
	array(string) bonuses=({});
	int active=query_newmoon_resonance_active();
	int value;
	value=active ? query_newmoon_resonance_value("str") :
		(int)this_object()[NEWMOON_RESONANCE_ROOT+"/str"]*2;
	if(value>0) bonuses+=({"力量+"+(string)value});
	value=active ? query_newmoon_resonance_value("dex") :
		(int)this_object()[NEWMOON_RESONANCE_ROOT+"/dex"]*2;
	if(value>0) bonuses+=({"敏捷+"+(string)value});
	value=active ? query_newmoon_resonance_value("think") :
		(int)this_object()[NEWMOON_RESONANCE_ROOT+"/think"]*2;
	if(value>0) bonuses+=({"智力+"+(string)value});
	value=active ? query_newmoon_resonance_value("life") :
		(int)this_object()[NEWMOON_RESONANCE_ROOT+"/life"]*2;
	if(value>0) bonuses+=({"生命+"+(string)(value*10)});
	value=active ? query_newmoon_resonance_value("mofa") :
		(int)this_object()[NEWMOON_RESONANCE_ROOT+"/mofa"]*2;
	if(value>0) bonuses+=({"法力+"+(string)(value*10)});
	return bonuses*"、";
}

private int str_add=0;//物品附带力量增加属性
int query_str_add(){ return str_add+query_newmoon_resonance_value("str");}
void set_str_add(int a){ str_add=a;}

private int dex_add=0;//物品附带敏捷增加属性
int query_dex_add(){ return dex_add+query_newmoon_resonance_value("dex");}
void set_dex_add(int a){ dex_add=a;}

private int think_add=0;//物品附带智力增加属性
int query_think_add(){ return think_add+query_newmoon_resonance_value("think");}
void set_think_add(int a){ think_add=a;}

private int life_add=0;//生命附加
int query_life_add(){ return (life_add+query_newmoon_resonance_value("life"))*10;}
void set_life_add(int a){ life_add=a;}

private int mofa_add=0;//法力附加
int query_mofa_add(){ return (mofa_add+query_newmoon_resonance_value("mofa"))*10;}
void set_mofa_add(int a){ mofa_add=a;}

private int lunck_add=0;//幸运附加
int query_lunck_add(){ return lunck_add+query_newmoon_set_extra_value("lunck");}
void set_lunck_add(int a){ lunck_add=a;}

private int appear_add=0;//容貌附加
int query_appear_add(){ return appear_add;}
void set_appear_add(int a){ appear_add=a;}

//附加攻击，防御，闪避，命中，暴击属性
private int attack_add=0;//附加攻击
int query_attack_add(){ return attack_add;}
void set_attack_add(int a){ attack_add=a;}

private int defend_add=0;//附加防御
int query_defend_add(){ return (defend_add+query_newmoon_set_extra_value("defend"))*10;}
void set_defend_add(int a){ defend_add=a;}

private int dodge_add=0;//附加闪避
int query_dodge_add(){ return dodge_add+query_newmoon_set_extra_value("dodge");}
void set_dodge_add(int a){ dodge_add=a;}

private int hitte_add=0;//附加命中
int query_hitte_add(){ return hitte_add+query_newmoon_set_extra_value("hitte");}
void set_hitte_add(int a){ hitte_add=a;}

private int doub_add=0;//附加暴击
int query_doub_add(){ return doub_add+query_newmoon_set_extra_value("doub");}
void set_doub_add(int a){ doub_add=a;}
//新属性2024//////////////////////////////////
private int wulichuantou_add=0;//物理穿透转为有上限的无视防御伤害
int query_wulichuantou_add(){ return wulichuantou_add;}
void set_wulichuantou_add(int a){ wulichuantou_add=a;}

private int mofachuantou_add=0;//法术穿透转为有上限的无视防御伤害
int query_mofachuantou_add(){ return mofachuantou_add;}
void set_mofachuantou_add(int a){ mofachuantou_add=a;}

private int dodgechuantou_add=0;//闪避穿透按千分点保存，10点等于1%
/* 封顶600千分点（60%），与物理穿透同规三端一致。 */
int query_dodgechuantou_add(){ return min(600,dodgechuantou_add);}
void set_dodgechuantou_add(int a){ dodgechuantou_add=a;}

//新属性0121//////////////////////////////////
private int all_add=0;//物品附加全属性
int query_all_add(){ return all_add+query_newmoon_set_extra_value("all");}
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
int query_rase_life_add(){ return rase_life_add+
	query_newmoon_set_extra_value("rase_life_add");}
void set_rase_life_add(int a){ rase_life_add=a;}

private int rase_mofa_add=0;//物品附加法力恢复增加
int query_rase_mofa_add(){ return rase_mofa_add+
	query_newmoon_set_extra_value("rase_mofa_add");}
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
int query_mofa_all_add(){ return mofa_all_add+
	query_newmoon_set_extra_value("mofa_all");}
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
int query_all_mofa_defend_add(){ return all_mofa_defend_add+
	query_newmoon_set_extra_value("all_mofa_defend");}
void set_all_mofa_defend_add(int a){ all_mofa_defend_add=a;}

//新属性0121//////////////////////////////////
int equiped;//是否装备了该物品

// 追赶装备状态放进既有 dbase 数据树，不新增顶层持久化变量。
// Pike 9 的旧物品序列化器按继承布局读取顶层变量；在 equiped 后插入
// 新变量会把历史 equiped=1 错写成 catchup_equipment=1，导致下次登录
// 把普通装备误判为未激活追赶装并全部卸下。
#define CATCHUP_DATA_ROOT "/item_catchup"

int query_catchup_program_identity()
{
	string path = file_name(this_object());
	if(search(path,"#")!=-1)
		path = (path/"#")[0];
	return path==ROOT+"/gamelib/clone/item/catchup/zhuixingjia" ||
		path==ROOT+"/gamelib/clone/item/catchup/zhuixingjie" ||
		path==ROOT+"/gamelib/clone/item/catchup/zhuixingpei";
}

void set_catchup_equipment(int price,int max_level)
{
	if(!query_catchup_program_identity())
		return;
	this_object()[CATCHUP_DATA_ROOT+"/activation_price"]=max(0,price);
	this_object()[CATCHUP_DATA_ROOT+"/max_level"]=max(1,max_level);
}

int query_catchup_equipment(){ return query_catchup_program_identity(); }
int query_catchup_activated()
{
	return (int)this_object()[CATCHUP_DATA_ROOT+"/activated"];
}
int query_catchup_activation_price()
{
	int price=(int)this_object()[CATCHUP_DATA_ROOT+"/activation_price"];
	return price>0 ? price : (query_catchup_equipment() ? 100 : 0);
}
int query_catchup_max_level()
{
	int max_level=(int)this_object()[CATCHUP_DATA_ROOT+"/max_level"];
	return max_level>0 ? max_level : (query_catchup_equipment() ? 89 : 0);
}
string query_catchup_owner()
{
	return (string)(this_object()[CATCHUP_DATA_ROOT+"/owner"] || "");
}

mixed query_legacy_catchup_saved_value(string saved,string field)
{
	if(!saved || !field)
		return 0;
	foreach(saved/"\n",string line){
		string name;
		string encoded;
		if(sscanf(line,"%s %s",name,encoded)==2 && name==field){
			mixed value;
			mixed err=catch{ value=pikenv_decode_value(encoded); };
			if(!err)
				return value;
		}
	}
	return 0;
}

// 在通用反序列化之前剥离短暂版本的顶层字段。玩家若在故障版本中
// 反复登录，原 equiped=1 会依次移入后续 catchup_* 字段；真正的追赶
// 装备还可能把字符串 owner 错写到整型 renxing，必须先清理再恢复。
mapping(string:mixed) prepare_legacy_catchup_serialization(string saved)
{
	array(string) legacy_fields=({
		"catchup_equipment","catchup_activated",
		"catchup_activation_price","catchup_max_level","catchup_owner",
	});
	mapping(string:mixed) values=([]);
	array(string) cleaned=({});
	mixed shifted_owner=0;
	foreach((saved || "")/"\n",string line){
		string name;
		string encoded;
		if(sscanf(line,"%s %s",name,encoded)==2){
			if(search(legacy_fields,name)!=-1){
				mixed value;
				mixed err=catch{ value=pikenv_decode_value(encoded); };
				if(!err)
					values[name]=value;
				continue;
			}
			if(query_catchup_equipment() && name=="renxing"){
				mixed value;
				mixed err=catch{ value=pikenv_decode_value(encoded); };
				if(!err && stringp(value)){
					shifted_owner=value;
					continue;
				}
			}
		}
		cleaned+=({line});
	}
	mixed legacy_owner=values["catchup_owner"];
	if(!stringp(legacy_owner) && stringp(shifted_owner))
		legacy_owner=shifted_owner;
	int legacy_marker=0;
	foreach(legacy_fields,string field)
		if(intp(values[field]) && (int)values[field]==1)
			legacy_marker=1;
	return ([
		"saved":cleaned*"\n",
		"restore_equiped":!query_catchup_equipment() &&
			legacy_marker && (int)query_legacy_catchup_saved_value(
				saved,"equiped")!=1,
		"activated":query_catchup_equipment() &&
			((int)values["catchup_activated"]==1 ||
			 (int)values["catchup_activation_price"]==1),
		"owner":legacy_owner,
	]);
}

int apply_legacy_catchup_serialization(mapping(string:mixed) state,
	void|object owner)
{
	if(!mappingp(state))
		return 0;
	if(!query_catchup_equipment() && (int)state["restore_equiped"]){
		equiped=1;
		return 1;
	}
	// 真正的追赶装备迁移到 dbase；角色名必须与当前档案一致，不能
	// 接受被编辑的跨角色绑定状态。
	mixed legacy_owner=state["owner"];
	if(query_catchup_equipment() && (int)state["activated"]==1 &&
	   stringp(legacy_owner) && (string)legacy_owner!="" && owner &&
	   (string)legacy_owner==(string)owner->query_name()){
		this_object()[CATCHUP_DATA_ROOT+"/activated"]=1;
		this_object()[CATCHUP_DATA_ROOT+"/owner"]=(string)legacy_owner;
	}
	return 0;
}

int restore_legacy_catchup_serialization(string saved,void|object owner)
{
	return apply_legacy_catchup_serialization(
		prepare_legacy_catchup_serialization(saved),owner);
}

int activate_catchup_equipment(object player)
{
	if(!query_catchup_equipment() || !player || !player->is("player") ||
	   query_catchup_activated() || query_catchup_owner()!="")
		return 0;
	this_object()[CATCHUP_DATA_ROOT+"/owner"]=(string)player->query_name();
	this_object()[CATCHUP_DATA_ROOT+"/activated"]=1;
	return 1;
}

// 只供购买事务在人物原子存档失败时原地回滚，不能用于玩家操作。
int rollback_catchup_activation(object player)
{
	if(!query_catchup_equipment() || !player ||
	   !query_catchup_activated() ||
	   query_catchup_owner()!=(string)player->query_name())
		return 0;
	this_object()[CATCHUP_DATA_ROOT+"/activated"]=0;
	this_object()[CATCHUP_DATA_ROOT+"/owner"]="";
	return 1;
}

int query_catchup_can_equip(object player)
{
	if(!query_catchup_equipment())
		return 1;
	if(!player || !player->is("player") || !query_catchup_activated() ||
	   query_catchup_owner()=="" ||
	   query_catchup_owner()!=(string)player->query_name())
		return 0;
	if(query_catchup_max_level()>0 &&
	   player->query_level()>query_catchup_max_level())
		return 0;
	return 1;
}

// 追赶装只辅助 PVE。若当前对手是玩家或玩家召唤物，所有覆写过的
// 属性 getter 返回 0；这不会触碰既有战斗公式，也不会影响普通装备。
int query_catchup_effect_enabled(void|object player)
{
	array(object) targets=({});
	if(!player)
		player=environment(this_object());
	if(!query_catchup_can_equip(player))
		return 0;
	if(!equiped || !player->query_in_combat())
		return 1;
	if(functionp(player->get_all_targets))
		targets=player->get_all_targets() || ({});
	if(functionp(player->query_enemy) && player->query_enemy() &&
	   search(targets,player->query_enemy())==-1)
		targets+=({player->query_enemy()});
	// 不能只看当前主目标：混战时主目标可能是NPC，但仇恨表里已有玩家。
	// 玩家召唤物即使主人暂时不在find_player缓存，也仍按PVP处理。
	foreach(targets,object target){
		if(!target)
			continue;
		if(target->is && target->is("player"))
			return 0;
		if(target->query_master && (string)target->query_master()!="")
			return 0;
	}
	return 1;
}

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
array(string) query_item_profeLimit(){
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"fangshi")==-1)
		item_profeLimit += ({"fangshi"});
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"zhenyue")==-1)
		item_profeLimit += ({"zhenyue"});
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"tianxiang")==-1)
		item_profeLimit += ({"tianxiang"});
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"lingyi")==-1)
		item_profeLimit += ({"lingyi"});
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"wuxiang")==-1)
		item_profeLimit += ({"wuxiang"});
	// 太极与照命同批进入自动白名单：查询侧统一补齐，任何带职业
	// 限制的装备（含全部历史存量文件）即时可穿可显示，玩家曾反馈
	// 所有装备都没有太极和照命。
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"taiji")==-1)
		item_profeLimit += ({"taiji"});
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"zhaoming")==-1)
		item_profeLimit += ({"zhaoming"});
	// 无极为中立终极隐藏职业，同批进白名单。
	if(sizeof(item_profeLimit) &&
	   search(item_profeLimit,"wuji")==-1)
		item_profeLimit += ({"wuji"});
	return item_profeLimit;
}

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
	int current_attack_power=query_attack_power();
	int current_attack_power_limit=query_attack_power_limit();
	if(current_attack_power_limit<current_attack_power)
		current_attack_power_limit=current_attack_power;
	return current_attack_power+
		random(current_attack_power_limit-current_attack_power+1);
}
//装备的磨损计算
void reduce_power(int power){
	object ob=this_object();
	if(ob->item_canDura){
		if(ob->item_dura>=10000 || random(100)<99)
			return;
		ob->item_cur_dura-=power;
		if(ob->item_cur_dura<0)
			ob->item_cur_dura=0;
	}
}
string query_content(){
	string r="";
	object ob=this_object();
	array(string) profe_limits = ob->query_item_profeLimit();
	if(!ob->is_equip())
		return r;
	if(ob->query_newmoon_resonance_profession()!=""){
		int resonance_active=ob->query_newmoon_resonance_active();
		r+="【"+ob->query_newmoon_collection_name()+"共鸣·"+
			ob->query_newmoon_resonance_theme()+"】"+
			ob->query_newmoon_resonance_profession_cn()+"契合\n";
		r+="【套装品质】"+ob->query_newmoon_collection_quality()+
			"（"+(string)ob->query_newmoon_collection_rank()+"阶）\n";
		if(ob->query_newmoon_account_bound())
			r+="【账号绑定】同注册账号共享仓库可用；不可赠送、交易或拍卖；可由本人在背包中二次确认销毁\n";
		else
			r+="【未绑定】可自由交易；首次穿戴、炼化或镶嵌后账号绑定\n";
		r+=(resonance_active ? "已激活：" :
			"职业契合且穿戴后激活：")+
			ob->query_newmoon_resonance_bonus_text()+"\n";
		int set_count=ob->query_newmoon_set_piece_count();
		r+="【套装·"+ob->query_newmoon_set_name()+"】("+
			(string)set_count+"/10)\n";
		r+="2件·初月：职业共鸣120%；"+
			ob->query_newmoon_set_extra_description(2)+
			(resonance_active && set_count>=2 ? "（已激活）" : "")+"\n";
		r+="4件·弦月：职业共鸣140%；"+
			ob->query_newmoon_set_extra_description(4)+
			(resonance_active && set_count>=4 ? "（已激活）" : "")+"\n";
		r+="6件·望月：职业共鸣160%；"+
			ob->query_newmoon_set_extra_description(6)+
			(resonance_active && set_count>=6 ? "（已激活）" : "")+"\n";
		r+="8件·盈月：职业共鸣180%；"+
			ob->query_newmoon_set_extra_description(8)+
			(resonance_active && set_count>=8 ? "（已激活）" : "")+"\n";
		r+="10件·满月觉醒：职业共鸣200%；"+
			ob->query_newmoon_set_extra_description(10)+
			(resonance_active && set_count>=10 ? "（已激活）" : "")+"\n";
		if(resonance_active && set_count>=10){
			object set_skill_daemon=(object)(ROOT+
				"/gamelib/single/daemons/newmoon_set_skilld.pike");
			string set_skill_summary=set_skill_daemon ?
				(string)set_skill_daemon->query_active_skill_summary(
					environment(ob)) : "";
			if(set_skill_summary!="")
				r+="【满月套装技】"+set_skill_summary+
					"已自动激活，可在技能、快捷栏和自动连招中配置\n";
		}
		else
			r+="【满月套装技】完整穿戴同职业、同主题、同品质十件后自动激活\n";
	}
	if(functionp(ob->query_catchup_equipment) &&
	   ob->query_catchup_equipment()){
		if(ob->query_catchup_activated())
			r += "(追赶装备：已绑定激活，限"+
				ob->query_catchup_max_level()+"级及以下PVE使用)\n";
		else
			r += "(追赶装备：未激活，需"+
				ob->query_catchup_activation_price()+
				"碎玉；激活前不能装备)\n";
	}
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
	if(ob->wulichuantou_add) r+="全物理穿透 "+ob->wulichuantou_add+"点\n";
	if(ob->mofachuantou_add) r+="全法术穿透 "+ob->mofachuantou_add+"点\n";
	if(ob->query_dodgechuantou_add()) r+="闪避穿透 "+
		sprintf("%0.2f",(float)min(600,ob->dodgechuantou_add)/10.0)+"%\n";

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
	if(profe_limits&&sizeof(profe_limits)){
		r+="要求职业：";
		for(int i=0; i<sizeof(profe_limits); i++){
			if(profe_limits[i]&&sizeof(profe_limits[i]))
				r+=this_player()->query_profe_cn(profe_limits[i])+" ";
		}
		r+="\n";
	}
	r+="--------\n";
	// 装备对比参考：同槽位已穿装备的关键属性差值。
	{
		object viewer=this_player();
		object current;
		mapping equipped;
		string kind;
		if(viewer && functionp(viewer->is) && viewer->is("player") &&
		   !ob["equiped"] && functionp(ob->query_item_kind)){
			kind=(string)ob->query_item_kind();
			equipped=functionp(viewer->query_equip) ?
				(mapping)viewer->query_equip() : 0;
			current=mappingp(equipped) && objectp(equipped[kind]) ?
				(object)equipped[kind] : 0;
			if(current){
				r+="〖与当前装备对比〗"+(string)current->query_name_cn()+"\n";
				if(functionp(ob->query_attack_power)){
					int new_atk=(int)ob->query_attack_power();
					int cur_atk=(int)current->query_attack_power();
					if(new_atk||cur_atk){
						r+="攻击："+cur_atk+" → "+new_atk+
							(new_atk>cur_atk?" (+"+(new_atk-cur_atk)+")":
							 new_atk<cur_atk?" ("+(new_atk-cur_atk)+")":" (=)")+"\n";
					}
				}
				if(functionp(ob->query_equip_defend)){
					int new_def=(int)ob->query_equip_defend();
					int cur_def=(int)current->query_equip_defend();
					if(new_def||cur_def){
						r+="防御："+cur_def+" → "+new_def+
							(new_def>cur_def?" (+"+(new_def-cur_def)+")":
							 new_def<cur_def?" ("+(new_def-cur_def)+")":" (=)")+"\n";
					}
				}
				// 三维属性对比
				foreach(({"str_add","dex_add","think_add"}),
					string attr){
					int new_v=(int)ob[attr];
					int cur_v=(int)current[attr];
					if(new_v||cur_v){
						string label=attr=="str_add"?"力量":
							attr=="dex_add"?"敏捷":"智力";
						r+=label+"："+cur_v+" → "+new_v+
							(new_v>cur_v?" (+"+(new_v-cur_v)+")":"")+"\n";
					}
				}
				if(functionp(ob->query_life_add)){
					int new_life=(int)ob->query_life_add();
					int cur_life=(int)current->query_life_add();
					if(new_life||cur_life){
						r+="生命："+cur_life+" → "+new_life+
							(new_life>cur_life?" (+"+(new_life-cur_life)+")":
							 new_life<cur_life?" ("+(new_life-cur_life)+")":" (=)")+"\n";
					}
				}
			}
		}
	}
	return r;
}
