//自动练级功能模块
//说明：花费一定玉石，挂机获取经验
//
/*
【数据结构】
 1.玩家信息  记录了所有当前正在挂机的玩家
       mapping(string:mapping(string:mixed)) autoLearnPlayer = ([
	     player1:([type:1,time:5,time_max:20,state:1,exp:23432,state_desc:正在修炼中，已经获得XXX点经验，你已经升到了8级])，
		 .
		 .
		 ])

【实现逻辑】   
	    本deamon中，每隔1分钟执行一次 refresh() 方法，完成以下几件任务：
		  1、对于state = 1的用户，执行一次获得经验的操作(耗费 speed 潜能)；
		  2、该用户的time 减少 60 点;
		  3、修改该用对应的state_cn;
		  4、如果该用户的 time=0, 那么将该用户的state设置为 0；
		本deamon中，每隔1小时执行一次 clear() 方法，完成任务：
		  1、保存 state为0 的玩家数据，然后将玩家踢下线；
		  2、清除autoLearnPlayer 中，state为0的玩家信息；
【其他说明】
		1.用户选择挂机后，会将相关信息写入数据结构autoLearnPlayer中；
		2.用户中途中断挂机，则从autoLearnPlayer中清除相关信息；
		3.如果服务器将要关闭，将执行store_all_info()方法，保存当前的挂机信息(将剩余的挂机时间，写到玩家身上)。
*/
#include <globals.h>
#include <gamelib/include/gamelib.h>
#include <wapmud2/include/wapmud2.h>
#define AUTO_LEARN_TIME 60                                             //1分钟调用一次消潜操作
#define CLEAR_TIME 60*60                                               //1小时调用一次清理算法

object LOG;

private protected mapping (string:mapping(string:mixed)) autoLearnPlayer =([]);         //所有消潜玩家的信息列表
private protected mapping (string:int) autoLearnInfo =(["dazuo":12,"xiuchan":72]);      //不同挂机方式价格等级列表（小时/碎玉）

private int valid_runtime(mapping runtime)
{
	return mappingp(runtime) &&
		((string)runtime["type"]=="dazuo" ||
		 (string)runtime["type"]=="xiuchan") &&
		intp(runtime["time_max"]) && (int)runtime["time_max"]>=5 &&
		(int)runtime["time_max"]<=10000000 && intp(runtime["time"]) &&
		(int)runtime["time"]>=0 &&
		(int)runtime["time"]<=(int)runtime["time_max"] &&
		intp(runtime["speed"]) && (int)runtime["speed"]>=0 &&
		(int)runtime["speed"]<=1000000000 && intp(runtime["exp"]) &&
		(int)runtime["exp"]>=0 &&
		intp(runtime["state"]) &&
		((int)runtime["state"]==0 || (int)runtime["state"]==1) &&
		stringp(runtime["state_desc"]) &&
		sizeof((string)runtime["state_desc"])<=2048 &&
		(!runtime["remaining_seconds"] ||
		 (intp(runtime["remaining_seconds"]) &&
		  (int)runtime["remaining_seconds"]>=0 &&
		  (int)runtime["remaining_seconds"]<=20*366*24*60*60));
}

private void persist_runtime(object user,mapping runtime)
{
	if(user && valid_runtime(runtime) &&
	   functionp(user->set_auto_learn_runtime)){
		if((int)runtime["state"]==1 &&
		   functionp(user->query_doing_status_remaining))
			runtime["remaining_seconds"] =
				user->query_doing_status_remaining();
		else
			runtime["remaining_seconds"] = 0;
		user->set_auto_learn_runtime(runtime);
	}
}

