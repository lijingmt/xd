#!/usr/bin/env pike
/** 七只扩展共享宠物的图鉴、兑换、存档、PVE/PVP真实链路回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);
string test_account = "xd99testunitpetexpand";
object|zero test_player = 0;
array(string) expanded_species = ({
	"fuzhu","qinggeng","dijiang","feifei",
	"yuehenli","wudenghe","shuangjingmo",
});

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_test_data()
{
	if(test_player){
		catch(destruct(test_player));
		test_player = 0;
	}
	PETD->remove_test_pet_data(test_account);
	string path = player_file(test_account);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_test_player()
{
	cleanup_test_data();
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(test_account);
	player->set_password("testunit99");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "共享宠物扩展测试";
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = 80;
	player->set_att_by_level();
	player->set_term("noterm");
	player->packageLevel = 20;
	player->packaged_items = ({});
	player->save_with_result();
	return player;
}

mapping find_species(mapping state,string species)
{
	foreach((array)state["pets"],mapping pet)
		if((string)pet["species"]==species)
			return pet;
	return ([]);
}

int is_hex_pet_id(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	foreach(value;int index;int one)
		if(!((one>='0' && one<='9') || (one>='a' && one<='f')))
			return 0;
	return 1;
}

void test_catalog_contract()
{
	werror("\n【共享宠物扩展】公开图鉴与定位\n");
	mapping catalog = PETD->query_pet_catalog();
	mapping(string:mapping(string:mixed)) expected = ([
		"fuzhu":(["name":"夫诸","family":"水","role":"守护"]),
		"qinggeng":(["name":"青耕","family":"木","role":"疗愈"]),
		"dijiang":(["name":"帝江","family":"风","role":"迅捷"]),
		"feifei":(["name":"朏朏","family":"灵","role":"灵息"]),
		"yuehenli":(["name":"月痕狸","family":"灵","role":"迅捷"]),
		"wudenghe":(["name":"雾灯鹤","family":"风","role":"疗愈"]),
		"shuangjingmo":(["name":"霜镜貘","family":"水","role":"守护"]),
	]);
	int valid = sizeof(catalog)==23;
	foreach(expected;string species;mapping wanted){
		mapping info = catalog[species] || ([]);
		valid = valid && (string)info["name"]==(string)wanted["name"] &&
			(string)info["family"]==(string)wanted["family"] &&
			(string)info["role"]==(string)wanted["role"] &&
			(int)info["exchange"]==1 && !(int)info["boss"] &&
			!(int)info["hidden"] && (string)info["origin"]!="" &&
			(string)info["basic_attack"]!="" &&
			sizeof((array)info["skill_sets"])==3;
		foreach((array)info["skill_sets"],array skills)
			valid = valid && sizeof(skills)==3;
	}
	check("七只扩展宠物是公开稳定兑换且三套灵纹资料完整",valid,
		"图鉴数量、名称、定位、公开兑换或灵纹资料不完整");
	check("水木灵归阴、风归阳并复用既有融合规则",
		PETD->query_pet_species_polarity("fuzhu")=="yin" &&
		PETD->query_pet_species_polarity("qinggeng")=="yin" &&
		PETD->query_pet_species_polarity("feifei")=="yin" &&
		PETD->query_pet_species_polarity("dijiang")=="yang" &&
		PETD->query_pet_species_polarity("yuehenli")=="yin" &&
		PETD->query_pet_species_polarity("wudenghe")=="yang" &&
		PETD->query_pet_species_polarity("shuangjingmo")=="yin",
		"新增族系没有落入已有阴阳规则");
}

void test_existing_combat_formulas()
{
	werror("\n【共享宠物扩展】PVE/PVP既有公式边界\n");
	mapping fuzhu = PETD->query_pet_assist_profile(
		"fuzhu",100000,100000,100000,100000);
	mapping qinggeng = PETD->query_pet_assist_profile(
		"qinggeng",100000,100000,100000,100000);
	mapping dijiang = PETD->query_pet_assist_profile(
		"dijiang",100000,100000,100000,100000);
	mapping feifei = PETD->query_pet_assist_profile(
		"feifei",100000,100000,100000,100000);
	mapping yuehenli = PETD->query_pet_assist_profile(
		"yuehenli",100000,100000,100000,100000);
	mapping wudenghe = PETD->query_pet_assist_profile(
		"wudenghe",100000,100000,100000,100000);
	mapping shuangjingmo = PETD->query_pet_assist_profile(
		"shuangjingmo",100000,100000,100000,100000);
	check("四种定位分别进入守护、疗愈、迅捷、灵息原有结算分支",
		(string)fuzhu["type"]=="heal" && (int)fuzhu["amount"]>0 &&
		(string)qinggeng["type"]=="heal" && (int)qinggeng["amount"]>0 &&
		(string)dijiang["type"]=="damage" && (int)dijiang["amount"]>0 &&
		(string)feifei["type"]=="mofa" && (int)feifei["amount"]>0 &&
		(string)yuehenli["type"]=="damage" && (int)yuehenli["amount"]>0 &&
		(string)wudenghe["type"]=="heal" && (int)wudenghe["amount"]>0 &&
		(string)shuangjingmo["type"]=="heal" &&
		(int)shuangjingmo["amount"]>0,
		"新增宠物误入新公式或协战收益为零");
	int pvp_valid = 1;
	foreach(expanded_species,string species){
		mapping profile = PETD->query_pet_pvp_assist_profile(
			species,100000,100000,100000,100000);
		pvp_valid = pvp_valid && (int)profile["amount"]>0 &&
			(int)profile["max_uses"]==2 &&
			(int)profile["charge_required"]>0;
	}
	check("七只扩展宠物沿用PVP充能与每场两次上限",pvp_valid,
		"新增宠物绕过PVP充能、次数限制或没有有效结算");
	mapping duel = PETD->test_simulate_pet_match("yuehenli","shuangjingmo");
	check("新增阴阳宠可进入原有三局两胜论道",
		sizeof((array)duel["bouts"])==3 &&
		(int)duel["left_wins"]+(int)duel["right_wins"]+
		(int)duel["draws"]==3,
		"论道模拟未完成三局或结果不守恒");
}

void test_exchange_persistence_and_active_pet()
{
	werror("\n【共享宠物扩展】真实兑换、存档与出战\n");
	test_player = create_test_player();
	if(!test_player){
		check("测试人物可创建",0,"无法创建测试人物");
		return;
	}
	mapping starter = PETD->choose_starter_pet(test_player,"dangkang");
	int funded = PETD->test_add_pet_material(
		test_player,"spirit_mark",210);
	int acquired = starter["ok"] && funded;
	foreach(expanded_species,string species){
		mapping exchanged = PETD->exchange_pet(test_player,species);
		acquired = acquired && (int)exchanged["ok"] &&
			(string)exchanged["pet"]["species"]==species &&
			(string)exchanged["pet"]["source"]=="spirit_exchange" &&
			is_hex_pet_id((string)exchanged["pet"]["id"]);
	}
	mapping state = PETD->query_pet_state(test_player);
	check("210枚灵印按每只30枚稳定兑换七只且产生不可预测唯一ID",
		acquired && (int)state["materials"]["spirit_mark"]==0 &&
		(int)state["collection_count"]==8,
		"真实兑换、扣费、来源、唯一ID或收藏数量不正确");

	PETD->test_add_pet_material(test_player,"spirit_mark",30);
	mapping before_duplicate = PETD->query_pet_state(test_player);
	mapping duplicate = PETD->exchange_pet(test_player,"fuzhu");
	mapping before_unknown = PETD->query_pet_state(test_player);
	mapping unknown = PETD->exchange_pet(test_player,"not_a_pet");
	mapping after_reject = PETD->query_pet_state(test_player);
	check("重复或未知兑换均拒绝且不扣灵印",
		!duplicate["ok"] && !unknown["ok"] &&
		(int)before_duplicate["materials"]["spirit_mark"]==30 &&
		(int)before_unknown["materials"]["spirit_mark"]==30 &&
		(int)after_reject["materials"]["spirit_mark"]==30,
		"失败兑换扣除了灵印或错误增加收藏");

	int all_active = 1;
	foreach(expanded_species,string species){
		mapping pet = find_species(after_reject,species);
		mapping activated = PETD->set_active_pet(test_player,(string)pet["id"]);
		all_active = all_active && (int)activated["ok"] &&
			(string)test_player["/tmp/wanling/species"]==species;
	}
	check("七只扩展宠物均可轮换为共享协战宠并同步战斗运行态",all_active,
		"至少一只宠物无法出战或运行态没有同步");

	PETD->drop_test_pet_cache(test_account);
	mapping restored = PETD->query_pet_state(test_player);
	int persisted = (int)restored["collection_count"]==8;
	foreach(expanded_species,string species){
		mapping pet = find_species(restored,species);
		persisted = persisted && sizeof(pet)>0 &&
			(string)pet["source"]=="spirit_exchange" &&
			is_hex_pet_id((string)pet["id"]);
	}
	check("清空守护进程缓存后七只宠物仍从唯一账号档案完整恢复",persisted,
		"新增宠物只留在内存或重载后字段损坏");
}

int main()
{
	werror("\n========== 共享宠物扩展回归测试 ==========\n");
	mixed err = catch {
		test_catalog_contract();
		test_existing_combat_formulas();
		test_exchange_persistence_and_active_pet();
	};
	if(err)
		check("测试脚本自身无未捕获异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	cleanup_test_data();
	werror("\n共享宠物扩展测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
