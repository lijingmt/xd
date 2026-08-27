#include <command.h>
#include <gamelib/include/gamelib.h>

#define AUTO_EQUIP_CMD ((object)(ROOT "/gamelib/cmds/auto_equip.pike"))
#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))
#define SET_CLEANUP_CONFIRM_SECONDS 120
#define SET_CLEANUP_LOG ROOT "/log/set_equipment_cleanup.log"

int is_set_equipment(object item)
{
	return item && item->is("item") && item->is("equip") &&
		functionp(item->query_newmoon_resonance_profession) &&
		(string)item->query_newmoon_resonance_profession()!="" &&
		functionp(item->query_newmoon_collection_id) &&
		(string)item->query_newmoon_collection_id()!="";
}

string query_set_group_key(object item)
{
	if(!is_set_equipment(item))
		return "";
	return (string)item->query_newmoon_collection_id()+"|"+
		(string)item->query_newmoon_resonance_profession()+"|"+
		(string)item->query_newmoon_resonance_theme()+"|"+
		(string)item->query_item_kind();
}

private int has_socketed_gem(object item)
{
	if(!item || !functionp(item->query_baoshi))
		return 0;
	foreach(({"blue","red","yellow"}),string color){
		array(object) gems=item->query_baoshi(color);
		if(gems && sizeof(gems))
			return 1;
	}
	return 0;
}

// 套装清理接收未绑定的可交易掉落重复件（含升级/洗炼过的）。
// 旧清包的品质配置不能放宽这里的硬保护；任何状态不明的老物品
// 都失败关闭。
string query_set_cleanup_reject_reason(object player,object item)
{
	string source;
	if(!player || !item || environment(item)!=player)
		return "not_in_backpack";
	if(!is_set_equipment(item))
		return "not_set";
	if(item->equiped)
		return "equipped";
	if(functionp(item->query_newmoon_account_bound) &&
	   (int)item->query_newmoon_account_bound()==1)
		return "bound";
	if(item->query_item_task()==1)
		return "task_item";
	// 账号绑定的新月套装件允许清理：清理只给银两不给物品，
	// 不存在跨账号风险。绑定件的canTrade=0此前把所有
	// 新月套装挡在清理之外（玩家反馈"套装放不下又销毁不了"）。
	if(functionp(item->query_newmoon_account_bound) &&
	   (int)item->query_newmoon_account_bound()==1){
		// 绑定件跳过canTrade检查，但task/unique/player标记仍拦截
	}
	else if(item->query_item_canTrade()!=1 ||
	   item->query_item_canDrop()!=1 ||
	   item->query_item_canStorage()!=1)
		return "restricted";
	if(item->query_item_only()==1)
		return "unique";
	if(item->item_playerDesc && (string)item->item_playerDesc!="")
		return "player_marked";
	if((string)item->query_item_from()!="")
		return "special_source";
	// 升级/洗炼过的套装件（convert_count>0）允许清理：玩家升级后
	// 的重复件无处可去（原"converted"一刀切拒绝），绑定/任务/唯一
	// 等硬保护已在前面拦截，这里只做显式选中的销毁。
	if(has_socketed_gem(item))
		return "socketed";
	source=(file_name(item)/"#")[0];
	if(search(source,"/duanzao/")!=-1 ||
	   search(source,"/suit_")!=-1 ||
	   search(source,"Xa")!=-1 || search(source,"Xl")!=-1 ||
	   search(source,"Xh")!=-1 || search(source,"Xf")!=-1)
		return "forged_or_fused";
	// 空觉及以上仍是永久珍品保护线。
	if((int)item->query_item_rareLevel()>=8)
		return "rare";
	return "";
}

int query_set_cleanup_value(object item)
{
	int value;
	if(!is_set_equipment(item))
		return 0;
	value=(int)item->query_item_canLevel()*50/4;
	return max(1,value);
}

