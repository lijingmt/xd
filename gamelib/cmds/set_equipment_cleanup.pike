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

/* ===== 角色仓库套装清理（2026-09-30 玩家反馈"仓库爆了"）=====
 * 逐行恢复→校验→评估→立即回仓，仓库净零容量变化；重复件销毁
 * 换银两，比较口径与背包清理一致：稀有度绝对优先，评分次之。
 * 共享仓库行在ACCOUNT_STORAGED锁控下，另开一轮，不在本入口。
 */
private array(array) cangku_snapshot_rows(object player)
{
	array(array) rows=({});
	if(!arrayp(player->packaged_items))
		return rows;
	foreach(player->packaged_items,array row)
		if(arrayp(row) && sizeof(row)>=8 && stringp(row[7]) &&
		   sizeof((string)row[7])==64)
			rows+=({row});
	return rows;
}

private object cangku_restore_row(object player,string sid)
{
	object ob=player->repackaged_by_storage_id(sid);
	if(!ob)
		return 0;
	if(ob->is("combine_item"))
		ob->move_player(player->query_name());
	else
		ob->move(player);
	return ob;
}

/** 评估快照：恢复全部套装行并立即回仓，返回分组与重复件候选。
 * 回仓失败（理论不可达：本行刚腾出）的件留在背包并计入leftover。 */
mapping query_cangku_set_state(object player)
{
	mapping(string:array(mapping)) groups=([]);
	array(mapping) duplicates=({});
	array(string) leftover=({});
	int set_rows=0;
	foreach(cangku_snapshot_rows(player),array row){
		object ob=cangku_restore_row(player,(string)row[7]);
		if(!ob)
			continue;
		string key="";
		if(environment(ob)==player &&
		   query_set_cleanup_reject_reason(player,ob)=="" &&
		   is_set_equipment(ob))
			key=query_set_group_key(ob);
		if(key!=""){
			if(!groups[key])
				groups[key]=({});
			groups[key]+=({([
				"base_name":(string)ob->query_name(),
				"name":(string)ob->query_name_cn(),
				"rare":(int)ob->query_item_rareLevel(),
				"score":AUTO_EQUIP_CMD->query_item_score(ob),
				"value":query_set_cleanup_value(ob),
			])});
			set_rows++;
		}
		// packaged()只写快照行不销毁原对象；回仓成功必须destruct，
		// 否则背包残留实体在后续存仓时被反复快照（仓库行数滚雪球）。
		if(player->packaged(ob,player->query_cangku_size()))
			leftover+=({(string)ob->query_name_cn()});
		else
			destruct(ob);
	}
	// 回仓会重建行并丢失第8列永久ID；重新读取共享仓把ID就地
	// 补齐，否则后续执行扫描（cangku_snapshot_rows按ID找行）
	// 看不到任何行。与登录路径的补齐调用同源。
	ACCOUNT_STORAGED->query_storage(player);
	foreach(sort(indices(groups)),string key){
		array(mapping) items=groups[key];
		if(sizeof(items)<2)
			continue;
		int keep_index=0;
		for(int index=1;index<sizeof(items);index++)
			if((int)items[index]["rare"]>(int)items[keep_index]["rare"] ||
			   ((int)items[index]["rare"]==
					(int)items[keep_index]["rare"] &&
				(int)items[index]["score"]>
					(int)items[keep_index]["score"]))
				keep_index=index;
		for(int index=0;index<sizeof(items);index++)
			if(index!=keep_index)
				duplicates+=({items[index]});
	}
	return (["groups":groups,"duplicates":duplicates,
		"leftover":leftover,"set_rows":set_rows]);
}

/** 执行清理：按预览分组逐组恢复全部成员，保留最优一件回仓，
 * 其余销毁换银两。每件执行前重新过全部硬保护（与背包口径一致）。 */
