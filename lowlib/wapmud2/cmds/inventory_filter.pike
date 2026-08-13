#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me=this_player();
	string category;
	string keyword;
	string group_id;
	int page;
	if(!me)
		return 1;
	category=(string)(me["/tmp/inventory_browser/category"] || "all");
	keyword=(string)(me["/tmp/inventory_browser/keyword"] || "");
	page=(int)me["/tmp/inventory_browser/page"];
	if(page<1)
		page=1;
	if(arg){
		arg=replace(arg,(["%20":" ","%2B":"+","%3A":":",
			"\r":" ","\n":" "]));
		arg=String.trim_all_whites(arg);
	}
	if(!arg || arg==""){
		write(me->view_inventory_browser(category,page,keyword));
		return 1;
	}
	if(arg=="clear"){
		keyword="";
		page=1;
	}
	else if(sscanf(arg,"category %s",category)==1){
		if(!me->valid_inventory_browser_category(category)){
			write("背包分类无效。\n[返回分类背包:inventory_filter]\n");
			return 1;
		}
		keyword="";
		page=1;
	}
	else if(sscanf(arg,"page %d",page)==1 ||
	   sscanf(arg,"jump %d",page)==1){
		if(page<1 || page>10000){
			write("页码无效，请输入正整数。\n[inventory_filter jump ...]\n"+
				"[返回分类背包:inventory_filter]\n");
			return 1;
		}
	}
	else if(sscanf(arg,"group %s %d",group_id,page)==2){
		if(page<1 || page>10000){
			write("装备组页码无效。\n[返回分类背包:inventory_filter]\n");
			return 1;
		}
		write(me->view_inventory_equipment_group(group_id,page));
		return 1;
	}
	else if(sscanf(arg,"group %s",group_id)==1){
		write(me->view_inventory_equipment_group(group_id,1));
		return 1;
	}
	else if(sscanf(arg,"search %s",keyword)==1){
		keyword=String.trim_all_whites(keyword);
		if(keyword=="" || sizeof(keyword)>96){
			write("请输入1至96字节的搜索词。\n"+
				"[inventory_filter search ...]\n"+
				"[返回分类背包:inventory_filter]\n");
			return 1;
		}
		page=1;
	}
	else{
		write("未知的背包操作。\n[返回分类背包:inventory_filter]\n");
		return 1;
	}
	me["/tmp/inventory_browser/category"]=category;
	me["/tmp/inventory_browser/page"]=page;
	me["/tmp/inventory_browser/keyword"]=keyword;
	write(me->view_inventory_browser(category,page,keyword));
	return 1;
}
