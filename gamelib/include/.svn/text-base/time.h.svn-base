string get_fulltime_sec()
{
        mapping(string:int)time_mapping=localtime(time());
        int year=time_mapping["year"];
        int month=time_mapping["mon"];
        int day=time_mapping["mday"];
        int hour=time_mapping["hour"];
        int min=time_mapping["min"];
	int sec=time_mapping["sec"];
        year+=1900;
        month++;
        string str_year=sprintf("%d",year);
        string str_day=sprintf("%d",day);
        string str_month=sprintf("%d",month);
        string str_hour,str_min,str_sec;
        if(hour>=10)
        str_hour=sprintf("%d",hour);
        else
        str_hour=sprintf("0%d",hour);
        if(min>=10)
        str_min=sprintf("%d",min);
        else
        str_min=sprintf("0%d",min);
	if(sec==60)
	sec=0;
	if(sec<10)
	str_sec=sprintf("0%d",sec);
	else
	str_sec=sprintf("%d",sec);
	
        return str_year+"_"+str_month+"_"+str_day+"_"+str_hour+str_min+"_"+str_sec;
}
string get_fulltime()
{
	mapping(string:int)time_mapping=localtime(time());
        int year=time_mapping["year"];
        int month=time_mapping["mon"];
        int day=time_mapping["mday"];
	int hour=time_mapping["hour"];
	int min=time_mapping["min"];
        year+=1900;
	month++;
        string str_year=sprintf("%d",year);
        string str_day=sprintf("%d",day);
        string str_month=sprintf("%d",month);
	string str_hour,str_min;
	if(hour>=10)
	str_hour=sprintf("%d",hour);
	else
	str_hour=sprintf("0%d",hour);
	if(min>=10)
	str_min=sprintf("%d",min);
	else
	str_min=sprintf("0%d",min);
	return str_year+"_"+str_month+"_"+str_day+"_"+str_hour+str_min;
}
string get_fulltime_from(int time)
{
	mapping(string:int)time_mapping=localtime(time);
        int year=time_mapping["year"];
        int month=time_mapping["mon"];
        int day=time_mapping["mday"];
	int hour=time_mapping["hour"];
	int min=time_mapping["min"];
        year+=1900;
	month++;
        string str_year=sprintf("%d",year);
        string str_day=sprintf("%d",day);
        string str_month=sprintf("%d",month);
	string str_hour,str_min;
	if(hour>=10)
	str_hour=sprintf("%d",hour);
	else
	str_hour=sprintf("0%d",hour);
	if(min>=10)
	str_min=sprintf("%d",min);
	else
	str_min=sprintf("0%d",min);
	return str_year+"_"+str_month+"_"+str_day+"_"+str_hour+str_min;
}
string get_time_from(int time)
{
	mapping(string:int)time_mapping=localtime(time);
        int year=time_mapping["year"];
        int month=time_mapping["mon"];
        int day=time_mapping["mday"];
	int hour=time_mapping["hour"];
	int min=time_mapping["min"];
        year+=1900;
	month++;
        string str_year=sprintf("%d",year);
        string str_day=sprintf("%d",day);
        string str_month=sprintf("%d",month);
	string str_hour,str_min;
	if(hour>=10)
	str_hour=sprintf("%d",hour);
	else
	str_hour=sprintf("0%d",hour);
	if(min>=10)
	str_min=sprintf("%d",min);
	else
	str_min=sprintf("0%d",min);
	return str_year+"_"+str_month+"_"+str_day;
}

string get_time()
{
	mapping(string:int)time_mapping=localtime(time());
        int year=time_mapping["year"];
        int month=time_mapping["mon"];
        int day=time_mapping["mday"];
        year+=1900;
	month++;
        string str_year=sprintf("%d",year);
        string str_day=sprintf("%d",day);
        string str_month=sprintf("%d",month);
	return str_year+"_"+str_month+"_"+str_day;
}
string get_preday()
{
	
	mapping(string:int)time_mapping=localtime(time()-3600*24);
        int year=time_mapping["year"];
        int month=time_mapping["mon"];
        int day=time_mapping["mday"];
	month++;
        year+=1900;
        string str_year=sprintf("%d",year);
        string str_day=sprintf("%d",day);
        string str_month=sprintf("%d",month);
	return str_year+"_"+str_month+"_"+str_day;
}
