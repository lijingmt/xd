#include <command.h>
#include <wapmud2/include/wapmud2.h>

#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd"))
#define PROFESSIONVIPD ((object)(ROOT "/gamelib/single/daemons/professionvipd.pike"))

private string format_time(int seconds)
{
	int hours;
	int minutes;
	if(seconds < 0)
		seconds = 0;
	hours = seconds/3600;
	minutes = (seconds%3600)/60;
	return hours+"小时"+minutes+"分钟";
}

private void stop_with_reason(object me, string reason)
{
	AUTOFIGHTD->stop_autofight(me);
	write("\n自动挂机已停止："+reason+"\n");
	write("[挂机设置:autofight open]\n");
	write("[返回游戏:look]\n");
}

private int use_recovery_item(object me,string kind)
{
	object|zero item;
	int count;
	item = AUTOFIGHTD->query_recovery_item_with_newbie_supply(me,kind);
	if(!item)
		return 0;
	count = AUTOFIGHTD->query_object_count(item,me);
	if(kind=="life")
		me->command("eat "+item->query_name()+" "+count);
	else
		me->command("drink "+item->query_name()+" "+count);
	return 1;
}

private int continue_auto_rest(object me)
{
	mapping route;
	object env;
	string current;
	string rest_room;
	string route_path;
	if(!AUTOFIGHTD->query_is_resting(me))
		return 0;
	if(me->in_combat){
		me->command("escape");
		return 1;
	}
	env = environment(me);
	if(!env)
		return 0;
	current = AUTOFIGHTD->query_current_room_path(me);
	rest_room = AUTOFIGHTD->query_rest_room(me);
	if(current!=rest_room){
		AUTOFIGHTD->record_route(me,rest_room);
		me->command("qge74hye "+rest_room);
		AUTOFIGHTD->start_autofight(me);
		return 1;
	}
	if(me->get_cur_life()<me->query_life_max() ||
	   me->get_cur_mofa()<me->query_mofa_max()){
		me->command("sleep");
		return 1;
	}
	AUTOFIGHTD->finish_auto_rest(me);
	route = AUTOFIGHTD->query_training_route(me);
	route_path = (string)route["path"];
	if(AUTOFIGHTD->query_smart_route_enabled(me) && route_path!=""){
		AUTOFIGHTD->record_route(me,route_path);
		me->command("qge74hye "+route_path);
		AUTOFIGHTD->start_autofight(me);
		return 1;
	}
	me->command("look");
	return 1;
}

