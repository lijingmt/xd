#include <command.h>

int main(string arg)
{
	string path,user_name,queryData;
        if(arg&&(sscanf(arg,"%s %s %s",path,user_name,queryData)==3))
        {
		if(!user_name)
		{
			write("error");
			return 1;
		}
		else if( sizeof(user_name)<2 )
		{
			write("error");
			return 1;
		}
		for(int i=0;i<sizeof(user_name);i++)
		{
			if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			{

			}
			else
			{
				write("error");
				return 1;
			}
		}
		//取出在线用户列表
		if(user_name!="managerTxAll20060520")
		{
			write("error");
			return 1;
		}
		else
		{
			string getDirCmd="/home/httpd/awstats/data/";
			//得到文件名和日期适配
			/*string s_mon,s_day;                                                                           
        		int year,mon,day=0;                                                                                    
        		mapping now_time = localtime(time());                                                                     
			mon = now_time["mon"]+1;                                                                                  
        		day = now_time["mday"];                                                                                   
			year = now_time["year"]+1900;
			if(mon<10)                                                                                                
        		        s_mon = "0"+mon;                                                                                  
        		else                                                                                                      
                		s_mon = (string)mon;                                                                              
        		if(day<10)                                                                                                
                		s_day = "0"+day;                                                                                  
       	 		else                                                                                                      
                		s_day = (string)day;                                                                              
			*/		
			//string logFile = "awstats"+s_mon+year+".txt";
			//logFile = awstats052006.txt
			//keyValue = 20060523
			//queryData = 20060523
			string spllitYear = "";
			string spllitMonth = "";
			
			for(int i=0; i<4; i++)
				spllitYear += sprintf("%c",queryData[i]);
			for(int j=4; j<6; j++)
				spllitMonth += sprintf("%c",queryData[j]);
			
			string logFile = "awstats"+spllitMonth+spllitYear+".txt";	
			
			array log_detail,day_record;
			string logContent = Stdio.read_file(getDirCmd+logFile);
			
			string day_log = "error";
			int flag = 0;
			
			if(logContent && sizeof(logContent))
			{
				log_detail = logContent/"\n\n";	
				foreach(log_detail, string strLogs)
				{
					day_record = strLogs/"\n";
					foreach(day_record, string strdays)
					{
						if(search(strdays,"BEGIN_DAY")!=-1)
						{
							day_log = strLogs;
							//write("get begin_day !");
							flag = 1;
						}
						if(flag)
							break;
					}
					if(flag)
						break;
				}
			}
			//write(day_log);
			array findday;//,tmp;
			int flagget = 0;
			string getdaypv = "error";
			
			if(flag)
			{
				findday = day_log/"\n";
				foreach(findday, string strtmp)
				{
					if(search(strtmp,queryData)!=-1)
					{
						getdaypv = (strtmp/" ")[2];
						flagget = 1;
					}
					if(flagget)
						break;
				}
			}
			write(getdaypv);
			return 1;
		}
	}
	else
	{
		write("error");
		return 1;
	}
	return 1;
}
