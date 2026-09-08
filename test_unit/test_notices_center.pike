#!/usr/bin/env pike
/** 公告中心回归：历史公告数据可加载、命令索引/详情可渲染、
 * 登录首页与客户端/网页入口接线齐全。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

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

int main()
{
	werror("\n========== 公告中心测试 ==========\n");
	mixed err=catch{
		string raw=Stdio.read_file(ROOT+"/gamelib/etc/notices.json") || "";
		mapping data;
		mixed jerr=catch{ data=Standards.JSON.decode(raw); };
		check("公告JSON可解析且含多期",
			!jerr && mappingp(data) && arrayp(data["notices"]) &&
			sizeof(data["notices"])>=7,
			sprintf("size=%d",sizeof(data && data["notices"] || ({}))));
		array(mapping) list=data["notices"];
		int all_valid=1;
		foreach(list,mapping n)
			if(!stringp(n["date"]) || !stringp(n["title"]) ||
			   !arrayp(n["body"]) || sizeof(n["body"])<1)
				all_valid=0;
		check("每期公告字段完整",all_valid,"字段缺失");
		check("最新一期为提炼大扩充公告",
			(string)list[0]["date"]=="2026-09-08" &&
			search((string)list[0]["title"],"提炼")!=-1,
			sprintf("date=%s",(string)list[0]["date"]));

		string init_src=Stdio.read_file(ROOT+"/gamelib/d/init") || "";
		check("登录首页提供全部公告入口",
			search(init_src,"[全部历史公告:notices]")!=-1 &&
			search(init_src,"装备提炼系统上线")!=-1,
			"入口或新提示缺失");

		string rn=Stdio.read_file(ROOT+
			"/rn_client/src/components/GameScreen.js") || "";
		check("APP更多面板含公告入口",
			search(rn,"'公告', cmd: 'notices'")!=-1,"RN入口缺失");
		string vue=Stdio.read_file(ROOT+"/vue_source/index.html") || "";
		string vjs=Stdio.read_file(ROOT+"/vue_source/js/app.js") || "";
		check("网页右上角菜单含公告入口",
			search(vue,"openNotices")!=-1 &&
			search(vjs,"sendJsonCommand('notices')")!=-1,
			"Vue入口缺失");
		check("公告命令可由真实Pike编译",
			!catch{ compile_file(ROOT+"/gamelib/cmds/notices.pike"); },
			"编译失败");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	werror("========== 公告中心测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