/** Reattach one paid-training session to the daemon local to this player. */
int resume_player(object user)
{
	string uid;
	mapping runtime;
	int remaining;
	int had_local;
	if(!user || !functionp(user->query_name))
		return 0;
	uid=(string)user->query_name();
	if(uid=="")
		return 0;
	runtime=autoLearnPlayer[uid];
	had_local=valid_runtime(runtime);
	if(!valid_runtime(runtime) && functionp(user->query_auto_learn_runtime))
		runtime=user->query_auto_learn_runtime();
	if(!valid_runtime(runtime)){
		m_delete(autoLearnPlayer,uid);
		if(functionp(user->clear_auto_learn_runtime))
			user->clear_auto_learn_runtime();
		return 0;
	}
	autoLearnPlayer[uid]=copy_value(runtime);
	runtime=autoLearnPlayer[uid];
	// Runtime archives are trusted only for progress, never for the experience
	// rate. Recompute from the existing historical formula and current level.
	runtime["speed"]=work_out_speed((int)user->query_level(),
		(string)runtime["type"]);
	if((int)runtime["state"]==1){
		remaining=(int)runtime["time_max"]-(int)runtime["time"];
		if(remaining<1){
			runtime["state"]=0;
			persist_runtime(user,runtime);
			return 0;
		}
		// A new process/worker resumes the exact saved seconds, so neither restart
		// downtime nor transport latency consumes paid time. An already-registered
		// local session keeps its live callout and cannot be extended by refreshes.
		if(!had_local){
			int remaining_seconds = intp(runtime["remaining_seconds"]) ?
				(int)runtime["remaining_seconds"] : remaining*60;
			if(remaining_seconds<1 || remaining_seconds>remaining*60)
				remaining_seconds=remaining*60;
			if(functionp(user->resume_paid_training_activity))
				user->resume_paid_training_activity(remaining_seconds);
			else
				user->sleep_for_learn(remaining);
		}
	}
	else if(functionp(user->query_doing_status) &&
	   user->query_doing_status()=="修炼中" &&
	   functionp(user->wakeup_from_auto_learn))
		user->wakeup_from_auto_learn();
	persist_runtime(user,runtime);
	return 1;
}

/** Synchronize daemon progress into the archive before the source atomic save. */
int prepare_worker_handoff(object user)
{
	string uid;
	mapping durable;
	if(!user || !functionp(user->query_name))
		return 0;
	uid=(string)user->query_name();
	if(uid=="")
		return 0;
	if(!valid_runtime(autoLearnPlayer[uid])){
		durable=functionp(user->query_auto_learn_runtime) ?
			user->query_auto_learn_runtime() : ([]);
		if(!sizeof(durable))
			return 1;
		if(!valid_runtime(durable) || !resume_player(user))
			return 0;
	}
	if(!valid_runtime(autoLearnPlayer[uid]))
		return 0;
	persist_runtime(user,autoLearnPlayer[uid]);
	return 1;
}

/** Source worker forgets only its process-local copy after the atomic save. */
void detach_worker_handoff(object user)
{
	string uid;
	if(!user || !functionp(user->query_name))
		return;
	uid=(string)user->query_name();
	if(uid=="")
		return;
	m_delete(autoLearnPlayer,uid);
}


protected void create()
{
	werror("===== [Auto_learn start!!]======\n");
	call_out(refresh,AUTO_LEARN_TIME);//自动消潜
	call_out(clear,CLEAR_TIME);       //清除已经完成的记录
	werror("===== [Auto_learn end!!]======\n");
}

int is_now_auto_learn(string uid)
{
	object user;
	mapping tmp = autoLearnPlayer[uid];
	if(!valid_runtime(tmp)){
		user=find_player(uid);
		if(user)
			resume_player(user);
		tmp=autoLearnPlayer[uid];
	}
	if(tmp&&tmp["state"]==1)
		return 1;
	else
		return 0;
}

