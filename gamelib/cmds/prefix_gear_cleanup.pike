#include <command.h>
#include <gamelib/include/gamelib.h>
// 一键清理空觉~三摩地前缀装备（玩家反馈：高幸运掉落大量前缀装
// 占满背包）。只清：未装备、非新月绑定、可丢弃可交易的非任务装备；
// 已装备/绑定/保护名单内的一律不碰。先预览分类再确认。
// arg: 0/空=预览  confirm=执行
private array(object) query_cleanup_gear(object me)
{
	array(object) result=({});
	foreach(all_inventory(me),object ob){
		if(!ob || !functionp(ob->query_item_rareLevel))
			continue;
		if(!ITEMSD->can_equip(ob))
			continue;
		if((int)ob->query_item_rareLevel()<8)
			continue;
		if(ob->equiped)
			continue;
		// 新月/收藏绑定件不碰（含绑定的前缀底装）。
		if(functionp(ob->query_newmoon_collection_id) &&
		   (string)ob->query_newmoon_collection_id()!="")
			continue;
		if(functionp(ob->query_item_from) &&
		   (string)ob->query_item_from()!="")
			continue;
		if(!functionp(ob->query_item_canDrop) ||
		   !(int)ob->query_item_canDrop())
			continue;
		if(!functionp(ob->query_item_canTrade) ||
		   !(int)ob->query_item_canTrade())
			continue;
		if(functionp(ob->query_item_task) &&
		   (int)ob->query_item_task()==1)
			continue;
		result+=({ob});
	}
	return result;
}

int main(string|zero arg)
{
	object me=this_player();
	string action="";
	array(object) gear;
	mapping(string:int) by_prefix=([]);
	string s;
	if(!me)
		return 0;
	if(me->query_in_combat()){
		write("交战中不能清理，请脱离战斗后再试。\n"+
			"[返回战斗:flushview]\n");
		return 1;
	}
	if(arg)
		sscanf(arg,"%s",action);
	gear=query_cleanup_gear(me);
	foreach(gear,object ob){
		string label=(string)ob->query_rare_level();
		by_prefix[label]=(int)(by_prefix[label] || 0)+1;
	}
	if(action=="confirm"){
		if(!sizeof(gear)){
			write("没有可清理的前缀装备。\n[返回游戏:look]\n");
			return 1;
		}
		int count=0;
		foreach(gear,object ob){
			destruct(ob);
			count++;
		}
		me->save_with_result();
		write("§y清理完成§r：共销毁"+count+
			"件空觉~三摩地装备，背包已腾出空间。\n"+
			"[继续清理:prefix_gear_cleanup]|[返回游戏:look]\n");
		return 1;
	}
	s="§g前缀装备清理§r（空觉/破空/寂灭/三摩地）\n";
	if(!sizeof(gear)){
		s+="背包里没有可清理的前缀装备"+
			"（已装备、绑定、任务、不可交易的一律跳过）。\n";
	}
	else{
		foreach(sort(indices(by_prefix)),string label)
			s+="· "+label+"　"+(string)by_prefix[label]+"件\n";
		s+="合计"+sizeof(gear)+"件（销毁不返还，换取背包空间）。\n";
		s+="§R确认后将不可恢复，请先自行检查！§r\n";
		s+="[确认销毁:prefix_gear_cleanup confirm]\n";
	}
	s+="[装备背包:inventory]|[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
