#!/usr/bin/env pike
/** Boss掉落等级缩放回归：高等级Boss掉落与转化装同口径
 * （×min(等级/25,20)，>73级启用），修复饰品/挂件属性停留几十。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[Boss掉落缩放] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[Boss掉落缩放] ✗ %s: %s\n",name,detail);
	}
}

int attr_value(string content,string setter)
{
	int value=0;
	sscanf(content,"%*s"+setter+"(%d);",value);
	return value;
}

int main()
{
	string generated="";
	mixed err=catch{
		// 104级Boss掉落49级底版饰品：旧口径力量上限12×3.24≈38，
		// 新口径=旧rate×min(104/25,20)=×4.16，下限12×4.16≈50。
		generated=BOSSDROPD->get_org_converted_level(
			"jewelry/49xingmangzhihuan",104);
		check("高等级Boss掉落返回生成文件名",
			stringp(generated) && has_prefix(generated,
				"jewelry/49xingmangzhihuan_c_"),
			sprintf("generated=%O",generated));
		string content=Stdio.read_file(ITEM_PATH+generated) || "";
		int str_add=attr_value(content,"set_str_add");
		int think_add=attr_value(content,"set_think_add");
		int canlevel=attr_value(content,"set_item_canLevel");
		int hitte=attr_value(content,"set_hitte_add");
		check("饰品三维带等级缩放（旧口径不可能超过38）",
			str_add>45 && think_add>45,
			sprintf("str=%d think=%d",str_add,think_add));
		check("穿戴等级改写为Boss等级",
			canlevel==104,
			sprintf("canLevel=%d",canlevel));
		check("百分比属性仍受上限钳制",
			hitte<=20,
			sprintf("hitte=%d",hitte));
	};
	if(err)
		check("Boss掉落生成流程无异常",0,describe_error(err));
	else
		check("Boss掉落生成流程无异常",1,"");
	if(generated!="" && has_prefix(generated,"jewelry/49xingmangzhihuan_c_"))
		rm(ITEM_PATH+generated);
	werror("[Boss掉落缩放] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
