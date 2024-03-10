#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_DAEMON;
void create()
{
}
string get_mysql_timedesc(){
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
	return ""+year+"-"+s_mon+"-"+s_day+" "+s_hour+":"+s_min+":"+s_sec;
}
string get_year_month(){
	string s_mon;
	int mon,year;
	mapping now_time = localtime(time());
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	if(mon<10)
		s_mon = "0"+mon;
	else                                                                                    
		s_mon = (string)mon;
	return ""+year+"-"+s_mon;
}
string get_year_month_day(){
	string s_mon,s_day;
	int day,mon,year;
	mapping now_time = localtime(time());
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
	return ""+year+"-"+s_mon+"-"+s_day;
}
string get_hour_min_sec(){
	string s_hour,s_min,s_sec;
	mapping now_time = localtime(time());                                                                     
	int hour = now_time["hour"];
	int min = now_time["min"];
	int sec = now_time["sec"];
	if(hour<10)
		s_hour = "0"+hour;
	else
		s_hour = (string)hour;
	if(min<10)
		s_min = "0"+min;
	else
		s_min = (string)min;
	if(sec<10)
		s_sec = "0"+sec;
	else
		s_sec = (string)sec;
	return s_hour+":"+s_min+":"+s_sec;
}
