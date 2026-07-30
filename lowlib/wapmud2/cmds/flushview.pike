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

int main(string|zero arg)
{
	object me;
	object env;
	object|zero target;
	object|zero item;
	string reason;
	string direction;
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
	if(me->in_combat){
		write("[关闭自动挂机:autofightclose] 今日剩余"+
			format_time(left)+"\n");
		write(me->query_status()+"\n");
		write(me->query_fighting_msg()+"\n");
		return 1;
	}
	item = AUTOFIGHTD->query_loot_item(me);
	if(item){
		count = AUTOFIGHTD->query_object_count(item,env);
		me->command("get "+item->query_name()+" "+count);
		return 1;
	}
	if(AUTOFIGHTD->should_recover_life(me)){
		item = AUTOFIGHTD->query_recovery_item(me,"life");
		if(!item){
			stop_with_reason(me,"生命低于保护线，背包中没有可用的回血食物");
			return 1;
		}
		count = AUTOFIGHTD->query_object_count(item,me);
		me->command("eat "+item->query_name()+" "+count);
		return 1;
	}
	if(AUTOFIGHTD->should_recover_mana(me)){
		item = AUTOFIGHTD->query_recovery_item(me,"mana");
		if(item){
			count = AUTOFIGHTD->query_object_count(item,me);
			me->command("drink "+item->query_name()+" "+count);
			return 1;
		}
	}
	target = AUTOFIGHTD->query_target(me);
	if(target){
		count = AUTOFIGHTD->query_object_count(target,env);
		me->command("kill "+target->query_name()+" "+count);
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
