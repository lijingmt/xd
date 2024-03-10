#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
void create()
{
}
string query_cur_time()
{
	//return getTimeLongDesc();	
	return getTimeCurDesc();
}
string getTimeCurDesc()
{
	mapping now_time = localtime(time());                                                                     
	int hour = now_time["hour"];
	int min = now_time["min"];
	int sec = now_time["sec"];

	return ""+hour+":"+min+":"+sec;
}
string getTimeShortDesc()
{
	mapping now_time = localtime(time());                                                                     
	int year = now_time["year"] + 1900;
	int mon = now_time["mon"]+1;                                               
	int day = now_time["mday"];                                                                                 
	return year + "-" + mon + "-" + day;
}
string getTimeLongDesc()
{
	mapping now_time = localtime(time());                                                                     
	int year = now_time["year"] + 1900;
	int mon = now_time["mon"]+1;                                               
	int day = now_time["mday"];                                                                                 
	int hour = now_time["hour"];
	int min = now_time["min"];
	int sec = now_time["sec"];

	return year + "-" + mon + "-" + day  + " " + hour + ":" + min + ":" +sec;
}
string get_user_year_month_day(int time){
	string s_mon,s_day;
	int day,mon,year;
	mapping now_time = localtime(time);
	day = now_time["mday"];
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	if(mon<10)
		s_mon = "0"+mon;
	else
		s_mon = (string)mon;
	if(day<10)
		s_day = "0"+day;
	else
		s_day = (string)day;
	return ""+year+"年"+s_mon+"月"+s_day+"日";
}
string get_user_year_to_second(int time){
	string s_mon,s_day;
	int day,mon,year,hour,min,sec;
	mapping now_time = localtime(time);
	day = now_time["mday"];
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	hour = now_time["hour"];
	min = now_time["min"];
	sec = now_time["sec"];
	if(mon<10)
		s_mon = "0"+mon;
	else
		s_mon = (string)mon;
	if(day<10)
		s_day = "0"+day;
	else
		s_day = (string)day;
	return ""+year+"年"+s_mon+"月"+s_day+"日"+(string)hour+"点"+(string)min+"分"+(string)sec+"秒";
}

//返回剩余时间描述
string get_remainTime_desc(int deadline){
	string time_s = "";
	if(deadline<=time()){
		return time_s;
	}
	else{
		int lastTime = deadline - time();   //剩余时间
		int day = (int)(lastTime/(24*3600));
		int hourTmp = (int)(lastTime%(24*3600));
		int hour = (int)(hourTmp/3600);
		int min = (hourTmp%3600)/60;
		if(day)
			time_s += day+"天";
		if(hour)
			time_s += hour+"小时";
		if(min)
			time_s += min+"分";
	}
	return time_s;
}

//返回拍卖行剩余时间描述
string get_lasttime_desc(int deadline){
	string time_s = "";
	if(deadline<=0)
		return "";
	int lastTime = deadline;
	int day = (int)(lastTime/(24*3600));
	int hourTmp = (int)(lastTime%(24*3600));
	int hour = (int)(hourTmp/3600);
	int min = (hourTmp%3600)/60;
	if(day)
		time_s += day+"天";
	if(hour)
		time_s += hour+"小时";
	if(min)
		time_s += min+"分";
	return time_s;
}
