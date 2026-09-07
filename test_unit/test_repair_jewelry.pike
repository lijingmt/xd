#!/usr/bin/env pike
/** 修理命令回归：首饰(jewelry)与挂件(decorate)进入修理白名单；
 * 新月首饰与心渊套装部件均可修理。 */

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
	werror("\n========== 修理命令首饰覆盖测试 ==========\n");
	mixed err = catch{
		string src = Stdio.read_file(ROOT+
			"/gamelib/cmds/repair.pike") || "";
		check("repair 白名单包含 jewelry",
			search(src,"query_item_type()==\"jewelry\"")!=-1,
			"jewelry缺失");
		check("repair 白名单包含 decorate",
			search(src,"query_item_type()==\"decorate\"")!=-1,
			"decorate缺失");
		/* 列表视图与修理动作两处都要有 */
		int jewelry_count = 0;
		int pos = 0;
		while((pos = search(src,"query_item_type()==\"jewelry\"",pos))!=-1){
			jewelry_count++;
			pos += 10;
		}
		check("两处类型检查都接受首饰",jewelry_count>=2,
			sprintf("count=%d",jewelry_count));

		/* 实物克隆：首饰耐久磨损后可修理（类型通过） */
		object ring = clone(ROOT+
			"/gamelib/clone/item/wuxinsuit/xinyuanjie");
		check("心渊戒类型=jewelry",
			objectp(ring) && (string)ring->query_item_type()=="jewelry",
			sprintf("type=%s", ring ? "jewelry" : "nil"));
		if(ring){
			ring->item_cur_dura = 1000;
			check("心渊戒耐久可磨损且非满",
				(int)ring->item_cur_dura<
				(int)ring->item_dura,"dura异常");
		}
		/* 新月首饰（生产生成源同类型） */
		string f = ROOT+
			"/gamelib/clone/item/jewelry/49xingmangzhihuan_c_12554_104";
		if(Stdio.file_size(f)>0){
			string jsrc = Stdio.read_file(f) || "";
			check("新月首饰生成源类型=decorate",
				search(jsrc,"set_item_type(\"decorate\")")!=-1,
				"新月首饰类型漂移");
		}
		else
			check("新月首饰生成源存在",0,"文件缺失");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	werror("========== 修理覆盖测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