void add_new_player(string type,object user,int time)
{
	int re =0;
	string uid = user->name;
	int speed = work_out_speed(user->level,type); 
	mapping tmp = ([]);
	tmp["type"] = type;               //消潜类型
	tmp["time_max"] = time;           //总时间
	tmp["time"] = 0;                  //已消耗的时间
	tmp["speed"] = speed;             //消潜速度
	tmp["exp"] = 0;                   //已获得的经验
	tmp["state"] = 1;                 //当前状态
	tmp["state_desc"] = "你刚刚开始修炼，没有获得经验\n";           //当前状态描述
	autoLearnPlayer[uid] = tmp;	
	persist_runtime(user,tmp);
}
string clear_user(object user)
{
	string re = "";
	string uid;
	string typeDesc = "打坐";
	string type;
	mapping tmp;
	int timeTotal = 0;
	int timeRemind = 0;
	int oldSavedTime = 0;
	int saved = 0;
	if(!user || !functionp(user->query_name))
		return "修炼状态无效，请稍后重试。\n";
	uid = user->query_name();
	resume_player(user);
	tmp = autoLearnPlayer[uid];
	if(!valid_runtime(tmp))
		return "你的修炼很久之前就已经完成，或者你不在正确的位置\n";
	tmp = copy_value(tmp);
	type = (string)tmp["type"];
	if(type=="xiuchan")
		typeDesc = "修禅";
	if((int)tmp["state"]==1){
		timeRemind = (int)tmp["time_max"]-(int)tmp["time"];
		if(type=="dazuo"){
			oldSavedTime = user->query_auto_learn_dazuo();
			timeTotal = oldSavedTime+timeRemind;
			user->set_auto_learn_dazuo(timeTotal);
		}
		else{
			oldSavedTime = user->query_auto_learn_xiuchan();
			timeTotal = oldSavedTime+timeRemind;
			user->set_auto_learn_xiuchan(timeTotal);
		}
	}
	m_delete(autoLearnPlayer,uid);
	if(functionp(user->clear_auto_learn_runtime))
		user->clear_auto_learn_runtime();
	if(functionp(user->save_with_result))
		saved = user->save_with_result();
	if(!saved){
		// Refund and session removal are one archive transaction. If the save is
		// fenced or fails, restore both sides and re-enable the exact timer.
		if((int)tmp["state"]==1){
			if(type=="dazuo")
				user->set_auto_learn_dazuo(oldSavedTime);
			else
				user->set_auto_learn_xiuchan(oldSavedTime);
		}
		if(functionp(user->set_auto_learn_runtime))
			user->set_auto_learn_runtime(tmp);
		m_delete(autoLearnPlayer,uid);
		resume_player(user);
		werror("[AUTO_LEARND] interrupt save failed uid=%s\n",uid);
		return "修炼中断存档失败，原修炼已恢复，请稍后重试。\n";
	}
	re = (int)tmp["state"]==1 ? "修炼已中断!\n" : "修炼已完成!\n";
	re += "你一共修炼了"+(int)tmp["time"]+"分钟，获得"+
		(int)tmp["exp"]+"点经验。你的"+typeDesc+"时间还剩余"+
		timeTotal+"分钟";
	return re;
}
int work_out_speed(int level,string type)
{
	int npclevel = level + 3;//玩家的经验基础值 base_exp 为玩家杀戮比自己等级高3级的NPC所得经验
	int base_exp= 0;
	if(npclevel<10)
		base_exp = 20+(npclevel-1)*15;
	else
		base_exp = 100+(npclevel-9)*5;

	int re = 0;
	if(type =="dazuo")
	{
		switch(level){
			case 1..15: 
				re = base_exp*80/100;
				break;
			case 16..25: 
				re = base_exp*70/100;
				break;
			case 26..35: 
				re = base_exp*60/100;
				break;
			case 36..45: 
				re = base_exp*50/100;
				break;
			case 46..55: 
				re = base_exp*40/100;
				break;
			case 56..70: 
				re = base_exp*30/100;
				break;
			default : 
				break;
		}
	}
	if(type =="xiuchan")
	{
		switch(level){
			case 1..15: 
				re = base_exp*98/100;
				break;
			case 16..25: 
				re = base_exp*90/100;
				break;
			case 26..35: 
				re = base_exp*85/100;
				break;
			case 36..45: 
				re = base_exp*75/100;
				break;
			case 46..55: 
				re = base_exp*65/100;
				break;
			case 56..70: 
				re = base_exp*55/100;
				break;
			default : 
				break;
		}
	}
	return re;
}
mapping query_level_info()
{
	return autoLearnInfo;
}
mapping query_player_info(string uid)
{
	object user;
	if(!valid_runtime(autoLearnPlayer[uid])){
		user=find_player(uid);
		if(user)
			resume_player(user);
	}
	return autoLearnPlayer[uid];
}
string query_state_desc(string uid)
{
	object user;
	mapping tmp = autoLearnPlayer[uid];
	if(!valid_runtime(tmp)){
		user=find_player(uid);
		if(user)
			resume_player(user);
		tmp=autoLearnPlayer[uid];
	}
	if(tmp)
	{
		return tmp["state_desc"];
	}
	else
		return "你的修行已经结束了。";
}
//清除内存中所有已经完成修炼的玩家信息
void clear()
{
	string s = "";//保存日志
	foreach(sort(indices(autoLearnPlayer)),string uid)                         
	{
		mapping tmp = autoLearnPlayer[uid];
		if(tmp&&tmp["state"]==0)
		{
			string type = (string)tmp["type"];
			int used_time = (int)tmp["time"];
			object user=find_player(uid);
			if(user && functionp(user->clear_auto_learn_runtime)){
				mapping finished_runtime=copy_value(tmp);
				m_delete(autoLearnPlayer,uid);
				user->clear_auto_learn_runtime();
				if(!functionp(user->save_with_result) ||
				   user->save_with_result())
					s += "["+MUD_TIMESD->get_mysql_timedesc()+"]-[uid:"+
						uid+"][type:"+type+"][time:"+used_time+"]\n";
				else{
					autoLearnPlayer[uid]=finished_runtime;
					user->set_auto_learn_runtime(finished_runtime);
				}
			}
			else{
				m_delete(autoLearnPlayer,uid);
				s += "["+MUD_TIMESD->get_mysql_timedesc()+"]-[uid:"+uid+
					"][type:"+type+"][time:"+used_time+"]\n";
			}
		}
	}
	if(s!="")
		Stdio.append_file(ROOT+"/log/auto_learn/auto_learn_del_"+MUD_TIMESD->get_year_month_day()+".log",s);
}
//对每个符合条件的玩家，模拟进行一次获得经验的操作
void refresh()
{
	foreach(sort(indices(autoLearnPlayer)),string uid)                         
	{
		mapping singleInfo = autoLearnPlayer[uid];
		if(singleInfo&&singleInfo["state"]== 1)//"state"为1，表示修炼尚未完成
		{
			int load_flag = 0;//是否手动加载某玩家的标志位
			object|zero user = find_player(uid);
			if(!user){ //如果当前要操作的玩家不在线，则加载
				// A worker without the live leased player is not authoritative for
				// this archive. Pause locally; setup() will resume from the durable
				// runtime when the player next arrives on the owning worker.
				if(MAP_WORKERD->query_node_role()=="worker"){
					m_delete(autoLearnPlayer,uid);
					continue;
				}
				mixed load_err=catch {
					user=clone(GAMELIB_USER);
					user->set_name(uid);
					user->set_project("gamelib");
					if(!user->restore()){
						destruct(user);
						user=0;
					}
				};
				if(load_err || !user){
					werror("[AUTO_LEARND] restore failed uid=%s\n",uid);
					continue;
				}
				load_flag =1;
			}
			user->mark_user_activity();
			if(!load_flag && HTTP_APID->has_virtual_connection(uid))
				HTTP_APID->update_connection_time(uid);

			do_learn(user);//开始获得经验

			if(!user)
				continue;
			if(load_flag){
				if(functionp(user->save_with_result))
					user->save_with_result();
				destruct(user);
			}
		}
	}
	call_out(refresh,AUTO_LEARN_TIME);//每分钟执行一次模拟获得经验的操作
}