array(object) query_set_cleanup_candidates(object player)
{
	mapping(string:array(object)) groups=([]);
	array(object) candidates=({});
	if(!player)
		return candidates;
	foreach(all_inventory(player),object item){
		string key;
		if(query_set_cleanup_reject_reason(player,item)!="")
			continue;
		key=query_set_group_key(item);
		if(key=="")
			continue;
		if(!groups[key])
			groups[key]=({});
		groups[key]+=({item});
	}
	foreach(sort(indices(groups)),string key){
		array(object) items=groups[key];
		int keep_index=0;
		int keep_score;
		if(sizeof(items)<2)
			continue;
		keep_score=AUTO_EQUIP_CMD->query_item_score(items[0]);
		for(int index=1;index<sizeof(items);index++){
			int score=AUTO_EQUIP_CMD->query_item_score(items[index]);
			if(score>keep_score){
				keep_index=index;
				keep_score=score;
			}
		}
		for(int index=0;index<sizeof(items);index++)
			if(index!=keep_index)
				candidates+=({items[index]});
	}
	return candidates;
}

array(string) query_set_cleanup_runtime_refs(array(object) items)
{
	array(string) refs=({});
	foreach(items,object item)
		if(item)
			refs+=({file_name(item)});
	return refs;
}

array(object) resolve_set_cleanup_runtime_refs(object player,array refs)
{
	array(object) resolved=({});
	if(!player || !arrayp(refs))
		return resolved;
	foreach(refs,mixed raw_ref){
		object matched;
		if(!stringp(raw_ref) || (string)raw_ref=="")
			continue;
		foreach(all_inventory(player),object item)
			if(item && file_name(item)==(string)raw_ref){
				matched=item;
				break;
			}
		if(matched && search(resolved,matched)==-1)
			resolved+=({matched});
	}
	return resolved;
}

mapping(string:mixed) perform_set_cleanup(object player,
	array(object) preview_items)
{
	mapping(string:mixed) result=(["count":0,"money":0,"names":({})]);
	array(object) live_candidates;
	if(!player || player->query_in_combat() || !arrayp(preview_items))
		return result;
	live_candidates=query_set_cleanup_candidates(player);
	foreach(preview_items,object item){
		string name;
		string path;
		string collection;
		int value;
		if(!item || search(live_candidates,item)==-1 ||
		   query_set_cleanup_reject_reason(player,item)!="")
			continue;
		name=(string)item->query_name_cn();
		path=(file_name(item)/"#")[0];
		collection=(string)item->query_newmoon_collection_id();
		value=query_set_cleanup_value(item);
		// 先销毁精确候选，再结算银两。即使 remove() 抛错或被物品
		// 自身拒绝，也不能让同一件套装被反复兑换银两。
		mixed remove_err=catch{ item->remove(); };
		if(remove_err || item)
			continue;
		player->add_money(value);
		result["count"]=(int)result["count"]+1;
		result["money"]=(int)result["money"]+value;
		result["names"]+=({name});
		ASYNC_IOD->append_log(SET_CLEANUP_LOG,
			MUD_TIMESD->get_mysql_timedesc()+" user="+
			(string)player->query_name()+" collection="+collection+
			" item="+replace(name,(["\n":" ","\r":" "]))+
			" path="+path+" money="+(string)value+"\n");
	}
	return result;
}

string render_set_manager(object player)
{
	mapping(string:int) collections=([]);
	int total=0;
	int equipped=0;
	int bound=0;
	array(object) candidates=query_set_cleanup_candidates(player);
	string out="【套装管理】\n";
	foreach(all_inventory(player),object item){
		string label;
		if(!is_set_equipment(item))
			continue;
		total++;
		if(item->equiped)
			equipped++;
		if(functionp(item->query_newmoon_account_bound) &&
		   (int)item->query_newmoon_account_bound()==1)
			bound++;
		label=(string)item->query_newmoon_collection_name()+"·"+
			(string)item->query_newmoon_resonance_profession_cn();
		collections[label]=(int)collections[label]+1;
	}
	out+="背包套装："+total+"件；已穿"+equipped+"件；已绑定"+
		bound+"件。\n";
	foreach(sort(indices(collections)),string label)
		out+="· "+label+"："+(int)collections[label]+"件\n";
	if(!total)
		out+="背包里暂时没有套装。\n";
	out+="\n重复件候选："+sizeof(candidates)+"件。系统按同系列、同职业、"+
		"同主题、同部位分组，每组永久保留评分最高的一件。\n";
	out+="已穿、账号绑定、任务、玩家标记、洗炼、锻造、融合、镶嵌、"+
		"特殊来源、空觉及以上套装不会进入候选。\n\n";
	out+="[只看套装:inventory_filter category set]|"+
		"[套装优先穿装:auto_equip set]\n";
	if(sizeof(candidates))
		out+="[预览清理重复套装:set_equipment_cleanup preview]\n";
	out+="[返回分类背包:inventory_filter]|[返回游戏:look]\n";
	return out;
}

