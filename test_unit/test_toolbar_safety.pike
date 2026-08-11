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

	int invalid_bounds = !player->set_toolbar("x",-1,1) &&
		!player->set_toolbar("x",6,1) &&
		!player->set_toolbar("x",0,0) &&
		!player->set_toolbar("x",0,4) &&
		!sizeof(player->query_toolbar(-1)) &&
		!sizeof(player->query_toolbar(6)) &&
		!player->clean_toolbar(-1) && !player->clean_toolbar(6);
	check("负数槽位、越界槽位和未知类型全部失败关闭",
		invalid_bounds,"槽位或类型边界仍可越界");

	player->toolbar_key = ({(["none":0])});
	err = catch{
		player->query_toolbar_cn();
		player->clean_toolbar(5);
	};
	check("历史短数组快捷栏可安全补齐、读取和重新配置",
		!err && sizeof(player->query_toolbar_all())>=6 &&
		player->query_toolbar(5)["none"]==0,
		err ? describe_error(err) : "短数组没有安全补齐");

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