mapping perform_cangku_set_cleanup(object player)
{
	mapping(string:mixed) result=(["count":0,"money":0,"names":({})]);
	mapping state=query_cangku_set_state(player);
	mapping(string:array(mapping)) groups=
		(mapping)state["groups"];
	if(!player || player->query_in_combat() || !sizeof(groups))
		return result;
	foreach(sort(indices(groups)),string key){
		array(mapping) snaps=groups[key];
		if(sizeof(snaps)<2)
			continue;
		multiset(string) base_names=(<>);
		foreach(snaps,mapping snap)
			base_names[(string)snap["base_name"]]=1;
		// 组成员按底版名匹配当前仓库行；玩家在预览后动过仓库时
		// 逐件重校验失败关闭。
		array(array) rows=cangku_snapshot_rows(player);
		array(object) members=({});
		object|zero best=0;
		foreach(rows,array row){
			if(!base_names[(string)row[0]])
				continue;
			object ob=cangku_restore_row(player,(string)row[7]);
			if(!ob || environment(ob)!=player ||
			   query_set_cleanup_reject_reason(player,ob)!="" ||
			   !is_set_equipment(ob) ||
			   query_set_group_key(ob)!=key){
				if(ob){
					if(player->packaged(ob,
						player->query_cangku_size()))
						continue;
					destruct(ob);
				}
				continue;
			}
			members+=({ob});
			if(!best ||
			   (int)ob->query_item_rareLevel()>
					(int)best->query_item_rareLevel() ||
			   ((int)ob->query_item_rareLevel()==
					(int)best->query_item_rareLevel() &&
				AUTO_EQUIP_CMD->query_item_score(ob)>
					AUTO_EQUIP_CMD->query_item_score(best)))
				best=ob;
		}
		// 组内有效成员不足2件（预览后变动）时全部原样回仓。
		if(sizeof(members)<2 || !best){
			foreach(members,object ob){
				if(player->packaged(ob,player->query_cangku_size()))
					continue;
				destruct(ob);
			}
			continue;
		}
		foreach(members,object ob){
			if(ob==best){
				if(player->packaged(ob,player->query_cangku_size()))
					continue;
				destruct(ob);
				continue;
			}
			string name=(string)ob->query_name_cn();
			string path=(file_name(ob)/"#")[0];
			string collection=(string)ob->
				query_newmoon_collection_id();
			int value=query_set_cleanup_value(ob);
			mixed remove_err=catch{ ob->remove(); };
			if(remove_err || ob)
				continue;
			player->add_money(value);
			result["count"]=(int)result["count"]+1;
			result["money"]=(int)result["money"]+value;
			result["names"]+=({name});
			ASYNC_IOD->append_log(SET_CLEANUP_LOG,
				MUD_TIMESD->get_mysql_timedesc()+" user="+
				(string)player->query_name()+" collection="+
				collection+" item="+
				replace(name,(["\n":" ","\r":" "]))+
				" path="+path+" money="+(string)value+
				" scope=cangku\n");
		}
	}
	return result;
}