int main(string|zero arg)
{
	object player=this_player();
	array(object) candidates;
	if(!player)
		return 0;
	if(player->query_in_combat()){
		write("交战中不能整理套装，请脱离战斗后再试。\n"+
			"[返回战斗:flushview]\n");
		return 1;
	}
	if(arg=="preview"){
		int value=0;
		string out="【重复套装清理预览】\n";
		candidates=query_set_cleanup_candidates(player);
		if(!sizeof(candidates)){
			write("当前没有可安全清理的重复套装。\n"+
				"[返回套装管理:set_equipment_cleanup]\n");
			return 1;
		}
		// data_tmp is part of the legacy archive. Store only ephemeral clone
		// identity strings so an autosave can never serialize live objects.
		player["/tmp/set_equipment_cleanup/objects"]=
			query_set_cleanup_runtime_refs(candidates);
		player["/tmp/set_equipment_cleanup/runtime_nonce"]=
			PLAYER_TRANSFERD->query_ephemeral_runtime_nonce();
		player["/tmp/set_equipment_cleanup/created_at"]=time();
		foreach(candidates,object item)
			value+=query_set_cleanup_value(item);
		out+="将清理"+sizeof(candidates)+"件同组较弱重复件，预计获得"+
			MUD_MONEYD->query_store_money_cn(value)+"。\n";
		for(int index=0;index<sizeof(candidates) && index<30;index++)
			out+="· "+(string)candidates[index]->query_short()+"\n";
		if(sizeof(candidates)>30)
			out+="……另有"+(sizeof(candidates)-30)+"件。\n";
		out+="\n确认有效期两分钟；确认时会再次校验并至少保留每组最优一件。\n"+
			"[确认清理:set_equipment_cleanup confirm]|"+
			"[取消:set_equipment_cleanup]\n";
		write(out);
		return 1;
	}
	if(arg=="confirm"){
		array(object) preview=resolve_set_cleanup_runtime_refs(player,
			(array)(player["/tmp/set_equipment_cleanup/objects"] || ({})));
		int created_at=(int)player[
			"/tmp/set_equipment_cleanup/created_at"];
		int same_runtime=(string)player[
			"/tmp/set_equipment_cleanup/runtime_nonce"]==
			PLAYER_TRANSFERD->query_ephemeral_runtime_nonce();
		player->m_delete_foruser("/tmp/set_equipment_cleanup/objects");
		player->m_delete_foruser("/tmp/set_equipment_cleanup/created_at");
		player->m_delete_foruser("/tmp/set_equipment_cleanup/runtime_nonce");
		if(!same_runtime || !created_at ||
		   time()-created_at>SET_CLEANUP_CONFIRM_SECONDS ||
		   !sizeof(preview)){
			write("清理确认已失效，请重新预览。\n"+
				"[重新预览:set_equipment_cleanup preview]\n");
			return 1;
		}
		mapping result=perform_set_cleanup(player,preview);
		if((int)result["count"]<=0)
			write("套装状态已经变化，本次没有清理任何物品。\n");
		else
			write("套装整理完成：清理"+(int)result["count"]+
				"件重复套装，获得"+MUD_MONEYD->query_store_money_cn(
				(int)result["money"])+"。\n");
		write("[继续管理套装:set_equipment_cleanup]|"+
			"[查看背包:inventory]|[返回游戏:look]\n");
		return 1;
	}
	write(render_set_manager(player));
	return 1;
}
