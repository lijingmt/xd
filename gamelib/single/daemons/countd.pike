#include <globals.h>
#include <gamelib/include/gamelib.h>
#define TIME_UNIT 900
inherit LOW_DAEMON;
int reg_num=0;
int reg_female_num=0;
int msg_num=0;
multiset day_login=(<>);
multiset day_msg=(<>);
mapping (string:int) mon_login=([]);
array online_user=allocate(24);

void create()
{
	read_tmp_log();
}

void count_register()
{
	reg_num++;
}
void count_reg_female()
{
	reg_female_num++;
}
void count_msg()
{
	msg_num++;
}
void count_day_msg(string arg)
{
	if(!day_msg[arg])
		day_msg+=(<arg>);
}
void count_login_time(string arg)
{
	if(!day_login[arg])
		day_login+=(<arg>);
}
void add_online_user()
{
	mapping now_time = localtime(time());
	int hour = now_time["hour"];
	online_user[hour] = sizeof(users());
	string c_log = "";//统计使用的日志 evan added 2008.07.10                                 
	c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ hour +"]["+sizeof(users())+"]\n";
	if(c_log != ""){                        
		Stdio.append_file(ROOT+"/log/stat/online/"+GAME_NAME_S+"_online_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
}
int write_tmp_log()
{
	int i,a_size;
	string s,log_file;
	array tmp;
	log_file = ROOT+"/log/daily/temp.log";
	s=reg_num+"\n"+reg_female_num+"\n"+sizeof(day_login)+"\n"+msg_num+"\n"+sizeof(day_msg)+"\n\n";
	for(i=0;i<23;i++)
		s+=online_user[i]+"\n";
	s+=online_user[i]+"\n\n";
	tmp = indices(day_login);
	a_size = sizeof(tmp);
	if(a_size){
		for(i=0;i<a_size-1;i++)
			s+=tmp[i]+"\n";
		s+=tmp[i]+"\n\n";
	}
	else
		s+="0\n\n";
	tmp = indices(day_msg);
	a_size = sizeof(tmp);
	if(a_size){
		for(i=0;i<a_size-1;i++)
			s+=tmp[i]+"\n";
		s+=tmp[i];
	}
	else
		s+="0\n\n";
	Stdio.write_file(log_file,s);
	return 1;
}
int read_tmp_log()
{
	int i,a_size;
	string str,log_file;
	array arr,tmp;
	log_file = ROOT+"/log/daily/temp.log";
	//werror("log file=%s\n",log_file);
	str = Stdio.read_file(log_file);
	if(str && sizeof(str)){
		arr = str/"\n\n";
		tmp = arr[0]/"\n";
		reg_num = (int)tmp[0];
		reg_female_num = (int)tmp[1];
		msg_num = (int)tmp[3];
		tmp = arr[1]/"\n";//get onlie_user
		for(i=0;i<24;i++)
			online_user[i] = (int)tmp[i];
		tmp = arr[2]/"\n";//get day_login
		a_size = sizeof(tmp);
		for(i=0;i<a_size;i++)
			day_login += (<tmp[i]>);
		tmp = arr[3]/"\n";//get day_msg
		a_size = sizeof(tmp);
		for(i=0;i<a_size;i++)
			day_msg += (<tmp[i]>);
	}
	return 1;
}
int write_day_log()
{
	string s,s_mon,s_day,log_file;
	int i,mon,day,total=0;
	mapping now_time = localtime(time());
	mon = now_time["mon"]+1;
	day = now_time["mday"];	
	if(mon<10)
		s_mon = "0"+mon;
	else
		s_mon = (string)mon;
	if(day<10)
		s_day = "0"+day;
	else
		s_day = (string)day;
	log_file = ROOT+"/log/daily/count"+s_mon+s_day+".log";
	s=mon+"-"+day+"统计数据\n注册人数 "+reg_num+"\n注册女id数 "+reg_female_num+"\n";
	s+="当天用户访问数 "+sizeof(day_login)+"\n当天交流次数 "+msg_num+"\n当天交流人次 "+sizeof(day_msg)+"\n\n";
	s+="当天每小时在线人数\n";
	s+="时间 在线人数 区号\n";
	for(i=0;i<24;i++){
		s+=i+" "+online_user[i]+" "+GAME_NAME_S+"\n";
		total+=online_user[i];
	}
	s+="当天平均在线人数："+total/24+"\n";
	Stdio.write_file(log_file,s);
	read_mon_log();
	write_mon_log();	
	reg_num=0;
	reg_female_num=0;
	msg_num=0;
	day_login=(<>);
	day_msg=(<>);
	for(i=0;i<24;i++)
		online_user[i]=0;		
	return 1;
}
int read_mon_log()
{
	string str,s_mon,u_name,log_file;
	int i,t_size,mon,year,log_time;
	array arr,tmp;
	mapping now_time = localtime(time());
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	if(mon<10)
		s_mon = "0"+mon;
	else
		s_mon = (string)mon;
	log_file = ROOT+"/log/month/count"+year+s_mon+".log";
	str = Stdio.read_file(log_file);
	if(str && sizeof(str)){
		arr = str/"\n\n";
		tmp = arr[1]/"\n";
		t_size = sizeof(tmp);
		for(i=0;i<t_size;i++){
			sscanf(tmp[i],"%s:%d",u_name,log_time);
			if(u_name && sizeof(u_name) && log_time)
				mon_login[u_name]=log_time;		
		}
	}
	return 1;
}
int write_mon_log()
{
	string str,s_mon,u_name,log_file;
	int i,mon,year,t_size;
	array arr;
	mapping now_time = localtime(time());
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	if(mon<10)
		s_mon = "0"+mon;
	else
		s_mon = (string)mon;	
	if(sizeof(day_login))
		arr = indices(day_login);
	if(arr && sizeof(arr)){
		foreach(arr,u_name){
			if(mon_login[u_name])
				mon_login[u_name]++;
			else
				mon_login[u_name]=1;
		}
	}
	t_size = sizeof(mon_login);
	str=year+"-"+s_mon+"统计数据\n累计到今天月进入数："+t_size+"\n\n";
	if(t_size){
		arr = indices(mon_login);
		foreach(arr,u_name)
			str+=u_name+":"+mon_login[u_name]+"\n";
	}
	log_file = ROOT+"/log/month/count"+year+s_mon+".log";
	Stdio.write_file(log_file,str);
	mon_login=([]);
	return 1;
}
