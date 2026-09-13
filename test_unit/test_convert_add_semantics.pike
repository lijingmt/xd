#!/usr/bin/env pike
/** 增加属性语义回归：成功=保留旧词条+新增一条；批量flag归一化顺序。 */

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

int count_affixes(object item,string base)
{
	return sizeof(ITEMSD->query_item_current_affixes(item,base));
}

int main()
{
	string base = "armor/10lupimao/10lupimao";
	string error_desc = "";
	mixed err = catch {
		// 1) 生成一件2词条底装
		object|zero item2 = ITEMSD->get_convert_item(base,2,10,10);
		check("底装生成成功且2词条",
			objectp(item2) && (int)item2->query_item_rareLevel()==2 &&
			count_affixes(item2,base)==2,
			sprintf("item=%O rare=%d affix=%d",
				item2,objectp(item2)?(int)item2->query_item_rareLevel():-1,
				objectp(item2)?count_affixes(item2,base):-1));
		array(string) old_names = ITEMSD->
			query_item_current_affixes(item2,base);
		mapping(string:int) old_values = ([]);
		foreach(old_names,string n)
			old_values[n] = (int)call_function(item2["query_"+n]);

		// 2) 增加属性：保留旧词条并补到3条
		object|zero item3 = ITEMSD->get_convert_item(base,3,10,10,
			item2,copy_value(old_names),1);
		check("增加属性后=3条且旧词条全部保留",
			objectp(item3) && (int)item3->query_item_rareLevel()==3 &&
			count_affixes(item3,base)==3,
			sprintf("rare=%d affix=%d",
				objectp(item3)?(int)item3->query_item_rareLevel():-1,
				objectp(item3)?count_affixes(item3,base):-1));
		int kept = 1;
		array(string) new_names = ITEMSD->
			query_item_current_affixes(item3,base);
		foreach(old_names,string n){
			if(search(new_names,n)==-1)
				kept = 0;
		}
		check("旧词条名无损保留",kept,
			sprintf("old=%O new=%O",old_names,new_names));
		int floored = 1;
		foreach(old_names,string n){
			if((int)call_function(item3["query_"+n])<old_values[n])
				floored = 0;
		}
		check("旧词条数值不低于原值（保值）",floored,"数值回退");

		// 3) 不传fill时保持回收语义：恰好forced条
		object|zero item_exact = ITEMSD->get_convert_item(base,3,10,10,
			item2,copy_value(old_names));
		check("回收语义不受影响（仍=forced条数）",
			objectp(item_exact) &&
			(int)item_exact->query_item_rareLevel()==2,
			sprintf("rare=%d",
				objectp(item_exact)?
					(int)item_exact->query_item_rareLevel():-1));

		// 4) 批量flag归一化顺序（sscanf之后）
		string source = Stdio.read_file(
			ROOT+"/gamelib/cmds/convert_equip_confirm.pike");
		int parse_pos = search(source,"sscanf(arg,");
		int batch_pos = search(source,"if(flag>=6){");
		check("批量归一化已移到sscanf之后",
			parse_pos>0 && batch_pos>parse_pos,
			sprintf("parse=%d batch=%d",parse_pos,batch_pos));
		check("批量明细逐次呈现",
			search(source,"【本次明细】")!=-1 &&
			search(source,"attempt_log")!=-1,
			"缺明细");
	};
	if(err)
		error_desc = describe_error(err);
	if(error_desc!="")
		check("增加属性语义流程无异常",0,error_desc);
	else
		check("增加属性语义流程无异常",1,"");
	werror("[增加属性语义] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
