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
		"dusu_defend_add","all_mofa_defend_add",
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
	array(string) errors=({});

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
				if(item->query_attack_power()<170 ||
				   item->query_attack_power_limit()<
					item->query_attack_power() ||
				   item->query_attack_power_limit()>420)
					budget_valid=0;
			}
			else if(query_piece_parent(slot)=="armor"){
				if(item->query_item_type()!="armor" ||
				   item->query_item_kind()!=query_expected_kind(slot))
					slot_valid=0;
				if(item->query_equip_defend()<190 ||
				   item->query_equip_defend()>720)
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
				foreach(profile_parts[1]/",",string attribute_spec){
					array(string) attribute_parts=attribute_spec/":";
					if(attribute_spec=="")
						continue;
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
	check("全部底版等级、流通能力、主题与职业元数据完整",
		metadata_valid,"某件装备元数据不完整");
	check("十件套覆盖主武器、六防具与三首饰且槽位不冲突",
		slot_valid,"存在错误的装备类型或部位");
	check("69级武器与六防具白板攻防保持在旧装备预算区间",
		budget_valid,"存在异常放大的基础攻防");
	check("120件底版在掉落登记和随机词缀表中各出现一次",
		profile_valid,"登记表或词缀表存在缺项或重复");
	check("十件套词缀均受生成器支持且没有非武器攻击词缀",
		effective_profile_valid,"发现无效、反向或错槽词缀");
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
			item->query_str_add()==bonus[0] &&
			item->query_dex_add()==bonus[1] &&
			item->query_think_add()==bonus[2] &&
			item->query_life_add()==bonus[3]*10 &&
			item->query_mofa_add()==bonus[4]*10;
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

void test_full_set_progression()
{
	mapping config=catalog[0];
	object player=create_player("__testunit_newmoon_progress__",
		"human","jianxian");
	array(object) items=clone_full_set(config);
	array(int) milestones=({1,2,4,6,8,10});
	array(int) expected_percent=({100,120,140,160,180,200});
	array(int) expected_strength=({3,6,16,24,40,60});
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
		search(detail,"【套装·新月·剑仙·剑心】(10/10)")!=-1 &&
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
		broken_strength==45 && sum_set_attribute(items,"all")==0,
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
				int expected=checkpoint*((int)bonus[bonus_index]*percent/100)*factor;
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
		sum_core_attribute(coherent_items[..3],"str")==16 &&
		sum_core_attribute(mixed_items[..3],"str")==12 &&
		sum_set_attribute(coherent_items[..3],"doub")==4 &&
		sum_set_attribute(mixed_items[..3],"doub")==0 &&
		coherent->query_str()>mixed_player->query_str() &&
		(int)coherent_profile["physical_raw"]>
			(int)mixed_profile["physical_raw"] &&
		(int)coherent_profile["critical"]>
			(int)mixed_profile["critical"] &&
		(int)coherent_damage["damage"]==coherent_damage_reference &&
		(int)mixed_damage["damage"]==mixed_damage_reference &&
		coherent_expected_output>mixed_expected_output,
		mixed_error!="" ? mixed_error :
			sprintf("完整/混搭攻击%d/%d，暴击%d/%d，伤害%d/%d，百次期望%d/%d",
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
		valid,err ? describe_error(err) : "高等级装备套装元数据丢失");
	if(generated)
		destruct(generated);
	if(!existed_before && Stdio.exist(generated_path))
		rm(generated_path);
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
		!old_item->query_newmoon_resonance_active(),
		"旧装备被共鸣逻辑改变");
	check("旧装备存档不新增新月扩展数据",
		search(saved,"item_newmoon")==-1,
		"旧装备序列化出现新字段");
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
		restored->query_attack_power()==248 &&
		restored->query_item_canLevel()==69,
		"套装元数据恢复后丢失或旧装备字段错位");
	destruct(new_item);
	destruct(restored);
}

int main()
{
	werror("\n========== 新月十二职业十件套测试 ==========\n");
	test_catalog_and_templates();
	test_resonance_boundaries();
	test_full_set_progression();
	test_all_profession_set_extras();
	test_requested_piece_attribute_matrix();
	test_set_identity_and_duplicate_boundaries();
	test_two_player_real_combat_comparisons();
	test_high_level_dynamic_generation();
	test_legacy_equipment_compatibility();
	werror("新月十件套测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
