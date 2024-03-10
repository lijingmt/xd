#include <command.h>

int main(string arg)
{
	string path,user_name;
        if(arg&&(sscanf(arg,"%s %s",path,user_name)==2))
        {
		if(!user_name)
		{
			write("error1");
			return 1;
		}
		else if( sizeof(user_name)<2 )
		{
			write("error2");
			return 1;
		}
		for(int i=0;i<sizeof(user_name);i++)
		{
			if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			{

			}
			else
			{
				write("error3");
				return 1;
			}
		}
		//取出在线用户列表
		if(user_name!="managerTxAll20060520")
		{
			write("error4");
			return 1;
		}
		else
		{
			string log_file;
			//log_file = ROOT+"txonline/u/";
			log_file = "/usr/local/games/usrdate/u/";
			
			string s_mon,s_day;                                                                           
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

			string logdate = "";
			logdate += year+s_mon+year;

			string cmdget="cd "+log_file+";find *|wc -l > "+log_file+"totalreg."+logdate+".txt";
			Process.system(cmdget);

			string strlist = Stdio.read_file(log_file+"totalreg."+logdate+".txt");
			write(strlist);
			return 1;
		}
	}
	else
	{
		write("error5");
		return 1;
	}
	return 1;
}
