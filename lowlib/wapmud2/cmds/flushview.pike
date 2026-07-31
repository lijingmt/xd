#include <command.h>
#include <wapmud2/include/wapmud2.h>

#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd"))

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
	mapping route;
	mapping sell_result;
	string reason;
	string direction;
	string route_path;
	int count;
	int left;
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
	item = AUTOFIGHTD->query_loot_item(me);
	if(item){
		count = AUTOFIGHTD->query_object_count(item,env);
		me->command("get "+item->query_name()+" "+count);
		return 1;
	}
	target = AUTOFIGHTD->query_target(me);
	if(target){
		AUTOFIGHTD->clear_no_target(me);
		count = AUTOFIGHTD->query_object_count(target,env);
		me->command("kill "+target->query_name()+" "+count);
		return 1;
	}
	AUTOFIGHTD->record_no_target(me);
	if(AUTOFIGHTD->should_route_to_training_area(me)){
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
		me->command("leave "+direction);
		return 1;
	}
	write("[关闭自动挂机:autofightclose] 今日剩余"+
		format_time(left)+"\n");
	write("当前地图暂无可攻击目标，正在等待怪物刷新。\n");
	write("[挂机设置:autofight open]\n");
	me->command("look");
	return 1;
}
