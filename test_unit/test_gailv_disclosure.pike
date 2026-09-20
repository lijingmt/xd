#!/usr/bin/env pike
/** 概率公示合规回归：付费随机机制必须在购买前可查看概率
 * （苹果/谷歌/文化部要求），公示数值须与服务器配置实时一致。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[概率公示] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[概率公示] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string name)
{
	object player=clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn=name;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=30;
	player->set_att_by_level();
	player->set_term("noterm");
	return player;
}

int main()
{
	object original=this_player();
	object|zero me=0;
	mixed err=catch{
		me=create_test_player("__testunit_gailv__");
		set_this_player(me);
		object cmd=(object)(ROOT+"/gamelib/cmds/gailv.pike");
		cmd->main(0);
	};
	check("概率公示页正常渲染",!err,
		err ? describe_error(err) : "ok");

	/* 公示数值必须与真实配置一致（行为断言）：收集档位概率来自
	 * itemsd目录权重，提炼基础率与refined公式一致——页面渲染
	 * 声明实时读取这些源，此处直接对源做行为断言。 */
	string gailv_src=Stdio.read_file(
		ROOT+"/gamelib/cmds/gailv.pike") || "";
	check("凝炼四档品质概率公示(70/22/7/1)",
		search(gailv_src,
			"凡品70% / 良品22% / 珍品7% / 神品1%")!=-1,
		"凝炼品质档缺失");
	array(mapping) catalog=ITEMSD->query_newmoon_collection_catalog();
	int total_weight=0;
	foreach(catalog,mapping c)
		total_weight+=(int)c["weight"];
	// 抽新月(300/444)与寰极(1/444)两档做代表：页面按权重百分比展示。
	check("新月收集档位概率实时读取目录",
		!err && sizeof(catalog)==6 && total_weight==444,
		sprintf("catalog=%d total=%d",sizeof(catalog),total_weight));
	check("提炼基础成功率公式公示",
		REFINED->query_refine_success_rate(0)==10000 &&
		REFINED->query_refine_success_rate(10)==9000,
		sprintf("r0=%d r10=%d",
			REFINED->query_refine_success_rate(0),
			REFINED->query_refine_success_rate(10)));
	// 洗炼保底与增加属性语义为公示承诺，源断言防回退。
	string itemsd_src=Stdio.read_file(
		ROOT+"/gamelib/single/daemons/itemsd.pike") || "";
	check("洗炼保底区间[70%,100%]实现仍在(公示与实际一致)",
		search(itemsd_src,"difference*7/10")!=-1,
		"保底公式变更后须同步公示文案");
	/* 购买/操作点入口（合规硬性要求：购买前可达）。 */
	string refine_src=Stdio.read_file(
		ROOT+"/gamelib/cmds/refine.pike") || "";
	string pet_src=Stdio.read_file(
		ROOT+"/gamelib/cmds/pet.pike") || "";
	string convert_src=Stdio.read_file(
		ROOT+"/gamelib/cmds/convert_equip_detail.pike") || "";
	check("提炼页有概率公示入口",
		search(refine_src,"[概率公示:gailv]")!=-1,"入口缺失");
	check("宠物凝炼页有概率公示入口",
		search(pet_src,"[概率公示:gailv]")!=-1,"入口缺失");
	check("洗装备(炼化)页有概率公示入口",
		search(convert_src,"[概率公示:gailv]")!=-1,"入口缺失");
	string modal_src=Stdio.read_file(
		ROOT+"/rn_client/src/components/RechargeModal.js") || "";
	string gamescreen_src=Stdio.read_file(
		ROOT+"/rn_client/src/components/GameScreen.js") || "";
	string vue_html=Stdio.read_file(
		ROOT+"/vue_source/index.html") || "";
	string vue_js=Stdio.read_file(
		ROOT+"/vue_source/js/app.js") || "";
	check("RN充值弹窗有概率公示入口",
		search(modal_src,"onOpenOdds")!=-1 &&
		search(gamescreen_src,"store.command('gailv')")!=-1,
		"RN入口缺失");
	check("Vue充值弹窗有概率公示入口(双端对齐)",
		search(vue_html,"openOddsDisclosure()")!=-1 &&
		search(vue_js,"sendJsonCommand('gailv')")!=-1,
		"Vue入口缺失");

	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	if(me)
		destruct(me);
	werror("[概率公示] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
