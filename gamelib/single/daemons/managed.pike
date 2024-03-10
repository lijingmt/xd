#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define SAVE_MANAGER 600 //10分钟回写存档一次
#define MAX_BANG 5000 //上限500000人 
#define LOGIN_PATH ROOT+"/gamelib/etc/unlogin_id"//封号名单
#define CHAT_PATH ROOT+"/gamelib/etc/unchat_id"//禁止发言名单
#define MANAGER_PATH ROOT+"/gamelib/etc/mananer_id"//管理员id名单

mapping(string:string) manager_mem = ([]);//管理员列表([id:权限]) 权限设定:admin,assist,
mapping(string:array) unlogin_mem = ([]);//封号列表([id:({中文名，封号起始时间，封号期限，})])
mapping(string:array) unchat_mem = ([]);//禁言列表([id:({中文名，禁言起始时间，禁言期限，})])


//获取时间描述
string get_log_name(int type){ 
	string s_mon,s_day;
	string s_hour,s_min,s_sec;
	int day,mon,year,hour,min,sec;
	mapping now_time = localtime(time());
	day = now_time["mday"];	
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	hour = now_time["hour"];
	min = now_time["min"];
	sec = now_time["sec"];
	if(mon<10) s_mon = "0"+mon;
	else s_mon = (string)mon;
	if(day<10) s_day = "0"+day;
	else s_day = (string)day;
	if(hour<10) s_hour = "0"+hour;
	else s_hour = (string)hour;
	if(min<10) s_min = "0"+min;
	else s_min = (string)min;
	if(sec<10) s_sec = "0"+sec;
	else s_sec = (string)sec;
	string log_file = ""+year+"-"+s_mon+"-"+s_day;
	string log_time = ""+year+"-"+s_mon+"-"+s_day+" "+s_hour+":"+s_min+":"+s_sec;
	if(type ==1)
		return log_file;//[2010-09-19]
	else
		return log_time;//[2010-09-19 19:29:12]
}