int main(string|zero arg)
{
	object me;
	object env;
	object|zero target;
	object|zero item;
	object|zero source;
	mapping route;
	mapping sell_result;
	mapping material_sell_result;
	mapping storage_result;
	mapping destroy_result;
	mapping level_window;
	mapping profession_result;
	mapping target_snapshot;
	string reason;
	string direction;
	string route_path;
	string auto_skill;
	string profession_notice;
	int count;
	int left;
	int visible_monsters;
	me = this_player();
	if(!me)
		return 1;
	if(!functionp(me->query_autofight) ||
	   me->query_autofight() != "enable"){
		me->write_view();
		return 1;
	}
	AUTOFIGHTD->initialize_player(me);
	left = AUTOFIGHTD->charge_time(me);
	reason = AUTOFIGHTD->query_runtime_block_reason(me);
	if(reason != ""){
		stop_with_reason(me,reason);
		return 1;
	}
	env = environment(me);
	if(!env){
		stop_with_reason(me,"当前地图无效");
		return 1;
	}
	if(continue_auto_rest(me))
		return 1;
	if(me->in_combat){
		if(AUTOFIGHTD->should_recover_life(me)){
			if(use_recovery_item(me,"life"))
				return 1;
			if(me->get_cur_life()*100<=
			   me->query_life_max()*30 &&
			   AUTOFIGHTD->begin_auto_rest(me)){
				me->command("escape");
				return 1;
			}
		}
		if(AUTOFIGHTD->should_recover_mana(me) &&
		   use_recovery_item(me,"mana"))
			return 1;
		profession_notice = PROFESSIONVIPD->query_monitor_notice(me);
		if(profession_notice != "")
			write(profession_notice+"\n");
		profession_result = PROFESSIONVIPD->try_fangshi_resonance(me);
		if((int)profession_result["success"] == 1){
			write("职业助手已在PVE救援条件下发动灵契共鸣。\n");
			return 1;
		}
		auto_skill = AUTOFIGHTD->query_ready_auto_skill(me);
		if(auto_skill != ""){
			array(string) profession_skills = ({});
			if(me->query_profeId()=="tianxiang")
				profession_skills =
					PROFESSIONVIPD->query_tianxiang_context_candidates(me);
			else if(me->query_profeId()=="lingyi")
				profession_skills =
					PROFESSIONVIPD->query_lingyi_context_candidates(me);
			else
				profession_skills =
					PROFESSIONVIPD->query_zhenyue_context_candidates(me);
			int before_mofa = me->get_cur_mofa();
			int before_cooldown = me->f_skills ?
				(int)me->f_skills[auto_skill] : 0;
			me->perform(auto_skill);
			if(search(profession_skills,auto_skill) != -1 &&
			   (me->get_cur_mofa() < before_mofa ||
			   (me->f_skills &&
			   (int)me->f_skills[auto_skill] > before_cooldown))){
				if(me->query_profeId()=="tianxiang")
					PROFESSIONVIPD->record_tianxiang_action(me,auto_skill);
				else if(me->query_profeId()=="lingyi")
					PROFESSIONVIPD->record_lingyi_action(me,auto_skill);
				else
					PROFESSIONVIPD->record_zhenyue_action(me,auto_skill);
			}
			if(!me->in_combat){
				write("[关闭自动挂机:autofightclose] 今日剩余"+
					format_time(left)+"\n");
				me->command("look");
				return 1;
			}
		}
		write("[关闭自动挂机:autofightclose] 今日剩余"+
			format_time(left)+"\n");
		write(me->query_status()+"\n");
		write(me->query_fighting_msg()+"\n");
		return 1;
	}
	if(AUTOFIGHTD->should_recover_life(me)){
		if(use_recovery_item(me,"life"))
			return 1;
		if(AUTOFIGHTD->begin_auto_rest(me)){
			write("回血药不足，挂机助手正带你前往安全地点休息。\n");
			return continue_auto_rest(me);
		}
		if(!AUTOFIGHTD->query_auto_rest_enabled(me))
			stop_with_reason(me,
				"生命低于保护线、背包无药，且缺药休整已关闭");
		else
			stop_with_reason(me,
				"生命低于保护线，且当前场景不能自动离开休息");
		return 1;
	}
	if(AUTOFIGHTD->should_recover_mana(me)){
		if(use_recovery_item(me,"mana"))
			return 1;
		if(AUTOFIGHTD->begin_auto_rest(me)){
			write("回蓝药不足，挂机助手正带你前往安全地点休息。\n");
			return continue_auto_rest(me);
		}
	}
	profession_notice = PROFESSIONVIPD->query_monitor_notice(me);
	if(profession_notice != "")
		write(profession_notice+"\n");
	profession_result = PROFESSIONVIPD->try_out_of_combat_support(me);
	if((int)profession_result["success"] == 1){
		if(me->query_profeId()=="lingyi")
			write("百草助手已按当前伤势施放一次已学治疗技能。\n");
		else
			write("职业助手已按当前策略补召一只已学灵兽。\n");
		return 1;
	}
	if(AUTOFIGHTD->should_auto_store_non_equipment(me)){
		storage_result =
			AUTOFIGHTD->perform_auto_store_non_equipment(me);
		if((int)storage_result["object_count"] > 0){
			write("挂机助手已自动存入仓库"+
				(int)storage_result["object_count"]+"组，共"+
				(int)storage_result["item_count"]+"个非装备物品。\n");
			write("[查看清理设置:autofight cleanup]\n");
			return 1;
		}
	}
	if(AUTOFIGHTD->should_auto_destroy_non_equipment(me)){
		destroy_result =
			AUTOFIGHTD->perform_non_equipment_destroy(me,"autofight");
		if((int)destroy_result["object_count"] > 0){
			write("挂机助手已安全销毁"+
				(int)destroy_result["object_count"]+"组，共"+
				(int)destroy_result["item_count"]+"个非装备物品。\n");
			write("[查看清理设置:autofight cleanup]\n");
			return 1;
		}
	}
	if(AUTOFIGHTD->should_auto_sell(me)){
		sell_result = AUTOFIGHTD->perform_auto_sell(me);
		if((int)sell_result["count"] > 0){
			write("VIP智能清包已自动出售"+
				(int)sell_result["count"]+"件装备，获得"+
				MUD_MONEYD->query_store_money_cn(
					(int)sell_result["money"])+"。\n");
			write("[查看清包设置:autofight cleanup]\n");
			return 1;
		}
	}
	if(AUTOFIGHTD->should_auto_sell_material(me)){
		material_sell_result =
			AUTOFIGHTD->perform_auto_sell_material(me);
		if((int)material_sell_result["count"] > 0){
			write("采集助手已自动出售"+
				(int)material_sell_result["count"]+"个"+
				(string)material_sell_result["name"]+"，获得"+
				MUD_MONEYD->query_store_money_cn(
					(int)material_sell_result["money"])+"。\n");
			write("[查看挂机设置:autofight open]\n");
			return 1;
		}
	}
	source = AUTOFIGHTD->query_gather_source(me);
	if(source){
		count = AUTOFIGHTD->query_object_count(source,env);
		if(source->query_source_type() == "kuang")
			me->command("viceskill_dig "+source->query_name()+" "+count);
		else
			me->command("viceskill_gather "+source->query_name()+" "+count);
		return 1;
	}
	item = AUTOFIGHTD->query_loot_item(me);
	if(item){
		count = AUTOFIGHTD->query_object_count(item,env);
		me->command("get "+item->query_name()+" "+count);
		// 拾取命令可能因背包状态、并发拾取或物品自身规则失败。
		// 失败物若仍留在原房间，短期跳过它并继续寻敌，避免每秒
		// 重试同一件掉落直至其消失；成功拾取后同一轮即可继续战斗。
		if(item && environment(item)==env){
			AUTOFIGHTD->record_failed_loot(me,item);
			write("该掉落暂时无法拾取，挂机助手会跳过并继续战斗，稍后自动重试。\n");
		}
		else
			AUTOFIGHTD->clear_failed_loot(me);
	}
	target_snapshot = AUTOFIGHTD->query_target_snapshot(me);
	target = target_snapshot["target"];
	visible_monsters = (int)target_snapshot["visible"];
	if(target){
		count = AUTOFIGHTD->query_object_count(target,env);
		me->command("kill "+target->query_name()+" "+count);
		// 候选对象仍可能在命令执行前失效、被其他玩家击杀，或被
		// NPC 自身规则拒绝攻击。只有真实进入战斗后才清空防抖计数；
		// 否则继续走换图逻辑，避免对同一个无效候选无限重试。
		if(me->in_combat){
			AUTOFIGHTD->clear_no_target(me);
			return 1;
		}
	}
	if(!(int)target_snapshot["cycle_complete"]){
		write("当前房间对象较多，挂机助手已分批扫描"+
			(int)target_snapshot["scanned"]+"个，剩余"+
			(int)target_snapshot["deferred"]+
			"个将在下一轮继续检查。\n");
		return 1;
	}
	AUTOFIGHTD->record_no_target(me);
	if(AUTOFIGHTD->should_route_to_training_area(me,target_snapshot)){
		route = AUTOFIGHTD->query_training_route(me);
		route_path = (string)route["path"];
		AUTOFIGHTD->record_route(me,route_path);
		write("挂机助手正在寻找"+(string)route["name"]+
			"（约"+(int)route["level"]+"级怪）。\n");
		me->command("qge74hye "+route_path);
		AUTOFIGHTD->start_autofight(me);
		return 1;
	}
	direction = AUTOFIGHTD->query_safe_exit(me);
	if(direction != ""){
		AUTOFIGHTD->record_roam(me);
		write("当前地图连续没有可攻击目标，挂机助手正前往相邻地图继续寻找。\n");
		me->command("leave "+direction);
		return 1;
	}
	write("[关闭自动挂机:autofightclose] 今日剩余"+
		format_time(left)+"\n");
	if(visible_monsters>0){
		level_window = AUTOFIGHTD->query_target_level_window(me);
		write("当前地图可见"+visible_monsters+
			"只怪物，但没有符合安全攻击条件的目标。\n");
		write("当前允许等级："+(int)level_window["minimum"]+
			"-"+(int)level_window["maximum"]+
			"级；友方、BOSS、任务或召唤单位也会自动跳过。\n");
	}
	else
		write("当前地图暂无怪物，正在等待刷新。\n");
	write("[挂机设置:autofight open]\n");
	me->command("look");
	return 1;
}
