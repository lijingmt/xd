#include <command.h>
#include <gamelib/include/gamelib.h>
// 一键清理空觉~三摩地前缀装备（玩家反馈：高幸运掉落大量前缀装
// 占满背包）。只清：未装备、非新月绑定、可丢弃可交易的非任务装备；
// 已装备/绑定/保护名单内的一律不碰。先预览分类再确认。
// arg: 0/空=预览  confirm=执行
// 前缀档位：8空觉 9破空 10寂灭 11三摩地；0=全部
private array(int) prefix_tiers=({8,9,10,11});
private mapping(int:string) tier_names=([
	8:"空觉",9:"破空",10:"寂灭",11:"三摩地",
]);

private array(object) query_cleanup_gear(object me,void|int tier)
{
	array(object) result=({});
	foreach(all_inventory(me),object ob){
		if(!ob || !functionp(ob->query_item_rareLevel))
			continue;
		if(!ITEMSD->can_equip(ob))
			continue;
		if((int)ob->query_item_rareLevel()<8)
			continue;
		if(tier>0 && (int)ob->query_item_rareLevel()!=tier)
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
	int tier=0;
	// 参数形态：confirm [档位] / 纯档位数字 / 页面
	if(arg && sscanf(arg,"confirm %d",tier)==2)
		action="confirm";
	else if(arg && sscanf(arg,"%d",tier)==1)
		action="";
	else if(arg)
		sscanf(arg,"%s",action);
	gear=query_cleanup_gear(me,tier);
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
			"件"+(tier>0 ? tier_names[tier] : "空觉~三摩地")+
			"装备，背包已腾出空间。\n"+
			"[继续清理:prefix_gear_cleanup]|[返回游戏:look]\n");
		return 1;
	}
	s="§g前缀装备清理§r（空觉/破空/寂灭/三摩地）";
	if(tier>0)
		s+="——仅"+tier_names[tier];
	s+="\n";
	// 分档快捷入口：每档独立预览/清理
	string tier_links="";
	foreach(prefix_tiers,int one){
		tier_links+="["+tier_names[one]+
			"("+(string)sizeof(query_cleanup_gear(me,one))+
			"件):prefix_gear_cleanup "+(string)one+"] ";
	}
	s+=tier_links+"\n";
	s+="[全部("+(string)sizeof(query_cleanup_gear(me))+
		"件):prefix_gear_cleanup]\n";
	if(!sizeof(gear)){
		s+="背包里没有可清理的前缀装备"+
			"（已装备、绑定、任务、不可交易的一律跳过）。\n";
	}
	else{
		foreach(sort(indices(by_prefix)),string label)
			s+="· "+label+"　"+(string)by_prefix[label]+"件\n";
		s+="合计"+sizeof(gear)+"件（销毁不返还，换取背包空间）。\n";
		s+="§R确认后将不可恢复，请先自行检查！§r\n";
		s+="[确认销毁:prefix_gear_cleanup confirm"+
			(tier>0 ? " "+(string)tier : "")+"]\n";
	}
	s+="[装备背包:inventory]|[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