void do_learn(object user)
{
	mapping learnInfo = autoLearnPlayer[user->query_name()];
	int speed = learnInfo["speed"];         //每分钟获得的经验
	int level_limit = VIPD->query_player_level_limit(user);
	learnInfo["time"] = (int)(learnInfo["time"]+1);

	// 使用带加成的经验函数（HTTP API 用户自动获得 50% 加成）
	int actual_exp = user->add_exp_with_bonus(speed);
	learnInfo["exp"] = (int)(learnInfo["exp"]+actual_exp);
	// 构建 HTTP API 加成提示
	string api_bonus_tip = "";
	if(user->is_http_api_user && actual_exp > speed) {
		api_bonus_tip = "（含新界面加成）";
	}
	string resultDesc = "你已经修炼了"+ learnInfo["time"] +"分钟，获得"+learnInfo["exp"] +"点经验"+api_bonus_tip+"。还剩"+ (learnInfo["time_max"]-learnInfo["time"])+"分钟可以完成修炼。";
	learnInfo["state_desc"] = resultDesc;
	user->query_if_levelup();//检查是否升级，并做相关的处理
	if(user->query_levelFlag())//升级之后，玩家对应的speed将发生变化
	{
		learnInfo["speed"] = work_out_speed(user->level,learnInfo["type"]);
		resultDesc += "你的等级提升到了 "+user->query_level()+" 级！\n";
	}
	if(learnInfo["time"] >= learnInfo["time_max"] || user->query_level()>=level_limit){  //已经完成修炼或者达到当前上限
		learnInfo["state"] = 0;
		user->wakeup_from_auto_learn();
		resultDesc = "你已经完成"+ learnInfo["time"] +"分钟修炼过程，获得"+learnInfo["exp"] +"点经验"+api_bonus_tip+"。";
		if(user->query_level()>=level_limit)  //达到当前普通/VIP等级上限
			resultDesc = "你已经在"+ learnInfo["time"] +
				"分钟修炼过程中达到当前等级上限"+level_limit+
				"级(获得"+learnInfo["exp"] +"点经验)。\n"+
				VIPD->get_level_limit_action_links(user);
		learnInfo["state_desc"] = resultDesc;           //修改当前状态描述
		persist_runtime(user,learnInfo);
		user->command("quit"); //将玩家踢下线
		return;
	}
	persist_runtime(user,learnInfo);
}

