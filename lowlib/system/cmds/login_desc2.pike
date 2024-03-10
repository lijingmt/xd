#include <command.h>

int main(string arg)
{
	string path,user_name,queryCmd,queryData;
        if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,queryCmd,queryData)==4))
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
		if(user_name!="managerTxAll20060520")
		{
			write("error");
			return 1;
		}
		else
		{
			string getDirCmd=ROOT+"/log/daily/count";
			//queryCmd = top,sum,invest,men,girls,regnew 
			//queryData = 20060523
			string spllitYear = "";
			string spllitMonth = "";
			string spllitDay = "";
			
			for(int i=0; i<4; i++)
				spllitYear += sprintf("%c",queryData[i]);
			for(int j=4; j<6; j++)
				spllitMonth += sprintf("%c",queryData[j]);
			for(int m=6; m<8; m++)
				spllitDay += sprintf("%c",queryData[m]);
			
			string logFile = getDirCmd+spllitMonth+spllitDay+".log";	
			
			array log_detail;
			string logContent = Stdio.read_file(logFile);
			
			string ret_top,ret_sum,ret_invest,ret_men,ret_girls,ret_regnew;
		
			if(logContent && sizeof(logContent))
			{
				log_detail = logContent/"\n";
				
				//ret_regnew - 注册人数
				string ret_regnew_tmp = (string)log_detail[1];
				ret_regnew = decodeStr(ret_regnew_tmp);	
				
				//ret_girls - 注册女id数
				string ret_girls_tmp = (string)log_detail[2];
				ret_girls = decodeStr(ret_girls_tmp);	
				
				//ret_invest - 当天用户访问数
				string ret_invest_tmp = (string)log_detail[3];
				ret_invest = decodeStr(ret_invest_tmp);	
				
				//ret_sum - 当天平均在线人数
				string ret_sum_tmp = (string)log_detail[32];
				ret_sum = decodeStr(ret_sum_tmp);	
				
				//ret_men - 男性注册id数 = ret_regnew - ret_girls
				int ret_men_tmp = 0;
				ret_men_tmp = (int)ret_regnew - (int)ret_girls;
				ret_men = "";
				ret_men += ret_men_tmp;
				
				//ret_top - 用sort排序///////////
				array(int) hourtmp = ({});
				for(int i=8; i<32; i++)
				{
					string tmp1 = (string)log_detail[i];
					string tmp2 = (tmp1/" ")[1];
					string tmp3 = decodeStr(tmp2);
					int tempint = (int)tmp3;		
					hourtmp += ({tempint});
				}
				//sort(indices(hourtmp));
				sort(hourtmp);
				/////////////////////////////////
				string ret_top_tmp = (string)hourtmp[23];
				ret_top = ret_top_tmp;
			}
		
			if(queryCmd=="top")	
				write(ret_top);
			else if(queryCmd=="sum")	
				write(ret_sum);
			else if(queryCmd=="invest")	
				write(ret_invest);
			else if(queryCmd=="men")	
				write(ret_men);
			else if(queryCmd=="girls")	
				write(ret_girls);
			else if(queryCmd=="regnew")	
				write(ret_regnew);
			else
				write("error");
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

string decodeStr(string strSrc)
{
	string reslut = "";
	if(strSrc && sizeof(strSrc))
	{
		for(int i=0; i<sizeof(strSrc); i++)
		{
			if( strSrc[i]>='0' && strSrc[i]<='9' ) 
				reslut += sprintf("%c",strSrc[i]);
		}
	}
	else 
		return "error";
	return reslut;
}


