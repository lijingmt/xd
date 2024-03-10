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

private static mapping (string:mapping(string:mixed)) autoLearnPlayer =([]);         //所有消潜玩家的信息列表
private static mapping (string:int) autoLearnInfo =(["dazuo":12,"xiuchan":72]);      //不同挂机方式价格等级列表（小时/碎玉）


void create()
{
	werror("===== [Auto_learn start!!]======\n");
	call_out(refresh,AUTO_LEARN_TIME);//自动消潜
	call_out(clear,CLEAR_TIME);       //清除已经完成的记录
	werror("===== [Auto_learn end!!]======\n");
}

int is_now_auto_learn(string uid)
{
	mapping tmp = autoLearnPlayer[uid];
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
}
string clear_user(object user)
{
	string re = "";
	string uid = user->query_name();
	mapping tmp = autoLearnPlayer[uid];
	int timeTotal = 0;
	string typeDesc = "打坐";
	if(tmp["type"]=="xiuchan")typeDesc = "修禅";

	if(tmp&&tmp!=([]))
	{
		if(tmp["state"] ==1)                                              //玩家的修炼尚未结束，则要做相关处理
		{
			int timeRemind = tmp["time_max"] - tmp["time"];
			int myTime = 0;
			if(tmp["type"]=="dazuo"){                                 //将剩余的时间，保存在对应的字段中
				myTime = user->query_auto_learn_dazuo();
				timeTotal = myTime+timeRemind;
				user->set_auto_learn_dazuo(timeTotal); 
			}
			else if(tmp["type"]=="xiuchan")
			{
				myTime = user->query_auto_learn_xiuchan();
				timeTotal = myTime+timeRemind;
				user->set_auto_learn_xiuchan(timeTotal);
			}
			re += "修炼已中断!\n";
		}
		else
			re += "修炼已完成!\n";
		re += "你一共修炼了"+ tmp["time"] +"分钟，获得"+tmp["exp"]+"点经验。你的"+typeDesc+"时间还剩余"+timeTotal+"分钟";
		m_delete(autoLearnPlayer,uid);//删除该玩家的修炼信息
	}
	else
	{
		re += "你的修炼很久之前就已经完成，或者你不在正确的位置\n";
	}
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
	return autoLearnPlayer[uid];
}
string query_state_desc(string uid)
{
	mapping tmp = autoLearnPlayer[uid];
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
			string type = tmp["type"];
			string time = tmp["time"];
			string pot = tmp["total_pot"];
			string pot_r = tmp["remind_pot"];
			s += "["+MUD_TIMESD->get_mysql_timedesc()+"]-[uid:"+uid+"][type:"+type+"][time:"+time+"][pot:"+pot+"][pot_r:"+pot_r+"]\n";
			m_delete(autoLearnPlayer,uid);
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
			object user = find_player(uid);
			if(!user){ //如果当前要操作的玩家不在线，则加载
				array list=users(1);
				object helper; //随机找个在线的玩家，以调用load_player()来加载需要操作的玩家                                  
				for(int j=0;j<sizeof(list);j++){
					helper = list[j];
					if(helper)
						break;
				}
				user = helper->load_player(uid);
				load_flag =1;
			}
			string pswd = user->query_password();
			user->reconnect(pswd);//防止玩家掉线、发呆

			do_learn(user);//开始获得经验

			if(load_flag)
				user->remove();
		}
	}
	call_out(refresh,AUTO_LEARN_TIME);//每分钟执行一次模拟获得经验的操作
}

void do_learn(object user)
{
	mapping learnInfo = autoLearnPlayer[user->query_name()];
	int speed = learnInfo["speed"];         //每分钟获得的经验
	learnInfo["time"] = (int)(learnInfo["time"]+1);

	learnInfo["exp"] = (int)(learnInfo["exp"]+speed);
	user->exp += speed;                                                    
	user->current_exp += speed;
	string resultDesc = "你已经修炼了"+ learnInfo["time"] +"分钟，获得"+learnInfo["exp"] +"点经验。还剩"+ (learnInfo["time_max"]-learnInfo["time"])+"分钟可以完成修炼。";
	user->query_if_levelup();//检查是否升级，并做相关的处理
	if(user->query_levelFlag())//升级之后，玩家对应的speed将发生变化
	{
		learnInfo["speed"] = work_out_speed(user->level,learnInfo["type"]);
		resultDesc += "你的等级提升到了 "+user->query_level()+" 级！\n";    
	}
	if(learnInfo["time"] >= learnInfo["time_max"] || user->query_level()>=MAX_LEVEL){  //已经完成修炼或者达到满级
		learnInfo["state"] = 0;
		user->wakeup_from_auto_learn();
		resultDesc = "你已经完成"+ learnInfo["time"] +"分钟修炼过程，获得"+learnInfo["exp"] +"点经验。";
		if(user->query_level()>=MAX_LEVEL)  //达到满级
			resultDesc = "你已经在"+ learnInfo["time"] +"分钟修炼过程中达到满级(获得"+learnInfo["exp"] +"点经验)。";
		user->command("quit"); //将玩家踢下线 
		learnInfo["state_desc"] = resultDesc;           //修改当前状态描述
	}
}

void clear_all()
{
	string s = "";
	foreach(sort(indices(autoLearnPlayer)),string uid)                         
	{
		object user = find_player(uid);
		if(!user){ //如果当前要操作的玩家不在线，则加载
			array list=users(1);
			object helper; //随机找个在线的玩家，以调用load_player()来加载需要操作的玩家
			for(int j=0;j<sizeof(list);j++){
				helper = list[j];
				if(helper)
					break;
			}
			user = helper->load_player(uid);
		}
		mapping singleInfo = autoLearnPlayer[uid];
		if(singleInfo["state"]== 1)//未完成挂机的用户，要做相关处理
		{
			string type = singleInfo["type"];
			int time = singleInfo["time"];
			switch(type){ //将未完成的时间，保存在玩家身上。    
				case "dazuo":
					user->set_auto_learn_dazuo(time);
				break;
				case "xiuchan":
					user->set_auto_learn_xiuchan(time);
				break;
				default:
				break;
			}
			s += "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"[uid:"+ user->query_name()+"][type:"+type+"][time:"+time+"]\n";

		}
		singleInfo["state"] = "0";
		user->command("save");
		user->remove();//保存完玩家数据后，强制该玩家下线。
		if(s!="")
			Stdio.append_file(ROOT+"/log/auto_learn/auto_learn_return_"+MUD_TIMESD->get_year_month_day()+".log",s);
	}
}