string render_cangku_cleanup_view(object player)
{
	mapping state=query_cangku_set_state(player);
	array(mapping) duplicates=(array)state["duplicates"];
	array(string) leftover=(array)state["leftover"];
	int total_value=0;
	string out="§g【角色仓库·重复套装清理】§r\n"+
		"扫描角色仓库中的新月套装件，每组保留稀有度最高的一件"+
		"（同稀有比评分），其余销毁换银两。\n"+
		"保护规则与背包清理一致：任务/唯一/玩家标记/锻造/融合/"+
		"镶嵌/特殊来源件不会进入候选。\n\n";
	mapping(string:int) group_counts=([]);
	foreach(sort(indices((mapping)state["groups"])),string key){
		array(mapping) items=((mapping)state["groups"])[key];
		if(sizeof(items)<2)
			continue;
		string label=(string)items[0]["name"];
		group_counts[label]=(int)group_counts[label]+
			sizeof(items)-1;
	}
	if(!sizeof(group_counts))
		out+="角色仓库里没有可清理的重复套装件。\n";
	else{
		foreach(sort(indices(group_counts)),string label)
			out+="· "+label+"：清理"+group_counts[label]+"件\n";
		foreach(duplicates,mapping dup)
			total_value+=(int)dup["value"];
		out+="\n预计销毁"+sizeof(duplicates)+"件，获得约"+
			MUD_MONEYD->query_store_money_cn(total_value)+"。\n";
	}
	if(sizeof(leftover))
		out+="⚠ 有"+sizeof(leftover)+"件评估后未能回仓，"+
			"已留在背包，请手动处理。\n";
	out+="\n";
	if(sizeof(duplicates))
		out+="[确认清理角色仓库重复套装:"+
			"set_equipment_cleanup cangku sell]\n";
	out+="[背包套装清理:set_equipment_cleanup]|"+
		"[仓库助手:personal_storage]|[返回游戏:look]\n";
	return out;
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
	int bound;
	if(!player || !item || environment(item)!=player)
		return "not_in_backpack";
	if(!is_set_equipment(item))
		return "not_set";
	if(item->equiped)
		return "equipped";
	bound=functionp(item->query_newmoon_account_bound) &&
		(int)item->query_newmoon_account_bound()==1;
	// 账号绑定的新月套装件允许清理：清理只给银两不给物品，不存在
	// 跨账号风险。绑定件的canTrade/canDrop/canStorage=0不再把套装
	// 挡在清理之外（玩家反馈"套装放不下又销毁不了"；幻境角色还不能
	// 使用账号共享仓库，绑定件没有其他出口）。绑定归属必须匹配当前
	// 人物，其余任务/唯一/玩家标记等硬保护仍然生效。
	if(bound && !item->query_newmoon_binding_matches_owner(player))
		return "not_owner";
	if(item->query_item_task()==1)
		return "task_item";
	if(!bound && (item->query_item_canTrade()!=1 ||
	   item->query_item_canDrop()!=1 ||
	   item->query_item_canStorage()!=1))
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
		int keep_rare;
		if(sizeof(items)<2)
			continue;
		// 稀有度绝对优先再比评分：高级精制的等级权重会压过低级
		// 幻化（canLevel×100000），玩家实测“清了幻化留精制”——
		// 幻化/空觉等高稀有前缀件是不可再生掉落，永远优先保留。
		keep_rare=(int)items[0]->query_item_rareLevel();
		keep_score=AUTO_EQUIP_CMD->query_item_score(items[0]);
		for(int index=1;index<sizeof(items);index++){
			int score=AUTO_EQUIP_CMD->query_item_score(items[index]);
			int rare=(int)items[index]->query_item_rareLevel();
			if(rare>keep_rare ||
			   (rare==keep_rare && score>keep_score)){
				keep_index=index;
				keep_score=score;
				keep_rare=rare;
			}
		}
		for(int index=0;index<sizeof(items);index++)
			if(index!=keep_index)
				candidates+=({items[index]});
	}
	return candidates;
}

/**
 * 绑定套装清理候选：背包内未穿戴、账号绑定、且通过全部硬保护的新月
 * 套装件。与重复件候选不同，这里不做"每组保留一件"的自动判断——
 * 单件绑定旧装（换系列/换职业后遗留）没有重复件出口，只能由玩家
 * 在预览确认中显式选择销毁。
 */