void clear_all()
{
	string s = "";
	foreach(sort(indices(autoLearnPlayer)),string uid)
	{
		int loaded = 0;
		int saved = 0;
		object|zero user = find_player(uid);
		if(!user){
			// Never manufacture an unleased offline player inside a map worker.
			// Its durable runtime remains available for the next authoritative
			// setup() and is therefore safer than an unfenced refund save.
			if(MAP_WORKERD->query_node_role()=="worker")
				continue;
			mixed load_err=catch {
				user=clone(GAMELIB_USER);
				user->set_name(uid);
				user->set_project("gamelib");
				if(!user->restore()){
					destruct(user);
					user=0;
				}
			};
			if(load_err || !user){
				werror("[AUTO_LEARND] shutdown restore failed uid=%s\n",uid);
				continue;
			}
			loaded=1;
		}
		mapping singleInfo = autoLearnPlayer[uid];
		mapping retry_runtime = ([]);
		if(valid_runtime(singleInfo) && (int)singleInfo["state"]==1)
		{
			string type = (string)singleInfo["type"];
			int used_time = (int)singleInfo["time"];
			int remaining = (int)singleInfo["time_max"]-used_time;
			int old_saved_time = 0;
			persist_runtime(user,singleInfo);
			retry_runtime=copy_value(singleInfo);
			switch(type){
				case "dazuo":
					old_saved_time=user->query_auto_learn_dazuo();
					user->set_auto_learn_dazuo(
						old_saved_time+remaining);
				break;
				case "xiuchan":
					old_saved_time=user->query_auto_learn_xiuchan();
					user->set_auto_learn_xiuchan(
						old_saved_time+remaining);
				break;
				default:
				break;
			}
		}
		m_delete(autoLearnPlayer,uid);
		if(functionp(user->clear_auto_learn_runtime))
			user->clear_auto_learn_runtime();
		if(functionp(user->wakeup_from_auto_learn))
			user->wakeup_from_auto_learn();
		if(functionp(user->save_with_result))
			saved=user->save_with_result();
		if(saved && sizeof(retry_runtime))
			s += "["+MUD_TIMESD->get_mysql_timedesc()+"]-[uid:"+
				user->query_name()+"][type:"+(string)retry_runtime["type"]+
				"][used:"+(int)retry_runtime["time"]+"][returned:"+
				((int)retry_runtime["time_max"]-(int)retry_runtime["time"])+"]\n";
		else if(valid_runtime(singleInfo) && (int)singleInfo["state"]==1){
			// A failed save must not turn a retry into a duplicate refund. Roll
			// back the in-memory balance and restore the session exactly.
			if((string)singleInfo["type"]=="dazuo")
				user->set_auto_learn_dazuo(
					user->query_auto_learn_dazuo()-
					((int)singleInfo["time_max"]-(int)singleInfo["time"]));
			else if((string)singleInfo["type"]=="xiuchan")
				user->set_auto_learn_xiuchan(
					user->query_auto_learn_xiuchan()-
					((int)singleInfo["time_max"]-(int)singleInfo["time"]));
			if(functionp(user->set_auto_learn_runtime))
				user->set_auto_learn_runtime(retry_runtime);
			m_delete(autoLearnPlayer,uid);
			resume_player(user);
		}
		if(loaded && user)
			destruct(user);
	}
	if(s!="")
		Stdio.append_file(ROOT+"/log/auto_learn/auto_learn_return_"+
			MUD_TIMESD->get_year_month_day()+".log",s);
}
