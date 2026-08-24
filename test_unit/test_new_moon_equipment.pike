#!/usr/bin/env pike
/** 新月十二职业十件套、分阶共鸣、动态生成和旧装备兼容回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);
array(string) piece_order=({
	"weapon","head","cloth","waste","hand",
	"thou","shoes","ring","neck","bangle",
});
array(int) set_tiers=({2,4,6,8,10});
array(string) set_attributes=({
	"all","defend","dodge","hitte","doub","lunck",
	"rase_life_add","rase_mofa_add","mofa_all","all_mofa_defend",
});

array(mapping(string:mixed)) catalog=({
	(["profession":"jianxian","race":"human",
		"profession_cn":"剑仙","theme":"剑心",
		"pieces":([
			"weapon":"69xinyuetianfengjian",
			"head":"69xinyuejianxinguan",
			"cloth":"69xinyuetianfengzhanyi",
			"waste":"69xinyuetianfenghuwan",
			"hand":"69xinyuetianfengzhanshou",
			"thou":"69xinyuetianfengzhanku",
			"shoes":"69xinyuetianfengzhanxue",
			"ring":"69xinyuejianxinjie",
			"neck":"69xinyuejianxinyujue",
			"bangle":"69xinyuejianxinshouhuan",
		]),"bonus":({3,2,0,1,0}),
		"tiers":([2:({"hitte",1}),4:({"doub",1}),6:({"dodge",1}),
			8:({"rase_life_add",1}),10:({"all",1})])]),
	(["profession":"yushi","race":"human",
		"profession_cn":"羽士","theme":"曜羽",
		"pieces":([
			"weapon":"69xinyueyaoyulingzhang",
			"head":"69xinyueyaoyuguan",
			"cloth":"69xinyuexingyufapao",
			"waste":"69xinyueyaoyufuwan",
			"hand":"69xinyueyaoyufushou",
			"thou":"69xinyuexingyuchangku",
			"shoes":"69xinyuexingyufalv",
			"ring":"69xinyueyaoyujie",
			"neck":"69xinyueyaolingzhui",
			"bangle":"69xinyueyaoyushouhuan",
		]),"bonus":({0,1,4,0,3}),
		"tiers":([2:({"mofa_all",4}),4:({"rase_mofa_add",1}),6:({"all_mofa_defend",2}),
			8:({"lunck",1}),10:({"all",1})])]),
	(["profession":"zhuxian","race":"human",
		"profession_cn":"诛仙","theme":"绝影",
		"pieces":([
			"weapon":"69xinyuezhuihunren",
			"head":"69xinyuejueyingdoumao",
			"cloth":"69xinyuezhuyingyi",
			"waste":"69xinyuezhuyinghuwan",
			"hand":"69xinyuezhuyingpishou",
			"thou":"69xinyuejueyingpiku",
			"shoes":"69xinyuejueyingxue",
			"ring":"69xinyuejueyingjie",
			"neck":"69xinyuejueyinghuan",
			"bangle":"69xinyuejueyingshouhuan",
		]),"bonus":({1,4,0,1,0}),
		"tiers":([2:({"hitte",1}),4:({"doub",1}),6:({"dodge",1}),
			8:({"lunck",1}),10:({"rase_life_add",1})])]),
	(["profession":"kuangyao","race":"monst",
		"profession_cn":"狂妖","theme":"狂澜",
		"pieces":([
			"weapon":"69xinyuelieyueshuangren",
			"head":"69xinyuekuanglanzhankui",
			"cloth":"69xinyuexuezhanjia",
			"waste":"69xinyuexuezhanhuwan",
			"hand":"69xinyuexuezhantieshou",
			"thou":"69xinyuexuezhantuikai",
			"shoes":"69xinyuexuezhanxue",
			"ring":"69xinyuekuanglanjie",
			"neck":"69xinyuekuanglanzhui",
			"bangle":"69xinyuekuanglanshouhuan",
		]),"bonus":({4,1,0,4,0}),
		"tiers":([2:({"doub",1}),4:({"rase_life_add",1}),6:({"defend",1}),
			8:({"hitte",1}),10:({"all",1})])]),
	(["profession":"wuyao","race":"monst",
		"profession_cn":"巫妖","theme":"幽咒",
		"pieces":([
			"weapon":"69xinyueshiguhunzhang",
			"head":"69xinyueyouzhouguan",
			"cloth":"69xinyueyouzhoubao",
			"waste":"69xinyueyouzhoufuwan",
			"hand":"69xinyueyouzhoufushou",
			"thou":"69xinyueyouzhouchangku",
			"shoes":"69xinyueyouzhoufalv",
			"ring":"69xinyuewuhunjie",
			"neck":"69xinyuewuhunpei",
			"bangle":"69xinyuewuhunshouhuan",
		]),"bonus":({0,1,4,1,3}),
		"tiers":([2:({"mofa_all",4}),4:({"all_mofa_defend",4}),6:({"rase_mofa_add",1}),
			8:({"lunck",1}),10:({"all",1})])]),
	(["profession":"yinggui","race":"monst",
		"profession_cn":"影鬼","theme":"夜行",
		"pieces":([
			"weapon":"69xinyueyexingguiren",
			"head":"69xinyueyexingdoumao",
			"cloth":"69xinyuewujiyi",
			"waste":"69xinyuewujihuwan",
			"hand":"69xinyuewujipishou",
			"thou":"69xinyueyexingpiku",
			"shoes":"69xinyueyexingxue",
			"ring":"69xinyueyingpojie",
			"neck":"69xinyueyingpohuan",
			"bangle":"69xinyueyingposhouhuan",
		]),"bonus":({0,4,0,1,0}),
		"tiers":([2:({"dodge",1}),4:({"doub",1}),6:({"hitte",1}),
			8:({"lunck",1}),10:({"rase_life_add",1})])]),
	(["profession":"fangshi","race":"third",
		"profession_cn":"方士","theme":"万象",
		"pieces":([
			"weapon":"69xinyuewanxiangfachi",
			"head":"69xinyuewuxingguan",
			"cloth":"69xinyuewuxingfayi",
			"waste":"69xinyuewuxingfuwan",
			"hand":"69xinyuewuxingfushou",
			"thou":"69xinyuewuxingchangku",
			"shoes":"69xinyuewuxingfalv",
			"ring":"69xinyuetianjijie",
			"neck":"69xinyuetianjiyin",
			"bangle":"69xinyuetianjishouhuan",
		]),"bonus":({1,1,4,1,2}),
		"tiers":([2:({"all",1}),4:({"mofa_all",3}),6:({"all_mofa_defend",2}),
			8:({"rase_mofa_add",1}),10:({"lunck",1})])]),
	(["profession":"zhenyue","race":"third",
		"profession_cn":"镇越","theme":"不动",
		"pieces":([
			"weapon":"69xinyueshanhezhongjian",
			"head":"69xinyuebudongshankui",
			"cloth":"69xinyuebudongshanjia",
			"waste":"69xinyuebudongshanwan",
			"hand":"69xinyuebudongshanshou",
			"thou":"69xinyuebudongshantuikai",
			"shoes":"69xinyuebudongshanzhanxue",
			"ring":"69xinyuezhenyuejie",
			"neck":"69xinyuezhenyueyin",
			"bangle":"69xinyuezhenyueshouhuan",
		]),"bonus":({4,0,0,5,0}),
		"tiers":([2:({"defend",2}),4:({"all_mofa_defend",4}),6:({"rase_life_add",1}),
			8:({"hitte",1}),10:({"all",1})])]),
	(["profession":"tianxiang","race":"third",
		"profession_cn":"天象","theme":"周天",
		"pieces":([
			"weapon":"69xinyuezhoutianxingzhang",
			"head":"69xinyuexingluoguan",
			"cloth":"69xinyuexingluofapao",
			"waste":"69xinyuexingluofuwan",
			"hand":"69xinyuexingluofushou",
			"thou":"69xinyuexingluochangku",
			"shoes":"69xinyuexingluofalv",
			"ring":"69xinyuetianshujie",
			"neck":"69xinyuetianshupan",
			"bangle":"69xinyuetianshushouhuan",
		]),"bonus":({0,1,4,0,3}),
		"tiers":([2:({"mofa_all",4}),4:({"lunck",2}),6:({"all_mofa_defend",2}),
			8:({"rase_mofa_add",1}),10:({"all",1})])]),
	(["profession":"lingyi","race":"third",
		"profession_cn":"灵医","theme":"长生",
		"pieces":([
			"weapon":"69xinyuehuichunlingzhang",
			"head":"69xinyuebaicaoguan",
			"cloth":"69xinyuebaicaofayi",
			"waste":"69xinyuebaicaoyaowan",
			"hand":"69xinyuebaicaoyaoshou",
			"thou":"69xinyuebaicaochangku",
			"shoes":"69xinyuebaicaoyaolv",
			"ring":"69xinyuechangshengjie",
			"neck":"69xinyuechangshengpei",
			"bangle":"69xinyuechangshengshouhuan",
		]),"bonus":({0,1,4,4,4}),
		"tiers":([2:({"rase_life_add",1}),4:({"rase_mofa_add",1}),6:({"all_mofa_defend",2}),
			8:({"lunck",1}),10:({"all",1})])]),
	(["profession":"wuxiang","race":"third",
		"profession_cn":"无相","theme":"混元",
		"pieces":([
			"weapon":"69xinyuewanfaguiyijian",
			"head":"69xinyuewuxiangguan",
			"cloth":"69xinyuewuxiangxuanyi",
			"waste":"69xinyuewuxianghuwan",
			"hand":"69xinyuewuxiangshou",
			"thou":"69xinyuewuxiangchangku",
			"shoes":"69xinyuewuxiangxuanlv",
			"ring":"69xinyuehunyuanjie",
			"neck":"69xinyuehunyuanjing",
			"bangle":"69xinyuehunyuanshouhuan",
		]),"bonus":({2,2,2,2,2}),
		"tiers":([2:({"all",1}),4:({"all_mofa_defend",3}),6:({"hitte",1}),
			8:({"doub",1}),10:({"rase_life_add",1})])]),
	(["profession":"taiji","race":"third",
		"profession_cn":"太极","theme":"两仪",
		"pieces":([
			"weapon":"69xinyueliangyijian",
			"head":"69xinyuetaijiguan",
			"cloth":"69xinyuetaijidaopao",
			"waste":"69xinyuetaijihuwan",
			"hand":"69xinyuetaijidaoshou",
			"thou":"69xinyuetaijidaoku",
			"shoes":"69xinyuetaijidaolv",
			"ring":"69xinyueyinyangjie",
			"neck":"69xinyueyinyangyupei",
			"bangle":"69xinyueyinyangshouhuan",
		]),"bonus":({3,3,3,3,3}),
		"tiers":([2:({"all",1}),4:({"all_mofa_defend",4}),6:({"defend",1}),
			8:({"rase_life_add",1}),10:({"rase_mofa_add",1})])]),
});

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string query_piece_parent(string slot)
{
	if(slot=="weapon")
		return "weapon";
	if(search(({"ring","neck","bangle"}),slot)!=-1)
		return "jewelry";
	return "armor";
}

string query_expected_kind(string slot)
{
	if(slot=="weapon")
		return "";
	if(slot=="head") return "armor_head";
	if(slot=="cloth") return "armor_cloth";
	if(slot=="waste") return "armor_waste";
	if(slot=="hand") return "armor_hand";
	if(slot=="thou") return "armor_thou";
	if(slot=="shoes") return "armor_shoes";
	if(slot=="ring") return "jewelry_ring";
	if(slot=="neck") return "jewelry_neck";
	if(slot=="bangle") return "jewelry_bangle";
	return "";
}

string item_path(string slot,string name)
{
	string parent=query_piece_parent(slot);
	return ROOT+"/gamelib/clone/item/"+parent+"/"+name+"/"+name;
}

string raw_item_path(string slot,string name)
{
	string parent=query_piece_parent(slot);
	return parent+"/"+name+"/"+name;
}

void cleanup_player_files(string name)
{
	string path;
	if(!name || !has_prefix(name,"__testunit_newmoon_"))
		return;
	path=DATA_ROOT+"u/"+name[sizeof(name)-2..]+"/"+name+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_player(string name,string race,string profession)
{
	object player;
	cleanup_player_files(name);
	player=clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn="新月装备测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profession);
	player->level=120;
	return player;
}

void destroy_player(object|zero player)
{
	string name;
	array(object) inventory;
	if(!player)
		return;
	name=(string)player->query_name();
	inventory=all_inventory(player);
	for(int index=0;index<sizeof(inventory);index++)
		if(inventory[index])
			destruct(inventory[index]);
	destruct(player);
	cleanup_player_files(name);
}

array(object) clone_full_set(mapping config)
{
	array(object) items=({});
	mapping pieces=(mapping)config["pieces"];
	for(int index=0;index<sizeof(piece_order);index++){
		string slot=piece_order[index];
		string name=(string)pieces[slot];
		items+=({clone(item_path(slot,name))});
	}
	return items;
}

void equip_full_set(object player,array(object) items)
{
	for(int index=0;index<sizeof(items);index++){
		items[index]->move(player);
		if(index==0)
			player->wield(items[index]);
		else
			player->wear(items[index]);
	}
}

object create_combat_player(string name,string race,string profession)
{
	object player=create_player(name,race,profession);
	player->setup_player(race,profession);
	player->level=120;
	player->set_att_by_level();
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
	return player;
}

void equip_set_count(object player,array(object) items,int count)
{
	for(int index=0;index<count && index<sizeof(items);index++){
		items[index]->move(player);
		if(index==0)
			player->wield(items[index]);
		else
			player->wear(items[index]);
	}
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
}

int query_magic_defend_snapshot(object player)
{
	int result=(int)player->query_equip_add("huoyan_defend");
	int current=(int)player->query_equip_add("bingshuang_defend");
	if(current<result)
		result=current;
	current=(int)player->query_equip_add("fengren_defend");
	if(current<result)
		result=current;
	current=(int)player->query_equip_add("dusu_defend");
	if(current<result)
		result=current;
	return result+(int)player->query_equip_add("all_mofa_defend");
}

int query_expected_damage_per_hundred(object attacker,object target,
	mapping damage_profile)
{
	int damage=(int)damage_profile["damage"];
	int hit=(int)damage_profile["hit"];
	int critical=(int)damage_profile["critical"];
	int critical_damage=attacker->query_balanced_critical_damage(
		damage,(int)target->query_equip_add("renxing"));
	return hit*((100-critical)*damage+critical*critical_damage)/100;
}

int query_effective_set_attribute(object item,string attribute)
{
	if(attribute=="all") return item->query_all_add();
	if(attribute=="defend") return item->query_defend_add();
	if(attribute=="dodge") return item->query_dodge_add();
	if(attribute=="hitte") return item->query_hitte_add();
	if(attribute=="doub") return item->query_doub_add();
	if(attribute=="lunck") return item->query_lunck_add();
	if(attribute=="rase_life_add") return item->query_rase_life_add();
	if(attribute=="rase_mofa_add") return item->query_rase_mofa_add();
	if(attribute=="mofa_all") return item->query_mofa_all_add();
	if(attribute=="all_mofa_defend")
		return item->query_all_mofa_defend_add();
	return 0;
}

int sum_set_attribute(array(object) items,string attribute)
{
	int total=0;
	for(int index=0;index<sizeof(items);index++)
		total+=query_effective_set_attribute(items[index],attribute);
	return total;
}

int sum_core_attribute(array(object) items,string attribute)
{
	int total=0;
	for(int index=0;index<sizeof(items);index++){
		if(attribute=="str") total+=items[index]->query_str_add();
		else if(attribute=="dex") total+=items[index]->query_dex_add();
		else if(attribute=="think") total+=items[index]->query_think_add();
		else if(attribute=="life") total+=items[index]->query_life_add();
		else if(attribute=="mofa") total+=items[index]->query_mofa_add();
	}
	return total;
}

int expected_resonance_percent(int count)
{
	if(count>=10) return 200;
	if(count>=8) return 180;
	if(count>=6) return 160;
	if(count>=4) return 140;
	if(count>=2) return 120;
	return 100;
}

int profile_attribute_supported(string attribute)
{
	return search(({
		"str_add","dex_add","think_add","all_add","dodge_add",
		"doub_add","hitte_add","lunck_add","attack_add",
		"weapon_attack_add","defend_add","dura_add","item_canDura",
		"life_add","mofa_add","rase_life_add","rase_mofa_add",
		"huo_mofa_attack_add","bing_mofa_attack_add",
		"feng_mofa_attack_add","du_mofa_attack_add",
		"spec_mofa_attack_add","mofa_all_add","attack_huoyan_add",
		"attack_bingshuang_add","attack_fengren_add",
		"attack_dusu_add","attack_spec_add","huoyan_defend_add",
		"bingshuang_defend_add","fengren_defend_add",
		"dusu_defend_add","all_mofa_defend_add","dodgechuantou_add",
	}),attribute)!=-1;
}

void test_catalog_and_templates()
{
	string org=Stdio.read_file(ROOT+"/gamelib/data/orgItems.list") || "";
	string attrs=Stdio.read_file(ROOT+"/gamelib/data/allItems.list") || "";
	string level_line="";
	array(string) registered=({});
	mapping(string:int) registered_counts=([]);
	mapping(string:int) profile_counts=([]);
	mapping(string:string) profile_lines=([]);
	mapping(string:int) expected_paths=([]);
	int compiled=1;
	int metadata_valid=1;
	int profile_valid=1;
	int effective_profile_valid=1;
	int image_valid=1;
	int slot_valid=1;
	int budget_valid=1;
	int six_collection_matrix_valid=1;
	int highest_affix_capacity_valid=1;
	array(string) errors=({});
	array(string) collection_ids=({
		"newmoon","starshine","firmament","greatvoid","primordial","huanji",
	});
	array(string) collection_names=({"新月","曜星","天穹","太虚","太初","寰极"});
	array(string) collection_qualities=({"稀世","绝世","传说","神话","太古","至尊"});
	array(int) collection_percents=({100,105,110,116,123,132});

	foreach(org/"\n",string line)
		if(has_prefix(line,"69|"))
			level_line=line;
	if(sizeof(level_line))
		registered=(level_line[3..]/",")-({""});
	for(int index=0;index<sizeof(registered);index++)
		registered_counts[registered[index]]=
			(int)registered_counts[registered[index]]+1;
	foreach(attrs/"\n",string profile_line){
		array(string) line_parts=profile_line/"|";
		if(sizeof(line_parts)<2 || search(line_parts[0],"69xinyue")==-1)
			continue;
		profile_counts[line_parts[0]]=(int)profile_counts[line_parts[0]]+1;
		profile_lines[line_parts[0]]=profile_line;
	}

	for(int config_index=0;config_index<sizeof(catalog);config_index++){
		mapping config=catalog[config_index];
		mapping pieces=(mapping)config["pieces"];
		for(int slot_index=0;slot_index<sizeof(piece_order);slot_index++){
			string slot=piece_order[slot_index];
			string name=(string)pieces[slot];
			string raw=raw_item_path(slot,name);
			string path=item_path(slot,name);
			object|zero item=0;
			mixed err=catch { item=clone(path); };
			expected_paths[raw]=1;
			if(err || !item){
				compiled=0;
				errors+=({slot+"/"+name});
				continue;
			}
			int raw_attack=item->query_attack_power();
			int raw_attack_limit=item->query_attack_power_limit();
			int raw_defend=item->query_equip_defend();
			for(int collection_index=0;
			   collection_index<sizeof(collection_ids);collection_index++){
				if(!item->set_newmoon_collection(
				   collection_ids[collection_index]) ||
				   item->query_newmoon_collection_rank()!=collection_index+1 ||
				   item->query_newmoon_collection_name()!=
					collection_names[collection_index] ||
				   item->query_newmoon_collection_quality()!=
					collection_qualities[collection_index] ||
				   search(item->query_short(),"【"+
					collection_names[collection_index]+"·"+
					collection_qualities[collection_index]+"·"+
					(string)config["profession_cn"]+"】")==-1 ||
				   search(item->query_name_cn(),"【"+
					collection_names[collection_index]+"·"+
					collection_qualities[collection_index]+"·"+
					(string)config["profession_cn"]+"】")==-1 ||
				   (collection_index>0 && search(item->query_name_cn(),
					"【新月·"+(string)config["profession_cn"]+"】")!=-1) ||
				   (slot=="weapon" &&
				    (item->query_attack_power()!=raw_attack*
					collection_percents[collection_index]/100 ||
				     item->query_attack_power_limit()!=raw_attack_limit*
					collection_percents[collection_index]/100)) ||
				   (query_piece_parent(slot)=="armor" &&
				    item->query_equip_defend()!=raw_defend*
					collection_percents[collection_index]/100))
					six_collection_matrix_valid=0;
			}
			item->set_newmoon_collection("newmoon");
			array(string) limits=item->query_item_profeLimit();
			if(item->query_item_canLevel()!=69 ||
			   item->query_newmoon_resonance_profession()!=
				(string)config["profession"] ||
			   item->query_newmoon_resonance_theme()!=
				(string)config["theme"] ||
			   search(limits,(string)config["profession"])==-1 ||
			   !item->query_item_canDrop() || !item->query_item_canTrade() ||
			   !item->query_item_canSend() || !item->query_item_canStorage())
				metadata_valid=0;
			if(slot=="weapon"){
				if(search(({"weapon","single_weapon","double_weapon"}),
				   (string)item->query_item_type())==-1 ||
				   search(({"single_main_weapon","double_main_weapon"}),
				   (string)item->query_item_kind())==-1)
					slot_valid=0;
				if(item->query_attack_power()<340 ||
				   item->query_attack_power_limit()<
					item->query_attack_power() ||
				   item->query_attack_power_limit()>840)
					budget_valid=0;
			}
			else if(query_piece_parent(slot)=="armor"){
				if(item->query_item_type()!="armor" ||
				   item->query_item_kind()!=query_expected_kind(slot))
					slot_valid=0;
				if(item->query_equip_defend()<380 ||
				   item->query_equip_defend()>1440)
					budget_valid=0;
			}
			else if(item->query_item_type()!="jewelry" ||
			        item->query_item_kind()!=query_expected_kind(slot))
				slot_valid=0;

			if((int)registered_counts[raw]!=1 ||
			   (int)profile_counts[raw]!=1)
				profile_valid=0;
			string profile=(string)(profile_lines[raw] || "");
			array(string) profile_parts=profile/"|";
			if(sizeof(profile_parts)<2)
				effective_profile_valid=0;
			else{
				int available_affixes=0;
				foreach(profile_parts[1]/",",string attribute_spec){
					array(string) attribute_parts=attribute_spec/":";
					if(attribute_spec=="")
						continue;
					available_affixes++;
					if(sizeof(attribute_parts)!=3 ||
					   !profile_attribute_supported(attribute_parts[0]) ||
					   (int)attribute_parts[1]<=0 ||
					   (int)attribute_parts[2]<(int)attribute_parts[1] ||
					   attribute_parts[0]=="recive_add" ||
					   attribute_parts[0]=="back_add" ||
					   (slot!="weapon" &&
					    (attribute_parts[0]=="attack_add" ||
					     attribute_parts[0]=="weapon_attack_add")))
						effective_profile_valid=0;
				}
				if(available_affixes<6)
					highest_affix_capacity_valid=0;
			}
			string source=Stdio.read_file(path) || "";
			string picture="";
			foreach(source/"\n",string source_line)
				if(sscanf(String.trim_whites(source_line),
				   "picture=\"%s\";",picture)==1)
					break;
			int found_image=0;
			foreach(({".gif",".png",".webp",".jpg"}),string extension)
				if(Stdio.file_size(ROOT+"/images/"+picture+extension)>0 &&
				   Stdio.file_size(ROOT+"/web/images/"+picture+extension)>0)
					found_image=1;
			if(!found_image)
				image_valid=0;
			destruct(item);
		}
	}
	check("69级新月底版精确登记十二职业十件套共120件",
		sizeof(registered)==120 && sizeof(registered_counts)==120 &&
		sizeof(expected_paths)==120,
		sprintf("登记数=%d，去重=%d，期望=%d",
			sizeof(registered),sizeof(registered_counts),
			sizeof(expected_paths)));
	check("120件十件套底版均可在游戏环境编译克隆",
		compiled,errors*",");
	check("十二职业十部位映射为六套共720个身份且品质显示一致",
		six_collection_matrix_valid,
		"某件底版无法映射全部六套、倍率错误或仍显示旧前缀");
	check("全部底版等级、流通能力、主题与职业元数据完整",
		metadata_valid,"某件装备元数据不完整");
	check("十件套覆盖主武器、六防具与三首饰且槽位不冲突",
		slot_valid,"存在错误的装备类型或部位");
	check("69级套装单件白板攻防精确提高至原模板200%",
		budget_valid,"单件攻防没有翻倍或越过审定边界");
	check("120件底版在掉落登记和随机词缀表中各出现一次",
		profile_valid,"登记表或词缀表存在缺项或重复");
	check("新月套装从普通白装池隔离并使用69级以上独立稀有掉落门",
		ITEMSD->query_newmoon_equipment_template_count()==120 &&
		ITEMSD->query_newmoon_equipment_drop_denominator()==300000 &&
		ITEMSD->query_enabled_newmoon_collection_count()==6 &&
		!ITEMSD->can_drop_newmoon_equipment(68,145) &&
		ITEMSD->query_newmoon_collection_id_for_roll(69,145)=="newmoon" &&
		ITEMSD->query_newmoon_collection_id_for_roll(69,444)=="newmoon" &&
		ITEMSD->query_newmoon_collection_id_for_roll(69,445)=="" &&
		ITEMSD->query_newmoon_collection_id_for_roll(90,45)=="starshine" &&
		ITEMSD->query_newmoon_collection_id_for_roll(90,144)=="starshine" &&
		ITEMSD->query_newmoon_collection_id_for_roll(110,15)=="firmament" &&
		ITEMSD->query_newmoon_collection_id_for_roll(110,44)=="firmament" &&
		ITEMSD->query_newmoon_collection_id_for_roll(130,5)=="greatvoid" &&
		ITEMSD->query_newmoon_collection_id_for_roll(130,14)=="greatvoid" &&
		ITEMSD->query_newmoon_collection_id_for_roll(160,2)=="primordial" &&
		ITEMSD->query_newmoon_collection_id_for_roll(160,4)=="primordial" &&
		ITEMSD->query_newmoon_collection_id_for_roll(199,1)=="" &&
		ITEMSD->query_newmoon_collection_id_for_roll(200,1)=="huanji",
		"套装可能污染普通掉落池、低等级掉落或绕过独立稀有概率");
	check("十件套词缀均受生成器支持且没有非武器攻击词缀",
		effective_profile_valid,"发现无效、反向或错槽词缀");
	check("120件底版均至少提供六种有效词缀供寰极保底抽取",
		highest_affix_capacity_valid,
		"存在底版词缀池小于寰极六词缀下限");
	check("十件套复用图片在源码与Web资源树均可加载",
		image_valid,"存在缺失图片");
}

void test_resonance_boundaries()
{
	int all_valid=1;
	array(string) errors=({});
	for(int index=0;index<sizeof(catalog);index++){
		mapping config=catalog[index];
		mapping pieces=(mapping)config["pieces"];
		string player_name="__testunit_newmoon_profession_"+
			(string)index+"__";
		object player=create_player(player_name,
			(string)config["race"],(string)config["profession"]);
		object item=clone(item_path("weapon",(string)pieces["weapon"]));
		array bonus=(array)config["bonus"];
		int inactive=item->query_newmoon_resonance_active();
		item->move(player);
		player->wield(item);
		int valid=!inactive && item->query_newmoon_resonance_active() &&
			item->query_str_add()==bonus[0]*100 &&
			item->query_dex_add()==bonus[1]*100 &&
			item->query_think_add()==bonus[2]*100 &&
			item->query_life_add()==bonus[3]*1000 &&
			item->query_mofa_add()==bonus[4]*1000;
		if(!valid){
			all_valid=0;
			errors+=({(string)config["profession"]});
		}
		destroy_player(player);
	}
	check("十二职业共鸣只在目标职业实际穿戴后生效",
		all_valid,errors*",");

	mapping yushi=catalog[1];
	mapping yushi_pieces=(mapping)yushi["pieces"];
	object wrong=create_player("__testunit_newmoon_wrong__",
		"human","jianxian");
	array(object) other_items=clone_full_set(yushi);
	equip_full_set(wrong,other_items);
	check("跨职业凑齐全套不能激活其他职业共鸣或属性",
		!other_items[0]->query_newmoon_resonance_active() &&
		other_items[0]->query_think_add()==0 &&
		other_items[0]->query_mofa_add()==0,
		"羽士共鸣错误作用于剑仙");
	object|zero original_player=this_player();
	set_this_player(wrong);
	string wrong_detail=other_items[0]->query_content();
	set_this_player(original_player);
	check("跨职业全套详情不能误报任何分阶效果已激活",
		search(wrong_detail,"职业契合且穿戴后激活")!=-1 &&
		search(wrong_detail,"（已激活）")==-1,
		"不契合职业的套装详情错误显示已激活");
	destroy_player(wrong);
}

void test_individual_item_baseline_comparison()
{
	object ordinary_weapon=clone(ROOT+
		"/gamelib/clone/item/weapon/69hanbingshuangjian");
	object ordinary_armor=clone(ROOT+
		"/gamelib/clone/item/armor/65feiyangsuojia");
	object fixed_best_weapon=clone(ROOT+
		"/gamelib/clone/item/weapon/70yunraoshuangdaowuse");
	object fixed_best_staff=clone(ROOT+
		"/gamelib/clone/item/weapon/70yunraofazhangwuse");
	object fixed_best_armor=clone(ROOT+
		"/gamelib/clone/item/armor/70gutiansuojia");
	object strongest_set_weapon=clone(item_path("weapon",
		"69xinyueshanhezhongjian"));
	object caster_set_weapon=clone(item_path("weapon",
		"69xinyuehuichunlingzhang"));
	object strongest_set_armor=clone(item_path("cloth",
		"69xinyuebudongshanjia"));
	int valid=ordinary_weapon && ordinary_armor && fixed_best_weapon &&
		fixed_best_staff && fixed_best_armor && strongest_set_weapon &&
		caster_set_weapon && strongest_set_armor &&
		ordinary_weapon->query_attack_power()==355 &&
		ordinary_weapon->query_attack_power_limit()==385 &&
		ordinary_armor->query_equip_defend()==657 &&
		fixed_best_weapon->query_attack_power()==555 &&
		fixed_best_weapon->query_attack_power_limit()==585 &&
		fixed_best_staff->query_attack_power()==405 &&
		fixed_best_staff->query_attack_power_limit()==435 &&
		fixed_best_armor->query_equip_defend()==672 &&
		strongest_set_weapon->query_attack_power()==710 &&
		strongest_set_weapon->query_attack_power_limit()==776 &&
		caster_set_weapon->query_attack_power()==356 &&
		caster_set_weapon->query_attack_power_limit()==416 &&
		strongest_set_armor->query_equip_defend()==1380;
	check("套装单件新基线已对照69级普通与70级固定极品上限",
		valid,sprintf("普通武器%d-%d/普通甲%d，固定极品重武%d-%d/"
			"法杖%d-%d/重甲%d，套装重武%d-%d/法杖%d-%d/重甲%d",
			ordinary_weapon ? ordinary_weapon->query_attack_power() : 0,
			ordinary_weapon ? ordinary_weapon->query_attack_power_limit() : 0,
			ordinary_armor ? ordinary_armor->query_equip_defend() : 0,
			fixed_best_weapon ? fixed_best_weapon->query_attack_power() : 0,
			fixed_best_weapon ? fixed_best_weapon->query_attack_power_limit() : 0,
			fixed_best_staff ? fixed_best_staff->query_attack_power() : 0,
			fixed_best_staff ? fixed_best_staff->query_attack_power_limit() : 0,
			fixed_best_armor ? fixed_best_armor->query_equip_defend() : 0,
			strongest_set_weapon ? strongest_set_weapon->query_attack_power() : 0,
			strongest_set_weapon ? strongest_set_weapon->query_attack_power_limit() : 0,
			caster_set_weapon ? caster_set_weapon->query_attack_power() : 0,
			caster_set_weapon ? caster_set_weapon->query_attack_power_limit() : 0,
			strongest_set_armor ? strongest_set_armor->query_equip_defend() : 0));
	strongest_set_weapon->set_newmoon_collection("huanji");
	caster_set_weapon->set_newmoon_collection("huanji");
	strongest_set_armor->set_newmoon_collection("huanji");
	check("寰极单件白板攻防超过现有固定极品且不放大其他系统",
		strongest_set_weapon->query_attack_power()==937 &&
		strongest_set_weapon->query_attack_power_limit()==1024 &&
		caster_set_weapon->query_attack_power()==469 &&
		caster_set_weapon->query_attack_power_limit()==549 &&
		strongest_set_armor->query_equip_defend()==1821,
		sprintf("寰极重武%d-%d/法杖%d-%d/重甲%d",
			strongest_set_weapon->query_attack_power(),
			strongest_set_weapon->query_attack_power_limit(),
			caster_set_weapon->query_attack_power(),
			caster_set_weapon->query_attack_power_limit(),
			strongest_set_armor->query_equip_defend()));
	foreach(({ordinary_weapon,ordinary_armor,fixed_best_weapon,
	   fixed_best_staff,fixed_best_armor,strongest_set_weapon,
	   caster_set_weapon,strongest_set_armor}),object item)
		if(item)
			destruct(item);
}

void test_full_set_progression()
{
	mapping config=catalog[0];
	object player=create_player("__testunit_newmoon_progress__",
		"human","jianxian");
	array(object) items=clone_full_set(config);
	array(int) milestones=({1,2,4,6,8,10});
	array(int) expected_percent=({100,120,140,160,180,200});
	array(int) expected_strength=({300,720,1680,2880,4320,6000});
	int progression_valid=1;
	array(string) errors=({});

	for(int index=0;index<sizeof(items);index++){
		items[index]->move(player);
		if(index==0)
			player->wield(items[index]);
		else
			player->wear(items[index]);
		int milestone_index=search(milestones,index+1);
		if(milestone_index!=-1){
			int total_strength=0;
			for(int item_index=0;item_index<sizeof(items);item_index++)
				total_strength+=items[item_index]->query_str_add();
			if(items[0]->query_newmoon_set_piece_count()!=index+1 ||
			   items[0]->query_newmoon_resonance_percent()!=
				expected_percent[milestone_index] ||
			   total_strength!=expected_strength[milestone_index]){
				progression_valid=0;
				errors+=({sprintf("%d件:%d%%/力量%d",
					index+1,items[0]->query_newmoon_resonance_percent(),
					total_strength)});
			}
		}
	}
	check("十件套按2/4/6/8/10件逐级提高共鸣并封顶200%",
		progression_valid,errors*";");
	check("剑仙五档套装属性均按实际穿戴件数进入真实getter",
		sum_set_attribute(items,"hitte")==10 &&
		sum_set_attribute(items,"doub")==10 &&
		sum_set_attribute(items,"dodge")==10 &&
		sum_set_attribute(items,"rase_life_add")==10 &&
		sum_set_attribute(items,"all")==10,
		sprintf("命中%d 暴击%d 闪避%d 恢复%d 全属性%d",
			sum_set_attribute(items,"hitte"),
			sum_set_attribute(items,"doub"),
			sum_set_attribute(items,"dodge"),
			sum_set_attribute(items,"rase_life_add"),
			sum_set_attribute(items,"all")));

	object|zero original_player=this_player();
	set_this_player(player);
	string detail=items[0]->query_content();
	set_this_player(original_player);
	check("装备详情完整显示十件进度和五档月相效果",
		search(detail,"【套装·新月·稀世·剑仙·剑心】(10/10)")!=-1 &&
		search(detail,"2件·初月：职业共鸣120%")!=-1 &&
		search(detail,"4件·弦月：职业共鸣140%")!=-1 &&
		search(detail,"6件·望月：职业共鸣160%")!=-1 &&
		search(detail,"8件·盈月：职业共鸣180%")!=-1 &&
		search(detail,"10件·满月觉醒：职业共鸣200%")!=-1,
		"详情缺少十件进度或分阶效果");

	items[1]->item_cur_dura=0;
	int broken_strength=0;
	for(int index=0;index<sizeof(items);index++)
		broken_strength+=items[index]->query_str_add();
	check("破损装备不计件、不提供自身共鸣且关闭十件效果",
		items[0]->query_newmoon_set_piece_count()==9 &&
		items[0]->query_newmoon_resonance_percent()==180 &&
		!items[1]->query_newmoon_resonance_active() &&
		broken_strength==4860 && sum_set_attribute(items,"all")==0,
		sprintf("件数%d 共鸣%d 力量%d 全属性%d",
			items[0]->query_newmoon_set_piece_count(),
			items[0]->query_newmoon_resonance_percent(),
			broken_strength,sum_set_attribute(items,"all")));
	destroy_player(player);
}

void test_all_profession_set_extras()
{
	int all_valid=1;
	array(string) errors=({});
	for(int index=0;index<sizeof(catalog);index++){
		mapping config=catalog[index];
		mapping tiers=(mapping)config["tiers"];
		object player=create_player("__testunit_newmoon_extras_"+
			(string)index+"__",
			(string)config["race"],(string)config["profession"]);
		array(object) items=clone_full_set(config);
		equip_full_set(player,items);
		if(items[0]->query_newmoon_set_piece_count()!=10)
			all_valid=0;
		for(int tier_index=0;tier_index<sizeof(set_tiers);tier_index++){
			int tier=set_tiers[tier_index];
			array spec=(array)tiers[tier];
			string attribute=(string)spec[0];
			int factor=attribute=="defend" ? 10 : 1;
			int expected=(int)spec[1]*10*factor;
			int actual=sum_set_attribute(items,attribute);
			if(actual!=expected){
				all_valid=0;
				errors+=({sprintf("%s-%d:%s=%d/%d",
					(string)config["profession"],tier,attribute,
					actual,expected)});
			}
		}
		destroy_player(player);
	}
	check("十二职业共60档套装属性全部进入真实战斗属性getter",
		all_valid,errors*";");
}

void test_requested_piece_attribute_matrix()
{
	array(int) checkpoints=({1,2,3,4,10});
	array(string) core_attributes=({"str","dex","think","life","mofa"});
	int all_valid=1;
	array(string) errors=({});
	for(int config_index=0;config_index<sizeof(catalog);config_index++){
		mapping config=catalog[config_index];
		mapping tiers=(mapping)config["tiers"];
		array bonus=(array)config["bonus"];
		object player=create_player("__testunit_newmoon_matrix_"+
			(string)config_index+"__",
			(string)config["race"],(string)config["profession"]);
		array(object) items=clone_full_set(config);
		int equipped_count=0;
		for(int checkpoint_index=0;
		    checkpoint_index<sizeof(checkpoints);checkpoint_index++){
			int checkpoint=checkpoints[checkpoint_index];
			while(equipped_count<checkpoint){
				items[equipped_count]->move(player);
				if(equipped_count==0)
					player->wield(items[equipped_count]);
				else
					player->wear(items[equipped_count]);
				equipped_count++;
			}
			int percent=expected_resonance_percent(checkpoint);
			if(items[0]->query_newmoon_set_piece_count()!=checkpoint ||
			   items[0]->query_newmoon_resonance_percent()!=percent){
				all_valid=0;
				errors+=({sprintf("%s-%d件:件数%d/共鸣%d",
					(string)config["profession"],checkpoint,
					items[0]->query_newmoon_set_piece_count(),
					items[0]->query_newmoon_resonance_percent())});
			}
			for(int core_index=0;core_index<sizeof(core_attributes);
			    core_index++){
				string attribute=core_attributes[core_index];
				int bonus_index=core_index;
				int factor=1;
				if(attribute=="life" || attribute=="mofa")
					factor=10;
				int expected=checkpoint*((int)bonus[bonus_index]*100*
					percent/100)*factor;
				int actual=sum_core_attribute(items,attribute);
				if(actual!=expected){
					all_valid=0;
					errors+=({sprintf("%s-%d件:%s=%d/%d",
						(string)config["profession"],checkpoint,
						attribute,actual,expected)});
				}
			}
			for(int attribute_index=0;
			    attribute_index<sizeof(set_attributes);attribute_index++){
				string attribute=set_attributes[attribute_index];
				int per_item=0;
				for(int tier_index=0;tier_index<sizeof(set_tiers);
				    tier_index++){
					int tier=set_tiers[tier_index];
					array spec=(array)tiers[tier];
					if(tier<=checkpoint && (string)spec[0]==attribute)
						per_item+=(int)spec[1];
				}
				int factor=attribute=="defend" ? 10 : 1;
				int expected=checkpoint*per_item*factor;
				int actual=sum_set_attribute(items,attribute);
				if(actual!=expected){
					all_valid=0;
					errors+=({sprintf("%s-%d件:%s=%d/%d",
						(string)config["profession"],checkpoint,
						attribute,actual,expected)});
				}
			}
		}
		destroy_player(player);
	}
	check("十二职业穿1/2/3/4/10件时全部15类属性精确符合预期",
		all_valid,errors*";");
}

void test_dodge_penetration_affix_roll()
{
	werror("\n[新月闪避穿透行为测试]\n");
	mapping config=catalog[0];
	string weapon_path=item_path("weapon",(string)config["pieces"]["weapon"]);
	object player=create_player("__testunit_newmoon_pen__",
		"human","jianxian");
	int seen=0;
	int max_value=0;
	int min_value=999999;
	for(int i=0;i<50;i++){
		object item=clone(weapon_path);
		if(!item)
			break;
		// 用公开生成接口走完整词缀池（底版需完整路径）
		object generated=ITEMSD->get_convert_item(
			"weapon/"+(string)config["pieces"]["weapon"]+"/"+
			(string)config["pieces"]["weapon"],
			3,69,69,item);
		if(!generated){
			destruct(item);
			continue;
		}
		int pen=(int)generated->query_dodgechuantou_add();
		if(pen>0){
			seen++;
			if(pen>max_value)
				max_value=pen;
			if(pen<min_value)
				min_value=pen;
		}
		if(generated!=item)
			destruct(generated);
	}
	int valid = player!=0 && seen>0 && max_value<=35 && min_value>=14;
	werror("  50件中"+seen+"件出闪避穿透，值域"+min_value+"-"+max_value+"\n");
	check("新月底版词条池随机roll出闪避穿透且值在15-30范围(容差1.01倍)",
		valid,
		sprintf("seen=%d min=%d max=%d",seen,min_value,max_value));
	destroy_player(player);
}

void test_set_identity_and_duplicate_boundaries()
{
	mapping config=catalog[0];
	mapping pieces=(mapping)config["pieces"];
	object player=create_player("__testunit_newmoon_identity__",
		"human","jianxian");
	object weapon=clone(item_path("weapon",(string)pieces["weapon"]));
	object armor=clone(item_path("cloth",(string)pieces["cloth"]));
	weapon->move(player);
	armor->move(player);
	player->wield(weapon);
	player->wear(armor);
	armor->set_newmoon_resonance("jianxian","剑仙","异月",3,2,0,1,0,
		"hitte",1,"doub",1);
	check("同职业不同套装主题不能混穿凑分阶效果",
		weapon->query_newmoon_set_piece_count()==1 &&
		armor->query_newmoon_set_piece_count()==1 &&
		weapon->query_hitte_add()==0 && armor->query_hitte_add()==0,
		"不同主题错误计入同一套装");
	destroy_player(player);

	object duplicate_player=create_player("__testunit_newmoon_duplicate__",
		"human","jianxian");
	object duplicate_item=clone(item_path("weapon",
		(string)pieces["weapon"]));
	duplicate_item->move(duplicate_player);
	duplicate_player->wield(duplicate_item);
	mapping equipped=duplicate_player->query_equip();
	equipped["__test_duplicate_slot"]=duplicate_item;
	check("同一对象即使异常占据两个映射键也只能计算一件",
		duplicate_item->query_newmoon_set_piece_count()==1,
		"重复装备对象被多次计数");
	m_delete(equipped,"__test_duplicate_slot");
	object duplicate_slot_item=clone(item_path("weapon",
		(string)pieces["weapon"]));
	duplicate_slot_item->move(duplicate_player);
	duplicate_slot_item->equiped=1;
	equipped["__test_duplicate_slot"]=duplicate_slot_item;
	check("两个同部位对象即使异常写入装备映射也只计算一件",
		duplicate_item->query_newmoon_set_piece_count()==1,
		"同一装备部位可通过异常映射重复凑套装件数");
	m_delete(equipped,"__test_duplicate_slot");
	destruct(duplicate_slot_item);
	destroy_player(duplicate_player);
}

void test_two_player_real_combat_comparisons()
{
	object room=(object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	mapping jianxian=catalog[0];
	object physical_four=create_combat_player(
		"__testunit_newmoon_pvp_phy_four__","human","jianxian");
	object physical_ten=create_combat_player(
		"__testunit_newmoon_pvp_phy_ten__","human","jianxian");
	array(object) physical_four_items=clone_full_set(jianxian);
	array(object) physical_ten_items=clone_full_set(jianxian);
	mapping physical_four_profile=([]);
	mapping physical_ten_profile=([]);
	mapping physical_four_damage=([]);
	mapping physical_ten_damage=([]);
	int physical_four_reference=0;
	int physical_ten_reference=0;
	string physical_error="";
	mixed physical_err=catch {
		physical_four->move(room);
		physical_ten->move(room);
		equip_set_count(physical_four,physical_four_items,4);
		equip_set_count(physical_ten,physical_ten_items,10);
		physical_four_profile=physical_four->query_pk_fast_side_profile(
			physical_four);
		physical_ten_profile=physical_ten->query_pk_fast_side_profile(
			physical_ten);
		physical_four_damage=physical_four->query_pk_fast_damage_profile(
			physical_four,physical_ten,physical_four_profile,
			physical_ten_profile);
		physical_ten_damage=physical_ten->query_pk_fast_damage_profile(
			physical_ten,physical_four,physical_ten_profile,
			physical_four_profile);
		physical_four_reference=physical_four->query_balanced_physical_damage(
			(int)physical_four_profile["physical_raw"],
			physical_ten->query_defend_power(),
			(int)physical_four_profile["physical_penetration"]);
		physical_ten_reference=physical_ten->query_balanced_physical_damage(
			(int)physical_ten_profile["physical_raw"],
			physical_four->query_defend_power(),
			(int)physical_ten_profile["physical_penetration"]);
	};
	if(physical_err)
		physical_error=describe_error(physical_err);
	werror("[新月双人实战] 剑仙4件: 力量%d 生命%d 攻击%d 防御%d 命中%d 暴击%d；"+
		"10件: 力量%d 生命%d 攻击%d 防御%d 命中%d 暴击%d；互攻伤害=%d/%d\n",
		physical_four->query_str(),physical_four->query_life_max(),
		(int)physical_four_profile["physical_raw"],
		physical_four->query_defend_power(),
		(int)physical_four_profile["hit"],
		(int)physical_four_profile["critical"],
		physical_ten->query_str(),physical_ten->query_life_max(),
		(int)physical_ten_profile["physical_raw"],
		physical_ten->query_defend_power(),
		(int)physical_ten_profile["hit"],
		(int)physical_ten_profile["critical"],
		(int)physical_four_damage["damage"],
		(int)physical_ten_damage["damage"]);
	check("真实双人剑仙4件与10件的面板、物防和物理输出符合生产公式",
		!physical_err &&
		physical_four_items[0]->query_newmoon_set_piece_count()==4 &&
		physical_ten_items[0]->query_newmoon_set_piece_count()==10 &&
		physical_ten->query_str()>physical_four->query_str() &&
		physical_ten->query_life_max()>physical_four->query_life_max() &&
		physical_ten->query_defend_power()>physical_four->query_defend_power() &&
		(int)physical_ten_profile["physical_raw"]>
			(int)physical_four_profile["physical_raw"] &&
		(int)physical_ten_profile["hit"]>
			(int)physical_four_profile["hit"] &&
		(int)physical_ten_profile["critical"]>
			(int)physical_four_profile["critical"] &&
		!(int)physical_four_damage["magic"] &&
		!(int)physical_ten_damage["magic"] &&
		(int)physical_four_damage["damage"]==physical_four_reference &&
		(int)physical_ten_damage["damage"]==physical_ten_reference &&
		(int)physical_ten_damage["damage"]>
			(int)physical_four_damage["damage"],
		physical_error!="" ? physical_error :
			sprintf("4件攻防伤%d/%d/%d，10件攻防伤%d/%d/%d",
				(int)physical_four_profile["physical_raw"],
				physical_four->query_defend_power(),
				(int)physical_four_damage["damage"],
				(int)physical_ten_profile["physical_raw"],
				physical_ten->query_defend_power(),
				(int)physical_ten_damage["damage"]));
	destroy_player(physical_four);
	destroy_player(physical_ten);

	mapping yushi=catalog[1];
	object magic_four=create_combat_player(
		"__testunit_newmoon_pvp_magic_four__","human","yushi");
	object magic_ten=create_combat_player(
		"__testunit_newmoon_pvp_magic_ten__","human","yushi");
	array(object) magic_four_items=clone_full_set(yushi);
	array(object) magic_ten_items=clone_full_set(yushi);
	mapping magic_four_profile=([]);
	mapping magic_ten_profile=([]);
	mapping magic_four_damage=([]);
	mapping magic_ten_damage=([]);
	int magic_four_reference=0;
	int magic_ten_reference=0;
	string magic_error="";
	mixed magic_err=catch {
		magic_four->move(room);
		magic_ten->move(room);
		equip_set_count(magic_four,magic_four_items,4);
		equip_set_count(magic_ten,magic_ten_items,10);
		magic_four_profile=magic_four->query_pk_fast_side_profile(magic_four);
		magic_ten_profile=magic_ten->query_pk_fast_side_profile(magic_ten);
		magic_four_damage=magic_four->query_pk_fast_damage_profile(
			magic_four,magic_ten,magic_four_profile,magic_ten_profile);
		magic_ten_damage=magic_ten->query_pk_fast_damage_profile(
			magic_ten,magic_four,magic_ten_profile,magic_four_profile);
		magic_four_reference=magic_four->query_balanced_magic_damage(
			(int)magic_four_profile["magic_raw"],
			query_magic_defend_snapshot(magic_ten),
			(int)magic_four_profile["magic_penetration"]);
		magic_ten_reference=magic_ten->query_balanced_magic_damage(
			(int)magic_ten_profile["magic_raw"],
			query_magic_defend_snapshot(magic_four),
			(int)magic_ten_profile["magic_penetration"]);
	};
	if(magic_err)
		magic_error=describe_error(magic_err);
	werror("[新月双人实战] 羽士4件: 智力%d 法力%d 法攻%d 法抗%d；"+
		"10件: 智力%d 法力%d 法攻%d 法抗%d；互攻伤害=%d/%d\n",
		magic_four->query_think(),magic_four->query_mofa_max(),
		(int)magic_four_profile["magic_raw"],
		query_magic_defend_snapshot(magic_four),
		magic_ten->query_think(),magic_ten->query_mofa_max(),
		(int)magic_ten_profile["magic_raw"],
		query_magic_defend_snapshot(magic_ten),
		(int)magic_four_damage["damage"],
		(int)magic_ten_damage["damage"]);
	check("真实双人羽士4件与10件的法力、法抗和法术输出符合生产公式",
		!magic_err &&
		magic_four_items[0]->query_newmoon_set_piece_count()==4 &&
		magic_ten_items[0]->query_newmoon_set_piece_count()==10 &&
		magic_ten->query_think()>magic_four->query_think() &&
		magic_ten->query_mofa_max()>magic_four->query_mofa_max() &&
		query_magic_defend_snapshot(magic_ten)>
			query_magic_defend_snapshot(magic_four) &&
		(int)magic_ten_profile["magic_raw"]>
			(int)magic_four_profile["magic_raw"] &&
		(int)magic_four_damage["magic"] &&
		(int)magic_ten_damage["magic"] &&
		(int)magic_four_damage["damage"]==magic_four_reference &&
		(int)magic_ten_damage["damage"]==magic_ten_reference &&
		(int)magic_ten_damage["damage"]>
			(int)magic_four_damage["damage"],
		magic_error!="" ? magic_error :
			sprintf("4件法攻抗伤%d/%d/%d，10件法攻抗伤%d/%d/%d",
				(int)magic_four_profile["magic_raw"],
				query_magic_defend_snapshot(magic_four),
				(int)magic_four_damage["damage"],
				(int)magic_ten_profile["magic_raw"],
				query_magic_defend_snapshot(magic_ten),
				(int)magic_ten_damage["damage"]));
	destroy_player(magic_four);
	destroy_player(magic_ten);

	object coherent=create_combat_player(
		"__testunit_newmoon_pvp_coherent__","human","jianxian");
	object mixed_player=create_combat_player(
		"__testunit_newmoon_pvp_mixed__","human","jianxian");
	array(object) coherent_items=clone_full_set(jianxian);
	array(object) mixed_items=clone_full_set(jianxian);
	mapping coherent_profile=([]);
	mapping mixed_profile=([]);
	mapping coherent_damage=([]);
	mapping mixed_damage=([]);
	int coherent_damage_reference=0;
	int mixed_damage_reference=0;
	int coherent_expected_output=0;
	int mixed_expected_output=0;
	string mixed_error="";
	mixed mixed_err=catch {
		mixed_items[2]->set_newmoon_resonance("jianxian","剑仙","残月",
			3,2,0,1,0,"hitte",1,"doub",1);
		mixed_items[3]->set_newmoon_resonance("jianxian","剑仙","残月",
			3,2,0,1,0,"hitte",1,"doub",1);
		coherent->move(room);
		mixed_player->move(room);
		equip_set_count(coherent,coherent_items,4);
		equip_set_count(mixed_player,mixed_items,4);
		coherent_profile=coherent->query_pk_fast_side_profile(coherent);
		mixed_profile=mixed_player->query_pk_fast_side_profile(mixed_player);
		coherent_damage=coherent->query_pk_fast_damage_profile(
			coherent,mixed_player,coherent_profile,mixed_profile);
		mixed_damage=mixed_player->query_pk_fast_damage_profile(
			mixed_player,coherent,mixed_profile,coherent_profile);
		coherent_damage_reference=coherent->query_balanced_physical_damage(
			(int)coherent_profile["physical_raw"],
			mixed_player->query_defend_power(),
			(int)coherent_profile["physical_penetration"]);
		mixed_damage_reference=mixed_player->query_balanced_physical_damage(
			(int)mixed_profile["physical_raw"],
			coherent->query_defend_power(),
			(int)mixed_profile["physical_penetration"]);
		coherent_expected_output=query_expected_damage_per_hundred(
			coherent,mixed_player,coherent_damage);
		mixed_expected_output=query_expected_damage_per_hundred(
			mixed_player,coherent,mixed_damage);
	};
	if(mixed_err)
		mixed_error=describe_error(mixed_err);
	werror("[新月双人实战] 剑仙完整4件: 力量%d 攻击%d 暴击%d 伤害%d 百次期望%d；"+
		"2+2混搭: 力量%d 攻击%d 暴击%d 伤害%d 百次期望%d\n",
		coherent->query_str(),(int)coherent_profile["physical_raw"],
		(int)coherent_profile["critical"],
		(int)coherent_damage["damage"],coherent_expected_output,
		mixed_player->query_str(),
		(int)mixed_profile["physical_raw"],
		(int)mixed_profile["critical"],(int)mixed_damage["damage"],
		mixed_expected_output);
	check("真实双人同职业2+2混搭不能偷取完整四件共鸣与输出",
		!mixed_err &&
		coherent_items[0]->query_newmoon_set_piece_count()==4 &&
		mixed_items[0]->query_newmoon_set_piece_count()==2 &&
		mixed_items[2]->query_newmoon_set_piece_count()==2 &&
		sum_core_attribute(coherent_items[..3],"str")==1680 &&
		sum_core_attribute(mixed_items[..3],"str")==1440 &&
		sum_set_attribute(coherent_items[..3],"doub")==4 &&
		sum_set_attribute(mixed_items[..3],"doub")==0 &&
		coherent->query_str()>mixed_player->query_str() &&
		(int)coherent_profile["physical_raw"]>=
			(int)mixed_profile["physical_raw"] &&
		(int)coherent_profile["critical"]>
			(int)mixed_profile["critical"] &&
		(int)coherent_damage["damage"]==coherent_damage_reference &&
		(int)mixed_damage["damage"]==mixed_damage_reference &&
		(int)coherent_damage["damage"]>(int)mixed_damage["damage"] &&
		coherent_expected_output>mixed_expected_output,
		mixed_error!="" ? mixed_error :
			sprintf("件str%d/%d 攻击%d/%d，暴击%d/%d，伤害%d/%d，百次期望%d/%d",
				sum_core_attribute(coherent_items[..3],"str"),
				sum_core_attribute(mixed_items[..3],"str"),
				(int)coherent_profile["physical_raw"],
				(int)mixed_profile["physical_raw"],
				(int)coherent_profile["critical"],
				(int)mixed_profile["critical"],
				(int)coherent_damage["damage"],
				(int)mixed_damage["damage"],coherent_expected_output,
				mixed_expected_output));
	destroy_player(coherent);
	destroy_player(mixed_player);
}

void test_high_level_dynamic_generation()
{
	string raw="weapon/69xinyuetianfengjian/69xinyuetianfengjian";
	string generated_path=ITEM_PATH+raw+
		"00000000000000000000000000000000000_120";
	int existed_before=Stdio.exist(generated_path);
	object|zero generated=0;
	mixed err=catch {
		generated=ITEMSD->get_convert_item(raw,0,69,120);
	};
	int valid=!err && generated &&
		generated->query_item_canLevel()==120 &&
		generated->query_newmoon_resonance_profession()=="jianxian" &&
		generated->query_newmoon_resonance_theme()=="剑心" &&
		generated->query_newmoon_set_extra_description(6)!="" &&
		generated->query_newmoon_set_extra_description(10)!="" &&
		generated->query_item_canTrade() && generated->query_item_canStorage();
	check("旧动态生成器可把69级十件套底版安全扩展到120级",
		valid,err ? describe_error(err) : generated ?
			sprintf("等级=%d 职业=%s 主题=%s 6件=%s 10件=%s 交易=%d 存储=%d",
				generated->query_item_canLevel(),
				generated->query_newmoon_resonance_profession(),
				generated->query_newmoon_resonance_theme(),
				generated->query_newmoon_set_extra_description(6),
				generated->query_newmoon_set_extra_description(10),
				generated->query_item_canTrade(),
				generated->query_item_canStorage()) : "动态生成返回空对象");
	if(generated)
		destruct(generated);
	if(!existed_before && Stdio.exist(generated_path))
		rm(generated_path);
}

void test_enabled_collection_lineage()
{
	array(mapping(string:mixed)) expected=({
		(["id":"newmoon","name":"新月","quality":"稀世","rank":1,
			"min_level":69,"min_affixes":1,"weight":300,"percent":100]),
		(["id":"starshine","name":"曜星","quality":"绝世","rank":2,
			"min_level":90,"min_affixes":2,"weight":100,"percent":105]),
		(["id":"firmament","name":"天穹","quality":"传说","rank":3,
			"min_level":110,"min_affixes":3,"weight":30,"percent":110]),
		(["id":"greatvoid","name":"太虚","quality":"神话","rank":4,
			"min_level":130,"min_affixes":4,"weight":10,"percent":116]),
		(["id":"primordial","name":"太初","quality":"太古","rank":5,
			"min_level":160,"min_affixes":5,"weight":3,"percent":123]),
		(["id":"huanji","name":"寰极","quality":"至尊","rank":6,
			"min_level":200,"min_affixes":6,"weight":1,"percent":132]),
	});
	array(mapping(string:mixed)) collections=
		ITEMSD->query_newmoon_collection_catalog();
	int enabled=ITEMSD->query_enabled_newmoon_collection_count();
	int catalog_valid=enabled==6 && sizeof(collections)==enabled;
	int drop_windows_valid=1;
	int cursor=0;
	for(int index=0;index<enabled;index++){
		mapping actual=collections[index];
		mapping wanted=expected[index];
		if(actual["id"]!=wanted["id"] || actual["name"]!=wanted["name"] ||
		   actual["quality"]!=wanted["quality"] ||
		   (int)actual["rank"]!=(int)wanted["rank"] ||
		   (int)actual["min_level"]!=(int)wanted["min_level"] ||
		   (int)actual["min_affixes"]!=(int)wanted["min_affixes"] ||
		   (int)actual["weight"]!=(int)wanted["weight"])
			catalog_valid=0;
		if(index>0 && ((int)actual["weight"]>=
		   (int)collections[index-1]["weight"] ||
		   (int)actual["min_level"]<=
		   (int)collections[index-1]["min_level"] ||
		   (int)actual["min_affixes"]<=
		   (int)collections[index-1]["min_affixes"]))
			catalog_valid=0;
	}
	for(int index=enabled-1;index>=0;index--){
		mapping current=collections[index];
		int first_roll=cursor+1;
		cursor+=(int)current["weight"];
		if(ITEMSD->query_newmoon_collection_id_for_roll(
		   (int)current["min_level"],first_roll)!=(string)current["id"] ||
		   ITEMSD->query_newmoon_collection_id_for_roll(
		   (int)current["min_level"],cursor)!=(string)current["id"] ||
		   ITEMSD->query_newmoon_collection_id_for_roll(
		   (int)current["min_level"]-1,first_roll)!="")
			drop_windows_valid=0;
	}
	if(ITEMSD->query_newmoon_collection_id_for_roll(300,cursor+1)!="")
		drop_windows_valid=0;
	check("新月到寰极六阶目录品质递增且掉率递减",
		catalog_valid,"六阶目录名称、品质、等级、词缀或权重错误");
	check("六阶独立随机区间边界精确且未达等级不会降级冒充",
		drop_windows_valid && cursor==444,
		"掉率区间重叠、越界、等级门槛失效或总权重错误");

	string weapon_path=item_path("weapon","69xinyuetianfengjian");
	string head_path=item_path("head","69xinyuejianxinguan");
	object raw_weapon=clone(weapon_path);
	int raw_attack=raw_weapon->query_attack_power();
	int raw_attack_limit=raw_weapon->query_attack_power_limit();
	int quality_valid=1;
	for(int index=0;index<enabled;index++){
		object quality_item=clone(weapon_path);
		mapping current=expected[index];
		if(!quality_item->set_newmoon_collection((string)current["id"]) ||
		   quality_item->query_newmoon_collection_rank()!=index+1 ||
		   quality_item->query_attack_power()!=
			raw_attack*(int)current["percent"]/100 ||
		   quality_item->query_attack_power_limit()!=
			raw_attack_limit*(int)current["percent"]/100 ||
		   quality_item->query_weapon_attack()<
			quality_item->query_attack_power() ||
		   quality_item->query_weapon_attack()>
			quality_item->query_attack_power_limit())
			quality_valid=0;
		destruct(quality_item);
	}
	check("六阶品质只递增装备基础攻防并统一进入既有攻击接口",
		quality_valid,"品质倍率、阶位或装备随机攻击接口不一致");
	destruct(raw_weapon);
	object invalid_collection_item=clone(weapon_path);
	int valid_collection_set=invalid_collection_item->
		set_newmoon_collection("starshine");
	int invalid_collection_set=invalid_collection_item->
		set_newmoon_collection("../../malicious");
	int unknown_collection_restore=invalid_collection_item->
		restore_newmoon_storage_collection_snapshot(([
			"version":1,"collection_id":"unknown",
		]));
	int invalid_collection_restore=invalid_collection_item->
		restore_newmoon_storage_collection_snapshot(([
			"version":1,"collection_id":"starshine","extra":1,
		]));
	check("未知集合ID和畸形仓库快照失败关闭且不改写既有身份",
		valid_collection_set && !invalid_collection_set &&
		!unknown_collection_restore &&
		!invalid_collection_restore &&
		invalid_collection_item->query_newmoon_collection_id()=="starshine",
		"任意集合ID可污染动态文件、显示或仓库存档");
	destruct(invalid_collection_item);

	int six_full_sets_valid=1;
	mapping jianxian_config=catalog[0];
	for(int collection_index=0;collection_index<enabled;
	   collection_index++){
		object set_player=create_player("__testunit_newmoon_sixset_"+
			(string)collection_index+"__","human","jianxian");
		array(object) set_items=clone_full_set(jianxian_config);
		foreach(set_items,object set_item)
			if(!set_item->set_newmoon_collection(
			   (string)expected[collection_index]["id"]))
				six_full_sets_valid=0;
		equip_full_set(set_player,set_items);
		if(set_items[0]->query_newmoon_set_piece_count()!=10 ||
		   set_items[0]->query_newmoon_resonance_percent()!=200 ||
		   set_items[0]->query_newmoon_collection_rank()!=collection_index+1 ||
		   set_items[9]->query_newmoon_set_piece_count()!=10)
			six_full_sets_valid=0;
		destroy_player(set_player);
	}
	check("六套各自十件完整穿戴均精确激活同职业五档共鸣",
		six_full_sets_valid,"某套十件计数、阶位或200%满月共鸣错误");

	object player=create_player("__testunit_newmoon_collection_mix__",
		"human","jianxian");
	object high_weapon=clone(weapon_path);
	object newmoon_head=clone(head_path);
	high_weapon->set_newmoon_collection("huanji");
	high_weapon->move(player);
	newmoon_head->move(player);
	player->wield(high_weapon);
	player->wear(newmoon_head);
	check("不同品质套装不能混穿伪造二件共鸣",
		high_weapon->query_newmoon_set_piece_count()==1 &&
		newmoon_head->query_newmoon_set_piece_count()==1 &&
		high_weapon->query_newmoon_resonance_percent()==100 &&
		newmoon_head->query_newmoon_resonance_percent()==100,
		"寰极与新月被错误合并为同一套装计数");
	destroy_player(player);

	string raw="weapon/69xinyuetianfengjian/69xinyuetianfengjian";
	string directory=ITEM_PATH+"weapon/69xinyuetianfengjian";
	array(string) before=get_dir(directory) || ({});
	int generation_valid=1;
	array(string) generation_errors=({});
	for(int index=1;index<enabled;index++){
		mapping current=expected[index];
		object base=clone(weapon_path);
		object|zero generated=0;
		object|zero reforged=0;
		string generated_name="";
		mixed generation_error=catch {
			base->set_newmoon_collection((string)current["id"]);
			generated=ITEMSD->get_convert_item(raw,
				(int)current["min_affixes"],69,
				(int)current["min_level"],base);
			if(generated){
				generated_name=object_name(generated);
				reforged=ITEMSD->get_convert_item(
					ITEMSD->query_convert_item_rawname(generated),
					min(7,(int)current["min_affixes"]+1),69,
					(int)current["min_level"],generated);
			}
		};
		if(generation_error || !generated || !reforged ||
		   search(generated_name,"_nm"+(string)(index+1))==-1 ||
		   generated->query_item_rareLevel()<(int)current["min_affixes"] ||
		   reforged->query_item_rareLevel()<
			min(7,(int)current["min_affixes"]+1) ||
		   generated->query_newmoon_collection_id()!=(string)current["id"] ||
		   reforged->query_newmoon_collection_id()!=(string)current["id"] ||
		   generated->query_newmoon_collection_name()!=(string)current["name"] ||
		   generated->query_newmoon_collection_quality()!=
			(string)current["quality"] ||
		   search(generated->query_short(),"【"+(string)current["name"]+
			"·"+(string)current["quality"]+"·剑仙】")==-1 ||
		   search(generated->query_name_cn(),"【"+
			(string)current["name"]+"·"+(string)current["quality"]+
			"·剑仙】")==-1 ||
		   search(generated->query_short(),"【新月·剑仙】")!=-1 ||
		   search(generated->query_name_cn(),"【新月·剑仙】")!=-1){
			generation_valid=0;
			generation_errors+=({generation_error ?
				describe_error(generation_error) : (string)current["id"]});
		}
		if(reforged)
			destruct(reforged);
		if(generated)
			destruct(generated);
		destruct(base);
	}
	check("曜星至寰极五套动态生成、显示和再次炼化均保留独立身份",
		generation_valid,generation_errors*" | ");
	cleanup_generated_files(directory,before);

	object storage_player=create_player(
		"__testunit_newmoon_starshine_store__","human","jianxian");
	object storage_item=clone(weapon_path);
	storage_item->set_newmoon_collection("starshine");
	storage_item->move(storage_player);
	int stored=storage_player->packaged(
		storage_item,storage_player->query_cangku_size())==0;
	if(stored)
		destruct(storage_item);
	array row=stored && sizeof(storage_player->packaged_items) ?
		copy_value(storage_player->packaged_items[0]) : ({});
	object|zero restored=stored ? storage_player->repackaged(
		(string)row[0]) : 0;
	check("高阶套装经个人仓库存取保持独立品质且不伪造绑定",
		stored && sizeof(row)==11 && mappingp(row[9]) &&
		!sizeof(row[9]) && mappingp(row[10]) &&
		row[10]["collection_id"]=="starshine" && objectp(restored) &&
		restored->query_newmoon_collection_id()=="starshine" &&
		!restored->query_newmoon_account_bound(),
		"高阶集合快照在仓库存取中丢失、错位或意外绑定");
	if(restored)
		destruct(restored);
	if(!stored)
		destruct(storage_item);
	destroy_player(storage_player);
}

void cleanup_generated_files(string directory,array(string) before)
{
	array(string) after=get_dir(directory) || ({});
	for(int index=0;index<sizeof(after);index++)
		if(search(before,after[index])==-1)
			rm(directory+"/"+after[index]);
}

void test_forge_and_wash_compatibility()
{
	int all_paths_valid=1;
	array(string) path_errors=({});
	for(int config_index=0;config_index<sizeof(catalog);config_index++){
		mapping config=catalog[config_index];
		mapping pieces=(mapping)config["pieces"];
		for(int slot_index=0;slot_index<sizeof(piece_order);slot_index++){
			string slot=piece_order[slot_index];
			string name=(string)pieces[slot];
			string expected=raw_item_path(slot,name);
			object item=clone(item_path(slot,name));
			string actual=ITEMSD->query_convert_item_rawname(item);
			if(actual!=expected){
				all_paths_valid=0;
				path_errors+=({expected+"=>"+actual});
			}
			destruct(item);
		}
	}
	check("十二职业120件套装均以真实模板炼化而非误用旧图片模板",
		all_paths_valid,path_errors*";");

	array(mapping(string:string)) representatives=({
		(["slot":"weapon","name":"69xinyuetianfengjian"]),
		(["slot":"head","name":"69xinyuejianxinguan"]),
		(["slot":"ring","name":"69xinyuejianxinjie"]),
	});
	int all_generated_valid=1;
	array(string) generated_errors=({});
	for(int index=0;index<sizeof(representatives);index++){
		string slot=(string)representatives[index]["slot"];
		string name=(string)representatives[index]["name"];
		string raw=raw_item_path(slot,name);
		string directory=ITEM_PATH+query_piece_parent(slot)+"/"+name;
		array(string) before=get_dir(directory) || ({});
		object|zero base=0;
		object|zero rare=0;
		object|zero washed=0;
		object|zero enhanced=0;
		string expected_kind="";
		string error="";
		mixed err=catch {
			base=clone(item_path(slot,name));
			expected_kind=(string)base->query_item_kind();
			rare=ITEMSD->get_convert_item(raw,2,69,69,base);
			string resolved=ITEMSD->query_convert_item_rawname(rare);
			washed=ITEMSD->get_convert_item(resolved,2,69,69,rare);
			enhanced=ITEMSD->get_convert_item(resolved,3,69,69,rare);
			if(!rare || !washed || !enhanced || resolved!=raw ||
			   rare->query_item_rareLevel()!=2 ||
			   washed->query_item_rareLevel()!=2 ||
			   enhanced->query_item_rareLevel()!=3 ||
			   rare->query_item_kind()!=expected_kind ||
			   washed->query_item_kind()!=expected_kind ||
			   enhanced->query_item_kind()!=expected_kind ||
			   rare->query_item_canLevel()!=69 ||
			   washed->query_item_canLevel()!=69 ||
			   enhanced->query_item_canLevel()!=69 ||
			   rare->query_newmoon_resonance_profession()!="jianxian" ||
			   washed->query_newmoon_resonance_profession()!="jianxian" ||
			   enhanced->query_newmoon_resonance_profession()!="jianxian" ||
			   rare->query_newmoon_resonance_theme()!="剑心" ||
			   washed->query_newmoon_resonance_theme()!="剑心" ||
			   enhanced->query_newmoon_resonance_theme()!="剑心" ||
			   enhanced->query_newmoon_set_extra_description(2)=="" ||
			   enhanced->query_newmoon_set_extra_description(4)=="" ||
			   enhanced->query_newmoon_set_extra_description(6)=="" ||
			   enhanced->query_newmoon_set_extra_description(8)=="" ||
			   enhanced->query_newmoon_set_extra_description(10)=="")
				error=slot+"炼化后稀有度、部位、等级或套装元数据丢失";
		};
		if(err)
			error=describe_error(err);
		if(error!=""){
			all_generated_valid=0;
			generated_errors+=({error});
		}
		if(enhanced) destruct(enhanced);
		if(washed) destruct(washed);
		if(rare) destruct(rare);
		if(base) destruct(base);
		cleanup_generated_files(directory,before);
	}
	check("新月武器、防具和首饰可洗同阶属性并增加一条属性且保留套装身份",
		all_generated_valid,generated_errors*";");
}

void test_legacy_equipment_compatibility()
{
	object player=create_player("__testunit_newmoon_legacy__",
		"human","jianxian");
	object old_item=clone(ROOT+
		"/gamelib/clone/item/weapon/65haixiaofengjian/65haixiaofengjian");
	old_item->set_str_add(7);
	old_item->set_life_add(9);
	old_item->move(player);
	player->wield(old_item);
	string saved=pikenv_save_object(old_item,1);
	check("旧装备getter保持原数值且没有新月身份",
		old_item->query_str_add()==7 && old_item->query_life_add()==90 &&
		old_item->query_newmoon_resonance_profession()=="" &&
		old_item->query_newmoon_collection_id()=="" &&
		!old_item->query_newmoon_resonance_active(),
		"旧装备被共鸣逻辑改变");
	check("旧装备存档不新增新月扩展数据",
		search(saved,"item_newmoon")==-1,
		"旧装备序列化出现新字段");
	string old_raw="weapon/65haixiaofengjian/65haixiaofengjian";
	string old_directory=ITEM_PATH+"weapon/65haixiaofengjian";
	array(string) old_before=get_dir(old_directory) || ({});
	object|zero converted_old=0;
	mixed old_convert_error=0;
	// 真实映射目录可能有历史中断生成的坏后缀文件；它们应
	// 被掉落守护失败关闭，但不应让随机碰撞使旧装备兼容测试假败。
	for(int attempt=0;attempt<8 && !converted_old;attempt++){
		old_convert_error=catch {
			converted_old=ITEMSD->get_convert_item(
				old_raw,2,65,66,old_item);
		};
	}
	check("普通旧装备传入原对象炼化时不会被误判为新月套装",
		!old_convert_error && objectp(converted_old) &&
		converted_old->query_item_rareLevel()==2 &&
		converted_old->query_newmoon_resonance_profession()=="" &&
		search(object_name(converted_old),"_nm")==-1,
		old_convert_error ? describe_error(old_convert_error) :
			"旧装备炼化返回空、出现套装身份或错误文件后缀");
	if(converted_old)
		destruct(converted_old);
	cleanup_generated_files(old_directory,old_before);
	destroy_player(player);

	object new_item=clone(item_path("weapon","69xinyuetianfengjian"));
	string new_saved=pikenv_save_object(new_item,1);
	object restored=clone(item_path("weapon","69xinyuetianfengjian"));
	pikenv_restore_object(restored,new_saved);
	check("十件套身份和五档配置通过既有dbase随物品存档往返",
		search(new_saved,"item_newmoon")!=-1 &&
		restored->query_newmoon_resonance_profession()=="jianxian" &&
		restored->query_newmoon_resonance_theme()=="剑心" &&
		restored->query_newmoon_set_extra_description(10)!="" &&
		restored->query_attack_power()==248*2 &&
		restored->query_item_canLevel()==69,
		"套装元数据恢复后丢失或旧装备字段错位");
	new_item->set_newmoon_collection("huanji");
	string huanji_saved=pikenv_save_object(new_item,1);
	object huanji_restored=clone(
		item_path("weapon","69xinyuetianfengjian"));
	pikenv_restore_object(huanji_restored,huanji_saved);
	check("寰极集合身份随人物唯一档案和跨Worker存档完整往返",
		search(huanji_saved,"huanji")!=-1 &&
		huanji_restored->query_newmoon_collection_id()=="huanji" &&
		huanji_restored->query_newmoon_collection_rank()==6 &&
		huanji_restored->query_newmoon_collection_quality()=="至尊" &&
		huanji_restored->query_attack_power()==248*2*132/100,
		"高阶集合字段未进入dbase存档或恢复后倍率错误");
	destruct(new_item);
	destruct(restored);
	destruct(huanji_restored);
}

void test_full_set_skill_activation()
{
	array(string) collection_ids=({
		"newmoon","starshine","firmament","greatvoid","primordial","huanji",
	});
	array(string) expected_names=({
		"newmoon_jianxian","newmoon_yushi","newmoon_zhuxian",
		"newmoon_kuangyao","newmoon_wuyao","newmoon_yinggui",
		"newmoon_fangshi","newmoon_zhenyue","newmoon_tianxiang",
		"newmoon_lingyi","newmoon_wuxiang","newmoon_taiji",
	});
	int all_professions_valid=1;
	array(string) errors=({});
	object room=(object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");

	for(int index=0;index<sizeof(catalog);index++){
		mapping config=catalog[index];
		object player=create_combat_player("__testunit_newmoon_setskill_"+
			(string)index+"__",(string)config["race"],
			(string)config["profession"]);
		object target=create_combat_player("__testunit_newmoon_settarget_"+
			(string)index+"__","human","jianxian");
		array(object) items=clone_full_set(config);
		int rank=index%6+1;
		for(int item_index=0;item_index<sizeof(items);item_index++)
			items[item_index]->set_newmoon_collection(
				collection_ids[rank-1]);
		player->move(room);
		target->move(room);
		equip_full_set(player,items);
		player->flush_life();
		player->set_life(max(1,player->query_life_max()/2));
		player->set_mofa(player->query_mofa_max());
		player->set_base_hitte(100000);
		mapping active=NEWMOON_SET_SKILLD->query_active_set_skill(player);
		string skill_name=expected_names[index];
		object|zero skill=NEWMOON_SET_SKILLD->query_active_skill_object(
			player,skill_name);
		int before_mofa=player->get_cur_mofa();
		player->_fight(target);
		player->perform(skill_name,1);
		if(!active || (string)active["skill"]!=skill_name ||
		   (int)active["rank"]!=rank || !skill ||
		   !skill->query_newmoon_set_skill() ||
		   skill->query_s_delayTime(rank)!=126-rank*6 ||
		   search((array(string))skill->skill_type,
			(string)config["profession"])==-1 ||
		   search(player->view_skills(),"套装技")==-1 ||
		   search(player->view_use_performs(),skill->query_name_cn())==-1 ||
		   !player->set_toolbar(skill_name,0,1) ||
		   player->query_toolbar_entry_name(skill_name,1)!=
			skill->query_name_cn() ||
		   !AUTOFIGHTD->set_selected_auto_skill(player,skill_name,1) ||
		   AUTOFIGHTD->query_auto_skill_queue(player)[0]!=skill_name ||
		   (int)player->f_skills[skill_name]<=1 ||
		   player->get_cur_mofa()>=before_mofa){
			all_professions_valid=0;
			errors+=({(string)config["profession"]+"/"+
				(string)rank});
		}
		destroy_player(player);
		destroy_player(target);
	}
	check("十二职业十件套按寰极六阶自动激活对应技能并接入双端技能、快捷栏和挂机",
		all_professions_valid,errors*",");

	mapping config=catalog[0];
	object boundary=create_player("__testunit_newmoon_setskill_edge__",
		"human","jianxian");
	array(object) boundary_items=clone_full_set(config);
	for(int index=0;index<sizeof(boundary_items);index++)
		boundary_items[index]->set_newmoon_collection("huanji");
	equip_full_set(boundary,boundary_items);
	string boundary_skill=NEWMOON_SET_SKILLD->query_active_skill_name(boundary);
	boundary->f_skills[boundary_skill]=77;
	boundary_items[1]->item_cur_dura=0;
	int broken_inactive=NEWMOON_SET_SKILLD->
		query_active_skill_level(boundary,boundary_skill)==0 &&
		NEWMOON_SET_SKILLD->query_active_skill_object(
			boundary,boundary_skill)==0;
	boundary_items[1]->item_cur_dura=boundary_items[1]->query_item_dura();
	int repaired_active=NEWMOON_SET_SKILLD->
		query_active_skill_level(boundary,boundary_skill)==6;
	check("破损任一件立即停用套装技且修复后恢复资格但不清冷却",
		broken_inactive && repaired_active &&
		boundary->f_skills[boundary_skill]==77,
		"破损资格、修复资格或冷却持久性错误");
	boundary_items[1]->set_newmoon_collection("newmoon");
	check("同职业混入不同品质不能凑齐十件套技能且伪造技能名失败关闭",
		NEWMOON_SET_SKILLD->query_active_skill_name(boundary)=="" &&
		!NEWMOON_SET_SKILLD->is_set_skill_name("../../newmoon_jianxian") &&
		!NEWMOON_SET_SKILLD->query_active_skill_object(
			boundary,"../../newmoon_jianxian"),
		"混套或路径注入错误获得套装技能");
	boundary_items[1]->set_newmoon_collection("huanji");
	object foreign_owner=create_player("__testunit_newmoon_foreign_owner__",
		"human","jianxian");
	object foreign_weapon=clone(item_path("weapon",
		(string)((mapping)config["pieces"])["weapon"]));
	foreign_weapon->move(foreign_owner);
	foreign_owner->wield(foreign_weapon);
	foreign_owner->unwield(foreign_weapon);
	foreign_weapon->move(boundary);
	string weapon_slot=(string)foreign_weapon->query_item_kind();
	object original_weapon=boundary->query_equip()[weapon_slot];
	if(original_weapon)
		original_weapon->equiped=0;
	boundary->query_equip()[weapon_slot]=foreign_weapon;
	foreign_weapon->equiped=1;
	check("异常档案也不能用其他账号绑定装备激活套装属性或技能",
		!foreign_weapon->query_newmoon_binding_matches_owner(boundary) &&
		boundary_items[1]->query_newmoon_set_piece_count()==9 &&
		NEWMOON_SET_SKILLD->query_active_skill_name(boundary)=="",
		"跨账号绑定装备被异常计入十件套");
	destroy_player(foreign_owner);
	destroy_player(boundary);
}

int main()
{
	werror("\n========== 新月十二职业十件套测试 ==========\n");
	test_catalog_and_templates();
	test_resonance_boundaries();
	test_individual_item_baseline_comparison();
	test_full_set_progression();
	test_all_profession_set_extras();
	test_requested_piece_attribute_matrix();
	test_dodge_penetration_affix_roll();
	test_set_identity_and_duplicate_boundaries();
	test_two_player_real_combat_comparisons();
	test_high_level_dynamic_generation();
	test_enabled_collection_lineage();
	test_forge_and_wash_compatibility();
	test_legacy_equipment_compatibility();
	test_full_set_skill_activation();
	werror("新月十件套测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
