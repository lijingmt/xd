#!/usr/bin/env pike
/** 新月十二职业装备底版、职业共鸣和旧装备兼容回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

array(mapping(string:mixed)) catalog=({
	(["profession":"jianxian","race":"human","profession_cn":"剑仙",
		"weapon":"69xinyuetianfengjian","armor":"69xinyuetianfengzhanyi",
		"jewelry":"69xinyuejianxinyujue","bonus":({3,2,0,1,0}),
		"two_attr":"hitte","two_value":1,
		"three_attr":"doub","three_value":1]),
	(["profession":"yushi","race":"human","profession_cn":"羽士",
		"weapon":"69xinyueyaoyulingzhang","armor":"69xinyuexingyufapao",
		"jewelry":"69xinyueyaolingzhui","bonus":({0,1,4,0,3}),
		"two_attr":"mofa_all","two_value":4,
		"three_attr":"rase_mofa_add","three_value":1]),
	(["profession":"zhuxian","race":"human","profession_cn":"诛仙",
		"weapon":"69xinyuezhuihunren","armor":"69xinyuezhuyingyi",
		"jewelry":"69xinyuejueyinghuan","bonus":({1,4,0,1,0}),
		"two_attr":"hitte","two_value":1,
		"three_attr":"doub","three_value":1]),
	(["profession":"kuangyao","race":"monst","profession_cn":"狂妖",
		"weapon":"69xinyuelieyueshuangren","armor":"69xinyuexuezhanjia",
		"jewelry":"69xinyuekuanglanzhui","bonus":({4,1,0,4,0}),
		"two_attr":"doub","two_value":1,
		"three_attr":"rase_life_add","three_value":1]),
	(["profession":"wuyao","race":"monst","profession_cn":"巫妖",
		"weapon":"69xinyueshiguhunzhang","armor":"69xinyueyouzhoubao",
		"jewelry":"69xinyuewuhunpei","bonus":({0,1,4,1,3}),
		"two_attr":"mofa_all","two_value":4,
		"three_attr":"all_mofa_defend","three_value":4]),
	(["profession":"yinggui","race":"monst","profession_cn":"影鬼",
		"weapon":"69xinyueyexingguiren","armor":"69xinyuewujiyi",
		"jewelry":"69xinyueyingpohuan","bonus":({0,4,0,1,0}),
		"two_attr":"dodge","two_value":1,
		"three_attr":"doub","three_value":1]),
	(["profession":"fangshi","race":"third","profession_cn":"方士",
		"weapon":"69xinyuewanxiangfachi","armor":"69xinyuewuxingfayi",
		"jewelry":"69xinyuetianjiyin","bonus":({1,1,4,1,2}),
		"two_attr":"all","two_value":1,
		"three_attr":"mofa_all","three_value":3]),
	(["profession":"zhenyue","race":"third","profession_cn":"镇越",
		"weapon":"69xinyueshanhezhongjian","armor":"69xinyuebudongshanjia",
		"jewelry":"69xinyuezhenyueyin","bonus":({4,0,0,5,0}),
		"two_attr":"defend","two_value":2,
		"three_attr":"all_mofa_defend","three_value":4]),
	(["profession":"tianxiang","race":"third","profession_cn":"天象",
		"weapon":"69xinyuezhoutianxingzhang","armor":"69xinyuexingluofapao",
		"jewelry":"69xinyuetianshupan","bonus":({0,1,4,0,3}),
		"two_attr":"mofa_all","two_value":4,
		"three_attr":"lunck","three_value":2]),
	(["profession":"lingyi","race":"third","profession_cn":"灵医",
		"weapon":"69xinyuehuichunlingzhang","armor":"69xinyuebaicaofayi",
		"jewelry":"69xinyuechangshengpei","bonus":({0,1,4,4,4}),
		"two_attr":"rase_life_add","two_value":1,
		"three_attr":"rase_mofa_add","three_value":1]),
	(["profession":"wuxiang","race":"third","profession_cn":"无相",
		"weapon":"69xinyuewanfaguiyijian","armor":"69xinyuewuxiangxuanyi",
		"jewelry":"69xinyuehunyuanjing","bonus":({2,2,2,2,2}),
		"two_attr":"all","two_value":1,
		"three_attr":"all_mofa_defend","three_value":3]),
	(["profession":"taiji","race":"third","profession_cn":"太极",
		"weapon":"69xinyueliangyijian","armor":"69xinyuetaijidaopao",
		"jewelry":"69xinyueyinyangyupei","bonus":({3,3,3,3,3}),
		"two_attr":"all","two_value":1,
		"three_attr":"all_mofa_defend","three_value":4]),
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

string item_path(string kind,string name)
{
	return ROOT+"/gamelib/clone/item/"+kind+"/"+name+"/"+name;
}

void cleanup_player_files(string name)
{
	if(!name || !has_prefix(name,"__testunit_newmoon_"))
		return;
	string path=DATA_ROOT+"u/"+name[sizeof(name)-2..]+"/"+name+".o";
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_player(string name,string race,string profession)
{
	cleanup_player_files(name);
	object player=clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn="新月装备测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profession);
	player->level=120;
	return player;
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

void destroy_player(object|zero player)
{
	if(!player)
		return;
	string name=(string)player->query_name();
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
	cleanup_player_files(name);
}

void test_catalog_and_templates()
{
	string org=Stdio.read_file(ROOT+"/gamelib/data/orgItems.list") || "";
	string attrs=Stdio.read_file(ROOT+"/gamelib/data/allItems.list") || "";
	string level_line="";
	foreach(org/"\n",string line)
		if(has_prefix(line,"69|"))
			level_line=line;
	array(string) registered=({});
	if(sizeof(level_line))
		registered=(level_line[3..]/",")-({""});
	mapping(string:int) unique_registered=([]);
	foreach(registered,string raw_name)
		unique_registered[raw_name]=1;
	check("69级新月底版只登记十二职业三件套共36件",
		sizeof(registered)==36 && sizeof(unique_registered)==36,
		sprintf("登记数=%d，去重后=%d",sizeof(registered),
			sizeof(unique_registered)));

	int compiled=1;
	int metadata_valid=1;
	int profile_valid=1;
	int effective_profile_valid=1;
	int image_valid=1;
	int slot_valid=1;
	int budget_valid=1;
	array(string) errors=({});
	foreach(catalog,mapping config){
		foreach(({"weapon","armor","jewelry"}),string kind){
			string name=(string)config[kind];
			string path=item_path(kind,name);
			object|zero item=0;
			mixed err=catch { item=clone(path); };
			if(err || !item){
				compiled=0;
				errors+=({kind+"/"+name});
				continue;
			}
			array(string) limits=item->query_item_profeLimit();
			if(item->query_item_canLevel()!=69 ||
			   item->query_newmoon_resonance_profession()!=config["profession"] ||
			   search(limits,(string)config["profession"])==-1 ||
			   !item->query_item_canDrop() || !item->query_item_canTrade() ||
			   !item->query_item_canSend() || !item->query_item_canStorage())
				metadata_valid=0;
			if(kind=="weapon"){
				if(search(({"weapon","single_weapon","double_weapon"}),
				   (string)item->query_item_type())==-1 ||
				   search(({"single_main_weapon","double_main_weapon"}),
				   (string)item->query_item_kind())==-1)
					slot_valid=0;
				if(item->query_attack_power()<170 ||
				   item->query_attack_power_limit()<item->query_attack_power() ||
				   item->query_attack_power_limit()>420)
					budget_valid=0;
			}
			else if(kind=="armor"){
				if(item->query_item_type()!="armor" ||
				   item->query_item_kind()!="armor_cloth")
					slot_valid=0;
				if(item->query_equip_defend()<200 ||
				   item->query_equip_defend()>720)
					budget_valid=0;
			}
			else if(item->query_item_type()!="jewelry" ||
			        item->query_item_kind()!="jewelry_neck")
				slot_valid=0;
			string raw=(kind+"/"+name+"/"+name);
			if(search(level_line,raw)==-1 ||
			   search(attrs,raw+"|")==-1)
				profile_valid=0;
			foreach(attrs/"\n",string profile_line){
				if(!has_prefix(profile_line,raw+"|"))
					continue;
				array(string) profile_parts=profile_line/"|";
				if(sizeof(profile_parts)<2){
					effective_profile_valid=0;
					continue;
				}
				foreach(profile_parts[1]/",",string attribute_spec){
					array(string) attribute_parts=attribute_spec/":";
					string attribute=sizeof(attribute_parts) ?
						attribute_parts[0] : "";
					if(attribute=="recive_add" || attribute=="back_add" ||
					   (kind!="weapon" &&
					    (attribute=="attack_add" ||
					     attribute=="weapon_attack_add")))
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
	check("36件底版均可在游戏环境编译克隆",compiled,errors*",");
	check("全部底版等级、流通能力与职业元数据完整",
		metadata_valid,"某件装备元数据不完整");
	check("武器、衣服与项链使用既有且互不冲突的装备槽",
		slot_valid,"存在错误的装备类型或部位");
	check("69级武器和衣服的白板攻防保持在旧装备预算区间",
		budget_valid,"存在异常放大的基础攻防");
	check("每件底版同时进入掉落登记与随机词缀表",
		profile_valid,"登记表或词缀表缺项");
	check("新月随机词缀按装备槽使用战斗主链真实消费的字段",
		effective_profile_valid,"发现仅生成但实战不消费的词缀");
	check("新装备复用的原创资源在源码与Web树均可加载",
		image_valid,"存在缺失图片");
}

void test_resonance_boundaries()
{
	int all_valid=1;
	array(string) errors=({});
	for(int index=0;index<sizeof(catalog);index++){
		mapping config=catalog[index];
		string player_name="__testunit_newmoon_"+index+"__";
		object player=create_player(player_name,
			(string)config["race"],(string)config["profession"]);
		object item=clone(item_path("weapon",(string)config["weapon"]));
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

	object wrong=create_player("__testunit_newmoon_wrong__",
		"human","jianxian");
	object other=clone(item_path("weapon","69xinyueyaoyulingzhang"));
	object other_armor=clone(item_path("armor","69xinyuexingyufapao"));
	object other_jewelry=clone(item_path("jewelry","69xinyueyaolingzhui"));
	other->move(wrong);
	other_armor->move(wrong);
	other_jewelry->move(wrong);
	wrong->wield(other);
	wrong->wear(other_armor);
	wrong->wear(other_jewelry);
	check("跨职业持有不能激活其他职业共鸣",
		!other->query_newmoon_resonance_active() &&
		other->query_think_add()==0 && other->query_mofa_add()==0,
		"羽士共鸣错误作用于剑仙");
	object|zero original_player=this_player();
	set_this_player(wrong);
	string wrong_detail=other->query_content();
	set_this_player(original_player);
	check("跨职业凑齐三件时详情也不能误报已激活",
		search(wrong_detail,"职业契合且穿戴后激活")!=-1 &&
		search(wrong_detail,"（已激活）")==-1,
		"不契合职业的套装详情错误显示已激活");
	destroy_player(wrong);
}

void test_set_progression()
{
	object player=create_player("__testunit_newmoon_set__",
		"human","jianxian");
	object weapon=clone(item_path("weapon","69xinyuetianfengjian"));
	object armor=clone(item_path("armor","69xinyuetianfengzhanyi"));
	object jewelry=clone(item_path("jewelry","69xinyuejianxinyujue"));
	weapon->move(player);
	armor->move(player);
	jewelry->move(player);
	player->wield(weapon);
	int one_piece=weapon->query_str_add();
	player->wear(armor);
	int two_piece=weapon->query_str_add()+armor->query_str_add();
	int two_piece_hitte=weapon->query_hitte_add()+armor->query_hitte_add();
	player->wear(jewelry);
	int three_piece=weapon->query_str_add()+armor->query_str_add()+
		jewelry->query_str_add();
	int three_piece_doub=weapon->query_doub_add()+armor->query_doub_add()+
		jewelry->query_doub_add();
	check("一件、两件与三件套按100%/150%/200%强化共鸣",
		one_piece==3 && two_piece==8 && three_piece==18 &&
		weapon->query_newmoon_set_piece_count()==3 &&
		weapon->query_newmoon_resonance_percent()==200,
		sprintf("one=%d two=%d three=%d count=%d percent=%d",
			one_piece,two_piece,three_piece,
			weapon->query_newmoon_set_piece_count(),
			weapon->query_newmoon_resonance_percent()));
	check("剑仙两件命中与三件暴击属性按每件套装生效",
		two_piece_hitte==2 && three_piece_doub==3,
		sprintf("two_hitte=%d three_doub=%d",
			two_piece_hitte,three_piece_doub));
	object|zero original_player=this_player();
	set_this_player(player);
	string detail=weapon->query_content();
	set_this_player(original_player);
	check("装备详情显示套装进度、两件效果与满月觉醒",
		search(detail,"【套装·新月·剑仙·剑心】(3/3)")!=-1 &&
		search(detail,"已激活：力量+6、敏捷+4、生命+20")!=-1 &&
		search(detail,"2件：职业共鸣提高50%；每件已穿套装命中率+1%（已激活）")!=-1 &&
		search(detail,"3件：满月觉醒，职业共鸣提高100%；每件已穿套装暴击率+1%（已激活）")!=-1,
		"套装详情缺少进度或效果说明");
	armor->item_cur_dura=0;
	check("耐久耗尽的装备不计入套装件数或提供共鸣",
		weapon->query_newmoon_set_piece_count()==2 &&
		!armor->query_newmoon_resonance_active() &&
		weapon->query_doub_add()==0 &&
		weapon->query_str_add()+armor->query_str_add()+
		jewelry->query_str_add()==8,
		"破损套装仍激活三件效果或自身属性");
	destroy_player(player);
}

void test_all_profession_set_extras()
{
	int all_valid=1;
	array(string) errors=({});
	for(int index=0;index<sizeof(catalog);index++){
		mapping config=catalog[index];
		object player=create_player("__testunit_newmoon_extras_"+
			(string)index+"__",
			(string)config["race"],(string)config["profession"]);
		array(object) items=({
			clone(item_path("weapon",(string)config["weapon"])),
			clone(item_path("armor",(string)config["armor"])),
			clone(item_path("jewelry",(string)config["jewelry"])),
		});
		foreach(items,object item)
			item->move(player);
		player->wield(items[0]);
		player->wear(items[1]);
		player->wear(items[2]);
		string two_attr=(string)config["two_attr"];
		string three_attr=(string)config["three_attr"];
		int two_total=0;
		int three_total=0;
		foreach(items,object item){
			two_total+=query_effective_set_attribute(item,two_attr);
			three_total+=query_effective_set_attribute(item,three_attr);
		}
		int two_expected=(int)config["two_value"]*3*
			(two_attr=="defend" ? 10 : 1);
		int three_expected=(int)config["three_value"]*3*
			(three_attr=="defend" ? 10 : 1);
		if(two_total!=two_expected || three_total!=three_expected){
			all_valid=0;
			errors+=({sprintf("%s:%s=%d/%d,%s=%d/%d",
				(string)config["profession"],two_attr,two_total,two_expected,
				three_attr,three_total,three_expected)});
		}
		destroy_player(player);
	}
	check("十二职业两件与三件额外属性均进入真实属性getter",
		all_valid,errors*";");
}

void test_set_identity_boundary()
{
	object player=create_player("__testunit_newmoon_identity__",
		"human","jianxian");
	object weapon=clone(item_path("weapon","69xinyuetianfengjian"));
	object armor=clone(item_path("armor","69xinyuetianfengzhanyi"));
	weapon->move(player);
	armor->move(player);
	player->wield(weapon);
	player->wear(armor);
	armor->set_newmoon_resonance("jianxian","剑仙","异月",3,2,0,1,0,
		"hitte",1,"doub",1);
	check("同职业不同套装主题不能混穿凑两件效果",
		weapon->query_newmoon_set_piece_count()==1 &&
		armor->query_newmoon_set_piece_count()==1 &&
		weapon->query_str_add()==3 && armor->query_str_add()==3 &&
		weapon->query_hitte_add()==0 && armor->query_hitte_add()==0,
		"不同主题错误计入同一套装件数");
	destroy_player(player);
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
		generated->query_item_canTrade() && generated->query_item_canStorage();
	check("旧动态生成器可把69级新月底版安全扩展到120级",
		valid,err ? describe_error(err) : "高等级装备元数据丢失");
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
	check("旧装备属性getter保持原数值且无新月身份",
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
	check("新月套装身份通过既有dbase随物品存档往返",
		search(new_saved,"item_newmoon")!=-1 &&
		restored->query_newmoon_resonance_profession()=="jianxian" &&
		restored->query_newmoon_resonance_theme()=="剑心" &&
		restored->query_attack_power()==248 &&
		restored->query_item_canLevel()==69,
		"套装元数据存档恢复后丢失或装备字段错位");
	destruct(new_item);
	destruct(restored);
}

int main()
{
	werror("\n========== 新月十二职业装备测试 ==========\n");
	test_catalog_and_templates();
	test_resonance_boundaries();
	test_set_progression();
	test_all_profession_set_extras();
	test_set_identity_boundary();
	test_high_level_dynamic_generation();
	test_legacy_equipment_compatibility();
	werror("新月装备测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
