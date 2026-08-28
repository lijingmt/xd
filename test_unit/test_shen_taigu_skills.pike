#!/usr/bin/env pike
/** 神太古血饮传承（第八阶）：目录、数值、绑定与掉落门禁回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

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

void test_catalog()
{
	object daemon=ANCIENT_SKILLD;
	array(string) tier8=daemon->query_profession_skill_ids("jianxian");
	string last=tier8[sizeof(tier8)-1];
	mapping config=daemon->query_skill_config(last);
	check("第八阶神太古入目录且不入七阶掉落权重池",
		sizeof(tier8)==8 && last=="shenyaoyijian" &&
		(int)config["tier"]==8 && (int)config["weight"]==0 &&
		(string)config["type"]=="phy",
		sprintf("last=%O config=%O",last,config));
	check("神太古显示为纯白神太古前缀",
		has_prefix(daemon->query_colored_name(last),"§F【神太古】") &&
		has_suffix(daemon->query_colored_name(last),"§r"),
		daemon->query_colored_name(last));
	array(string) shen_ids=({});
	foreach(({"jianxian","yushi","zhuxian","kuangyao","wuyao",
		"yinggui","fangshi","zhenyue","tianxiang","lingyi"}),
		string profession){
		array(string) ids=daemon->query_profession_skill_ids(profession);
		shen_ids+=({ids[sizeof(ids)-1]});
	}
	int all_damage=1;
	foreach(shen_ids,string id){
		string type=(string)daemon->query_skill_config(id)["type"];
		if(type!="phy" && !has_suffix(type,"_mofa_attack"))
			all_damage=0;
	}
	check("十职业第八阶全部为伤害型技能",
		sizeof(shen_ids)==10 && all_damage &&
		sizeof(mkmapping(shen_ids,allocate(sizeof(shen_ids),
			0)))==10,
		"存在非伤害型或重复ID的第八阶技能");
	check("神太古独立掉落通道参数",
		daemon->query_shen_minimum_npc_level()==120 &&
		daemon->query_shen_drop_numerator()==100 &&
		daemon->query_profession_count()==10 &&
		daemon->query_shen_weighted_book(1)!="" &&
		daemon->query_shen_weighted_book(10)!="" &&
		daemon->query_shen_weighted_book(0)=="" &&
		daemon->query_shen_weighted_book(11)=="",
		sprintf("min=%d num=%d count=%d",
			daemon->query_shen_minimum_npc_level(),
			daemon->query_shen_drop_numerator(),
			daemon->query_profession_count()));
	check("七阶太古池绝对概率未被第八阶稀释",
		daemon->query_total_drop_weight()==390 &&
		sizeof(daemon->query_tier_drop_weights())==7 &&
		daemon->query_weighted_book(391)=="",
		sprintf("total=%d",daemon->query_total_drop_weight()));
}

void test_skill_numbers()
{
	// 技能克隆会注册进 skillsd，不能 destruct（见测试编写规约）。
	object phy=clone(ROOT+"/gamelib/single/skills/shenyaoyijian");
	int base=2300+4*(950+5*120)+8*260;
	check("神曜一剑保持太古系最长冷却且五阶伤害为曲线1.5倍",
		phy->query_s_delayTime(5)==75 &&
		phy->query_s_delayTime(5)>60 &&
		phy->query_performs_attack(5)==base*3/2 &&
		phy->query_performs_per(5)==45+8*5+5*8,
		sprintf("delay=%d atk=%d/%d per=%d",
			phy->query_s_delayTime(5),phy->query_performs_attack(5),
			base*3/2,phy->query_performs_per(5)));
	check("神太古按实际伤害50%吸血",
		phy->query_shen_taigu_lifesteal_percent()==50 &&
		search(phy->query_performs_desc(5),"血饮")!=-1,
		sprintf("steal=%d desc=%O",
			phy->query_shen_taigu_lifesteal_percent(),
			phy->query_performs_desc(5)));
	object mofa=clone(ROOT+"/gamelib/single/skills/shenyouhanshuang");
	check("神幽寒霜走冰系法术并同样享受血饮",
		(string)mofa->s_skill_type=="bing_mofa_attack" &&
		mofa->query_performs_mofa_attack_low(5)==base*3/2 &&
		mofa->query_shen_taigu_lifesteal_percent()==50,
		sprintf("low=%d/%d type=%s",
			mofa->query_performs_mofa_attack_low(5),base*3/2,
			(string)mofa->s_skill_type));
}

void test_book_binding()
{
	object book=clone(ITEM_PATH+"book/shenyaoyijian");
	check("神太古书拾取绑定且不可交易赠送入库",
		book->query_bind_account_on_pickup()==1 &&
		book->query_item_canDrop()==0 &&
		book->query_item_canTrade()==0 &&
		book->query_item_canSend()==0 &&
		book->query_item_canStorage()==0,
		"神太古书流通权限不符合账号绑定要求");
	object player=clone(GAMELIB_USER);
	player->set_name("__testunit_shentaigu__");
	player->set_account_owner("shentaiguacct");
	int bound=book->bind_to_account(player);
	object other=clone(GAMELIB_USER);
	other->set_name("__testunit_shentaigub__");
	other->set_account_owner("shentaiguacct2");
	check("神太古书绑定严格区分账号",
		bound && book->query_account_bind_owner()=="shentaiguacct" &&
		!book->bind_to_account(other),
		"跨账号绑定未失败关闭");
	destruct(other);
	destruct(player);
	destruct(book);
}

void test_drop_and_lifesteal_wiring()
{
	array(string) failures=({});
	foreach(({
		"/gamelib/single/daemons/itemsd.pike",
		"/gamelib/inherit/npc.pike",
		"/gamelib/inherit/ancient_hidden_skill.pike",
		"/gamelib/single/daemons/ancient_skilld.pike",
	}),string path){
		mixed err=catch{ compile_file(ROOT+path); };
		if(err)
			failures+=({path+":"+describe_error(err)});
	}
	check("神太古链路文件全部可编译",!sizeof(failures),failures*" | ");
	string items=Stdio.read_file(
		ROOT+"/gamelib/single/daemons/itemsd.pike") || "";
	string npc=Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike") || "";
	string fight=Stdio.read_file(
		ROOT+"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
	check("掉落门禁仅Boss、120级+且难度六档起",
		search(items,"get_shen_taigu_skill_book")!=-1 &&
		search(items,"npc->_boss")!=-1 &&
		search(items,"difficulty<6")!=-1 &&
		search(items,"query_shen_minimum_npc_level")!=-1,
		"itemsd缺少Boss或难度门禁");
	check("团队与单人击杀都接神太古掉落播报",
		sizeof(npc/"get_shen_taigu_skill_book")-1>=2 &&
		search(npc,"神太古血月当空")!=-1,
		"npc掉落点未完整接入");
	check("吸血在四个伤害落点统一结算",
		sizeof(fight/"apply_shen_taigu_lifesteal")-1>=5 &&
		search(fight,"query_shen_taigu_lifesteal_percent")!=-1,
		sprintf("call_sites=%d",
			sizeof(fight/"apply_shen_taigu_lifesteal")-1));
}

void test_global_broadcast_wiring()
{
	array(string) failures=({});
	mixed err=catch{
		// 环形事件文件行为：写入→读回→还原，不能污染真实事件流。
		string path=ROOT+"/data_xiand/shen_taigu_cast_events.json";
		string backup=Stdio.read_file(path);
		rm(path);
		append_shen_taigu_cast_event("§g测试施法者§r","§F【神太古】测试技能§r");
		append_shen_taigu_cast_event("测试施法者二","测试技能二","S1");
		array(mapping(string:mixed)) events=query_shen_taigu_cast_events(1);
		array(mapping(string:mixed)) eternal=query_shen_taigu_cast_events(1,
			"eternal");
		array(mapping(string:mixed)) season=query_shen_taigu_cast_events(1,
			"S1");
		int behavioral=sizeof(events)==2 &&
			events[0]["caster_name"]=="测试施法者" &&
			events[0]["skill_name"]=="【神太古】测试技能" &&
			(stringp(events[1]["id"]) && sizeof((string)events[1]["id"])>0);
		int isolated=sizeof(eternal)==1 &&
			eternal[0]["caster_name"]=="测试施法者" &&
			sizeof(season)==1 && season[0]["caster_name"]=="测试施法者二" &&
			(string)eternal[0]["scope"]=="eternal";
		if(!behavioral)
			failures+=({sprintf("ring=%O",events)});
		if(!isolated)
			failures+=({sprintf("isolated=%O/%O",eternal,season)});
		rm(path);
		if(backup && sizeof(backup))
			Stdio.write_file(path,backup);
	};
	if(err)
		failures+=({describe_error(err)});
	string fight=Stdio.read_file(
		ROOT+"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
	string efuns=Stdio.read_file(ROOT+"/lowlib/efuns.pike") || "";
	string api=Stdio.read_file(
		ROOT+"/gamelib/single/daemons/_http_api_mod/html_renderer.pike") || "";
	string appjs=Stdio.read_file(ROOT+"/vue_source/js/app.js") || "";
	string html=Stdio.read_file(ROOT+"/vue_source/index.html") || "";
	string css=Stdio.read_file(ROOT+"/vue_source/css/app.css") || "";
	check("神太古施法写全服事件且颜色码剥离",
		!sizeof(failures) &&
		search(fight,"append_shen_taigu_cast_event")!=-1 &&
		search(efuns,"strip_color_codes")!=-1,
		failures*" | ");
	check("状态接口携带全服事件且Vue全屏播放",
		search(api,"global_skill_effects")!=-1 &&
		search(api,"query_scope(player)")!=-1 &&
		search(fight,"query_scope(caster)")!=-1 &&
		search(appjs,"syncGlobalSkillEffects")!=-1 &&
		search(appjs,"'shentaigu': 'skill-shentaigu-bloodmoon'")!=-1 &&
		search(html,"global-shentaigu-stage")!=-1 &&
		search(css,"shentaigu-bloodmoon-effect")!=-1 &&
		search(css,"global-shentaigu-moon")!=-1,
		"全服广播链路缺件或未做世界隔离");
}

int main()
{
	werror("\n========== 神太古血饮传承测试 ==========\n");
	test_catalog();
	test_skill_numbers();
	test_book_binding();
	test_drop_and_lifesteal_wiring();
	test_global_broadcast_wiring();
	werror("神太古测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