array(object) query_bound_set_cleanup_candidates(object player)
{
	array(object) candidates=({});
	if(!player)
		return candidates;
	foreach(all_inventory(player),object item){
		if(!is_set_equipment(item))
			continue;
		if(!(functionp(item->query_newmoon_account_bound) &&
		   (int)item->query_newmoon_account_bound()==1))
			continue;
		if(query_set_cleanup_reject_reason(player,item)!="")
			continue;
		candidates+=({item});
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

mapping(string:mixed) perform_bound_set_cleanup(object player,
	array(object) preview_items)
{
	mapping(string:mixed) result=(["count":0,"money":0,"names":({})]);
	if(!player || player->query_in_combat() || !arrayp(preview_items))
		return result;
	foreach(preview_items,object item){
		string name;
		string path;
		string collection;
		int value;
		// 逐件重新校验：确认页与执行之间物品可能被穿戴、移动或
		// 保护状态变化。失败关闭，只跳过该件。
		if(!item || !is_set_equipment(item) ||
		   !functionp(item->query_newmoon_account_bound) ||
		   (int)item->query_newmoon_account_bound()!=1 ||
		   query_set_cleanup_reject_reason(player,item)!="")
			continue;
		name=(string)item->query_name_cn();
		path=(file_name(item)/"#")[0];
		collection=(string)item->query_newmoon_collection_id();
		value=query_set_cleanup_value(item);
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
			" path="+path+" money="+(string)value+" bound=1\n");
	}
	return result;
}

/** 挂机套装回收开关（默认关闭；独立于智能清包，套装保护不受其品质档影响）。 */
int query_set_recycle_enabled(object player)
{
	if(!player)
		return 0;
	return (int)(player["/plus/autofight_set_recycle"] || 0) == 1;
}

mapping(string:mixed) set_recycle_enabled(object player,int enabled)
{
	if(!player)
		return (["ok":0,"message":"人物无效"]);
	player["/plus/autofight_set_recycle"] = enabled ? 1 : 0;
	return (["ok":1,"enabled":enabled?1:0]);
}

/**
 * 挂机自动套装回收tick：只处理"同系列+同职业+同主题+同部位"的
 * 未绑定重复件（每组保留评分最高一件），复用手动清理的全部硬保护；
 * 账号绑定件不进入自动回收，只在手动入口中显式销毁；
 * 战斗中不执行（perform_set_cleanup自身也拒绝战斗态）。
 * 返回 (["count":N,"money":M])。
 */
mapping(string:mixed) auto_set_recycle_tick(object player)
{
	mapping(string:mixed) result = (["count":0,"money":0]);
	array(object) candidates;
	mapping(string:mixed) done;
	if(!query_set_recycle_enabled(player) || !player ||
	   player->query_in_combat())
		return result;
	mixed err = catch {
		candidates = query_set_cleanup_candidates(player);
	};
	if(err || !arrayp(candidates) || !sizeof(candidates))
		return result;
	// 自动回收只处理未绑定重复件：绑定件是玩家穿戴投入过的套装，
	// 仍只在一键清理/预览确认/绑定清理等手动入口中显式销毁。
	{
		array(object) unbound=({});
		foreach(candidates,object item){
			if(item && functionp(item->query_newmoon_account_bound) &&
			   (int)item->query_newmoon_account_bound()==1)
				continue;
			unbound+=({item});
		}
		candidates=unbound;
	}
	if(!sizeof(candidates))
		return result;
	err = catch {
		done = perform_set_cleanup(player,candidates);
	};
	if(err || !mappingp(done))
		return result;
	result["count"] = (int)done["count"];
	result["money"] = (int)done["money"];
	return result;
}

string render_set_manager(object player)
{
	mapping(string:int) collections=([]);
	int total=0;
	int equipped=0;
	array(object) candidates=query_set_cleanup_candidates(player);
	array(object) bound_items=query_bound_set_cleanup_candidates(player);
	string out="【套装管理】\n";
	foreach(all_inventory(player),object item){
		string label;
		if(!is_set_equipment(item))
			continue;
		total++;
		if(item->equiped)
			equipped++;
		label=(string)item->query_newmoon_collection_name()+"·"+
			(string)item->query_newmoon_resonance_profession_cn();
		collections[label]=(int)collections[label]+1;
	}
	out+="背包套装："+total+"件；已穿"+equipped+"件。\n";
	foreach(sort(indices(collections)),string label)
		out+="· "+label+"："+(int)collections[label]+"件\n";
	if(!total)
		out+="背包里暂时没有套装。\n";
	out+="\n重复件候选："+sizeof(candidates)+"件。系统按同系列、同职业、"+
		"同主题、同部位分组，每组永久保留评分最高的一件；账号绑定的"+
		"重复件同样参与清理。\n";
	out+="已穿、任务、玩家标记、锻造、融合、镶嵌、"+
		"特殊来源、空觉及以上套装不会进入候选。\n";
	if(sizeof(bound_items))
		out+="绑定未穿件："+sizeof(bound_items)+"件。绑定件不能交易/"+
			"丢弃/存仓（幻境角色也不能用共享仓库），可在下方显式"+
			"销毁换取银两。\n";
	out+="\n";
	out+="[只看套装:inventory_filter category set]|"+
		"[套装优先穿装:auto_equip set]\n";
	if(sizeof(candidates))
		out+="[一键清理重复套装:set_equipment_cleanup sell]|"+
			"[预览后清理:set_equipment_cleanup preview]\n";
	if(sizeof(bound_items))
		out+="[清理绑定套装:set_equipment_cleanup bound]\n";
	out+="[清理角色仓库重复套装:set_equipment_cleanup cangku]\n";
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
	if(arg=="cangku" || arg=="cangku sell"){
		if(player->if_over_easy_load &&
			player->if_over_easy_load()){
			write("背包已满。仓库清理需要临时取出评估，"+
				"请先清出背包空间再试。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		if(arg=="cangku"){
			write(render_cangku_cleanup_view(player));
			return 1;
		}
		mapping done=perform_cangku_set_cleanup(player);
		if((int)done["count"]<=0){
			write("仓库套装状态变化，本次没有清理任何物品。\n"+
				"[返回:set_equipment_cleanup cangku]\n");
			return 1;
		}
		if(functionp(player->save_with_result) &&
			!player->save_with_result()){
			write("⚠ 存档失败，请重新登录确认银两与仓库。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		write("【仓库套装清理】共销毁"+(int)done["count"]+
			"件重复套装，获得"+
			MUD_MONEYD->query_store_money_cn((int)done["money"])+
			"，每组最优件已放回角色仓库。\n"+
			"[再次清理:set_equipment_cleanup cangku]|"+
			"[仓库助手:personal_storage]|[返回游戏:look]\n");
		return 1;
	}
	if(arg=="sell"){
		// 一键清理：内部完成预览+确认+执行，保持全部安全闸门。
		// 只清理通过 reject 校验的重复件（每组保留评分最高一件），
		// 不跳过任何安全检查。
		candidates=query_set_cleanup_candidates(player);
		if(!sizeof(candidates)){
			write("没有可清理的重复套装件。\n"+
				"[返回套装管理:set_equipment_cleanup]\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		int quick_value=0;
		foreach(candidates,object item)
			quick_value+=query_set_cleanup_value(item);
		mapping quick=perform_set_cleanup(player,candidates);
		if((int)quick["count"]<=0){
			write("套装状态变化，本次没有清理任何物品。\n"+
				"[返回套装管理:set_equipment_cleanup]\n");
			return 1;
		}
		string quick_out="【一键套装清理】已清理"+
			(int)quick["count"]+"件重复套装，获得"+
			MUD_MONEYD->query_store_money_cn((int)quick["money"])+"。\n";
		array(string) quick_names=(array)quick["names"];
		for(int q=0;q<sizeof(quick_names) && q<15;q++)
			quick_out+="· "+quick_names[q]+"\n";
		if(sizeof(quick_names)>15)
			quick_out+="……另有"+(sizeof(quick_names)-15)+"件。\n";
		if(!player->save_with_result()){
			write(quick_out+
				"⚠ 存档失败，请重新登录确认银两。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		write(quick_out+
			"[继续清理:set_equipment_cleanup sell]|"+
			"[套装管理:set_equipment_cleanup]\n[返回游戏:look]\n");
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
	if(arg=="bound"){
		array(object) bound_items;
		int value=0;
		string out="【绑定套装清理预览】\n";
		bound_items=query_bound_set_cleanup_candidates(player);
		if(!sizeof(bound_items)){
			write("当前没有可清理的绑定套装件。\n"+
				"[返回套装管理:set_equipment_cleanup]\n");
			return 1;
		}
		player["/tmp/set_equipment_cleanup/bound_objects"]=
			query_set_cleanup_runtime_refs(bound_items);
		player["/tmp/set_equipment_cleanup/bound_runtime_nonce"]=
			PLAYER_TRANSFERD->query_ephemeral_runtime_nonce();
		player["/tmp/set_equipment_cleanup/bound_created_at"]=time();
		foreach(bound_items,object item)
			value+=query_set_cleanup_value(item);
		out+="将销毁"+sizeof(bound_items)+"件账号绑定套装件，获得"+
			MUD_MONEYD->query_store_money_cn(value)+"。\n";
		for(int index=0;index<sizeof(bound_items) && index<30;index++)
			out+="· "+(string)bound_items[index]->query_short()+"\n";
		if(sizeof(bound_items)>30)
			out+="……另有"+(sizeof(bound_items)-30)+"件。\n";
		out+="\n⚠ 绑定套装销毁后不可恢复，成套技能以实际穿戴的10件计算，"+
			"请确认这些不是还想收集的部件。\n"+
			"确认有效期两分钟；确认时会再次逐件校验。\n"+
			"[确认销毁:set_equipment_cleanup bound_confirm]|"+
			"[取消:set_equipment_cleanup]\n";
		write(out);
		return 1;
	}
	if(arg=="bound_confirm"){
		array(object) preview;
		int created_at;
		int same_runtime;
		mapping result;
		preview=resolve_set_cleanup_runtime_refs(player,
			(array)(player["/tmp/set_equipment_cleanup/bound_objects"] ||
				({})));
		created_at=(int)player[
			"/tmp/set_equipment_cleanup/bound_created_at"];
		same_runtime=(string)player[
			"/tmp/set_equipment_cleanup/bound_runtime_nonce"]==
			PLAYER_TRANSFERD->query_ephemeral_runtime_nonce();
		player->m_delete_foruser(
			"/tmp/set_equipment_cleanup/bound_objects");
		player->m_delete_foruser(
			"/tmp/set_equipment_cleanup/bound_created_at");
		player->m_delete_foruser(
			"/tmp/set_equipment_cleanup/bound_runtime_nonce");
		if(!same_runtime || !created_at ||
		   time()-created_at>SET_CLEANUP_CONFIRM_SECONDS ||
		   !sizeof(preview)){
			write("绑定清理确认已失效，请重新预览。\n"+
				"[重新预览:set_equipment_cleanup bound]\n");
			return 1;
		}
		result=perform_bound_set_cleanup(player,preview);
		if((int)result["count"]<=0){
			write("绑定套装状态已经变化，本次没有清理任何物品。\n"+
				"[返回套装管理:set_equipment_cleanup]\n");
			return 1;
		}
		if(!player->save_with_result()){
			write("绑定套装清理完成：销毁"+(int)result["count"]+
				"件，获得"+MUD_MONEYD->query_store_money_cn(
				(int)result["money"])+"。\n"+
				"⚠ 存档失败，请重新登录确认银两。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		write("绑定套装清理完成：销毁"+(int)result["count"]+
			"件，获得"+MUD_MONEYD->query_store_money_cn(
			(int)result["money"])+"。\n"+
			"[继续管理套装:set_equipment_cleanup]|[返回游戏:look]\n");
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
