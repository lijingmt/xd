/** 每日签到、真实行为目标与活跃度宝箱。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

#define DAILY_GOAL_ROOT "/plus/daily_goal"
#define DAILY_GOAL_VERSION 1
#define DAILY_ACTIVITY_MAX 100

private array(mapping(string:mixed)) daily_task_definitions = ({
	(["id":"signin","event":"signin","name":"每日签到",
		"target":1,"activity":10,"command":"daily sign"]),
	(["id":"kill","event":"kill","name":"同阶除魔",
		"target":5,"activity":25,"command":"map_display"]),
	(["id":"skill","event":"skill","name":"勤修术法",
		"target":5,"activity":20,"command":"myskills"]),
	(["id":"task","event":"task","name":"完成历练",
		"target":1,"activity":25,"command":"mytasks"]),
	(["id":"pet_assist","event":"pet_assist","name":"万灵同行",
		"target":3,"activity":20,"command":"pet"]),
	(["id":"gather","event":"gather","name":"采集天地",
		"target":3,"activity":20,"command":"autofight open"]),
});

private array(int) activity_thresholds = ({20,50,80,100});

int query_day_key()
{
	mapping(string:int) now_time = localtime(time());
	return ((int)now_time["year"])*1000+(int)now_time["yday"];
}

private mapping(string:mixed) build_fresh_state(
	mapping(string:mixed)|zero previous)
{
	int sign_total = 0;
	int last_sign_date = 0;
	if(mappingp(previous)){
		sign_total = (int)previous["sign_total"];
		last_sign_date = (int)previous["last_sign_date"];
	}
	if(sign_total<0)
		sign_total = 0;
	return ([
		"version":DAILY_GOAL_VERSION,
		"date":query_day_key(),
		"sign_total":sign_total,
		"last_sign_date":last_sign_date,
		"progress":([]),
		"activity_claimed":([]),
	]);
}

private mapping(string:mixed) normalize_state(object player)
{
	mapping state;
	if(!player)
		return ([]);
	state = player[DAILY_GOAL_ROOT];
	if(!mappingp(state) || (int)state["date"]!=query_day_key()){
		state = build_fresh_state(state);
		player[DAILY_GOAL_ROOT] = state;
	}
	state["version"] = DAILY_GOAL_VERSION;
	if(!mappingp(state["progress"]))
		state["progress"] = ([]);
	if(!mappingp(state["activity_claimed"]))
		state["activity_claimed"] = ([]);
	if((int)state["sign_total"]<0)
		state["sign_total"] = 0;
	return state;
}

private mapping(string:mixed) query_state_snapshot(object player)
{
	mapping state;
	if(!player)
		return ([]);
	state = player[DAILY_GOAL_ROOT];
	if(!mappingp(state) || (int)state["date"]!=query_day_key())
		return build_fresh_state(state);
	state = copy_value(state);
	if(!mappingp(state["progress"]))
		state["progress"] = ([]);
	if(!mappingp(state["activity_claimed"]))
		state["activity_claimed"] = ([]);
	return state;
}

array(mapping(string:mixed)) query_daily_tasks()
{
	return copy_value(daily_task_definitions);
}

array(int) query_activity_thresholds()
{
	return copy_value(activity_thresholds);
}

private mapping(string:mixed)|zero query_task_definition(string event)
{
	for(int i=0;i<sizeof(daily_task_definitions);i++){
		if((string)daily_task_definitions[i]["event"]==event)
			return daily_task_definitions[i];
	}
	return 0;
}

private int query_activity(mapping state)
{
	mapping progress = state["progress"];
	int activity = 0;
	if(!mappingp(progress))
		return 0;
	for(int i=0;i<sizeof(daily_task_definitions);i++){
		mapping task = daily_task_definitions[i];
		if((int)progress[(string)task["id"]]>=(int)task["target"])
			activity += (int)task["activity"];
	}
	if(activity>DAILY_ACTIVITY_MAX)
		activity = DAILY_ACTIVITY_MAX;
	return activity;
}

int record_event(object player,string event,void|int amount)
{
	mapping(string:mixed)|zero task;
	mapping state;
	mapping progress;
	string task_id;
	int before;
	int after;
	int target;
	if(!player || !event || event=="")
		return 0;
	if(!amount)
		amount = 1;
	if(amount<1)
		return 0;
	task = query_task_definition(event);
	if(!task)
		return 0;
	state = normalize_state(player);
	progress = state["progress"];
	task_id = (string)task["id"];
	target = (int)task["target"];
	before = (int)progress[task_id];
	if(before>=target)
		return 0;
	after = before+amount;
	if(after>target)
		after = target;
	progress[task_id] = after;
	if(after>=target){
		tell_object(player,"【每日目标】"+(string)task["name"]+
			"已完成，活跃度达到"+query_activity(state)+"。\n");
		return 2;
	}
	return 1;
}

int record_kill(object player,int killed_level)
{
	int player_level;
	int min_level;
	int max_level;
	if(!player || killed_level<1)
		return 0;
	player_level = player->query_level();
	min_level = player_level-10;
	if(min_level<1)
		min_level = 1;
	max_level = player_level+10;
	if(max_level>MAX_LEVEL)
		max_level = MAX_LEVEL;
	if(killed_level<min_level || killed_level>max_level)
		return 0;
	return record_event(player,"kill",1);
}

int record_skill(object player)
{
	return record_event(player,"skill",1);
}

int record_task_completion(object player)
{
	return record_event(player,"task",1);
}

int record_pet_assist(object player)
{
	return record_event(player,"pet_assist",1);
}

int record_gather(object player)
{
	return record_event(player,"gather",1);
}

private int query_reward_level(object player)
{
	int level = player ? player->query_level() : 1;
	if(level<1)
		level = 1;
	if(level>MAX_LEVEL)
		level = MAX_LEVEL;
	return level;
}

private mapping(string:int) grant_reward(object player,int exp,int money)
{
	int actual_exp = 0;
	if(exp<0)
		exp = 0;
	if(money<0)
		money = 0;
	if(player->query_level()<MAX_LEVEL && exp>0)
		actual_exp = player->add_exp_with_bonus(exp);
	if(money>0)
		player->add_account(money);
	player->query_if_levelup();
	return (["exp":actual_exp,"money":money,
		"level_up":player->query_levelFlag() ? 1 : 0]);
}

mapping(string:mixed) claim_signin(object player)
{
	mapping result = (["ok":0,"message":"签到失败，请稍后再试。"]);
	mapping state;
	mapping reward;
	int level;
	int cycle_day;
	int multiplier = 1;
	int exp;
	int money;
	if(!player)
		return result;
	state = normalize_state(player);
	if((int)state["last_sign_date"]==query_day_key()){
		result["message"] = "今天已经签到过了。";
		return result;
	}
	state["last_sign_date"] = query_day_key();
	state["sign_total"] = (int)state["sign_total"]+1;
	state["progress"]["signin"] = 1;
	cycle_day = ((int)state["sign_total"]-1)%7+1;
	if(cycle_day==7)
		multiplier = 3;
	else if(cycle_day>=4)
		multiplier = 2;
	level = query_reward_level(player);
	exp = (level*level*3+50)*multiplier;
	money = (level*30+100)*multiplier;
	reward = grant_reward(player,exp,money);
	if(functionp(player->save))
		player->save();
	result = ([
		"ok":1,
		"message":"签到成功。",
		"cycle_day":cycle_day,
		"exp":reward["exp"],
		"money":reward["money"],
		"level_up":reward["level_up"],
	]);
	return result;
}

private int query_activity_exp(int level,int threshold)
{
	switch(threshold){
		case 20: return level*level*3+50;
		case 50: return level*level*5+100;
		case 80: return level*level*8+200;
		case 100: return level*level*12+300;
	}
	return 0;
}

private int query_activity_money(int level,int threshold)
{
	switch(threshold){
		case 20: return level*20+100;
		case 50: return level*40+200;
		case 80: return level*60+300;
		case 100: return level*100+500;
	}
	return 0;
}

mapping(string:mixed) claim_activity_reward(object player,int threshold)
{
	mapping result = (["ok":0,"message":"活跃奖励领取失败。"]);
	mapping state;
	mapping reward;
	int level;
	if(!player || !has_value(activity_thresholds,threshold)){
		result["message"] = "没有这一档活跃奖励。";
		return result;
	}
	state = normalize_state(player);
	if((int)state["activity_claimed"][(string)threshold]){
		result["message"] = "这一档活跃奖励今天已经领取。";
		return result;
	}
	if(query_activity(state)<threshold){
		result["message"] = "活跃度还没有达到"+threshold+"。";
		return result;
	}
	// 先记领取凭据再发经验金币，HTTP核心锁下重复请求不会重复获利。
	state["activity_claimed"][(string)threshold] = 1;
	level = query_reward_level(player);
	reward = grant_reward(player,query_activity_exp(level,threshold),
		query_activity_money(level,threshold));
	if(functionp(player->save))
		player->save();
	result = ([
		"ok":1,
		"message":"领取了"+threshold+"点活跃奖励。",
		"threshold":threshold,
		"exp":reward["exp"],
		"money":reward["money"],
		"level_up":reward["level_up"],
	]);
	return result;
}

mapping(string:mixed) query_summary(object player)
{
	if(!player)
		return (["date":query_day_key(),"signed":0,"activity":0,
			"activity_max":DAILY_ACTIVITY_MAX,
			"claimable_rewards":0,"claimable":0]);
	mapping state = query_state_snapshot(player);
	mapping claimed = state["activity_claimed"];
	int activity = query_activity(state);
	int claimable_rewards = 0;
	for(int i=0;i<sizeof(activity_thresholds);i++){
		int threshold = activity_thresholds[i];
		if(activity>=threshold && !(int)claimed[(string)threshold])
			claimable_rewards++;
	}
	return ([
		"date":query_day_key(),
		"signed":(int)state["last_sign_date"]==query_day_key() ? 1 : 0,
		"activity":activity,
		"activity_max":DAILY_ACTIVITY_MAX,
		"claimable_rewards":claimable_rewards,
		"claimable":((int)state["last_sign_date"]!=query_day_key() ||
			claimable_rewards>0) ? 1 : 0,
	]);
}

mapping(string:mixed) query_daily_state(object player)
{
	if(!player)
		return ([]);
	mapping state = query_state_snapshot(player);
	array(mapping(string:mixed)) tasks = ({});
	mapping progress = state["progress"];
	for(int i=0;i<sizeof(daily_task_definitions);i++){
		mapping task = copy_value(daily_task_definitions[i]);
		task["progress"] = (int)progress[(string)task["id"]];
		task["complete"] = (int)task["progress"]>=(int)task["target"] ? 1 : 0;
		tasks += ({task});
	}
	return ([
		"date":state["date"],
		"sign_total":state["sign_total"],
		"last_sign_date":state["last_sign_date"],
		"activity":query_activity(state),
		"progress":copy_value(progress),
		"activity_claimed":copy_value(state["activity_claimed"]),
		"tasks":tasks,
	]);
}

private string query_progress_bar(int activity)
{
	int filled = activity/10;
	string result = "";
	if(filled>10)
		filled = 10;
	for(int i=0;i<10;i++)
		result += (i<filled ? "■" : "□");
	return result;
}

string query_daily_page(object player)
{
	if(!player)
		return "每日修行暂不可用。\n";
	mapping state = normalize_state(player);
	mapping progress = state["progress"];
	mapping claimed = state["activity_claimed"];
	int activity = query_activity(state);
	int signed = (int)state["last_sign_date"]==query_day_key();
	int display_cycle = signed ? ((int)state["sign_total"]-1)%7+1 :
		(int)state["sign_total"]%7+1;
	string result = "§g【每日修行】§r\n\n";
	result += "七日签到：本轮第"+display_cycle+"天 ";
	if(signed)
		result += "✓ 今日已签到\n";
	else
		result += "[领取今日签到:daily sign]\n";
	result += "第4至6天奖励翻倍，第7天三倍；漏签不会清空累计轮次。\n\n";
	result += "活跃度："+activity+"/100 "+query_progress_bar(activity)+"\n";
	for(int i=0;i<sizeof(daily_task_definitions);i++){
		mapping task = daily_task_definitions[i];
		int current = (int)progress[(string)task["id"]];
		int target = (int)task["target"];
		if(current>target)
			current = target;
		result += (current>=target ? "✓ " : "○ ");
		result += (string)task["name"]+" "+current+"/"+target+
			"（活跃度+"+(int)task["activity"]+"）";
		if(current<target)
			result += " [前往:"+(string)task["command"]+"]";
		result += "\n";
	}
	result += "\n【活跃宝箱】\n";
	for(int i=0;i<sizeof(activity_thresholds);i++){
		int threshold = activity_thresholds[i];
		int level = query_reward_level(player);
		result += threshold+"点："+query_activity_exp(level,threshold)+
			"基础经验、"+MUD_MONEYD->query_other_money_cn(
			query_activity_money(level,threshold))+" ";
		if((int)claimed[(string)threshold])
			result += "✓ 已领取";
		else if(activity>=threshold)
			result += "[领取:daily claim "+threshold+"]";
		else
			result += "尚未解锁";
		result += "\n";
	}
	result += "\n经验会继续使用当前界面经验规则与等级上限；VIP不增加签到、活跃度或宝箱次数。\n";
	result += "[万灵今日修行:daily_cultivation]|[每级职业历练:growth_task]\n";
	result += "[任务列表:mytasks]|[返回游戏:look]\n";
	return result;
}