//内存文件回写物理文件
void rewritefile()
{
	string tmp = "";
	//回写内存中封号玩家的id到文件中
	if(unlogin_mem&&sizeof(unlogin_mem))
	{
		foreach(sort(indices(unlogin_mem)),string id)
		{
			array arr1 = (array)unlogin_mem[id];	
			if(arr1&&sizeof(arr1))
			{
				string s1 = "";
				s1 += id + ",";//封号用户id
				s1 += arr1[0]+",";//封号用户id
				s1 += arr1[1]+",";//封号用户中文名
				s1 += arr1[2]+",";//封号起始时间
				s1 += arr1[3]+",";//封号期限
				s1 += arr1[4]+",";//封号起始时间描述
				tmp += s1 + "\n";
			}
		}
		if(tmp&&sizeof(tmp))
			Stdio.write_file(LOGIN_PATH,tmp);
	}
	//回写内存中禁言玩家的id到文件中
	string tmp2 = "";
	if(unchat_mem&&sizeof(unchat_mem))
	{
		foreach(sort(indices(unchat_mem)),string id)
		{
			array arr1 = (array)unchat_mem[id];	
			if(arr1&&sizeof(arr1))
			{
				string s1 = "";
				s1 += id + ",";//禁言用户id
				s1 += arr1[0]+",";//禁言用户id
				s1 += arr1[1]+",";//禁言用户中文名
				s1 += arr1[2]+",";//禁言起始时间
				s1 += arr1[3]+",";//禁言期限
				s1 += arr1[4]+",";//禁言起始时间描述
				tmp2 += s1 + "\n";
			}
		}
		if(tmp&&sizeof(tmp))
			Stdio.write_file(CHAT_PATH,tmp);
	}
	call_out(rewritefile,SAVE_MANAGER);
}
void create()
{
	//初始化将被封号玩家的信息装入内存文件
	string unlogin_str = Stdio.read_file(LOGIN_PATH);
	//初始化将被封号玩家的信息装入内存文件
	string unchat_str = Stdio.read_file(CHAT_PATH);
	//初始化将被封号玩家的信息装入内存文件
	string manager_str = Stdio.read_file(MANAGER_PATH);

	//读入封号名单
	if(unlogin_str&&sizeof(unlogin_str)){
		array arrtmp = unlogin_str/"\n";
		if(arrtmp&&sizeof(arrtmp)){
			arrtmp -= ({""});
			foreach(arrtmp,string eachline){
				array splist = eachline/",";//id,起始时间，期限限制
				splist -= ({""});
				array pt = ({});
				pt += ({splist[1]});//id
				pt += ({splist[2]});//中文名
				pt += ({splist[3]});//起始时间
				pt += ({splist[4]});//期限限制
				pt += ({splist[5]});//起始时间描述
				unlogin_mem[(string)splist[0]] = pt;		
			}
		}
	}
	//读入禁言名单
	if(unchat_str&&sizeof(unchat_str)){
		array arrtmp = unchat_str/"\n";
		if(arrtmp&&sizeof(arrtmp)){
			arrtmp -= ({""});
			foreach(arrtmp,string eachline){
				array splist = eachline/",";//id,起始时间，期限限制
				splist -= ({""});
				array pt = ({});
				pt += ({splist[1]});//id
				pt += ({splist[2]});//中文名
				pt += ({splist[3]});//起始时间
				pt += ({splist[4]});//期限限制
				pt += ({splist[5]});//起始时间描述
				unchat_mem[(string)splist[0]] = pt;		
			}
		}
	}
	//读入管理员名单
	if(manager_str&&sizeof(manager_str)){
		array arrtmp = manager_str/"\n";
		if(arrtmp&&sizeof(arrtmp)){
			arrtmp -= ({""});
			foreach(arrtmp,string eachline){
				array splist = eachline/",";//id,管理权限--admin,assist
				splist -= ({""});
				manager_mem[(string)splist[0]] = (string)splist[1];		
			}
		}
	}
	call_out(rewritefile,SAVE_MANAGER);
}
//将某个用户的账号状态解除禁言
string free_user_chat(string mid,string userid){
	string s = "";
	if(checkpower(mid)=="admin"){
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string id)
			{
				if(userid==id){
					array arr1 = (array)unchat_mem[id];	
					if(arr1&&sizeof(arr1))
					{
						string s1 = "";
						s1 += id + "|";//封号用户id
						s1 += arr1[1]+"|";//封号用户中文名
						s1 += "禁言时间："+arr1[4]+"|";//封号起始时间描述
						int unlogTime = (int)arr1[3];
						s1 += "禁言期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
						//封号剩余时间
						int now_diff = time()-(int)arr1[2];//时间差
						int last_time = unlogTime - now_diff; 
						s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
						s1 += "\n-----------------------\n";
						s += s1 + "现已成功解除禁言状态，请返回\n";
						m_delete(unchat_mem,id);
						break;
					}
				}
			}
		}
		else{
			s += "未找到该禁言玩家，请返回确认。\n";
		}
	}
	else
	//if(checkpower(userid)=="assist")
		s += "你没有相应权限进行解除禁言操作\n";
	return s; 
}
//将某个用户的账号状态解除封号
string free_user_login(string mid,string userid){
	string s = "";
	if(checkpower(mid)=="admin"){
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string id)
			{
				if(userid==id){
					array arr1 = (array)unlogin_mem[id];	
					if(arr1&&sizeof(arr1))
					{
						string s1 = "";
						s1 += id + "|";//封号用户id
						s1 += arr1[1]+"|";//封号用户中文名
						s1 += "封号时间："+arr1[4]+"|";//封号起始时间描述
						int unlogTime = (int)arr1[3];
						s1 += "封号期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
						//封号剩余时间
						int now_diff = time()-(int)arr1[2];//时间差
						int last_time = unlogTime - now_diff; 
						s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
						s1 += "\n-----------------------\n";
						s += s1 + "现已成功解除封号状态，请返回\n";
						m_delete(unlogin_mem,id);
						break;
					}
				}
			}
		}
		else{
			s += "未找到该封号玩家，请返回确认。\n";
		}
	}
	else
	//if(checkpower(userid)=="assist")
		s += "你没有相应权限进行解除封号操作\n";
	return s; 
}
//查询该用户id是否在禁言列表中，并返回禁言状态描述
string query_unchat_desc(string userid){
	string rtn = "";
	if(unchat_mem&&sizeof(unchat_mem)){
		foreach(sort(indices(unchat_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "你已经被管理员禁言\n";
					s1 += "禁言时间："+arr1[4]+"\n";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "禁言期限："+TIMESD->get_lasttime_desc(unlogTime)+"\n"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					rtn += s1 + "\n";
				}
			}
		}
	}
	return rtn;
}
//查询该用户id是否在封号列表中，并返回封号状态描述
string query_unlogin_desc(string userid){
	string rtn = "";
	if(unlogin_mem&&sizeof(unlogin_mem)){
		foreach(sort(indices(unlogin_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "你已经被管理员封号\n";
					s1 += "封号时间："+arr1[4]+"\n";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "封号期限："+TIMESD->get_lasttime_desc(unlogTime)+"\n"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					rtn += s1 + "\n";
				}
			}
		}
	}
	return rtn;
}
string query_user_deal_status(string mid,string userid){
	string s = "";
	if(unchat_mem&&sizeof(unchat_mem)){
		foreach(sort(indices(unchat_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//封号用户id
					s1 += arr1[1]+"|";//封号用户中文名
					s1 += "禁言时间："+arr1[4]+"|";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "禁言期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					if(checkpower(mid)=="admin")
						s1 += "|[解除禁言:game_deal free_chat "+id+" not not]";
					s += s1 + "\n";
				}
			}
		}
	}
	if(unlogin_mem&&sizeof(unlogin_mem)){
		foreach(sort(indices(unlogin_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//封号用户id
					s1 += arr1[1]+"|";//封号用户中文名
					s1 += "封号时间："+arr1[4]+"|";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "封号期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					if(checkpower(mid)=="admin")
						s1 += "|[解除封号:game_deal free_login "+id+" not not]";
					s += s1 + "\n";
				}
			}
		}
	}
	return s;
}
//检查管理员权限
//返回admin为权限最高管理员，assist为辅助管理员，只能增加操作，不能解封
string checkpower(string userid) 
{
	if(manager_mem&&sizeof(manager_mem))
	{
		foreach(sort(indices(manager_mem)),string id)
		{
			if(userid==id){
				string power = (string)manager_mem[id];	
				if(power&&sizeof(power))
					return power;
			}
		}
	}
	return "nopower";
}
//列出禁言名单列表，未做分页管理
string list_nochat_user(string userid){
	string s = "";
	if(checkpower(userid)=="admin"){
		//管理员权限，列出用户同时，列出解封链接
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string id)
			{
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//封号用户id
					s1 += arr1[1]+"|";//封号用户中文名
					s1 += "禁言时间："+arr1[4]+"|";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "禁言期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					s1 += "|[解除禁言:game_deal free_chat "+id+" not not]";
					s += s1 + "\n";
				}
			}
		}
		else{
			s += "暂无禁言人员\n";
		}
	}
	else if(checkpower(userid)=="assist"){
		//辅助管理员权限，只列出用户，不能解封	
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string id)
			{
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//封号用户id
					s1 += arr1[1]+"|";//封号用户中文名
					s1 += "禁言时间："+arr1[4]+"|";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "禁言期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					s += s1 + "\n";
				}
			}
		}
		else{
			s += "暂无禁言人员\n";
		}
	}
	else
		s += "你没有相应权限进行查看和管理操作\n";
	return s; 
}

