#!/usr/bin/env pike
/** 快捷栏旧档案兼容、输入校验与失效对象防空指针。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

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

object create_player()
{
	object player = clone(GAMELIB_USER);
	player->set_name("__testunit_toolbar_safety__");
	player->name_cn = "快捷栏安全测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->toolbar_key = ({
		(["none":0]),(["none":0]),(["none":0]),
		(["none":0]),(["none":0]),(["none":0]),
	});
	return player;
}

int main()
{
	object player = create_player();
	object|zero original = this_player();
	object toolbar_page = (object)(ROOT+"/gamelib/cmds/my_toolbar.pike");
	object toolbar_set = (object)(ROOT+"/gamelib/cmds/toolbar_set.pike");
	string error_desc = "";
	mixed err = catch{
		player->skills["removed_toolbar_skill"] = ({1,0});
		player->toolbar_key[0] = (["removed_toolbar_skill":1]);
		set_this_player(player);
		toolbar_page->main(0);
	};
	if(err)
		error_desc = describe_error(err);
	check("旧档案引用已删除技能时配置页不再空指针",
		!err && player->query_toolbar_entry_name(
			"removed_toolbar_skill",1)=="",
		error_desc);

	player->clean_toolbar(0);
	err = catch{
		set_this_player(player);
		toolbar_set->main("0 ../removed 2");
		toolbar_set->main("0 removed_toolbar_skill 1");
	};
	check("伪造路径和不存在的技能不能写入快捷栏",
		!err && player->query_toolbar(0)["none"]==0,
		err ? describe_error(err) : "非法配置污染了角色档案");

	player->skills["qieyunzhan"] = ({1,0});
	player->set_vip_flag(4);
	player->set_vip_end_time(time()+3600);
	err = catch{
		set_this_player(player);
		toolbar_set->main("9 qieyunzhan 1");
	};
	int invalid_bounds = !player->set_toolbar("x",-1,1) &&
		!err &&
		!player->set_toolbar("x",10,1) &&
		!player->set_toolbar("x",0,0) &&
		!player->set_toolbar("x",0,4) &&
		!sizeof(player->query_toolbar(-1)) &&
		!sizeof(player->query_toolbar(10)) &&
		player->query_toolbar(9)["qieyunzhan"]==1 &&
		search(player->query_toolbar_cn(),"use_toolbar 9")!=-1 &&
		!player->clean_toolbar(-1) && !player->clean_toolbar(10);
	check("VIP4快捷栏扩展到10格且负数、越界和未知类型失败关闭",
		invalid_bounds,"槽位或类型边界仍可越界");

	player->toolbar_key = ({(["none":0])});
	err = catch{
		player->query_toolbar_cn();
		player->clean_toolbar(9);
	};
	check("历史短数组快捷栏可安全补齐、读取和重新配置",
		!err && sizeof(player->query_toolbar_all())>=10 &&
		player->query_toolbar(9)["none"]==0,
		err ? describe_error(err) : "短数组没有安全补齐");

	player->set_toolbar("qieyunzhan",9,1);
	player->set_vip_end_time(time()-1);
	check("VIP到期隐藏额外快捷键但不删除旧配置",
		player->query_toolbar_slot_limit()==6 &&
		sizeof(player->query_toolbar_all())==6 &&
		!sizeof(player->query_toolbar(9)) &&
		player->toolbar_key[9]["qieyunzhan"]==1,
		"到期后额外格仍可执行或配置被破坏");
	player->set_vip_flag(8);
	player->set_vip_end_time(time()+3600);
	check("VIP8开放14格且续费恢复历史额外配置",
		player->query_toolbar_slot_limit()==14 &&
		sizeof(player->query_toolbar_all())==14 &&
		player->query_toolbar(9)["qieyunzhan"]==1 &&
		player->set_toolbar("qieyunzhan",13,1) &&
		search(player->query_toolbar_cn(),"use_toolbar 13")!=-1,
		"高阶VIP格数或续费恢复失败");
	string vip_show_source=Stdio.read_file(ROOT+
		"/gamelib/cmds/vip_service_show.pike") || "";
	string vip_detail_source=Stdio.read_file(ROOT+
		"/gamelib/cmds/vip_service_app_detail.pike") || "";
	check("会员说明与购买详情公开快捷栏逐级扩展规则",
		search(vip_show_source,"VIP4为10格，VIP8为14格")!=-1 &&
		search(vip_detail_source,"6+level")!=-1,
		"实际开放了扩展快捷栏，但会员页面没有说明");

	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	if(player)
		destruct(player);
	werror("\n快捷栏安全测试完成：%d通过/%d失败\n",
		results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
