#!/usr/bin/env pike
/** 读书返回导航回归：学习结果压在当前界面之上而非弹掉它。 */

#include <globals.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[读书导航] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[读书导航] ✗ %s: %s\n",name,detail);
	}
}

int main()
{
	object player=clone(GAMELIB_USER);
	object book=clone(ROOT+"/gamelib/clone/item/book/qieyunzhan");
	object original=this_player();
	string error_desc="";
	string after_read="";
	string after_back="";
	mixed err=catch{
		player->set_name("xd01testunitreadnav");
		player->name_cn="读书导航测试";
		player->set_project("gamelib");
		player->setup("testunit-only");
		player->set_raceId("human");
		player->set_profeId("jianxian");
		player->setup_player("human","jianxian");
		player->level=20;
		player->set_att_by_level();
		set_this_player(player);
		book->move(player);
		// 底层是历史页面，上层模拟玩家正在使用的“筛选卷轴”界面。
		player->reset_view(WAP_VIEWD["/read_repeat"]);
		player->push_view(WAP_VIEWD["/read_fail"],book);
		player->command("read qieyunzhan");
		after_read=(string)player->query_spliter()["text"];
		player->command("popview");
		after_back=(string)player->query_spliter()["text"];
	};
	check("学习成功后返回回到读书前的界面而不是更早页面",
		!err && search(after_read,"学会了")!=-1 &&
		search(after_back,"没有懂得其中的奥妙")!=-1,
		err ? describe_error(err) :
			sprintf("after_read=%O after_back=%O",
				after_read[..60],after_back[..60]));
	check("读书命令源码不再预先弹掉当前界面",
		search(Stdio.read_file(ROOT+
			"/lowlib/wapmud2/cmds/read.pike") || "",
			"this_player()->pop_view();")==-1,
		"读书前弹掉当前页会让返回落到更早的购买页");
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	if(book)
		destruct(book);
	if(player)
		destruct(player);
	werror("读书导航：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