//增加禁言人员,id,中文名，禁言期限
string add_unchat(string mid,string userid,string usernamecn,int limit_time){
	string rtn = "";
	if(checkpower(mid)=="admin"||checkpower(mid)=="assist"){
		string timedesc = get_log_name(2);//禁言起始时间描述
		//检查禁言内存，有则更新，无，则添加
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string index){
				if(index&&sizeof(index)){
					if(index==userid){
						rtn += "该禁言用户禁言时间已被成功重置\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unchat_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//封号用户id
						s1 += usernamecn+"|";//封号用户中文名
						s1 += "禁言时间："+timedesc+"|";//封号起始时间描述
						s1 += "禁言期限："+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
					else{
						rtn += "已成功将该用户加入禁言名单\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unchat_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//封号用户id
						s1 += usernamecn+"|";//封号用户中文名
						s1 += "禁言时间："+timedesc+"|";//封号起始时间描述
						s1 += "禁言期限："+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
				}
			}
		}
		else{
			rtn += "已成功将该用户加入首位禁言名单\n";
			array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
			unchat_mem[userid] = tmp;
			string s1 = "";
			s1 +=  userid + "|";//封号用户id
			s1 += usernamecn+"|";//封号用户中文名
			s1 += "禁言时间："+timedesc+"|";//封号起始时间描述
			s1 += "禁言期限："+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
			rtn += s1;
		}
	}
	else{
		rtn += "你没有操作权限，请返回确认。\n";	
	}
	return rtn;
}

