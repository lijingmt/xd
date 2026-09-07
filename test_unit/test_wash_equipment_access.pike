#!/usr/bin/env pike
/** 洗装备可达性回归：炼化白名单接受新月共鸣装备（S1玩家核心装备）、
 * 幻境补给页与主城八卦炉提供入口。 */

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
	werror("\n========== 洗装备可达性测试 ==========\n");
	object|zero nm_item = 0;
	mixed err = catch{
		/* 1) 三处炼化白名单都接受新月共鸣装备 */
		foreach(({"convert_equip_list.pike","convert_equip_detail.pike",
			"convert_equip_confirm.pike"}),string f){
			string src=Stdio.read_file(ROOT+"/gamelib/cmds/"+f) || "";
			check(f+" 白名单接受新月共鸣装备",
				search(src,"query_newmoon_collection_id")!=-1,
				"新月分支缺失");
		}

		/* 2) 真实新月共鸣装备克隆后身份可识别 */
		array(string) nm_files=sort(glob("*_nm*",
			get_dir(ROOT+
			"/gamelib/clone/item/weapon/69xinyueliangyijian/") || ({})));
		check("磁盘存在带共鸣源码的新月装备",
			sizeof(nm_files)>0,"无_nm文件");
		if(sizeof(nm_files)>0){
			nm_item=clone(ROOT+
				"/gamelib/clone/item/weapon/69xinyueliangyijian/"+
				nm_files[0]);
			check("新月装备共鸣身份可查询",
				objectp(nm_item) &&
				functionp(nm_item->query_newmoon_collection_id) &&
				(string)nm_item->query_newmoon_collection_id()!="",
				"collection_id为空");
		}

		/* 3) 幻境补给与主城八卦炉入口 */
		string supply=Stdio.read_file(ROOT+
			"/gamelib/cmds/illusion_supply.pike") || "";
		check("幻境补给页提供八卦炉炼化入口",
			search(supply,"[七彩八卦炉·炼化洗装:convert_equip_list]")!=-1,
			"入口缺失");
		string furnace=Stdio.read_file(ROOT+
			"/gamelib/d/kunlunshan/wanbaolu") || "";
		check("昆仑山万宝炉入口保留",
			search(furnace,"[七彩八卦炉:convert_equip_list]")!=-1,
			"入口缺失");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	if(nm_item)
		destruct(nm_item);
	werror("========== 洗装备可达性测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
