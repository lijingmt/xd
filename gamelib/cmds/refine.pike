#include <command.h>
#include <gamelib/include/gamelib.h>
// 装备提炼：每次成功+1级、全属性+1%。碎玉+淬炼石+金币三种材料，
// 成功率随等级下降；门槛级失败降级（守护符减免），普通失败保级。
// 任何地点可用（含新月幻境S1）。

private int is_refinable(object ob)
{
	return ob && ITEMSD->can_equip(ob) && (
		(ob->query_item_rareLevel()>0) ||
		(ob->query_item_canLevel()>=1 &&
		 (sizeof(ob->query_name_cn()/"】"))==1) ||
		(functionp(ob->query_newmoon_collection_id) &&
		 (string)ob->query_newmoon_collection_id()!=""));
}

private string success_desc(int bp)
{
	int whole=bp/100;
	int frac=bp%100;
	if(frac==0)
		return (string)whole+"%";
	return whole+"."+(frac<10 ? "0" : "")+frac+"%";
}

int main(string|zero arg)
{
	object me=this_player();
	string s="";
	if(!me)
		return 1;
	if(!arg || arg==""){
		s="【装备提炼】成功+1级，全属性+1%；可无限提炼。\n";
		s+="材料：碎玉+淬炼石（PK击杀其他玩家掉落）+金币。\n";
		s+="门槛规则：冲10/20/30…级失败降3级；100级后每50级、"+
			"1000级后每100级为门槛，失败降当前等级30%（守护符减免为降3级）。\n";
		s+="请选择要提炼的装备：\n";
		int listed=0;
		foreach(all_inventory(me),object ob){
			if(!is_refinable(ob) ||
			   !functionp(ob->query_refine_level))
				continue;
			int level=(int)ob->query_refine_level();
			mapping costs=REFINED->query_refine_costs(level);
			int rate=REFINED->query_refine_success_rate(level);
			int threshold=REFINED->query_is_threshold_attempt(level);
			s+="[+"+level+" "+ob->query_name_cn()+":refine "+
				ob->query_name()+"]("+success_desc(rate)+"/"+
				costs["yushi"]+"玉+"+costs["stone"]+"石)";
			if(threshold)
				s+="⚠门槛";
			s+="\n";
			listed++;
		}
		if(!listed)
			s+="身上没有可提炼的装备。\n";
		s+="[返回游戏:look]\n";
		write(s);
		return 1;
	}
	object|zero item=0;
	foreach(all_inventory(me),object ob){
		if(is_refinable(ob) && ob->query_name()==arg){
			item=ob;
			break;
		}
	}
	if(!item){
		write("请确认你身上有这件装备。\n[返回:refine]\n[返回游戏:look]\n");
		return 1;
	}
	mapping result=REFINED->attempt_refine(me,item);
	s=(string)result["message"]+"\n";
	if((int)result["ok"] && (int)result["success"])
		s+="[继续提炼:refine "+arg+"]\n";
	else
		s+="[返回:refine]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