//列出封号名单列表，未做分页管理
string list_nologin_user(string userid){
	string tmp = "";
	if(checkpower(userid)=="admin"){
		//管理员权限，列出用户同时，列出解封链接
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string id)
			{
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//封号用户id
					s1 += arr1[1]+"|";//封号用户中文名
					s1 += "封号时间："+arr1[4]+"|";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "封号期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					s1 += "|[解除封号:game_deal free_login "+id+" not not]";
					tmp += s1 + "\n";
				}
			}
		}
		else{
			tmp += "暂无封号人员\n";
		}
	}
	else if(checkpower(userid)=="assist"){
		//辅助管理员权限，只列出用户，不能解封	
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string id)
			{
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//封号用户id
					s1 += arr1[1]+"|";//封号用户中文名
					s1 += "封号时间："+arr1[4]+"|";//封号起始时间描述
					int unlogTime = (int)arr1[3];
					s1 += "封号期限："+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//封号剩余时间
					int now_diff = time()-(int)arr1[2];//时间差
					int last_time = unlogTime - now_diff; 
					s1 += "剩余时间："+TIMESD->get_lasttime_desc(last_time);//封号期限
					tmp += s1 + "\n";
				}
			}
		}
		else{
			tmp += "暂无封号人员\n";
		}
	}
	else
		tmp += "你没有相应权限进行查看和管理操作\n";
	return tmp;
}
//增加封号人员,id,中文名，禁言期限
string add_unlogin(string mid,string userid,string usernamecn,int limit_time){
	string rtn = "";
	if(checkpower(mid)=="admin"||checkpower(mid)=="assist"){
		string timedesc = get_log_name(2);//禁言起始时间描述
		//检查禁言内存，有则更新，无，则添加
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string index){
				if(index&&sizeof(index)){
					if(index==userid){
						rtn += "该封号用户封号时间已被成功重置\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unlogin_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//封号用户id
						s1 += usernamecn+"|";//封号用户中文名
						s1 += "封号时间："+timedesc+"|";//封号起始时间描述
						s1 += "封号期限："+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
					else{
						rtn += "已成功将该用户加入封号名单\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unlogin_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//封号用户id
						s1 += usernamecn+"|";//封号用户中文名
						s1 += "封号时间："+timedesc+"|";//封号起始时间描述
						s1 += "封号期限："+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
				}
			}
		}
		else{
			rtn += "已成功将该用户加入首位封号名单\n";
			array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
			unlogin_mem[userid] = tmp;
			string s1 = "";
			s1 +=  userid + "|";//封号用户id
			s1 += usernamecn+"|";//封号用户中文名
			s1 += "封号时间："+timedesc+"|";//封号起始时间描述
			s1 += "封号期限："+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
			rtn += s1;
		}
	}
	else{
		rtn += "你没有操作权限，请返回确认。\n";	
	}
	return rtn;
}



